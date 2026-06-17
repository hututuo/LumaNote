import Foundation

enum ClipboardDetector {
    private static let maximumScanCharacters = 20_000

    private enum CharacterSets {
        static let addressSentenceSeparators = CharacterSet(charactersIn: "\n;；")
        static let labeledValueTrim = CharacterSet.whitespacesAndNewlines
            .union(CharacterSet(charactersIn: "，,。；;、:："))
        static let filePathTrim = CharacterSet.whitespacesAndNewlines
            .union(CharacterSet(charactersIn: "，,。；;、!?！？)]}）】》\"'“”‘’"))
    }

    private enum LabelTokens {
        static let url = ["网址", "链接", "url", "link", "website", "site"]
        static let email = ["邮箱", "邮件", "email", "mail"]
        static let phone = ["电话", "手机", "手机号", "联系方式", "phone", "mobile", "tel"]
        static let address = ["地址", "收货", "寄送", "邮寄", "住址", "address", "addr", "location"]
        static let file = ["路径", "目录", "文件", "位置", "path", "file", "folder", "directory"]
        static let number = [
            "验证码", "校验码", "动态码", "取件码", "提取码",
            "订单号", "订单", "单号", "快递单号", "运单号", "物流单号",
            "票号", "发票号", "编号", "序列号", "工单号",
            "code", "pin", "otp", "order", "tracking", "invoice", "ticket", "serial", "case"
        ]
    }

    private enum Regexes {
        static let labeledValue = regex(
            #"(?:[\s,，;；]*)([\p{Han}A-Za-z][\p{Han}A-Za-z0-9 _-]{0,14})\s*[:：]\s*(.+?)(?=(?:[\s,，;；]+[\p{Han}A-Za-z][\p{Han}A-Za-z0-9 _-]{0,14}\s*[:：])|[\n;；]|$)"#,
            options: [.caseInsensitive]
        )
        static let url = regex(#"(?i)(?:https?://|www\.)[^\s<>"'，。；、！？]+"#)
        static let email = regex(#"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, options: [.caseInsensitive])
        static let filePath = regex(#"(?<![\w~.-])(?:~|/(?:Users|Applications|Volumes|Library|System|private|tmp|var|opt|usr|bin|sbin|etc|Developer|Network|cores))(?:/[^\n\r\t:：*?"<>|，。；、！？]+)+"#)
        static let labeledNumber = regex(#"(?i)(?:\#(numberLabels))\s*[:：#]?\s*([A-Z0-9][A-Z0-9 -]{2,30}[A-Z0-9])"#)
        static let phone = regex(#"(?<!\d)(?:\+?\d[\d\s().-]{6,}\d)(?!\d)"#)

        private static let numberLabels = LabelTokens.number.joined(separator: "|")

        private static func regex(
            _ pattern: String,
            options: NSRegularExpression.Options = []
        ) -> NSRegularExpression {
            do {
                return try NSRegularExpression(pattern: pattern, options: options)
            } catch {
                preconditionFailure("Invalid clipboard regex: \(pattern)")
            }
        }
    }

    static func detect(in text: String) -> [ClipboardDetection] {
        let detectionPrefix = text.prefix(maximumScanCharacters + 1)
        let scanText = detectionPrefix.count > maximumScanCharacters
            ? String(detectionPrefix.dropLast())
            : text
        var matches: [DetectedMatch] = []

        appendLabeledValueMatches(in: scanText, into: &matches)
        var excludedRanges: [NSRange] = []
        excludedRanges.reserveCapacity(40)
        appendNewExclusionRanges(from: matches, previousCount: 0, into: &excludedRanges)

        var previousCount = matches.count
        appendFilePathMatches(in: scanText, into: &matches, excluding: excludedRanges)
        appendNewExclusionRanges(from: matches, previousCount: previousCount, into: &excludedRanges)

        previousCount = matches.count
        appendMatches(kind: .url, regex: Regexes.url, in: scanText, into: &matches, excluding: excludedRanges)
        appendNewExclusionRanges(from: matches, previousCount: previousCount, into: &excludedRanges)

        previousCount = matches.count
        appendMatches(kind: .email, regex: Regexes.email, in: scanText, into: &matches, excluding: excludedRanges)
        appendNewExclusionRanges(from: matches, previousCount: previousCount, into: &excludedRanges)

        previousCount = matches.count
        appendPhoneMatches(in: scanText, into: &matches, excluding: excludedRanges)
        appendNewExclusionRanges(from: matches, previousCount: previousCount, into: &excludedRanges)

        previousCount = matches.count
        appendLabeledNumberMatches(in: scanText, into: &matches, excluding: excludedRanges)
        appendNewExclusionRanges(from: matches, previousCount: previousCount, into: &excludedRanges)

        appendAddressMatches(in: scanText, into: &matches, excluding: excludedRanges)

        let sortedMatches = matches
            .enumerated()
            .sorted { lhs, rhs in
                let left = lhs.element
                let right = rhs.element
                if left.priority != right.priority {
                    return left.priority.sortOrder < right.priority.sortOrder
                }
                if left.range.location != right.range.location {
                    return left.range.location < right.range.location
                }
                return lhs.offset < rhs.offset
            }

        var seen: Set<DetectionIdentity> = []
        return sortedMatches.compactMap { _, match in
            let identity = DetectionIdentity(kind: match.kind, value: match.value)
            guard seen.insert(identity).inserted else { return nil }
            return ClipboardDetection(id: UUID(), kind: match.kind, value: match.value)
        }
    }

    static func detectOffMain(in text: String) async -> [ClipboardDetection] {
        await Task.detached(priority: .utility) {
            detect(in: text)
        }.value
    }

    private static func appendLabeledValueMatches(in text: String, into matches: inout [DetectedMatch]) {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var acceptedCount = 0
        Regexes.labeledValue.enumerateMatches(in: text, range: range) { match, _, stop in
            guard acceptedCount < 10 else {
                stop.pointee = true
                return
            }
            guard let match,
                  match.numberOfRanges > 2,
                  let labelRange = Range(match.range(at: 1), in: text),
                  let valueRange = Range(match.range(at: 2), in: text)
            else { return }

            let label = String(text[labelRange])
            let rawValue = String(text[valueRange])
            let value = cleanedLabeledValue(rawValue)
            guard value.count >= 2 else { return }

            let valueNSRange = NSRange(valueRange, in: text)
            if let kind = kind(forLabel: label, value: value) {
                matches.append(.init(
                    kind: kind,
                    value: value,
                    range: valueNSRange,
                    priority: kind == .text ? .colonFallback : .confident
                ))
                acceptedCount += 1
                return
            }

            var nested: [DetectedMatch] = []
            appendFilePathMatches(in: value, into: &nested)
            appendMatches(kind: .url, regex: Regexes.url, in: value, into: &nested)
            appendMatches(kind: .email, regex: Regexes.email, in: value, into: &nested)
            appendPhoneMatches(in: value, into: &nested)
            appendLabeledNumberMatches(in: "\(label): \(value)", into: &nested)

            if nested.isEmpty, looksLikeAddress(value, allowNoDigit: true) {
                nested.append(.init(
                    kind: .address,
                    value: value,
                    range: NSRange(location: 0, length: (value as NSString).length),
                    priority: .confident
                ))
            }

            if !nested.isEmpty {
                nested.forEach { nestedMatch in
                    matches.append(.init(
                        kind: nestedMatch.kind,
                        value: nestedMatch.value,
                        range: shiftedRange(nestedMatch.range, by: valueNSRange.location),
                        priority: .confident
                    ))
                }
                acceptedCount += nested.count
            } else {
                matches.append(.init(kind: .text, value: value, range: valueNSRange, priority: .colonFallback))
                acceptedCount += 1
            }
        }
    }

    private struct DetectedMatch {
        let kind: ClipboardDetection.Kind
        let value: String
        let range: NSRange
        let priority: DetectionPriority
    }

    private struct DetectionIdentity: Hashable {
        let kind: ClipboardDetection.Kind
        let value: String
    }

    private enum DetectionPriority: Int, Comparable {
        case confident
        case colonFallback

        var sortOrder: Int {
            rawValue
        }

        static func < (lhs: DetectionPriority, rhs: DetectionPriority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    private static func shiftedRange(_ range: NSRange, by offset: Int) -> NSRange {
        NSRange(location: range.location + offset, length: range.length)
    }

    private static func numberCharacterCount(in value: String) -> Int {
        var count = 0
        for character in value where character.isNumber {
            count += 1
        }
        return count
    }

    private static func appendNewExclusionRanges(
        from matches: [DetectedMatch],
        previousCount: Int,
        into excludedRanges: inout [NSRange]
    ) {
        guard matches.count > previousCount else { return }
        excludedRanges.reserveCapacity(excludedRanges.count + matches.count - previousCount)
        for index in previousCount..<matches.count {
            excludedRanges.append(matches[index].range)
        }
    }

    private static func appendMatches(
        kind: ClipboardDetection.Kind,
        regex: NSRegularExpression,
        in text: String,
        into matches: inout [DetectedMatch],
        excluding excludedRanges: [NSRange] = [],
        limit: Int = 8
    ) {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var acceptedCount = 0
        regex.enumerateMatches(in: text, range: range) { match, _, stop in
            guard acceptedCount < limit else {
                stop.pointee = true
                return
            }
            guard let match else { return }
            guard !excludedRanges.contains(where: { NSIntersectionRange($0, match.range).length > 0 }) else { return }
            guard let swiftRange = Range(match.range, in: text) else { return }
            matches.append(.init(kind: kind, value: String(text[swiftRange]), range: match.range, priority: .confident))
            acceptedCount += 1
        }
    }

    private static func appendLabeledNumberMatches(
        in text: String,
        into matches: inout [DetectedMatch],
        excluding excludedRanges: [NSRange] = []
    ) {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var acceptedCount = 0
        Regexes.labeledNumber.enumerateMatches(in: text, range: range) { match, _, stop in
            guard acceptedCount < 6 else {
                stop.pointee = true
                return
            }
            guard let match else { return }
            guard !excludedRanges.contains(where: { NSIntersectionRange($0, match.range).length > 0 }) else { return }
            guard match.numberOfRanges > 1,
                  let valueRange = Range(match.range(at: 1), in: text)
            else { return }

            let value = String(text[valueRange])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let digitCount = numberCharacterCount(in: value)
            guard digitCount >= 3 else { return }

            matches.append(.init(kind: .number, value: value, range: match.range(at: 1), priority: .confident))
            acceptedCount += 1
        }
    }

    private static func appendFilePathMatches(
        in text: String,
        into matches: inout [DetectedMatch],
        excluding excludedRanges: [NSRange] = []
    ) {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var acceptedCount = 0
        Regexes.filePath.enumerateMatches(in: text, range: range) { match, _, stop in
            guard acceptedCount < 6 else {
                stop.pointee = true
                return
            }
            guard let match else { return }
            guard !excludedRanges.contains(where: { NSIntersectionRange($0, match.range).length > 0 }) else { return }
            guard let swiftRange = Range(match.range, in: text) else { return }

            let value = cleanedFilePath(String(text[swiftRange]))
            guard looksLikeFilePath(value) else { return }
            matches.append(.init(kind: .file, value: value, range: match.range, priority: .confident))
            acceptedCount += 1
        }
    }

    private static func appendPhoneMatches(
        in text: String,
        into matches: inout [DetectedMatch],
        excluding excludedRanges: [NSRange] = []
    ) {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var acceptedCount = 0
        Regexes.phone.enumerateMatches(in: text, range: range) { match, _, stop in
            guard acceptedCount < 6 else {
                stop.pointee = true
                return
            }
            guard let match else { return }
            guard !excludedRanges.contains(where: { NSIntersectionRange($0, match.range).length > 0 }) else { return }
            guard let swiftRange = Range(match.range, in: text) else { return }
            let value = String(text[swiftRange])
            let digitCount = numberCharacterCount(in: value)
            guard (10...15).contains(digitCount), !looksLikeDate(value) else { return }
            matches.append(.init(kind: .phone, value: value, range: match.range, priority: .confident))
            acceptedCount += 1
        }
    }

    private static func looksLikeDate(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.range(
            of: #"^\d{4}[-/.]\d{1,2}[-/.]\d{1,2}$"#,
            options: .regularExpression
        ) != nil
    }

    private static func appendAddressMatches(
        in text: String,
        into matches: inout [DetectedMatch],
        excluding excludedRanges: [NSRange] = []
    ) {
        let nsText = text as NSString
        var start = 0

        while start < nsText.length {
            var end = start
            while end < nsText.length {
                let scalar = UnicodeScalar(nsText.character(at: end)) ?? "\n"
                if CharacterSets.addressSentenceSeparators.contains(scalar) { break }
                end += 1
            }

            let range = NSRange(location: start, length: end - start)
            if !excludedRanges.contains(where: { NSIntersectionRange($0, range).length > 0 }) {
                let candidate = nsText.substring(with: range)
                let trimmed = cleanedLabeledValue(candidate)
                if looksLikeAddress(trimmed, allowNoDigit: false) {
                    matches.append(.init(kind: .address, value: trimmed, range: range, priority: .confident))
                }
            }

            start = end + 1
        }
    }

    private static func cleanedLabeledValue(_ value: String) -> String {
        value.trimmingCharacters(in: CharacterSets.labeledValueTrim)
    }

    private static func cleanedFilePath(_ value: String) -> String {
        return value
            .replacingOccurrences(of: #"\\ "#, with: " ")
            .trimmingCharacters(in: CharacterSets.filePathTrim)
    }

    private static func kind(forLabel label: String, value: String) -> ClipboardDetection.Kind? {
        let normalized = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if LabelTokens.url.contains(where: { normalized.contains($0) }) {
            let looksLikeURL = value.range(of: #"(?i)^(?:https?://|www\.)"#, options: .regularExpression) != nil
                || value.range(of: #"^[A-Z0-9.-]+\.[A-Z]{2,}(?:[/#?].*)?$"#, options: [.regularExpression, .caseInsensitive]) != nil
            return looksLikeURL ? .url : .text
        }
        if LabelTokens.email.contains(where: { normalized.contains($0) }) {
            let looksLikeEmail = value.range(of: #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#, options: [.regularExpression, .caseInsensitive]) != nil
            return looksLikeEmail ? .email : .text
        }
        if LabelTokens.phone.contains(where: { normalized.contains($0) }) {
            let digitCount = numberCharacterCount(in: value)
            return (10...15).contains(digitCount) && !looksLikeDate(value) ? .phone : .text
        }
        if LabelTokens.address.contains(where: { normalized.contains($0) }) {
            return .address
        }
        if LabelTokens.file.contains(where: { normalized.contains($0) }) {
            return looksLikeFilePath(value) ? .file : .text
        }
        if LabelTokens.number.contains(where: { normalized.contains($0) }) {
            let digitCount = numberCharacterCount(in: value)
            return digitCount >= 3 ? .number : .text
        }

        return nil
    }

    private static func looksLikeFilePath(_ text: String) -> Bool {
        let expanded = (cleanedFilePath(text) as NSString).expandingTildeInPath
        guard expanded.hasPrefix("/") else { return false }
        guard expanded.count > 4, expanded.count < 1_024 else { return false }
        guard !expanded.contains("\n"), !expanded.contains("\r"), !expanded.contains("\t") else { return false }
        return expanded.split(separator: "/").count >= 2
    }

    private static func looksLikeAddress(_ text: String, allowNoDigit: Bool) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 8, trimmed.count < 180 else { return false }
        let lower = trimmed.lowercased()
        let tokens = [" street", " st ", " road", " rd ", " avenue", " ave ", " lane", " ln ", " drive", " dr ", " boulevard", " blvd", " way", " court", " ct ", "号", "路", "街", "区", "县", "市", "省", "室", "楼", "栋"]
        let hasAddressToken = tokens.contains { lower.contains($0) }
        let hasDigit = trimmed.rangeOfCharacter(from: .decimalDigits) != nil
        return hasAddressToken && (allowNoDigit || hasDigit)
    }
}
