import AppKit
import SwiftUI

private enum MarkdownTaskLayout {
    static let baseFontSize: CGFloat = 15.5
    static let checkboxSize: CGFloat = 13
    static let checkboxTextGap: CGFloat = 5
    static let slotWidth: CGFloat = checkboxSize + checkboxTextGap

    static var baseFont: NSFont {
        NSFont.systemFont(ofSize: baseFontSize)
    }

    static func textWidth(_ text: String) -> CGFloat {
        NSAttributedString(string: text, attributes: [.font: baseFont]).size().width
    }
}

struct MarkdownRenderingEditor: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
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
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.insertionPointColor = .systemCyan
        textView.string = text

        scrollView.documentView = textView
        scrollView.refreshScrollIndicator()
        context.coordinator.textView = textView
        context.coordinator.applyMarkdownStyle()
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
        }
        context.coordinator.applyMarkdownStyle()
        (scrollView as? MarkdownScrollView)?.refreshScrollIndicator()
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var text: String
        weak var textView: NSTextView?
        private var isStyling = false

        init(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            text = textView.string
            applyMarkdownStyle()
        }

        func applyMarkdownStyle() {
            guard let textView, !isStyling else { return }
            isStyling = true
            defer { isStyling = false }

            let selectedRanges = textView.selectedRanges
            let storage = textView.textStorage ?? NSTextStorage()
            let fullRange = NSRange(location: 0, length: storage.length)
            guard fullRange.length > 0 else {
                (textView as? MarkdownTaskTextView)?.taskItems = []
                return
            }

            storage.beginEditing()
            storage.setAttributes(Self.baseAttributes(), range: fullRange)
            let taskItems = styleBlocks(in: storage)
            styleInline(in: storage)
            storage.endEditing()
            (textView as? MarkdownTaskTextView)?.taskItems = taskItems
            textView.selectedRanges = selectedRanges
        }

        private func styleBlocks(in storage: NSTextStorage) -> [MarkdownTaskTextView.TaskItem] {
            let nsString = storage.string as NSString
            let fullRange = NSRange(location: 0, length: nsString.length)
            var codeFenceMarker: String?
            var taskItems: [MarkdownTaskTextView.TaskItem] = []

            nsString.enumerateSubstrings(in: fullRange, options: [.byLines, .substringNotRequired]) { _, lineRange, _, _ in
                let line = nsString.substring(with: lineRange)
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }

                if let marker = codeFenceMarker {
                    if trimmed.hasPrefix(marker) {
                        storage.addAttributes(Self.codeFenceAttributes(), range: lineRange)
                        codeFenceMarker = nil
                    } else {
                        storage.addAttributes(Self.codeBlockAttributes(), range: lineRange)
                    }
                    return
                }

                if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                    storage.addAttributes(Self.codeFenceAttributes(), range: lineRange)
                    codeFenceMarker = trimmed.hasPrefix("~~~") ? "~~~" : "```"
                    return
                }

                if trimmed == "---" || trimmed == "***" {
                    storage.addAttributes(Self.ruleAttributes(), range: lineRange)
                    return
                }

                if let heading = Self.headingLevel(in: line) {
                    storage.addAttributes(Self.headingAttributes(level: heading.level), range: lineRange)
                    storage.addAttributes(Self.markerAttributes(), range: NSRange(location: lineRange.location, length: heading.markerLength))
                    return
                }

                if let alert = Self.alertPrefix(in: line, lineRange: lineRange) {
                    storage.addAttributes(Self.alertAttributes(kind: alert.kind, level: alert.level), range: lineRange)
                    storage.addAttributes(Self.markerAttributes(), range: alert.markerRange)
                    storage.addAttributes(Self.alertKindAttributes(kind: alert.kind), range: alert.kindRange)
                    return
                }

                if let quote = Self.quotePrefix(in: line, lineRange: lineRange) {
                    storage.addAttributes(Self.quoteAttributes(level: quote.level), range: lineRange)
                    storage.addAttributes(Self.markerAttributes(), range: quote.markerRange)
                    return
                }

                if let reference = Self.prefixRange(pattern: #"^\s*\[[^\]]+\]:\s+\S+"#, in: line, lineRange: lineRange) {
                    storage.addAttributes(Self.referenceDefinitionAttributes(), range: lineRange)
                    storage.addAttributes(Self.markerAttributes(), range: reference)
                    return
                }

                if let marker = Self.prefixRange(pattern: #"^\s*!\[[^\]]*\]\([^)]+\)"#, in: line, lineRange: lineRange) {
                    storage.addAttributes(Self.imageAttributes(), range: lineRange)
                    storage.addAttributes(Self.markerAttributes(), range: marker)
                    return
                }

                if let task = Self.taskPrefix(in: line, lineRange: lineRange) {
                    storage.addAttributes(Self.taskAttributes(done: task.done, indentationWidth: task.indentationWidth), range: lineRange)
                    storage.addAttributes(task.markerAttributes, range: task.markerRange)
                    taskItems.append(
                        MarkdownTaskTextView.TaskItem(
                            markerRange: task.markerRange,
                            stateRange: task.stateRange,
                            indentationWidth: task.indentationWidth,
                            done: task.done
                        )
                    )
                    return
                }

                if let list = Self.listPrefix(in: line, lineRange: lineRange) {
                    storage.addAttributes(Self.listAttributes(indentationWidth: list.indentationWidth), range: lineRange)
                    storage.addAttributes(Self.markerAttributes(), range: list.markerRange)
                    return
                }

                if Self.isTableLikeLine(line) {
                    storage.addAttributes(Self.tableAttributes(), range: lineRange)
                }
            }

            return taskItems
        }

        private func styleInline(in storage: NSTextStorage) {
            let fullRange = NSRange(location: 0, length: storage.length)
            apply(pattern: #"`([^`]+)`"#, attributes: Self.inlineCodeAttributes(), in: storage, range: fullRange)
            apply(pattern: #"\*\*\*([^*\n]+)\*\*\*"#, attributes: Self.boldItalicAttributes(), in: storage, range: fullRange)
            apply(pattern: #"___([^_\n]+)___"#, attributes: Self.boldItalicAttributes(), in: storage, range: fullRange)
            apply(pattern: #"\*\*([^*]+)\*\*"#, attributes: [.font: NSFont.boldSystemFont(ofSize: 15.5)], in: storage, range: fullRange)
            apply(pattern: #"__([^_]+)__"#, attributes: [.font: NSFont.boldSystemFont(ofSize: 15.5)], in: storage, range: fullRange)
            apply(pattern: #"(?<!\*)\*([^*\n]+)\*(?!\*)"#, attributes: [.obliqueness: 0.12], in: storage, range: fullRange)
            apply(pattern: #"(?<!_)_([^_\n]+)_(?!_)"#, attributes: [.obliqueness: 0.12], in: storage, range: fullRange)
            apply(pattern: #"~~([^~]+)~~"#, attributes: [.strikethroughStyle: NSUnderlineStyle.single.rawValue], in: storage, range: fullRange)
            apply(pattern: #"==([^=\n]+)=="#, attributes: Self.highlightAttributes(), in: storage, range: fullRange)
            apply(pattern: #"!\[([^\]]*)\]\(([^)]+)\)"#, attributes: Self.imageAttributes(), in: storage, range: fullRange)
            apply(pattern: #"\[([^\]]+)\]\(([^)\s]+)(?:\s+["'][^"']*["'])?\)"#, attributes: Self.linkAttributes(), in: storage, range: fullRange)
            apply(pattern: #"\[[^\]]+\]\[[^\]]*\]"#, attributes: Self.linkAttributes(), in: storage, range: fullRange)
            apply(pattern: #"\[\[[^\]\n]+\]\]"#, attributes: Self.wikiLinkAttributes(), in: storage, range: fullRange)
            apply(pattern: #"<https?://[^>\s]+>"#, attributes: Self.linkAttributes(), in: storage, range: fullRange)
            apply(pattern: #"<[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}>"#, attributes: Self.linkAttributes(), in: storage, range: fullRange)
            apply(pattern: #"https?://[^\s<>"']+"#, attributes: Self.linkAttributes(), in: storage, range: fullRange)
            apply(pattern: #"(?<![/\w.-])[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}(?![\w.-])"#, attributes: Self.linkAttributes(), in: storage, range: fullRange)
            apply(pattern: #":[a-zA-Z0-9_+-]+:"#, attributes: Self.shortcodeAttributes(), in: storage, range: fullRange)
        }

        private func apply(
            pattern: String,
            attributes: [NSAttributedString.Key: Any],
            in storage: NSTextStorage,
            range: NSRange
        ) {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            regex.matches(in: storage.string, range: range).forEach { match in
                storage.addAttributes(attributes, range: match.range)
            }
        }

        private static func headingLevel(in line: String) -> (level: Int, markerLength: Int)? {
            let markerLength = line.prefix { $0 == "#" }.count
            guard (1...6).contains(markerLength),
                  line.dropFirst(markerLength).first == " "
            else { return nil }
            return (markerLength, markerLength + 1)
        }

        private static func alertPrefix(
            in line: String,
            lineRange: NSRange
        ) -> (markerRange: NSRange, kindRange: NSRange, kind: String, level: Int)? {
            let pattern = #"^(\s*(?:>\s*)+)\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]"#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                  let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length))
            else { return nil }

            let marker = match.range(at: 1)
            let kind = match.range(at: 2)
            let markerText = (line as NSString).substring(with: marker)
            return (
                NSRange(location: lineRange.location + marker.location, length: marker.length),
                NSRange(location: lineRange.location + kind.location, length: kind.length),
                (line as NSString).substring(with: kind).uppercased(),
                markerText.filter { $0 == ">" }.count
            )
        }

        private static func quotePrefix(
            in line: String,
            lineRange: NSRange
        ) -> (markerRange: NSRange, level: Int)? {
            guard let regex = try? NSRegularExpression(pattern: #"^\s*(?:>\s*)+"#),
                  let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length))
            else { return nil }

            let markerText = (line as NSString).substring(with: match.range)
            return (
                NSRange(location: lineRange.location + match.range.location, length: match.range.length),
                markerText.filter { $0 == ">" }.count
            )
        }

        private static func listPrefix(
            in line: String,
            lineRange: NSRange
        ) -> (markerRange: NSRange, indentationWidth: CGFloat)? {
            let pattern = #"^([ \t]*)(?:[-*+]|\d+\.)\s+"#
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length))
            else { return nil }

            let indentation = match.range(at: 1)
            let indentationText = (line as NSString).substring(with: indentation)
            return (
                NSRange(location: lineRange.location + match.range.location, length: match.range.length),
                MarkdownTaskLayout.textWidth(indentationText)
            )
        }

        private static func isTableLikeLine(_ line: String) -> Bool {
            let pipeCount = line.filter { $0 == "|" }.count
            return pipeCount >= 2
        }

        private static func prefixRange(pattern: String, in line: String, lineRange: NSRange) -> NSRange? {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length))
            else { return nil }
            return NSRange(location: lineRange.location + match.range.location, length: match.range.length)
        }

        private static func taskPrefix(
            in line: String,
            lineRange: NSRange
        ) -> (
            markerRange: NSRange,
            stateRange: NSRange,
            indentationWidth: CGFloat,
            markerAttributes: [NSAttributedString.Key: Any],
            done: Bool
        )? {
            let pattern = #"^([ \t]*)([-*]\s+\[)([ xX])(\])([ \t]*)"#
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length))
            else { return nil }

            let markerRange = NSRange(location: lineRange.location + match.range.location, length: match.range.length)
            let indentation = match.range(at: 1)
            let indentationText = (line as NSString).substring(with: indentation)
            let indentationWidth = MarkdownTaskLayout.textWidth(indentationText)

            let markerText = (line as NSString).substring(with: match.range)
            let rawMarkerWidth = max(1, MarkdownTaskLayout.textWidth(markerText))
            let desiredMarkerWidth = indentationWidth + MarkdownTaskLayout.slotWidth
            let markerLength = max(1, (markerText as NSString).length)
            let markerKern = (desiredMarkerWidth - rawMarkerWidth) / CGFloat(markerLength)
            let markerAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.clear,
                .font: MarkdownTaskLayout.baseFont,
                .kern: markerKern
            ]

            let state = match.range(at: 3)
            let stateRange = NSRange(location: lineRange.location + state.location, length: state.length)
            let stateText = (line as NSString).substring(with: state)
            return (
                markerRange,
                stateRange,
                indentationWidth,
                markerAttributes,
                stateText.localizedCaseInsensitiveCompare("x") == .orderedSame
            )
        }

        private static func baseAttributes() -> [NSAttributedString.Key: Any] {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 3
            paragraph.paragraphSpacing = 7
            return [
                .font: NSFont.systemFont(ofSize: 15.5),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraph
            ]
        }

        private static func headingAttributes(level: Int) -> [NSAttributedString.Key: Any] {
            let size: CGFloat
            switch level {
            case 1: size = 24
            case 2: size = 20
            case 3: size = 17
            default: size = 15.5
            }

            let paragraph = NSMutableParagraphStyle()
            paragraph.paragraphSpacingBefore = level == 1 ? 6 : 4
            paragraph.paragraphSpacing = 9
            return [
                .font: NSFont.boldSystemFont(ofSize: size),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraph
            ]
        }

        private static func quoteAttributes(level: Int) -> [NSAttributedString.Key: Any] {
            let paragraph = NSMutableParagraphStyle()
            let indent = CGFloat(max(1, level)) * 12
            paragraph.headIndent = indent
            paragraph.firstLineHeadIndent = indent
            paragraph.lineSpacing = 4
            return [
                .font: NSFont.systemFont(ofSize: 15.5),
                .foregroundColor: NSColor.secondaryLabelColor,
                .obliqueness: 0.12,
                .paragraphStyle: paragraph
            ]
        }

        private static func alertAttributes(kind: String, level: Int) -> [NSAttributedString.Key: Any] {
            var attributes = quoteAttributes(level: level)
            attributes[.backgroundColor] = alertColor(kind: kind).withAlphaComponent(0.08)
            return attributes
        }

        private static func alertKindAttributes(kind: String) -> [NSAttributedString.Key: Any] {
            [
                .font: NSFont.boldSystemFont(ofSize: 13),
                .foregroundColor: alertColor(kind: kind)
            ]
        }

        private static func taskAttributes(done: Bool, indentationWidth: CGFloat) -> [NSAttributedString.Key: Any] {
            let paragraph = NSMutableParagraphStyle()
            let contentIndent = indentationWidth + MarkdownTaskLayout.slotWidth
            paragraph.headIndent = contentIndent
            paragraph.firstLineHeadIndent = 0
            paragraph.lineSpacing = 3
            paragraph.tabStops = [
                NSTextTab(textAlignment: .left, location: contentIndent)
            ]
            paragraph.defaultTabInterval = contentIndent

            if done {
                return [
                    NSAttributedString.Key.foregroundColor: NSColor.secondaryLabelColor,
                    NSAttributedString.Key.strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    NSAttributedString.Key.paragraphStyle: paragraph
                ]
            }

            return [
                NSAttributedString.Key.foregroundColor: NSColor.labelColor,
                NSAttributedString.Key.paragraphStyle: paragraph
            ]
        }

        private static func listAttributes(indentationWidth: CGFloat) -> [NSAttributedString.Key: Any] {
            let paragraph = NSMutableParagraphStyle()
            let contentIndent = indentationWidth + 18
            paragraph.headIndent = contentIndent
            paragraph.firstLineHeadIndent = indentationWidth
            paragraph.lineSpacing = 3
            return [.paragraphStyle: paragraph]
        }

        private static func tableAttributes() -> [NSAttributedString.Key: Any] {
            [
                .font: NSFont.monospacedSystemFont(ofSize: 13.5, weight: .regular),
                .backgroundColor: NSColor.controlAccentColor.withAlphaComponent(0.06)
            ]
        }

        private static func codeFenceAttributes() -> [NSAttributedString.Key: Any] {
            [
                .font: NSFont.monospacedSystemFont(ofSize: 13.5, weight: .semibold),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        }

        private static func codeBlockAttributes() -> [NSAttributedString.Key: Any] {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 2
            paragraph.paragraphSpacing = 2
            return [
                .font: NSFont.monospacedSystemFont(ofSize: 13.5, weight: .regular),
                .foregroundColor: NSColor.labelColor,
                .backgroundColor: NSColor.black.withAlphaComponent(0.07),
                .paragraphStyle: paragraph
            ]
        }

        private static func inlineCodeAttributes() -> [NSAttributedString.Key: Any] {
            [
                .font: NSFont.monospacedSystemFont(ofSize: 13.5, weight: .regular),
                .backgroundColor: NSColor.black.withAlphaComponent(0.08)
            ]
        }

        private static func boldItalicAttributes() -> [NSAttributedString.Key: Any] {
            [
                .font: NSFont.boldSystemFont(ofSize: 15.5),
                .obliqueness: 0.12
            ]
        }

        private static func highlightAttributes() -> [NSAttributedString.Key: Any] {
            [
                .backgroundColor: NSColor.systemYellow.withAlphaComponent(0.24)
            ]
        }

        private static func linkAttributes() -> [NSAttributedString.Key: Any] {
            [
                .foregroundColor: NSColor.systemBlue,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
        }

        private static func wikiLinkAttributes() -> [NSAttributedString.Key: Any] {
            [
                .foregroundColor: NSColor.systemPurple,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
        }

        private static func imageAttributes() -> [NSAttributedString.Key: Any] {
            [
                .foregroundColor: NSColor.systemTeal,
                .font: NSFont.monospacedSystemFont(ofSize: 13.5, weight: .medium),
                .backgroundColor: NSColor.systemTeal.withAlphaComponent(0.08)
            ]
        }

        private static func referenceDefinitionAttributes() -> [NSAttributedString.Key: Any] {
            [
                .font: NSFont.monospacedSystemFont(ofSize: 13.5, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        }

        private static func shortcodeAttributes() -> [NSAttributedString.Key: Any] {
            [
                .foregroundColor: NSColor.systemOrange,
                .font: NSFont.monospacedSystemFont(ofSize: 13.5, weight: .regular)
            ]
        }

        private static func markerAttributes() -> [NSAttributedString.Key: Any] {
            [
                .foregroundColor: NSColor.tertiaryLabelColor,
                .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            ]
        }

        private static func ruleAttributes() -> [NSAttributedString.Key: Any] {
            [
                .foregroundColor: NSColor.tertiaryLabelColor,
                .strikethroughStyle: NSUnderlineStyle.thick.rawValue
            ]
        }

        private static func alertColor(kind: String) -> NSColor {
            switch kind.uppercased() {
            case "TIP": return .systemGreen
            case "IMPORTANT": return .systemPurple
            case "WARNING": return .systemOrange
            case "CAUTION": return .systemRed
            default: return .systemBlue
            }
        }
    }
}

private final class MarkdownScrollView: NSScrollView {
    private let scrollIndicator = MarkdownScrollIndicatorView()
    private var isRefreshingScrollIndicator = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        installScrollIndicator()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        installScrollIndicator()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override var documentView: NSView? {
        didSet {
            observeScrollGeometry()
            refreshScrollIndicator()
        }
    }

    override func scrollWheel(with event: NSEvent) {
        scrollIndicator.markActive()
        super.scrollWheel(with: event)
        refreshScrollIndicator()
    }

    override func layout() {
        super.layout()
        layoutScrollIndicator()
        refreshScrollIndicator()
    }

    func refreshScrollIndicator() {
        guard !isRefreshingScrollIndicator else { return }
        isRefreshingScrollIndicator = true
        defer { isRefreshingScrollIndicator = false }

        layoutScrollIndicator()

        guard let documentView else {
            scrollIndicator.isHidden = true
            return
        }

        let viewportHeight = max(1, contentView.bounds.height)
        let documentHeight = measuredDocumentHeight(for: documentView, viewportHeight: viewportHeight)
        guard documentHeight > viewportHeight + 1 else {
            scrollIndicator.isHidden = true
            return
        }

        let maxOffset = max(1, documentHeight - viewportHeight)
        let offset = min(max(scrollOffset(for: documentView, documentHeight: documentHeight), 0), maxOffset)
        let progress = offset / maxOffset
        let thumbHeight = max(24, viewportHeight / documentHeight * scrollIndicator.bounds.height)

        scrollIndicator.isHidden = false
        scrollIndicator.update(progress: progress, thumbHeight: thumbHeight)
    }

    private func installScrollIndicator() {
        drawsBackground = false
        addSubview(scrollIndicator, positioned: .above, relativeTo: nil)
        observeScrollGeometry()
    }

    private func observeScrollGeometry() {
        NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSView.frameDidChangeNotification, object: nil)

        contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scrollGeometryDidChange),
            name: NSView.boundsDidChangeNotification,
            object: contentView
        )

        documentView?.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scrollGeometryDidChange),
            name: NSView.frameDidChangeNotification,
            object: documentView
        )
    }

    private func layoutScrollIndicator() {
        let width: CGFloat = 5
        let x = max(0, bounds.width - width + 2)
        let y = contentView.frame.minY + 2
        let height = max(0, contentView.frame.height - 4)
        scrollIndicator.frame = NSRect(x: x, y: y, width: width, height: height)
    }

    private func measuredDocumentHeight(for documentView: NSView, viewportHeight: CGFloat) -> CGFloat {
        guard let textView = documentView as? NSTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer
        else {
            return max(viewportHeight, documentView.bounds.height, documentView.frame.height)
        }

        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        let contentHeight = ceil(usedRect.maxY + textView.textContainerInset.height * 2)
        return max(viewportHeight, contentHeight)
    }

    private func scrollOffset(for documentView: NSView, documentHeight: CGFloat) -> CGFloat {
        let visibleRect = documentView.visibleRect
        if documentView.isFlipped {
            return visibleRect.minY
        }
        return documentHeight - visibleRect.maxY
    }

    @objc private func scrollGeometryDidChange() {
        refreshScrollIndicator()
    }
}

private final class MarkdownScrollIndicatorView: NSView {
    private var isPointerInside = false
    private var isRecentlyActive = false
    private var visualProgress: CGFloat = 0
    private var scrollProgress: CGFloat = 0
    private var thumbHeight: CGFloat = 24
    private var trackingAreaToken: NSTrackingArea?
    private var idleGeneration = 0
    private var animationGeneration = 0

    override var isFlipped: Bool {
        true
    }

    override func updateTrackingAreas() {
        if let trackingAreaToken {
            removeTrackingArea(trackingAreaToken)
        }

        let area = NSTrackingArea(
            rect: .zero,
            options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited],
            owner: self
        )
        addTrackingArea(area)
        trackingAreaToken = area
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        setPointerInside(true)
        super.mouseEntered(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        setPointerInside(false)
        super.mouseExited(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let progress = min(max(visualProgress, 0), 1)
        let knobWidth = 2 + progress * 1
        let availableTravel = max(0, bounds.height - thumbHeight)
        let y = availableTravel * min(max(scrollProgress, 0), 1)
        let knobRect = NSRect(
            x: (bounds.width - knobWidth) / 2,
            y: y,
            width: knobWidth,
            height: thumbHeight
        ).insetBy(dx: 0, dy: 1.5 - progress * 0.8)

        guard knobRect.height > 8 else { return }
        NSColor.systemGray.withAlphaComponent(0.36 + progress * 0.2).setFill()
        NSBezierPath(roundedRect: knobRect, xRadius: knobRect.width / 2, yRadius: knobRect.width / 2).fill()
    }

    func update(progress: CGFloat, thumbHeight: CGFloat) {
        scrollProgress = min(max(progress, 0), 1)
        self.thumbHeight = min(max(thumbHeight, 24), max(24, bounds.height))
        needsDisplay = true
    }

    func markActive() {
        isRecentlyActive = true
        animateVisibility(to: targetVisualProgress)
        idleGeneration += 1
        let generation = idleGeneration

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard let self, self.idleGeneration == generation else { return }
            self.isRecentlyActive = false
            self.animateVisibility(to: self.targetVisualProgress)
        }
    }

    private func setPointerInside(_ value: Bool) {
        isPointerInside = value
        animateVisibility(to: targetVisualProgress)
    }

    private var targetVisualProgress: CGFloat {
        isPointerInside || isRecentlyActive ? 1 : 0
    }

    private func animateVisibility(to target: CGFloat) {
        animationGeneration += 1
        let generation = animationGeneration
        let start = visualProgress
        let distance = target - start

        guard abs(distance) > 0.01 else {
            visualProgress = target
            needsDisplay = true
            return
        }

        Task { @MainActor [weak self] in
            let frames = 12
            for frame in 1...frames {
                guard let self, self.animationGeneration == generation else { return }
                let t = CGFloat(frame) / CGFloat(frames)
                let eased = 1 - pow(1 - t, 3)
                self.visualProgress = start + distance * eased
                self.needsDisplay = true
                try? await Task.sleep(for: .seconds(0.015))
            }
            guard let self, self.animationGeneration == generation else { return }
            self.visualProgress = target
            self.needsDisplay = true
        }
    }
}

private final class MarkdownTaskTextView: NSTextView {
    struct TaskItem {
        let markerRange: NSRange
        let stateRange: NSRange
        let indentationWidth: CGFloat
        let done: Bool
    }

    var taskItems: [TaskItem] = [] {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawTaskCheckboxes()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let item = taskItems.first(where: { checkboxRect(for: $0).insetBy(dx: -4, dy: -4).contains(point) }) {
            toggleTask(item)
            return
        }
        super.mouseDown(with: event)
    }

    override func insertNewline(_ sender: Any?) {
        guard completeTaskListNewline() else {
            super.insertNewline(sender)
            return
        }
    }

    private func toggleTask(_ item: TaskItem) {
        guard shouldChangeText(in: item.stateRange, replacementString: item.done ? " " : "x") else { return }
        textStorage?.replaceCharacters(in: item.stateRange, with: item.done ? " " : "x")
        didChangeText()
    }

    private func completeTaskListNewline() -> Bool {
        guard selectedRange().length == 0 else { return false }

        let text = string as NSString
        let insertionLocation = selectedRange().location
        let lineRange = text.lineRange(for: NSRange(location: max(0, insertionLocation - 1), length: 0))
        let line = text.substring(with: lineRange).trimmingCharacters(in: .newlines)
        let contentBeforeCursorLength = max(0, insertionLocation - lineRange.location)
        let contentBeforeCursor = (line as NSString).substring(to: min(contentBeforeCursorLength, (line as NSString).length))

        guard let indentation = Self.taskContinuationPrefix(in: contentBeforeCursor) else { return false }

        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if Self.isEmptyTaskLine(trimmed) {
            let contentLineRange = NSRange(location: lineRange.location, length: (line as NSString).length)
            guard shouldChangeText(in: contentLineRange, replacementString: "") else { return true }
            textStorage?.replaceCharacters(in: contentLineRange, with: "")
            didChangeText()
            setSelectedRange(NSRange(location: lineRange.location, length: 0))
            typingAttributes = Self.baseTypingAttributes()
            return true
        }

        let insertion = "\n\(indentation)- [ ] "
        guard shouldChangeText(in: selectedRange(), replacementString: insertion) else { return true }
        insertText(insertion, replacementRange: selectedRange())
        typingAttributes = Self.baseTypingAttributes()
        return true
    }

    private static func baseTypingAttributes() -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        paragraph.paragraphSpacing = 7
        return [
            .font: NSFont.systemFont(ofSize: 15.5),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]
    }

    private static func taskContinuationPrefix(in linePrefix: String) -> String? {
        let pattern = #"^(\s*)[-*]\s+\[[ xX]\][ \t]*"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              regex.firstMatch(in: linePrefix, range: NSRange(location: 0, length: (linePrefix as NSString).length)) != nil
        else { return nil }

        let indentation = String(linePrefix.prefix { $0 == " " || $0 == "\t" })
        return indentation
    }

    private static func isEmptyTaskLine(_ trimmed: String) -> Bool {
        trimmed == "- [ ]" || trimmed == "* [ ]" || trimmed == "- [x]" || trimmed == "- [X]" || trimmed == "* [x]" || trimmed == "* [X]"
    }

    private func drawTaskCheckboxes() {
        guard let layoutManager, let textContainer else { return }
        layoutManager.ensureLayout(for: textContainer)

        for item in taskItems {
            let rect = checkboxRect(for: item)
            let box = NSBezierPath(roundedRect: rect, xRadius: 3.2, yRadius: 3.2)
            NSColor.controlBackgroundColor.withAlphaComponent(0.35).setFill()
            box.fill()

            (item.done ? NSColor.systemCyan : NSColor.tertiaryLabelColor).setStroke()
            box.lineWidth = item.done ? 1.8 : 1.2
            box.stroke()

            guard item.done else { continue }
            let check = NSBezierPath()
            check.move(to: NSPoint(x: rect.minX + 3.4, y: rect.midY + 0.4))
            check.line(to: NSPoint(x: rect.minX + 6.4, y: rect.maxY - 3.8))
            check.line(to: NSPoint(x: rect.maxX - 3.2, y: rect.minY + 3.4))
            NSColor.systemCyan.setStroke()
            check.lineWidth = 1.8
            check.lineCapStyle = .round
            check.lineJoinStyle = .round
            check.stroke()
        }
    }

    private func checkboxRect(for item: TaskItem) -> NSRect {
        guard let layoutManager, let textContainer else { return .zero }
        let firstGlyphIndex = layoutManager.glyphIndexForCharacter(at: item.markerRange.location)
        let lineRect = layoutManager.lineFragmentRect(forGlyphAt: firstGlyphIndex, effectiveRange: nil)
        let origin = textContainerOrigin
        let size = MarkdownTaskLayout.checkboxSize
        return NSRect(
            x: origin.x + lineRect.minX + textContainer.lineFragmentPadding + item.indentationWidth,
            y: origin.y + lineRect.midY - size / 2,
            width: size,
            height: size
        )
    }
}
