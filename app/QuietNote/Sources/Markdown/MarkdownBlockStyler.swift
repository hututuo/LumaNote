import AppKit

struct MarkdownBlockStyleResult {
    let taskItems: [MarkdownTaskTextView.TaskItem]
    let codeBlocks: [MarkdownTaskTextView.CodeBlockItem]
    let headingItems: [MarkdownTaskTextView.HeadingItem]
    let inlineExclusionRanges: [NSRange]
}

enum MarkdownBlockStyler {
    static func styleBlocks(
        in storage: NSTextStorage,
        activeSelectionRanges: [NSRange],
        fontSize: CGFloat,
        attributes styles: MarkdownStyleAttributes
    ) -> MarkdownBlockStyleResult {
        let nsString = storage.string as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        var openCodeFence: (
            marker: String,
            openingLineRange: NSRange,
            openingFullLineRange: NSRange,
            contentStart: Int,
            language: String?
        )?
        var taskItems: [MarkdownTaskTextView.TaskItem] = []
        var codeBlocks: [MarkdownTaskTextView.CodeBlockItem] = []
        var headingItems: [MarkdownTaskTextView.HeadingItem] = []
        var inlineExclusionRanges: [NSRange] = []
        let taskMetrics = MarkdownTaskLayoutMetrics(fontSize: fontSize)

        nsString.enumerateSubstrings(in: fullRange, options: [.byLines, .substringNotRequired]) { _, lineRange, _, _ in
            let line = nsString.substring(with: lineRange)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let fullLineRange = nsString.lineRange(for: lineRange)

            if let fence = openCodeFence {
                inlineExclusionRanges.append(fullLineRange)
                if MarkdownStyleRules.isCodeFenceClose(trimmed, marker: fence.marker) {
                    let contentRange = MarkdownRangeHelpers.range(from: fence.contentStart, to: fullLineRange.location)
                    let blockRange = MarkdownRangeHelpers.range(
                        from: fence.openingFullLineRange.location,
                        to: lineRange.location + lineRange.length
                    )
                    let isActive = MarkdownRangeHelpers.ranges(activeSelectionRanges, activateCodeBlock: blockRange)
                    if contentRange.length > 0 {
                        storage.addAttributes(styles.codeBlockAttributes(), range: contentRange)
                    }
                    applyCodeFenceAttributes(to: storage, range: fence.openingLineRange, isActive: isActive, isOpening: true, attributes: styles)
                    applyCodeFenceAttributes(to: storage, range: lineRange, isActive: isActive, isOpening: false, attributes: styles)
                    codeBlocks.append(
                        MarkdownTaskTextView.CodeBlockItem(
                            blockRange: blockRange,
                            contentRange: contentRange,
                            openingFenceRange: fence.openingLineRange,
                            closingFenceRange: lineRange,
                            language: fence.language,
                            isActive: isActive
                        )
                    )
                    openCodeFence = nil
                } else {
                    storage.addAttributes(styles.codeBlockAttributes(), range: lineRange)
                }
                return
            }

            guard !trimmed.isEmpty else { return }

            if let fence = MarkdownStyleRules.codeFenceStart(in: trimmed) {
                inlineExclusionRanges.append(fullLineRange)
                applyCodeFenceAttributes(to: storage, range: lineRange, isActive: false, isOpening: true, attributes: styles)
                openCodeFence = (
                    marker: fence.marker,
                    openingLineRange: lineRange,
                    openingFullLineRange: fullLineRange,
                    contentStart: fullLineRange.location + fullLineRange.length,
                    language: fence.language
                )
                return
            }

            if trimmed == "---" || trimmed == "***" {
                storage.addAttributes(styles.ruleAttributes(), range: lineRange)
                return
            }

            if let heading = MarkdownStyleRules.headingLevel(in: line) {
                let markerRange = NSRange(location: lineRange.location, length: heading.markerLength)
                let activationRange = MarkdownRangeHelpers.range(
                    from: markerRange.location + max(0, heading.markerLength - 1),
                    to: lineRange.location + lineRange.length
                )
                let isActive = MarkdownRangeHelpers.ranges(activeSelectionRanges, touch: activationRange)
                storage.addAttributes(styles.headingAttributes(level: heading.level), range: lineRange)
                storage.addAttributes(styles.headingMarkerAttributes(isActive: isActive), range: markerRange)
                headingItems.append(MarkdownTaskTextView.HeadingItem(lineRange: lineRange, level: heading.level))
                return
            }

            if let alert = MarkdownStyleRules.alertPrefix(in: line, lineRange: lineRange) {
                storage.addAttributes(styles.alertAttributes(kind: alert.kind, level: alert.level), range: lineRange)
                storage.addAttributes(styles.markerAttributes(), range: alert.markerRange)
                storage.addAttributes(styles.alertKindAttributes(kind: alert.kind), range: alert.kindRange)
                return
            }

            if let quote = MarkdownStyleRules.quotePrefix(in: line, lineRange: lineRange) {
                storage.addAttributes(styles.quoteAttributes(level: quote.level), range: lineRange)
                storage.addAttributes(styles.markerAttributes(), range: quote.markerRange)
                return
            }

            if let reference = MarkdownStyleRules.prefixRange(regex: MarkdownStyleRules.referenceDefinitionRegex, in: line, lineRange: lineRange) {
                storage.addAttributes(styles.referenceDefinitionAttributes(), range: lineRange)
                storage.addAttributes(styles.markerAttributes(), range: reference)
                return
            }

            if let marker = MarkdownStyleRules.prefixRange(regex: MarkdownStyleRules.imagePrefixRegex, in: line, lineRange: lineRange) {
                storage.addAttributes(styles.imageAttributes(), range: lineRange)
                storage.addAttributes(styles.markerAttributes(), range: marker)
                return
            }

            if let task = MarkdownTaskPrefixParser.prefix(in: line, lineRange: lineRange, metrics: taskMetrics) {
                storage.addAttributes(styles.taskAttributes(done: task.done, indentationWidth: task.indentationWidth), range: lineRange)
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

            if let list = MarkdownStyleRules.listPrefix(in: line, lineRange: lineRange, metrics: taskMetrics) {
                storage.addAttributes(styles.listAttributes(indentationWidth: list.indentationWidth), range: lineRange)
                storage.addAttributes(styles.markerAttributes(), range: list.markerRange)
                return
            }

            if MarkdownStyleRules.isTableLikeLine(line) {
                storage.addAttributes(styles.tableAttributes(), range: lineRange)
            }
        }

        if let fence = openCodeFence {
            let contentRange = MarkdownRangeHelpers.range(from: fence.contentStart, to: fullRange.location + fullRange.length)
            let blockRange = MarkdownRangeHelpers.range(
                from: fence.openingFullLineRange.location,
                to: fullRange.location + fullRange.length
            )
            let isActive = MarkdownRangeHelpers.ranges(activeSelectionRanges, activateCodeBlock: blockRange)
            if contentRange.length > 0 {
                storage.addAttributes(styles.codeBlockAttributes(), range: contentRange)
            }
            applyCodeFenceAttributes(to: storage, range: fence.openingLineRange, isActive: isActive, isOpening: true, attributes: styles)
            codeBlocks.append(
                MarkdownTaskTextView.CodeBlockItem(
                    blockRange: blockRange,
                    contentRange: contentRange,
                    openingFenceRange: fence.openingLineRange,
                    closingFenceRange: nil,
                    language: fence.language,
                    isActive: isActive
                )
            )
        }

        return MarkdownBlockStyleResult(
            taskItems: taskItems,
            codeBlocks: codeBlocks,
            headingItems: headingItems,
            inlineExclusionRanges: inlineExclusionRanges
        )
    }

    private static func applyCodeFenceAttributes(
        to storage: NSTextStorage,
        range: NSRange,
        isActive: Bool,
        isOpening: Bool,
        attributes styles: MarkdownStyleAttributes
    ) {
        if isActive {
            storage.removeAttribute(.markdownHiddenSyntax, range: range)
        }
        storage.addAttributes(styles.codeFenceAttributes(isActive: isActive, isOpening: isOpening), range: range)
    }
}
