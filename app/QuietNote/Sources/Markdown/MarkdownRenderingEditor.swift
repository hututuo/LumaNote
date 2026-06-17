import AppKit
import SwiftUI

extension NSAttributedString.Key {
    static let markdownHiddenSyntax = NSAttributedString.Key("LumaNoteMarkdownHiddenSyntax")
}

struct MarkdownRenderingEditor: NSViewRepresentable {
    @Binding var text: String
    var contentRevision: Int = 0
    var fontSize: Double = MarkdownTaskLayout.defaultBaseFontSize
    var accentColor: NSColor = .systemCyan

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, contentRevision: contentRevision, fontSize: CGFloat(fontSize))
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = MarkdownScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder

        let textView = MarkdownTaskTextView()
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
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
        context.coordinator.applyMarkdownStyle()
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let markdownScrollView = scrollView as? MarkdownScrollView
        guard let textView = markdownScrollView?.markdownTextView ?? scrollView.documentView as? NSTextView else { return }
        var didReplaceText = false
        let newFontSize = MarkdownTaskLayout.normalizedFontSize(CGFloat(fontSize))
        let didChangeFontSize = abs(context.coordinator.fontSize - newFontSize) > 0.05
        let didChangeTextRevision = context.coordinator.contentRevision != contentRevision
        let taskTextView = textView as? MarkdownTaskTextView
        let didChangeAccentColor = taskTextView.map { !$0.taskAccentColor.isEqual(accentColor) } ?? false
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
            guard !textView.hasMarkedText() else { return }
            context.coordinator.contentRevision = contentRevision
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
            didReplaceText = true
        } else if didChangeTextRevision {
            context.coordinator.contentRevision = contentRevision
        }
        if didReplaceText || didChangeFontSize {
            context.coordinator.applyMarkdownStyle()
            markdownScrollView?.invalidateDocumentHeight()
            markdownScrollView?.refreshScrollIndicator()
        } else if didChangeAccentColor {
            textView.needsDisplay = true
            markdownScrollView?.refreshScrollIndicator()
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var text: String
        var contentRevision: Int
        var fontSize: CGFloat
        weak var textView: NSTextView?
        private var isStyling = false
        private var lastStyledSelectionRanges: [NSRange] = []
        private var styles: MarkdownStyleAttributes {
            MarkdownStyleAttributes(fontSize: fontSize)
        }

        init(text: Binding<String>, contentRevision: Int, fontSize: CGFloat) {
            _text = text
            self.contentRevision = contentRevision
            self.fontSize = MarkdownTaskLayout.normalizedFontSize(fontSize)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            let markdownScrollView = textView.enclosingScrollView as? MarkdownScrollView
            guard !textView.hasMarkedText() else {
                markdownScrollView?.invalidateDocumentHeight()
                markdownScrollView?.refreshScrollIndicator()
                return
            }
            text = textView.string
            applyMarkdownStyle()
            markdownScrollView?.invalidateDocumentHeight()
            markdownScrollView?.refreshScrollIndicator()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isStyling,
                  let textView,
                  !textView.hasMarkedText(),
                  MarkdownRangeHelpers.nsRanges(from: textView.selectedRanges) != lastStyledSelectionRanges
            else { return }
            applyMarkdownStyle()
        }

        func applyMarkdownStyle() {
            guard let textView, !isStyling else { return }
            guard !textView.hasMarkedText() else { return }
            isStyling = true
            defer { isStyling = false }

            let selectedRanges = textView.selectedRanges
            let activeSelectionRanges = MarkdownRangeHelpers.nsRanges(from: selectedRanges)
            lastStyledSelectionRanges = activeSelectionRanges
            let storage = textView.textStorage ?? NSTextStorage()
            let fullRange = NSRange(location: 0, length: storage.length)
            guard fullRange.length > 0 else {
                (textView as? MarkdownTaskTextView)?.taskItems = []
                (textView as? MarkdownTaskTextView)?.codeBlocks = []
                (textView as? MarkdownTaskTextView)?.headingItems = []
                return
            }

            let styles = self.styles
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
            }
            if let taskTextView = textView as? MarkdownTaskTextView {
                taskTextView.restoreSelectedRangesWithoutScroll(selectedRanges)
            } else {
                textView.selectedRanges = selectedRanges
            }
        }

        func baseTypingAttributes() -> [NSAttributedString.Key: Any] {
            styles.baseAttributes()
        }
    }
}
