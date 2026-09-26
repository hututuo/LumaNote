import AppKit

struct MarkdownEmphasisStyle: OptionSet, Codable, Hashable {
    let rawValue: Int

    static let bold = Self(rawValue: 1 << 0)
    static let italic = Self(rawValue: 1 << 1)
    static let strikethrough = Self(rawValue: 1 << 2)
    static let highlight = Self(rawValue: 1 << 3)
    static let smallHeading = Self(rawValue: 1 << 4)

    static let defaultOneTap: Self = [.bold, .highlight]
    static let inlineRemovalOrder: [Self] = [.bold, .italic, .strikethrough, .highlight]
    static let inlineAdditionOrder: [Self] = [.highlight, .strikethrough, .italic, .bold]
    static let allControls: [Self] = [.bold, .italic, .strikethrough, .highlight, .smallHeading]
}

struct MarkdownEmphasisFormattingResult: Equatable {
    let text: String
    let selectedRange: NSRange
}

struct MarkdownEmphasisCommand: Equatable {
    let id: Int
    let styles: MarkdownEmphasisStyle
}

enum MarkdownEmphasisFormatting {
    static func apply(
        styles: MarkdownEmphasisStyle,
        to text: String,
        selectedRange: NSRange
    ) -> MarkdownEmphasisFormattingResult {
        guard !styles.isEmpty else {
            return MarkdownEmphasisFormattingResult(
                text: text,
                selectedRange: clampedRange(selectedRange, in: text)
            )
        }

        var result = MarkdownEmphasisFormattingResult(
            text: text,
            selectedRange: initialTargetRange(selectedRange, in: text)
        )

        let inlineStyles = styles.intersection([.bold, .italic, .strikethrough, .highlight])
        let inlineOrder = hasAllInlineMarkers(
            inlineStyles,
            in: result.text,
            selectedRange: result.selectedRange
        ) ? MarkdownEmphasisStyle.inlineRemovalOrder : MarkdownEmphasisStyle.inlineAdditionOrder

        inlineOrder.forEach { style in
            guard styles.contains(style), let markers = markers(for: style) else { return }
            result = toggleMarkers(
                prefix: markers.prefix,
                suffix: markers.suffix,
                in: result.text,
                selectedRange: result.selectedRange
            )
        }

        if styles.contains(.smallHeading) {
            result = toggleSmallHeading(in: result.text, selectedRange: result.selectedRange)
        }

        return result
    }

    private static func hasAllInlineMarkers(
        _ styles: MarkdownEmphasisStyle,
        in text: String,
        selectedRange: NSRange
    ) -> Bool {
        guard !styles.isEmpty else { return false }
        let storage = NSString(string: text)
        var expandedRange = clampedRange(selectedRange, length: storage.length)

        for style in MarkdownEmphasisStyle.inlineRemovalOrder where styles.contains(style) {
            guard let markers = markers(for: style) else { return false }
            let prefixLength = (markers.prefix as NSString).length
            let suffixLength = (markers.suffix as NSString).length
            let prefixRange = NSRange(location: expandedRange.location - prefixLength, length: prefixLength)
            let suffixRange = NSRange(location: expandedRange.upperBound, length: suffixLength)
            guard prefixRange.location >= 0,
                  suffixRange.upperBound <= storage.length,
                  storage.substring(with: prefixRange) == markers.prefix,
                  storage.substring(with: suffixRange) == markers.suffix
            else { return false }

            expandedRange = NSRange(
                location: prefixRange.location,
                length: expandedRange.length + prefixLength + suffixLength
            )
        }

        return true
    }

    private static func markers(for style: MarkdownEmphasisStyle) -> (prefix: String, suffix: String)? {
        switch style {
        case .bold:
            ("**", "**")
        case .italic:
            ("*", "*")
        case .strikethrough:
            ("~~", "~~")
        case .highlight:
            ("==", "==")
        default:
            nil
        }
    }

    private static func toggleMarkers(
        prefix: String,
        suffix: String,
        in text: String,
        selectedRange: NSRange
    ) -> MarkdownEmphasisFormattingResult {
        let storage = NSMutableString(string: text)
        var range = clampedRange(selectedRange, length: storage.length)
        let prefixLength = (prefix as NSString).length
        let suffixLength = (suffix as NSString).length
        let hasPrefix = range.location >= prefixLength
            && storage.substring(with: NSRange(location: range.location - prefixLength, length: prefixLength)) == prefix
        let hasSuffix = range.upperBound + suffixLength <= storage.length
            && storage.substring(with: NSRange(location: range.upperBound, length: suffixLength)) == suffix

        if hasPrefix && hasSuffix {
            storage.deleteCharacters(in: NSRange(location: range.upperBound, length: suffixLength))
            storage.deleteCharacters(in: NSRange(location: range.location - prefixLength, length: prefixLength))
            range.location -= prefixLength
        } else {
            storage.insert(suffix, at: range.upperBound)
            storage.insert(prefix, at: range.location)
            range.location += prefixLength
        }

        return MarkdownEmphasisFormattingResult(text: storage as String, selectedRange: range)
    }

    private static func toggleSmallHeading(
        in text: String,
        selectedRange: NSRange
    ) -> MarkdownEmphasisFormattingResult {
        let storage = NSMutableString(string: text)
        var range = clampedRange(selectedRange, length: storage.length)
        let lineRange = storage.lineRange(for: NSRange(location: min(range.location, storage.length), length: 0))
        let contentStart = firstContentLocation(in: storage, lineRange: lineRange)
        let lineEnd = lineContentEnd(in: storage, lineRange: lineRange)
        let contentLength = max(0, lineEnd - contentStart)
        let contentRange = NSRange(location: contentStart, length: contentLength)
        let lineContent = storage.substring(with: contentRange)

        if lineContent.hasPrefix("## ") {
            storage.deleteCharacters(in: NSRange(location: contentStart, length: 3))
            range = shifted(range, by: -3, afterEditAt: contentStart)
        } else if let existingHeadingLength = headingMarkerLength(in: lineContent) {
            storage.replaceCharacters(
                in: NSRange(location: contentStart, length: existingHeadingLength),
                with: "## "
            )
            range = shifted(range, by: 3 - existingHeadingLength, afterEditAt: contentStart)
        } else {
            storage.insert("## ", at: contentStart)
            range = shifted(range, by: 3, afterEditAt: contentStart)
        }

        return MarkdownEmphasisFormattingResult(text: storage as String, selectedRange: range)
    }

    private static func initialTargetRange(_ selectedRange: NSRange, in text: String) -> NSRange {
        let range = clampedRange(selectedRange, in: text)
        guard range.length == 0 else { return range }

        let storage = NSString(string: text)
        let lineRange = storage.lineRange(for: NSRange(location: min(range.location, storage.length), length: 0))
        let contentEnd = lineContentEnd(in: storage, lineRange: lineRange)
        return NSRange(location: lineRange.location, length: max(0, contentEnd - lineRange.location))
    }

    private static func firstContentLocation(in storage: NSString, lineRange: NSRange) -> Int {
        let lineEnd = lineContentEnd(in: storage, lineRange: lineRange)
        var location = lineRange.location
        while location < lineEnd {
            let character = storage.character(at: location)
            guard character == 32 || character == 9 else { break }
            location += 1
        }
        return location
    }

    private static func lineContentEnd(in storage: NSString, lineRange: NSRange) -> Int {
        var end = min(lineRange.upperBound, storage.length)
        while end > lineRange.location {
            let character = storage.character(at: end - 1)
            guard character == 10 || character == 13 else { break }
            end -= 1
        }
        return end
    }

    private static func headingMarkerLength(in lineContent: String) -> Int? {
        let markerLength = lineContent.prefix { $0 == "#" }.count
        guard (1...6).contains(markerLength),
              lineContent.dropFirst(markerLength).first == " "
        else { return nil }
        return markerLength + 1
    }

    private static func shifted(_ range: NSRange, by delta: Int, afterEditAt editLocation: Int) -> NSRange {
        guard range.location >= editLocation else { return range }
        return NSRange(location: max(0, range.location + delta), length: range.length)
    }

    private static func clampedRange(_ range: NSRange, in text: String) -> NSRange {
        clampedRange(range, length: (text as NSString).length)
    }

    private static func clampedRange(_ range: NSRange, length: Int) -> NSRange {
        let location = min(max(0, range.location), length)
        let maxLength = max(0, length - location)
        return NSRange(location: location, length: min(max(0, range.length), maxLength))
    }
}
