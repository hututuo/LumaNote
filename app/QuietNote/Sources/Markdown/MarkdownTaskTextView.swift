import AppKit

enum MarkdownTaskLayout {
    static let defaultBaseFontSize: CGFloat = 15.5

    static func normalizedFontSize(_ fontSize: CGFloat) -> CGFloat {
        min(max(fontSize, 11), 28)
    }

    static func baseFont(for fontSize: CGFloat) -> NSFont {
        NSFont.systemFont(ofSize: normalizedFontSize(fontSize))
    }

    static func monoFontSize(for fontSize: CGFloat) -> CGFloat {
        max(10, normalizedFontSize(fontSize) - 2)
    }

    static func markerFontSize(for fontSize: CGFloat) -> CGFloat {
        max(10, normalizedFontSize(fontSize) - 2.5)
    }

    static func checkboxSize(for fontSize: CGFloat) -> CGFloat {
        max(10, normalizedFontSize(fontSize) - 2.5)
    }

    static func checkboxTextGap(for fontSize: CGFloat) -> CGFloat {
        max(4, normalizedFontSize(fontSize) * 0.32)
    }

    static func slotWidth(for fontSize: CGFloat) -> CGFloat {
        checkboxSize(for: fontSize) + checkboxTextGap(for: fontSize)
    }

    static func textWidth(_ text: String, fontSize: CGFloat) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: baseFont(for: fontSize)]).width
    }
}

final class MarkdownTaskLayoutMetrics {
    let fontSize: CGFloat
    let baseFont: NSFont
    let slotWidth: CGFloat

    private var widthCache: [String: CGFloat] = [:]

    init(fontSize: CGFloat) {
        self.fontSize = MarkdownTaskLayout.normalizedFontSize(fontSize)
        baseFont = MarkdownTaskLayout.baseFont(for: self.fontSize)
        slotWidth = MarkdownTaskLayout.slotWidth(for: self.fontSize)
    }

    func textWidth(_ text: String) -> CGFloat {
        if let cached = widthCache[text] {
            return cached
        }
        let width = (text as NSString).size(withAttributes: [.font: baseFont]).width
        widthCache[text] = width
        return width
    }
}

final class MarkdownTaskTextView: NSTextView, @preconcurrency NSLayoutManagerDelegate {
    struct TaskItem {
        let markerRange: NSRange
        let stateRange: NSRange
        let indentationWidth: CGFloat
        let done: Bool
    }

    struct CodeBlockItem {
        let blockRange: NSRange
        let contentRange: NSRange
        let openingFenceRange: NSRange
        let closingFenceRange: NSRange?
        let language: String?
        let isActive: Bool
    }

    struct HeadingItem {
        let lineRange: NSRange
        let level: Int
    }

    var bodyFontSize: CGFloat = MarkdownTaskLayout.defaultBaseFontSize {
        didSet {
            bodyFontSize = MarkdownTaskLayout.normalizedFontSize(bodyFontSize)
            typingAttributes = baseTypingAttributes()
            needsDisplay = true
        }
    }

    var taskAccentColor: NSColor = .systemCyan {
        didSet { needsDisplay = true }
    }

    var taskItems: [TaskItem] = [] {
        didSet { needsDisplay = true }
    }

    var codeBlocks: [CodeBlockItem] = [] {
        didSet {
            if let copiedCodeBlockRange,
               !codeBlocks.contains(where: { NSEqualRanges($0.blockRange, copiedCodeBlockRange) }) {
                clearCodeBlockCopiedFeedback()
            }
            needsDisplay = true
        }
    }

    var headingItems: [HeadingItem] = [] {
        didSet { needsDisplay = true }
    }

    private var copiedCodeBlockRange: NSRange?
    private var suppressSelectionScrollForUserEvent = false
    private var selectionScrollSuppressionGeneration = 0

    private static let codeCopyFeedbackDuration: TimeInterval = 1.15

    override func draw(_ dirtyRect: NSRect) {
        drawCodeBlockBackgrounds(in: dirtyRect)
        super.draw(dirtyRect)
        drawHeadingSeparators(in: dirtyRect)
        drawCodeBlockChrome(in: dirtyRect)
        drawTaskCheckboxes(in: dirtyRect)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let item = codeBlocks.first(where: { codeBlockCopyButtonRect(for: $0).insetBy(dx: -5, dy: -4).contains(point) }) {
            copyCodeBlock(item)
            return
        }
        if let item = taskItems.first(where: { checkboxRect(for: $0).insetBy(dx: -4, dy: -4).contains(point) }) {
            toggleTask(item)
            return
        }
        suppressSelectionScrollForCurrentUserEvent {
            super.mouseDown(with: event)
        }
    }

    override func scrollRangeToVisible(_ range: NSRange) {
        if suppressSelectionScrollForUserEvent {
            return
        }
        super.scrollRangeToVisible(range)
    }

    func restoreSelectedRangesWithoutScroll(_ ranges: [NSValue]) {
        suppressSelectionScrollForCurrentUserEvent {
            selectedRanges = ranges
        }
    }

    func layoutManager(
        _ layoutManager: NSLayoutManager,
        shouldGenerateGlyphs glyphs: UnsafePointer<CGGlyph>,
        properties props: UnsafePointer<NSLayoutManager.GlyphProperty>,
        characterIndexes charIndexes: UnsafePointer<Int>,
        font aFont: NSFont,
        forGlyphRange glyphRange: NSRange
    ) -> Int {
        guard let textStorage else { return 0 }

        var properties: [NSLayoutManager.GlyphProperty] = []
        properties.reserveCapacity(glyphRange.length)
        var didHideSyntax = false

        for index in 0..<glyphRange.length {
            var property = props[index]
            let characterIndex = charIndexes[index]
            if characterIndex >= 0,
               characterIndex < textStorage.length,
               textStorage.attribute(.markdownHiddenSyntax, at: characterIndex, effectiveRange: nil) != nil {
                property.insert(.null)
                didHideSyntax = true
            }
            properties.append(property)
        }

        guard didHideSyntax else { return 0 }

        properties.withUnsafeBufferPointer { propertyBuffer in
            guard let baseAddress = propertyBuffer.baseAddress else { return }
            layoutManager.setGlyphs(
                glyphs,
                properties: baseAddress,
                characterIndexes: charIndexes,
                font: aFont,
                forGlyphRange: glyphRange
            )
        }
        return glyphRange.length
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
            typingAttributes = baseTypingAttributes()
            return true
        }

        let insertion = "\n\(indentation)- [ ] "
        guard shouldChangeText(in: selectedRange(), replacementString: insertion) else { return true }
        insertText(insertion, replacementRange: selectedRange())
        typingAttributes = baseTypingAttributes()
        return true
    }

    private func baseTypingAttributes() -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        paragraph.paragraphSpacing = 7
        return [
            .font: NSFont.systemFont(ofSize: bodyFontSize),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]
    }

    private func suppressSelectionScrollForCurrentUserEvent(_ body: () -> Void) {
        selectionScrollSuppressionGeneration += 1
        let generation = selectionScrollSuppressionGeneration
        let clipView = enclosingScrollView?.contentView
        let scrollOrigin = clipView?.bounds.origin
        suppressSelectionScrollForUserEvent = true
        body()
        restoreScrollOrigin(scrollOrigin, in: clipView)
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  self.selectionScrollSuppressionGeneration == generation
            else { return }
            self.restoreScrollOrigin(scrollOrigin, in: clipView)
            self.suppressSelectionScrollForUserEvent = false
        }
    }

    private func restoreScrollOrigin(_ origin: NSPoint?, in clipView: NSClipView?) {
        guard let origin, let clipView else { return }
        clipView.scroll(to: origin)
        enclosingScrollView?.reflectScrolledClipView(clipView)
    }

    private static func taskContinuationPrefix(in linePrefix: String) -> String? {
        guard Self.taskContinuationRegex.firstMatch(
            in: linePrefix,
            range: NSRange(location: 0, length: (linePrefix as NSString).length)
        ) != nil
        else { return nil }

        let indentation = String(linePrefix.prefix { $0 == " " || $0 == "\t" })
        return indentation
    }

    private static let taskContinuationRegex: NSRegularExpression = {
        do {
            return try NSRegularExpression(pattern: #"^(\s*)[-*]\s+\[[ xX]\][ \t]*"#)
        } catch {
            preconditionFailure("Invalid task continuation regex")
        }
    }()

    private static func isEmptyTaskLine(_ trimmed: String) -> Bool {
        trimmed == "- [ ]" || trimmed == "* [ ]" || trimmed == "- [x]" || trimmed == "- [X]" || trimmed == "* [x]" || trimmed == "* [X]"
    }

    private func drawHeadingSeparators(in dirtyRect: NSRect) {
        guard !headingItems.isEmpty,
              let layoutManager,
              let textContainer
        else { return }

        let origin = textContainerOrigin
        let horizontalInset = textContainer.lineFragmentPadding

        for item in headingItems where item.level <= 3 {
            guard let range = clampedRange(item.lineRange, upperBound: string.utf16.count),
                  range.length > 0
            else { continue }

            let characterIndex = min(range.location + max(0, range.length - 1), max(0, string.utf16.count - 1))
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: characterIndex)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            let y = origin.y + lineRect.maxY + (item.level == 1 ? 5 : 3)
            let rect = NSRect(
                x: origin.x + horizontalInset,
                y: y,
                width: max(0, bounds.width - origin.x * 2 - horizontalInset * 2),
                height: 1
            )
            guard rect.intersects(dirtyRect.insetBy(dx: -2, dy: -4)) else { continue }

            NSColor.separatorColor.withAlphaComponent(item.level == 1 ? 0.22 : 0.14).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 0.5, yRadius: 0.5).fill()
        }
    }

    private func drawCodeBlockBackgrounds(in dirtyRect: NSRect) {
        guard !codeBlocks.isEmpty else { return }

        for item in codeBlocks {
            let rect = codeBlockRect(for: item)
            guard !rect.isEmpty, rect.intersects(dirtyRect) else { continue }

            let path = NSBezierPath(roundedRect: rect, xRadius: 9, yRadius: 9)
            NSColor.controlBackgroundColor.withAlphaComponent(0.56).setFill()
            path.fill()

            NSColor.separatorColor.withAlphaComponent(0.42).setStroke()
            path.lineWidth = 1
            path.stroke()
        }
    }

    private func drawCodeBlockChrome(in dirtyRect: NSRect) {
        guard !codeBlocks.isEmpty else { return }

        for item in codeBlocks {
            let rect = codeBlockRect(for: item)
            guard !rect.isEmpty, rect.intersects(dirtyRect) else { continue }

            let headerRect = codeBlockHeaderRect(for: item, blockRect: rect)
            let dividerY = headerRect.maxY - 3
            if dividerY < rect.maxY - 4 {
                NSColor.separatorColor.withAlphaComponent(0.24).setStroke()
                let divider = NSBezierPath()
                divider.move(to: NSPoint(x: rect.minX + 10, y: dividerY))
                divider.line(to: NSPoint(x: rect.maxX - 10, y: dividerY))
                divider.lineWidth = 1
                divider.stroke()
            }

            if !item.isActive {
                let title = item.language?.isEmpty == false ? item.language! : "代码"
                let titleAttributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: max(10, bodyFontSize - 4), weight: .semibold),
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
                NSAttributedString(string: title, attributes: titleAttributes).draw(
                    in: headerRect.insetBy(dx: 8, dy: max(0, (headerRect.height - 14) / 2))
                )
            }

            let buttonRect = codeBlockCopyButtonRect(for: item, blockRect: rect)
            let buttonVisualRect = buttonRect.insetBy(dx: 1.25, dy: 1.5)
            let downwardOffset: CGFloat = isFlipped ? 0.7 : -0.7
            let buttonChromeRect = buttonVisualRect.insetBy(dx: 2.5, dy: 0).offsetBy(dx: 0, dy: downwardOffset)
            let iconUpwardOffset: CGFloat = isFlipped ? -0.5 : 0.5
            let buttonIconRect = buttonVisualRect.offsetBy(dx: 0, dy: iconUpwardOffset)
            let buttonPath = NSBezierPath(
                roundedRect: buttonChromeRect,
                xRadius: 3.5,
                yRadius: 3.5
            )
            taskAccentColor.withAlphaComponent(0.12).setFill()
            buttonPath.fill()
            taskAccentColor.withAlphaComponent(0.28).setStroke()
            buttonPath.lineWidth = 0.8
            buttonPath.stroke()

            if isCodeBlockCopied(item) {
                drawCopiedIcon(in: buttonIconRect)
            } else {
                drawCopyIcon(in: buttonIconRect)
            }
        }
    }

    private func copyCodeBlock(_ item: CodeBlockItem) {
        let nsText = string as NSString
        guard let range = clampedRange(item.contentRange, upperBound: nsText.length) else { return }
        let code = nsText.substring(with: range).trimmingCharacters(in: .newlines)
        NSPasteboard.general.clearContents()
        if NSPasteboard.general.setString(code, forType: .string) {
            showCodeBlockCopiedFeedback(for: item)
        }
    }

    private func showCodeBlockCopiedFeedback(for item: CodeBlockItem) {
        cancelCodeBlockCopiedFeedbackReset()
        copiedCodeBlockRange = item.blockRange
        setNeedsDisplay(codeBlockCopyButtonRect(for: item).insetBy(dx: -6, dy: -6))
        perform(
            #selector(resetCodeBlockCopiedFeedbackIfNeeded),
            with: nil,
            afterDelay: Self.codeCopyFeedbackDuration
        )
    }

    private func isCodeBlockCopied(_ item: CodeBlockItem) -> Bool {
        guard let copiedCodeBlockRange else { return false }
        return NSEqualRanges(copiedCodeBlockRange, item.blockRange)
    }

    private func clearCodeBlockCopiedFeedback() {
        cancelCodeBlockCopiedFeedbackReset()
        copiedCodeBlockRange = nil
    }

    private func cancelCodeBlockCopiedFeedbackReset() {
        NSObject.cancelPreviousPerformRequests(
            withTarget: self,
            selector: #selector(resetCodeBlockCopiedFeedbackIfNeeded),
            object: nil
        )
    }

    @objc private func resetCodeBlockCopiedFeedbackIfNeeded() {
        guard let copiedCodeBlockRange else { return }
        let copiedItem = codeBlocks.first { NSEqualRanges($0.blockRange, copiedCodeBlockRange) }
        self.copiedCodeBlockRange = nil
        if let copiedItem {
            setNeedsDisplay(codeBlockCopyButtonRect(for: copiedItem).insetBy(dx: -6, dy: -6))
        } else {
            needsDisplay = true
        }
    }

    private func drawCopyIcon(in rect: NSRect) {
        let iconScale: CGFloat = 0.765
        let squareSize = min(rect.height * 0.62, rect.width * 0.38) * iconScale
        let offset = max(2.5, squareSize * 0.34)
        let groupSize = squareSize + offset
        let verticalOffset: CGFloat = isFlipped ? 1 : -1
        let origin = NSPoint(x: rect.midX - groupSize / 2, y: rect.midY - groupSize / 2 + verticalOffset)
        let backRect = NSRect(x: origin.x, y: origin.y, width: squareSize, height: squareSize)
        let frontRect = backRect.offsetBy(dx: offset, dy: offset)

        taskAccentColor.withAlphaComponent(0.62).setStroke()
        let backPath = NSBezierPath(roundedRect: backRect, xRadius: 2, yRadius: 2)
        backPath.lineWidth = 1.3
        backPath.stroke()

        let frontPath = NSBezierPath(roundedRect: frontRect, xRadius: 2, yRadius: 2)
        frontPath.lineWidth = 1.3
        frontPath.stroke()
    }

    private func drawCopiedIcon(in rect: NSRect) {
        let verticalDirection: CGFloat = isFlipped ? 1 : -1
        let iconScale: CGFloat = 0.765
        let midY = rect.midY + (isFlipped ? 1 : -1)
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.midX - 5.5 * iconScale, y: midY + verticalDirection * 0.2 * iconScale))
        path.line(to: NSPoint(x: rect.midX - 1.6 * iconScale, y: midY + verticalDirection * 4.2 * iconScale))
        path.line(to: NSPoint(x: rect.midX + 6 * iconScale, y: midY - verticalDirection * 4.5 * iconScale))
        path.lineWidth = 1.9
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        taskAccentColor.withAlphaComponent(0.68).setStroke()
        path.stroke()
    }

    private func codeBlockRect(for item: CodeBlockItem) -> NSRect {
        guard let layoutManager,
              let textContainer,
              let range = clampedRange(item.blockRange, upperBound: string.utf16.count),
              range.length > 0
        else { return .zero }

        guard let glyphRange = exactGlyphRange(forCharacterRange: range, layoutManager: layoutManager) else {
            return .zero
        }
        guard glyphRange.length > 0 else { return .zero }

        var union = NSRect.null
        let visibleCharacterEnd = range.location + range.length
        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { lineRect, _, _, lineGlyphRange, _ in
            let lineCharacterRange = layoutManager.characterRange(forGlyphRange: lineGlyphRange, actualGlyphRange: nil)
            guard lineCharacterRange.location < visibleCharacterEnd else { return }
            union = union.isNull ? lineRect : union.union(lineRect)
        }
        guard !union.isNull else { return .zero }

        let origin = textContainerOrigin
        let pageWidth = max(0, min(textContainer.containerSize.width, bounds.width - origin.x * 2))
        let horizontalInset = textContainer.lineFragmentPadding + 6
        let topPadding: CGFloat = 3
        let bottomPadding: CGFloat = -2
        let minimumWidth = min(140, pageWidth)
        let width = max(minimumWidth, pageWidth - horizontalInset * 2)
        return NSRect(
            x: origin.x + (pageWidth - width) / 2,
            y: origin.y + union.minY - topPadding,
            width: width,
            height: union.height + topPadding + bottomPadding
        )
    }

    private func exactGlyphRange(forCharacterRange range: NSRange, layoutManager: NSLayoutManager) -> NSRange? {
        let textLength = string.utf16.count
        guard range.location != NSNotFound,
              range.length > 0,
              range.location < textLength
        else { return nil }

        let firstCharacter = range.location
        let lastCharacter = min(textLength - 1, range.location + range.length - 1)
        let firstGlyph = layoutManager.glyphIndexForCharacter(at: firstCharacter)
        let lastGlyph = layoutManager.glyphIndexForCharacter(at: lastCharacter)
        guard lastGlyph >= firstGlyph else { return nil }
        return NSRange(location: firstGlyph, length: lastGlyph - firstGlyph + 1)
    }

    private func codeBlockHeaderRect(for item: CodeBlockItem, blockRect: NSRect) -> NSRect {
        guard let layoutManager,
              let textContainer,
              let range = clampedRange(item.openingFenceRange, upperBound: string.utf16.count),
              range.length > 0
        else {
            return NSRect(x: blockRect.minX + 2, y: blockRect.minY + 2, width: blockRect.width - 4, height: 22)
        }

        let glyphIndex = layoutManager.glyphIndexForCharacter(at: range.location)
        let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
        let origin = textContainerOrigin
        let y = origin.y + lineRect.minY
        _ = textContainer
        return NSRect(
            x: blockRect.minX + 2,
            y: y,
            width: blockRect.width - 4,
            height: max(20, lineRect.height)
        )
    }

    private func codeBlockCopyButtonRect(for item: CodeBlockItem) -> NSRect {
        codeBlockCopyButtonRect(for: item, blockRect: codeBlockRect(for: item))
    }

    private func codeBlockCopyButtonRect(for item: CodeBlockItem, blockRect: NSRect) -> NSRect {
        guard !blockRect.isEmpty else { return .zero }
        let headerRect = codeBlockHeaderRect(for: item, blockRect: blockRect)
        let height = min(20, max(18, headerRect.height - 4))
        let size = NSSize(width: height + 10, height: height)
        let upwardOffset: CGFloat = isFlipped ? -3.5 : 3.5
        return NSRect(
            x: blockRect.maxX - size.width - 8,
            y: headerRect.midY - size.height / 2 + upwardOffset,
            width: size.width,
            height: size.height
        )
    }

    private func clampedRange(_ range: NSRange, upperBound: Int) -> NSRange? {
        guard range.location != NSNotFound,
              range.location < upperBound,
              range.length >= 0
        else { return nil }

        let end = min(upperBound, range.location + range.length)
        guard end >= range.location else { return nil }
        return NSRange(location: range.location, length: end - range.location)
    }

    private func drawTaskCheckboxes(in dirtyRect: NSRect) {
        guard let layoutManager, let textContainer else { return }
        let visibleTasks = taskItemsForDrawing(in: dirtyRect, layoutManager: layoutManager, textContainer: textContainer)

        for item in visibleTasks {
            let rect = checkboxRect(for: item)
            let scale = rect.width / 13
            let cornerRadius = max(2.6, rect.width * 0.25)
            let box = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
            NSColor.controlBackgroundColor.withAlphaComponent(0.35).setFill()
            box.fill()

            (item.done ? taskAccentColor : NSColor.tertiaryLabelColor).setStroke()
            box.lineWidth = item.done ? max(1.5, 1.8 * scale) : max(1, 1.2 * scale)
            box.stroke()

            guard item.done else { continue }
            let check = NSBezierPath()
            check.move(to: NSPoint(x: rect.minX + 3.4 * scale, y: rect.midY + 0.4 * scale))
            check.line(to: NSPoint(x: rect.minX + 6.4 * scale, y: rect.maxY - 3.8 * scale))
            check.line(to: NSPoint(x: rect.maxX - 3.2 * scale, y: rect.minY + 3.4 * scale))
            taskAccentColor.setStroke()
            check.lineWidth = max(1.5, 1.8 * scale)
            check.lineCapStyle = .round
            check.lineJoinStyle = .round
            check.stroke()
        }
    }

    private func taskItemsForDrawing(
        in dirtyRect: NSRect,
        layoutManager: NSLayoutManager,
        textContainer: NSTextContainer
    ) -> [TaskItem] {
        guard !taskItems.isEmpty else { return [] }

        let origin = textContainerOrigin
        let containerDirtyRect = dirtyRect.offsetBy(dx: -origin.x, dy: -origin.y).insetBy(dx: -16, dy: -8)
        let glyphRange = layoutManager.glyphRange(forBoundingRect: containerDirtyRect, in: textContainer)
        let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        guard characterRange.length > 0 else { return [] }

        return taskItems.filter { item in
            NSIntersectionRange(item.markerRange, characterRange).length > 0
                || NSLocationInRange(item.markerRange.location, characterRange)
        }
    }

    private func checkboxRect(for item: TaskItem) -> NSRect {
        guard let layoutManager, let textContainer else { return .zero }
        let firstGlyphIndex = layoutManager.glyphIndexForCharacter(at: item.markerRange.location)
        let lineRect = layoutManager.lineFragmentRect(forGlyphAt: firstGlyphIndex, effectiveRange: nil)
        let origin = textContainerOrigin
        let size = MarkdownTaskLayout.checkboxSize(for: bodyFontSize)
        return NSRect(
            x: origin.x + lineRect.minX + textContainer.lineFragmentPadding + item.indentationWidth,
            y: origin.y + lineRect.midY - size / 2,
            width: size,
            height: size
        )
    }
}
