import AppKit
import SwiftUI

extension NSAttributedString.Key {
    static let markdownHiddenSyntax = NSAttributedString.Key("LumaNoteMarkdownHiddenSyntax")
}

enum MarkdownDocumentPositionApplicator {
    @MainActor
    static func apply(
        _ position: MarkdownDocumentPosition,
        textView: NSTextView,
        scrollView: MarkdownScrollView?
    ) {
        let textLength = (textView.string as NSString).length
        let location = min(max(0, position.selectedLocation), textLength)
        let maxLength = max(0, textLength - location)
        let length = min(max(0, position.selectedLength), maxLength)
        let savedRange = NSRange(location: location, length: length)
        scrollView?.scroll(toY: CGFloat(position.scrollY))
        let selectedRange = visibleSelectionRange(
            savedRange,
            textLength: textLength,
            textView: textView,
            scrollView: scrollView
        )
        let selectedRanges = [NSValue(range: selectedRange)]
        if let taskTextView = textView as? MarkdownTaskTextView {
            taskTextView.restoreSelectedRangesWithoutScroll(selectedRanges)
        } else {
            textView.selectedRanges = selectedRanges
        }
        scrollView?.scroll(toY: CGFloat(position.scrollY))
    }

    @MainActor
    private static func visibleSelectionRange(
        _ savedRange: NSRange,
        textLength: Int,
        textView: NSTextView,
        scrollView: MarkdownScrollView?
    ) -> NSRange {
        guard let visibleRange = visibleCharacterRange(textView: textView, scrollView: scrollView),
              visibleRange.length > 0,
              !NSLocationInRange(savedRange.location, visibleRange)
        else { return savedRange }

        let location = min(max(0, visibleRange.location), textLength)
        return NSRange(location: location, length: 0)
    }

    @MainActor
    private static func visibleCharacterRange(
        textView: NSTextView,
        scrollView: MarkdownScrollView?
    ) -> NSRange? {
        guard let scrollView,
              let documentView = scrollView.documentView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer
        else { return nil }

        layoutManager.ensureLayout(for: textContainer)
        let visibleRect = textView.convert(documentView.visibleRect, from: documentView)
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        return layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
    }
}

struct MarkdownRenderingEditorInteractionMode: Equatable {
    let isEditable: Bool
    let isSelectable: Bool
    let allowsUndo: Bool
    let observesDocumentPosition: Bool

    static let editable = MarkdownRenderingEditorInteractionMode(
        isEditable: true,
        isSelectable: true,
        allowsUndo: true,
        observesDocumentPosition: true
    )

    static let readOnlyPreview = MarkdownRenderingEditorInteractionMode(
        isEditable: false,
        isSelectable: false,
        allowsUndo: false,
        observesDocumentPosition: false
    )
}

/// Applies the complete Markdown presentation in one place so the live editor
/// and the static swipe snapshot cannot drift in their active-selection rules.
@MainActor
enum MarkdownEditorStyling {
    static func apply(
        to textView: NSTextView,
        fontSize: CGFloat,
        activeSelectionRanges: [NSRange]
    ) {
        guard let storage = textView.textStorage else { return }
        let selectedRanges = textView.selectedRanges
        let fullRange = NSRange(location: 0, length: storage.length)
        guard fullRange.length > 0 else {
            if let taskTextView = textView as? MarkdownTaskTextView {
                taskTextView.taskItems = []
                taskTextView.codeBlocks = []
                taskTextView.headingItems = []
                taskTextView.clearHiddenSyntaxRanges()
            }
            return
        }

        let styles = MarkdownStyleAttributes(fontSize: fontSize)
        storage.beginEditing()
        storage.setAttributes(styles.baseAttributes(), range: fullRange)
        let blockResult = MarkdownBlockStyler.styleBlocks(
            in: storage,
            activeSelectionRanges: activeSelectionRanges,
            fontSize: fontSize,
            attributes: styles
        )
        MarkdownInlineStyler.styleInline(
            in: storage,
            excluding: blockResult.inlineExclusionRanges,
            activeSelectionRanges: activeSelectionRanges,
            attributes: styles
        )
        storage.endEditing()

        if let taskTextView = textView as? MarkdownTaskTextView {
            taskTextView.taskItems = blockResult.taskItems
            taskTextView.codeBlocks = blockResult.codeBlocks
            taskTextView.headingItems = blockResult.headingItems
            taskTextView.updateHiddenSyntaxRanges(from: storage)
            taskTextView.restoreSelectedRangesWithoutScroll(selectedRanges)
        } else {
            textView.selectedRanges = selectedRanges
        }
    }
}

struct MarkdownRenderingEditor: NSViewRepresentable {
    @Binding var text: String
    var documentID: String = ""
    var contentRevision: Int = 0
    var fontSize: Double = MarkdownTaskLayout.defaultBaseFontSize
    var accentColor: NSColor = .systemCyan
    var documentPosition: MarkdownDocumentPosition?
    var emphasisCommand: MarkdownEmphasisCommand?
    var onDocumentPositionChange: ((MarkdownDocumentPosition) -> Void)?
    var interactionMode: MarkdownRenderingEditorInteractionMode = .editable

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            documentID: documentID,
            contentRevision: contentRevision,
            fontSize: CGFloat(fontSize),
            interactionMode: interactionMode,
            onDocumentPositionChange: onDocumentPositionChange
        )
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = MarkdownScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder

        let textView = MarkdownTaskTextView()
        textView.delegate = interactionMode.isEditable ? context.coordinator : nil
        textView.drawsBackground = false
        textView.isRichText = false
        textView.isEditable = interactionMode.isEditable
        textView.isSelectable = interactionMode.isSelectable
        textView.allowsUndo = interactionMode.allowsUndo
        textView.importsGraphics = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.enabledTextCheckingTypes = 0
        textView.smartInsertDeleteEnabled = false
        textView.textContainerInset = NSSize(width: 0, height: 10)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.layoutManager?.delegate = textView
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.insertionPointColor = accentColor
        textView.bodyFontSize = context.coordinator.fontSize
        textView.taskAccentColor = accentColor
        textView.typingAttributes = context.coordinator.baseTypingAttributes()
        textView.string = text

        scrollView.setMarkdownTextView(textView)
        scrollView.refreshScrollIndicator()
        context.coordinator.textView = textView
        if interactionMode.observesDocumentPosition {
            context.coordinator.observeScrollView(scrollView)
        }
        context.coordinator.applyDocumentPosition(
            documentPosition ?? .top,
            scrollView: scrollView
        )
        context.coordinator.applyMarkdownStyle()
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let markdownScrollView = scrollView as? MarkdownScrollView
        guard let textView = markdownScrollView?.markdownTextView ?? scrollView.documentView as? NSTextView else { return }
        var didReplaceText = false
        let didChangeDocument = context.coordinator.documentID != documentID
        let newFontSize = MarkdownTaskLayout.normalizedFontSize(CGFloat(fontSize))
        let didChangeFontSize = abs(context.coordinator.fontSize - newFontSize) > 0.05
        let didChangeTextRevision = context.coordinator.contentRevision != contentRevision
        let taskTextView = textView as? MarkdownTaskTextView
        let didChangeAccentColor = taskTextView.map { !$0.taskAccentColor.isEqual(accentColor) } ?? false
        context.coordinator.interactionMode = interactionMode
        textView.delegate = interactionMode.isEditable ? context.coordinator : nil
        textView.isEditable = interactionMode.isEditable
        textView.isSelectable = interactionMode.isSelectable
        textView.allowsUndo = interactionMode.allowsUndo
        context.coordinator.onDocumentPositionChange = interactionMode.observesDocumentPosition ? onDocumentPositionChange : nil
        if interactionMode.observesDocumentPosition {
            markdownScrollView.map { context.coordinator.observeScrollView($0) }
        } else {
            context.coordinator.stopObservingScrollView()
        }
        if didChangeFontSize {
            context.coordinator.fontSize = newFontSize
            taskTextView?.bodyFontSize = newFontSize
            textView.typingAttributes = context.coordinator.baseTypingAttributes()
        }
        if didChangeAccentColor {
            textView.insertionPointColor = accentColor
            taskTextView?.taskAccentColor = accentColor
        }
        if didChangeTextRevision, textView.string != text {
            if textView.hasMarkedText() {
                context.coordinator.replaceDocumentSafely(
                    text: text,
                    documentID: documentID,
                    contentRevision: contentRevision,
                    documentPosition: documentPosition ?? .top,
                    scrollView: markdownScrollView
                )
            } else {
                context.coordinator.contentRevision = contentRevision
                textView.string = text
                context.coordinator.applyDocumentPosition(
                    documentPosition ?? .top,
                    scrollView: markdownScrollView
                )
            }
            didReplaceText = true
        } else if didChangeTextRevision {
            context.coordinator.contentRevision = contentRevision
        }
        if didChangeDocument {
            if !didReplaceText {
                context.coordinator.replaceDocumentSafely(
                    text: text,
                    documentID: documentID,
                    contentRevision: contentRevision,
                    documentPosition: documentPosition ?? .top,
                    scrollView: markdownScrollView
                )
            } else {
                context.coordinator.documentID = documentID
            }
        }
        if didReplaceText || didChangeFontSize {
            context.coordinator.applyMarkdownStyle()
            markdownScrollView?.invalidateDocumentHeight()
            markdownScrollView?.refreshScrollIndicator()
        } else if didChangeAccentColor {
            textView.needsDisplay = true
            markdownScrollView?.refreshScrollIndicator()
        }
        if let emphasisCommand,
           context.coordinator.lastAppliedEmphasisCommandID != emphasisCommand.id {
            context.coordinator.lastAppliedEmphasisCommandID = emphasisCommand.id
            context.coordinator.applyEmphasis(styles: emphasisCommand.styles)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var text: String
        var documentID: String
        var contentRevision: Int
        var fontSize: CGFloat
        var interactionMode: MarkdownRenderingEditorInteractionMode
        var onDocumentPositionChange: ((MarkdownDocumentPosition) -> Void)?
        weak var textView: NSTextView?
        private var isStyling = false
        private var isApplyingDocumentPosition = false
        private var isReplacingDocument = false
        private var lastStyledSelectionRanges: [NSRange] = []
        private weak var observedClipView: NSClipView?
        private var lastEmittedPosition: MarkdownDocumentPosition?
        var lastAppliedEmphasisCommandID: Int?
        private var styles: MarkdownStyleAttributes {
            MarkdownStyleAttributes(fontSize: fontSize)
        }

        init(
            text: Binding<String>,
            documentID: String = "",
            contentRevision: Int,
            fontSize: CGFloat,
            interactionMode: MarkdownRenderingEditorInteractionMode = .editable,
            onDocumentPositionChange: ((MarkdownDocumentPosition) -> Void)? = nil
        ) {
            _text = text
            self.documentID = documentID
            self.contentRevision = contentRevision
            self.fontSize = MarkdownTaskLayout.normalizedFontSize(fontSize)
            self.interactionMode = interactionMode
            self.onDocumentPositionChange = interactionMode.observesDocumentPosition ? onDocumentPositionChange : nil
        }

        deinit {
            if let observedClipView {
                NotificationCenter.default.removeObserver(
                    self,
                    name: NSView.boundsDidChangeNotification,
                    object: observedClipView
                )
            }
        }

        func observeScrollView(_ scrollView: MarkdownScrollView) {
            guard interactionMode.observesDocumentPosition else { return }
            guard observedClipView !== scrollView.contentView else { return }
            if let observedClipView {
                NotificationCenter.default.removeObserver(
                    self,
                    name: NSView.boundsDidChangeNotification,
                    object: observedClipView
                )
            }
            observedClipView = scrollView.contentView
            scrollView.contentView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(scrollPositionDidChange(_:)),
                name: NSView.boundsDidChangeNotification,
                object: scrollView.contentView
            )
        }

        func stopObservingScrollView() {
            guard let observedClipView else { return }
            NotificationCenter.default.removeObserver(
                self,
                name: NSView.boundsDidChangeNotification,
                object: observedClipView
            )
            observedClipView.postsBoundsChangedNotifications = false
            self.observedClipView = nil
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            let markdownScrollView = textView.enclosingScrollView as? MarkdownScrollView
            guard !isReplacingDocument else {
                markdownScrollView?.invalidateDocumentHeight()
                markdownScrollView?.refreshScrollIndicator()
                return
            }
            guard !textView.hasMarkedText() else {
                markdownScrollView?.invalidateDocumentHeight()
                markdownScrollView?.refreshScrollIndicator()
                return
            }
            text = textView.string
            applyMarkdownStyle()
            markdownScrollView?.invalidateDocumentHeight()
            markdownScrollView?.refreshScrollIndicator()
            emitDocumentPosition()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isStyling,
                  !isApplyingDocumentPosition,
                  !isReplacingDocument,
                  let textView,
                  !textView.hasMarkedText(),
                  MarkdownRangeHelpers.nsRanges(from: textView.selectedRanges) != lastStyledSelectionRanges
            else { return }
            applyMarkdownStyle()
            emitDocumentPosition()
        }

        func applyMarkdownStyle() {
            guard let textView, !isStyling else { return }
            guard !textView.hasMarkedText() else { return }
            isStyling = true
            defer { isStyling = false }

            let selectedRanges = textView.selectedRanges
            let activeSelectionRanges = MarkdownRangeHelpers.nsRanges(from: selectedRanges)
            lastStyledSelectionRanges = activeSelectionRanges
            MarkdownEditorStyling.apply(
                to: textView,
                fontSize: fontSize,
                activeSelectionRanges: activeSelectionRanges
            )
        }

        /// Ends an IME composition in an isolated transaction before replacing
        /// the bound document. AppKit may emit a final text-change callback when
        /// `unmarkText()` commits the composition; the guard prevents that old
        /// document payload from being written into the new binding.
        func replaceDocumentSafely(
            text: String,
            documentID: String,
            contentRevision: Int,
            documentPosition: MarkdownDocumentPosition,
            scrollView: MarkdownScrollView?
        ) {
            guard let textView else { return }
            isReplacingDocument = true
            isApplyingDocumentPosition = true
            defer {
                isApplyingDocumentPosition = false
                isReplacingDocument = false
            }

            if textView.hasMarkedText() {
                textView.unmarkText()
            }
            self.documentID = documentID
            self.contentRevision = contentRevision
            textView.string = text
            textView.undoManager?.removeAllActions()
            MarkdownDocumentPositionApplicator.apply(
                documentPosition,
                textView: textView,
                scrollView: scrollView
            )
            applyMarkdownStyle()
            lastEmittedPosition = currentDocumentPosition()
        }

        func baseTypingAttributes() -> [NSAttributedString.Key: Any] {
            styles.baseAttributes()
        }

        func applyEmphasis(styles: MarkdownEmphasisStyle) {
            guard let textView, !textView.hasMarkedText() else { return }
            let oldText = textView.string
            let result = MarkdownEmphasisFormatting.apply(
                styles: styles,
                to: oldText,
                selectedRange: textView.selectedRange()
            )
            guard result.text != oldText || result.selectedRange != textView.selectedRange() else { return }

            let fullRange = NSRange(location: 0, length: (oldText as NSString).length)
            guard textView.shouldChangeText(in: fullRange, replacementString: result.text) else { return }
            textView.textStorage?.replaceCharacters(in: fullRange, with: result.text)
            text = result.text
            textView.setSelectedRange(result.selectedRange)
            textView.didChangeText()
            textView.typingAttributes = baseTypingAttributes()
            applyMarkdownStyle()
            if let markdownScrollView = textView.enclosingScrollView as? MarkdownScrollView {
                markdownScrollView.invalidateDocumentHeight()
                markdownScrollView.refreshScrollIndicator()
            }
            emitDocumentPosition()
        }

        func applyDocumentPosition(
            _ position: MarkdownDocumentPosition,
            scrollView: MarkdownScrollView?
        ) {
            guard let textView else { return }
            isApplyingDocumentPosition = true
            MarkdownDocumentPositionApplicator.apply(
                position,
                textView: textView,
                scrollView: scrollView
            )
            lastEmittedPosition = currentDocumentPosition()
            isApplyingDocumentPosition = false
        }

        @objc private func scrollPositionDidChange(_ notification: Notification) {
            emitDocumentPosition()
        }

        private func emitDocumentPosition() {
            guard !isApplyingDocumentPosition else { return }
            guard let position = currentDocumentPosition() else { return }
            guard position != lastEmittedPosition else { return }
            lastEmittedPosition = position
            onDocumentPositionChange?(position)
        }

        private func currentDocumentPosition() -> MarkdownDocumentPosition? {
            guard let textView,
                  let scrollView = textView.enclosingScrollView as? MarkdownScrollView
            else { return nil }
            let selectedRange = textView.selectedRange()
            return MarkdownDocumentPosition(
                selectedLocation: selectedRange.location,
                selectedLength: selectedRange.length,
                scrollY: Double(scrollView.contentView.bounds.origin.y)
            )
        }
    }
}
