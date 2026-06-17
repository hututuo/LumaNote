import AppKit

enum MarkdownTaskPrefixParser {
    struct ParsedTaskPrefix {
        let markerRange: NSRange
        let stateRange: NSRange
        let indentationWidth: CGFloat
        let markerAttributes: [NSAttributedString.Key: Any]
        let done: Bool
    }

    private static let taskRegex = markdownRegex(#"^([ \t]*)([-*]\s+\[)([ xX])(\])([ \t]*)"#)

    static func prefix(
        in line: String,
        lineRange: NSRange,
        metrics: MarkdownTaskLayoutMetrics
    ) -> ParsedTaskPrefix? {
        guard let match = taskRegex.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length))
        else { return nil }

        let markerRange = NSRange(location: lineRange.location + match.range.location, length: match.range.length)
        let indentation = match.range(at: 1)
        let indentationText = (line as NSString).substring(with: indentation)
        let indentationWidth = metrics.textWidth(indentationText)

        let markerText = (line as NSString).substring(with: match.range)
        let rawMarkerWidth = max(1, metrics.textWidth(markerText))
        let desiredMarkerWidth = indentationWidth + metrics.slotWidth
        let markerLength = max(1, (markerText as NSString).length)
        let markerKern = (desiredMarkerWidth - rawMarkerWidth) / CGFloat(markerLength)
        let markerAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.clear,
            .font: metrics.baseFont,
            .kern: markerKern
        ]

        let state = match.range(at: 3)
        let stateRange = NSRange(location: lineRange.location + state.location, length: state.length)
        let stateText = (line as NSString).substring(with: state)
        return ParsedTaskPrefix(
            markerRange: markerRange,
            stateRange: stateRange,
            indentationWidth: indentationWidth,
            markerAttributes: markerAttributes,
            done: stateText.localizedCaseInsensitiveCompare("x") == .orderedSame
        )
    }

    private static func markdownRegex(
        _ pattern: String,
        options: NSRegularExpression.Options = []
    ) -> NSRegularExpression {
        do {
            return try NSRegularExpression(pattern: pattern, options: options)
        } catch {
            preconditionFailure("Invalid Markdown regex: \(pattern)")
        }
    }
}
