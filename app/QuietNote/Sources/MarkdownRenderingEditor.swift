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
        let scrollView = NSScrollView()
        let verticalScroller = ThinOverlayScroller()
        verticalScroller.controlSize = .mini
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.borderType = .noBorder
        scrollView.verticalScroller = verticalScroller

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
            var inCodeFence = false
            var taskItems: [MarkdownTaskTextView.TaskItem] = []

            nsString.enumerateSubstrings(in: fullRange, options: [.byLines, .substringNotRequired]) { _, lineRange, _, _ in
                let line = nsString.substring(with: lineRange)
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }

                if trimmed.hasPrefix("```") {
                    storage.addAttributes(Self.codeFenceAttributes(), range: lineRange)
                    inCodeFence.toggle()
                    return
                }

                if inCodeFence {
                    storage.addAttributes(Self.codeBlockAttributes(), range: lineRange)
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

                if let marker = Self.prefixRange(pattern: #"^\s*>\s?"#, in: line, lineRange: lineRange) {
                    storage.addAttributes(Self.quoteAttributes(), range: lineRange)
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

                if let marker = Self.prefixRange(pattern: #"^\s*[-*+]\s+"#, in: line, lineRange: lineRange) {
                    storage.addAttributes(Self.listAttributes(), range: lineRange)
                    storage.addAttributes(Self.markerAttributes(), range: marker)
                    return
                }

                if let marker = Self.prefixRange(pattern: #"^\s*\d+\.\s+"#, in: line, lineRange: lineRange) {
                    storage.addAttributes(Self.listAttributes(), range: lineRange)
                    storage.addAttributes(Self.markerAttributes(), range: marker)
                    return
                }

                if line.contains("|") {
                    storage.addAttributes(Self.tableAttributes(), range: lineRange)
                }
            }

            return taskItems
        }

        private func styleInline(in storage: NSTextStorage) {
            let fullRange = NSRange(location: 0, length: storage.length)
            apply(pattern: #"`([^`]+)`"#, attributes: Self.inlineCodeAttributes(), in: storage, range: fullRange)
            apply(pattern: #"\*\*([^*]+)\*\*"#, attributes: [.font: NSFont.boldSystemFont(ofSize: 15.5)], in: storage, range: fullRange)
            apply(pattern: #"__([^_]+)__"#, attributes: [.font: NSFont.boldSystemFont(ofSize: 15.5)], in: storage, range: fullRange)
            apply(pattern: #"(?<!\*)\*([^*\n]+)\*(?!\*)"#, attributes: [.obliqueness: 0.12], in: storage, range: fullRange)
            apply(pattern: #"~~([^~]+)~~"#, attributes: [.strikethroughStyle: NSUnderlineStyle.single.rawValue], in: storage, range: fullRange)
            apply(pattern: #"\[([^\]]+)\]\(([^)]+)\)"#, attributes: Self.linkAttributes(), in: storage, range: fullRange)
            apply(pattern: #"https?://[^\s<>"']+"#, attributes: Self.linkAttributes(), in: storage, range: fullRange)
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

        private static func quoteAttributes() -> [NSAttributedString.Key: Any] {
            let paragraph = NSMutableParagraphStyle()
            paragraph.headIndent = 12
            paragraph.firstLineHeadIndent = 12
            paragraph.lineSpacing = 4
            return [
                .font: NSFont.systemFont(ofSize: 15.5),
                .foregroundColor: NSColor.secondaryLabelColor,
                .obliqueness: 0.12,
                .paragraphStyle: paragraph
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

        private static func listAttributes() -> [NSAttributedString.Key: Any] {
            let paragraph = NSMutableParagraphStyle()
            paragraph.headIndent = 18
            paragraph.firstLineHeadIndent = 0
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

        private static func linkAttributes() -> [NSAttributedString.Key: Any] {
            [
                .foregroundColor: NSColor.systemBlue,
                .underlineStyle: NSUnderlineStyle.single.rawValue
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
    }
}

private final class ThinOverlayScroller: NSScroller {
    override class func scrollerWidth(
        for controlSize: NSControl.ControlSize,
        scrollerStyle: NSScroller.Style
    ) -> CGFloat {
        if scrollerStyle == .overlay {
            return 5
        }
        return super.scrollerWidth(for: controlSize, scrollerStyle: scrollerStyle)
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
