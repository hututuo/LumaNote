import Foundation

enum ClipboardDetector {
    static func detect(in text: String) -> [ClipboardDetection] {
        var matches: [DetectedMatch] = []
        appendMatches(kind: .url, pattern: #"https?://[^\s<>"'，。；、！？]+"#, in: text, into: &matches)
        appendMatches(kind: .email, pattern: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, in: text, into: &matches, options: [.caseInsensitive])
        appendPhoneMatches(in: text, into: &matches)
        appendLabeledNumberMatches(in: text, into: &matches, excluding: matches.map(\.range))

        var detections = matches.map {
            ClipboardDetection(id: UUID(), kind: $0.kind, value: $0.value)
        }

        if looksLikeAddress(text) {
            detections.append(.init(id: UUID(), kind: .address, value: text))
        }

        var seen = Set<String>()
        return detections.filter { detection in
            let key = "\(detection.kind.rawValue):\(detection.value)"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    private struct DetectedMatch {
        let kind: ClipboardDetection.Kind
        let value: String
        let range: NSRange
    }

    private static func appendMatches(
        kind: ClipboardDetection.Kind,
        pattern: String,
        in text: String,
        into matches: inout [DetectedMatch],
        options: NSRegularExpression.Options = [],
        excluding excludedRanges: [NSRange] = []
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        regex.matches(in: text, range: range).prefix(8).forEach { match in
            guard !excludedRanges.contains(where: { NSIntersectionRange($0, match.range).length > 0 }) else { return }
            guard let swiftRange = Range(match.range, in: text) else { return }
            matches.append(.init(kind: kind, value: String(text[swiftRange]), range: match.range))
        }
    }

    private static func appendLabeledNumberMatches(
        in text: String,
        into matches: inout [DetectedMatch],
        excluding excludedRanges: [NSRange] = []
    ) {
        let labels = [
            "验证码", "校验码", "动态码", "取件码", "提取码",
            "订单号", "订单", "单号", "快递单号", "运单号", "物流单号",
            "票号", "发票号", "编号", "序列号", "工单号",
            "code", "pin", "otp", "order", "tracking", "invoice", "ticket", "serial", "case"
        ].joined(separator: "|")
        let pattern = #"(?i)(?:\#(labels))\s*[:：#]?\s*([A-Z0-9][A-Z0-9 -]{2,30}[A-Z0-9])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        regex.matches(in: text, range: range).prefix(6).forEach { match in
            guard !excludedRanges.contains(where: { NSIntersectionRange($0, match.range).length > 0 }) else { return }
            guard match.numberOfRanges > 1,
                  let valueRange = Range(match.range(at: 1), in: text)
            else { return }

            let value = String(text[valueRange])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let digitCount = value.filter(\.isNumber).count
            guard digitCount >= 3 else { return }

            matches.append(.init(kind: .number, value: value, range: match.range(at: 1)))
        }
    }

    private static func appendPhoneMatches(in text: String, into matches: inout [DetectedMatch]) {
        let pattern = #"(?<!\d)(?:\+?\d[\d\s().-]{6,}\d)(?!\d)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        regex.matches(in: text, range: range).prefix(6).forEach { match in
            guard let swiftRange = Range(match.range, in: text) else { return }
            let value = String(text[swiftRange])
            let digitCount = value.filter(\.isNumber).count
            guard (10...15).contains(digitCount), !looksLikeDate(value) else { return }
            matches.append(.init(kind: .phone, value: value, range: match.range))
        }
    }

    private static func looksLikeDate(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.range(
            of: #"^\d{4}[-/.]\d{1,2}[-/.]\d{1,2}$"#,
            options: .regularExpression
        ) != nil
    }

    private static func looksLikeAddress(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 8, trimmed.count < 180 else { return false }
        let lower = trimmed.lowercased()
        let tokens = [" street", " st ", " road", " rd ", " avenue", " ave ", " lane", " ln ", " drive", " dr ", " boulevard", " blvd", "号", "路", "街", "区", "市"]
        return tokens.contains { lower.contains($0) } && trimmed.rangeOfCharacter(from: .decimalDigits) != nil
    }
}
