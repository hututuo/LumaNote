import AppKit

enum MarkdownInlineStyle {
    case inlineCode
    case boldItalic
    case bold
    case italic
    case strikethrough
    case highlight
    case image
    case link
    case wikiLink
    case shortcode

    var preventsNestedInlineStyling: Bool {
        switch self {
        case .inlineCode, .image, .link, .wikiLink:
            true
        case .boldItalic, .bold, .italic, .strikethrough, .highlight, .shortcode:
            false
        }
    }
}

struct MarkdownInlineRule {
    let regex: NSRegularExpression
    let style: MarkdownInlineStyle
}

enum MarkdownStyleRules {
    static let inlineRules: [MarkdownInlineRule] = [
        MarkdownInlineRule(regex: regex(#"`([^`]+)`"#), style: .inlineCode),
        MarkdownInlineRule(regex: regex(#"\*\*\*([^*\n]+)\*\*\*"#), style: .boldItalic),
        MarkdownInlineRule(regex: regex(#"___([^_\n]+)___"#), style: .boldItalic),
        MarkdownInlineRule(regex: regex(#"\*\*([^*]+)\*\*"#), style: .bold),
        MarkdownInlineRule(regex: regex(#"__([^_]+)__"#), style: .bold),
        MarkdownInlineRule(regex: regex(#"(?<!\*)\*([^*\n]+)\*(?!\*)"#), style: .italic),
        MarkdownInlineRule(regex: regex(#"(?<!_)_([^_\n]+)_(?!_)"#), style: .italic),
        MarkdownInlineRule(regex: regex(#"~~([^~]+)~~"#), style: .strikethrough),
        MarkdownInlineRule(regex: regex(#"==([^=\n]+)=="#), style: .highlight),
        MarkdownInlineRule(regex: regex(#"!\[([^\]\n]*)\]\(\s*(?:<[^>\n]+>|(?:\\.|[^()\s\\]|\([^()\n]*\))+)(?:\s+["'][^"'\n]*["'])?\s*\)"#), style: .image),
        MarkdownInlineRule(regex: regex(#"\[([^\]\n]+)\]\(\s*(?:<[^>\n]+>|(?:\\.|[^()\s\\]|\([^()\n]*\))+)(?:\s+["'][^"'\n]*["'])?\s*\)"#), style: .link),
        MarkdownInlineRule(regex: regex(#"\[([^\]]+)\]\[[^\]]*\]"#), style: .link),
        MarkdownInlineRule(regex: regex(#"\[\[([^\]\n]+)\]\]"#), style: .wikiLink),
        MarkdownInlineRule(regex: regex(#"<(https?://[^>\s]+)>"#), style: .link),
        MarkdownInlineRule(regex: regex(#"<([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})>"#), style: .link),
        MarkdownInlineRule(regex: regex(#"https?://[^\s<>"'，。！？、；]+"#), style: .link),
        MarkdownInlineRule(regex: regex(#"(?<![/\w.-])[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}(?![\w.-])"#), style: .link),
        MarkdownInlineRule(regex: regex(#":[a-zA-Z0-9_+-]+:"#), style: .shortcode)
    ]

    static let alertRegex = regex(
        #"^(\s*(?:>\s*)+)\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]"#,
        options: [.caseInsensitive]
    )
    static let quoteRegex = regex(#"^\s*(?:>\s*)+"#)
    static let listRegex = regex(#"^([ \t]*)(?:[-*+]|\d+\.)\s+"#)
    static let referenceDefinitionRegex = regex(#"^\s*\[[^\]]+\]:\s+\S+"#)
    static let imagePrefixRegex = regex(#"^\s*!\[[^\]]*\]\([^)]+\)"#)

    static func visibleContentRange(for match: NSTextCheckingResult, style: MarkdownInlineStyle) -> NSRange? {
        switch style {
        case .inlineCode, .boldItalic, .bold, .italic, .strikethrough, .highlight, .image, .link, .wikiLink:
            guard match.numberOfRanges > 1 else { return nil }
            let range = match.range(at: 1)
            return range.location == NSNotFound || range.length <= 0 ? nil : range
        case .shortcode:
            return nil
        }
    }

    static func headingLevel(in line: String) -> (level: Int, markerLength: Int)? {
        let markerLength = line.prefix { $0 == "#" }.count
        guard (1...6).contains(markerLength),
              line.dropFirst(markerLength).first == " "
        else { return nil }
        return (markerLength, markerLength + 1)
    }

    static func alertPrefix(
        in line: String,
        lineRange: NSRange
    ) -> (markerRange: NSRange, kindRange: NSRange, kind: String, level: Int)? {
        guard let match = alertRegex.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length))
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

    static func quotePrefix(
        in line: String,
        lineRange: NSRange
    ) -> (markerRange: NSRange, level: Int)? {
        guard let match = quoteRegex.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length))
        else { return nil }

        let markerText = (line as NSString).substring(with: match.range)
        return (
            NSRange(location: lineRange.location + match.range.location, length: match.range.length),
            markerText.filter { $0 == ">" }.count
        )
    }

    static func listPrefix(
        in line: String,
        lineRange: NSRange,
        metrics: MarkdownTaskLayoutMetrics
    ) -> (markerRange: NSRange, indentationWidth: CGFloat)? {
        guard let match = listRegex.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length))
        else { return nil }

        let indentation = match.range(at: 1)
        let indentationText = (line as NSString).substring(with: indentation)
        return (
            NSRange(location: lineRange.location + match.range.location, length: match.range.length),
            metrics.textWidth(indentationText)
        )
    }

    static func isTableLikeLine(_ line: String) -> Bool {
        let pipeCount = line.filter { $0 == "|" }.count
        return pipeCount >= 2
    }

    static func codeFenceStart(in trimmedLine: String) -> (marker: String, language: String?)? {
        guard let first = trimmedLine.first,
              first == "`" || first == "~"
        else { return nil }

        let markerLength = trimmedLine.prefix { $0 == first }.count
        guard markerLength >= 3 else { return nil }

        let marker = String(repeating: String(first), count: markerLength)
        let info = trimmedLine.dropFirst(markerLength).trimmingCharacters(in: .whitespaces)
        let language = info.split(whereSeparator: { $0 == " " || $0 == "\t" }).first.map(String.init)
        return (marker, language?.isEmpty == false ? language : nil)
    }

    static func isCodeFenceClose(_ trimmedLine: String, marker: String) -> Bool {
        guard trimmedLine.hasPrefix(marker) else { return false }
        let remainder = trimmedLine.dropFirst(marker.count)
        return remainder.allSatisfy { $0 == " " || $0 == "\t" }
    }

    static func prefixRange(regex: NSRegularExpression, in line: String, lineRange: NSRange) -> NSRange? {
        guard let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length))
        else { return nil }
        return NSRange(location: lineRange.location + match.range.location, length: match.range.length)
    }

    private static func regex(
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
