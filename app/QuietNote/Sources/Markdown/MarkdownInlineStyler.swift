import AppKit

enum MarkdownInlineStyler {
    static func styleInline(
        in storage: NSTextStorage,
        excluding blockExclusionRanges: [NSRange],
        activeSelectionRanges: [NSRange],
        attributes styles: MarkdownStyleAttributes
    ) {
        let fullRange = NSRange(location: 0, length: storage.length)
        var exclusionRanges = MarkdownRangeHelpers.normalizedRanges(blockExclusionRanges, upperBound: storage.length)

        if let inlineCodeRule = MarkdownStyleRules.inlineRules.first(where: { $0.style == .inlineCode }) {
            MarkdownRangeHelpers.availableRanges(in: fullRange, excluding: exclusionRanges).forEach { range in
                let matchedRanges = apply(
                    rule: inlineCodeRule,
                    in: storage,
                    range: range,
                    activeSelectionRanges: activeSelectionRanges,
                    attributes: styles
                )
                exclusionRanges.append(contentsOf: matchedRanges)
            }
            exclusionRanges = MarkdownRangeHelpers.normalizedRanges(exclusionRanges, upperBound: storage.length)
        }

        MarkdownStyleRules.inlineRules.filter { $0.style != .inlineCode }.forEach { rule in
            MarkdownRangeHelpers.availableRanges(in: fullRange, excluding: exclusionRanges).forEach { range in
                let matchedRanges = apply(
                    rule: rule,
                    in: storage,
                    range: range,
                    activeSelectionRanges: activeSelectionRanges,
                    attributes: styles
                )
                if rule.style.preventsNestedInlineStyling {
                    exclusionRanges.append(contentsOf: matchedRanges)
                    exclusionRanges = MarkdownRangeHelpers.normalizedRanges(exclusionRanges, upperBound: storage.length)
                }
            }
        }
    }

    @discardableResult
    private static func apply(
        rule: MarkdownInlineRule,
        in storage: NSTextStorage,
        range: NSRange,
        activeSelectionRanges: [NSRange],
        attributes styles: MarkdownStyleAttributes
    ) -> [NSRange] {
        let matches = rule.regex.matches(in: storage.string, range: range)
        matches.forEach { match in
            guard match.range.length > 0 else { return }
            if let visibleRange = MarkdownStyleRules.visibleContentRange(for: match, style: rule.style) {
                storage.addAttributes(styles.attributes(for: rule.style), range: visibleRange)
                if !MarkdownRangeHelpers.ranges(activeSelectionRanges, touch: match.range) {
                    hideSyntax(in: storage, fullRange: match.range, visibleRanges: [visibleRange], attributes: styles)
                }
            } else {
                storage.addAttributes(styles.attributes(for: rule.style), range: match.range)
            }
        }
        return matches.map(\.range)
    }

    private static func hideSyntax(
        in storage: NSTextStorage,
        fullRange: NSRange,
        visibleRanges: [NSRange],
        attributes styles: MarkdownStyleAttributes
    ) {
        MarkdownRangeHelpers.syntaxRanges(in: fullRange, visibleRanges: visibleRanges).forEach { range in
            storage.addAttributes(styles.hiddenSyntaxAttributes(), range: range)
        }
    }
}
