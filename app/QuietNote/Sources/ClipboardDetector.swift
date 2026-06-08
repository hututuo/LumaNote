import Foundation

enum ClipboardDetector {
    static func detect(in text: String) -> [ClipboardDetection] {
        var matches: [DetectedMatch] = []

        appendLabeledValueMatches(in: text, into: &matches)
        appendMatches(kind: .url, pattern: #"(?i)(?:https?://|www\.)[^\s<>"'，。；、！？]+"#, in: text, into: &matches, excluding: matches.map(\.range))
        appendMatches(kind: .email, pattern: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, in: text, into: &matches, options: [.caseInsensitive], excluding: matches.map(\.range))
        appendPhoneMatches(in: text, into: &matches, excluding: matches.map(\.range))
        appendLabeledNumberMatches(in: text, into: &matches, excluding: matches.map(\.range))
        appendAddressMatches(in: text, into: &matches, excluding: matches.map(\.range))

        let detections = matches.map {
            ClipboardDetection(id: UUID(), kind: $0.kind, value: $0.value)
        }

        var seen = Set<String>()
        return detections.filter { detection in
            let key = "\(detection.kind.rawValue):\(detection.value)"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    private static func appendLabeledValueMatches(in text: String, into matches: inout [DetectedMatch]) {
        let labelPattern = #"(?:[\s,，;；]*)([\p{Han}A-Za-z][\p{Han}A-Za-z0-9 _-]{0,14})\s*[:：]\s*(.+?)(?=(?:[\s,，;；]+[\p{Han}A-Za-z][\p{Han}A-Za-z0-9 _-]{0,14}\s*[:：])|[\n;；]|$)"#
        guard let regex = try? NSRegularExpression(pattern: labelPattern, options: [.caseInsensitive]) else { return }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        regex.matches(in: text, range: range).prefix(10).forEach { match in
            guard match.numberOfRanges > 2,
                  let labelRange = Range(match.range(at: 1), in: text),
                  let valueRange = Range(match.range(at: 2), in: text)
            else { return }

            let label = String(text[labelRange])
            let rawValue = String(text[valueRange])
            let value = cleanedLabeledValue(rawValue)
            guard value.count >= 2 else { return }

            let valueNSRange = NSRange(valueRange, in: text)
            if let kind = kind(forLabel: label, value: value) {
                matches.append(.init(kind: kind, value: value, range: valueNSRange))
                return
            }

            var nested: [DetectedMatch] = []
            appendMatches(kind: .url, pattern: #"(?i)(?:https?://|www\.)[^\s<>"'，。；、！？]+"#, in: value, into: &nested)
            appendMatches(kind: .email, pattern: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, in: value, into: &nested, options: [.caseInsensitive])
            appendPhoneMatches(in: value, into: &nested)
            appendLabeledNumberMatches(in: "\(label): \(value)", into: &nested)

            if nested.isEmpty, looksLikeAddress(value, allowNoDigit: true) {
                nested.append(.init(kind: .address, value: value, range: NSRange(location: 0, length: (value as NSString).length)))
            }

            if !nested.isEmpty {
                nested.forEach { nestedMatch in
                    matches.append(.init(kind: nestedMatch.kind, value: nestedMatch.value, range: valueNSRange))
                }
            } else {
                matches.append(.init(kind: .text, value: value, range: valueNSRange))
            }
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

    private static func appendPhoneMatches(
        in text: String,
        into matches: inout [DetectedMatch],
        excluding excludedRanges: [NSRange] = []
    ) {
        let pattern = #"(?<!\d)(?:\+?\d[\d\s().-]{6,}\d)(?!\d)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        regex.matches(in: text, range: range).prefix(6).forEach { match in
            guard !excludedRanges.contains(where: { NSIntersectionRange($0, match.range).length > 0 }) else { return }
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

    private static func appendAddressMatches(
        in text: String,
        into matches: inout [DetectedMatch],
        excluding excludedRanges: [NSRange] = []
    ) {
        let sentenceSeparators = CharacterSet(charactersIn: "\n;；")
        let nsText = text as NSString
        var start = 0

        while start < nsText.length {
            var end = start
            while end < nsText.length {
                let scalar = UnicodeScalar(nsText.character(at: end)) ?? "\n"
                if sentenceSeparators.contains(scalar) { break }
                end += 1
            }

            let range = NSRange(location: start, length: end - start)
            if !excludedRanges.contains(where: { NSIntersectionRange($0, range).length > 0 }) {
                let candidate = nsText.substring(with: range)
                let trimmed = cleanedLabeledValue(candidate)
                if looksLikeAddress(trimmed, allowNoDigit: false) {
                    matches.append(.init(kind: .address, value: trimmed, range: range))
                }
            }

            start = end + 1
        }
    }

    private static func cleanedLabeledValue(_ value: String) -> String {
        value.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "，,。；;、:：")))
    }

    private static func kind(forLabel label: String, value: String) -> ClipboardDetection.Kind? {
        let normalized = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if ["网址", "链接", "url", "link", "website", "site"].contains(where: { normalized.contains($0) }) {
            let looksLikeURL = value.range(of: #"(?i)^(?:https?://|www\.)"#, options: .regularExpression) != nil
                || value.range(of: #"^[A-Z0-9.-]+\.[A-Z]{2,}(?:[/#?].*)?$"#, options: [.regularExpression, .caseInsensitive]) != nil
            return looksLikeURL ? .url : .text
        }
        if ["邮箱", "邮件", "email", "mail"].contains(where: { normalized.contains($0) }) {
            let looksLikeEmail = value.range(of: #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#, options: [.regularExpression, .caseInsensitive]) != nil
            return looksLikeEmail ? .email : .text
        }
        if ["电话", "手机", "手机号", "联系方式", "phone", "mobile", "tel"].contains(where: { normalized.contains($0) }) {
            let digitCount = value.filter(\.isNumber).count
            return (10...15).contains(digitCount) && !looksLikeDate(value) ? .phone : .text
        }
        if ["地址", "收货", "寄送", "邮寄", "住址", "address", "addr", "location"].contains(where: { normalized.contains($0) }) {
            return .address
        }
        if [
            "验证码", "校验码", "动态码", "取件码", "提取码",
            "订单号", "订单", "单号", "快递单号", "运单号", "物流单号",
            "票号", "发票号", "编号", "序列号", "工单号",
            "code", "pin", "otp", "order", "tracking", "invoice", "ticket", "serial", "case"
        ].contains(where: { normalized.contains($0) }) {
            let digitCount = value.filter(\.isNumber).count
            return digitCount >= 3 ? .number : .text
        }

        return nil
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
