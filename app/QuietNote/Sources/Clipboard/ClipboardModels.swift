import Foundation

struct ClipboardItem: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let text: String
    let createdAt: Date
    let detections: [ClipboardDetection]
    let preview: String
    let timeLabel: String

    init(id: UUID, text: String, createdAt: Date, detections: [ClipboardDetection], preview: String? = nil) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.detections = detections
        self.preview = preview ?? Self.makePreview(from: text)
        timeLabel = Self.makeTimeLabel(from: createdAt)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case text
        case createdAt
        case detections
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        id = try container.decode(UUID.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        detections = try container.decode([ClipboardDetection].self, forKey: .detections)
        preview = Self.makePreview(from: text)
        timeLabel = Self.makeTimeLabel(from: createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(detections, forKey: .detections)
    }

    private static func makePreview(from text: String) -> String {
        let maxCharacters = 640
        let prefix = text.prefix(maxCharacters)
        let clipped = prefix.endIndex != text.endIndex
        var preview = String(prefix).replacingOccurrences(of: "\n", with: " ")
        if clipped {
            preview += "…"
        }
        return preview
    }

    private static func makeTimeLabel(from date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

struct ClipboardDetection: Codable, Identifiable, Equatable, Sendable {
    enum Kind: String, Codable, CaseIterable, Sendable {
        case url = "URL"
        case email = "Email"
        case phone = "Phone"
        case address = "Address"
        case file = "File"
        case number = "Number"
        case text = "Text"
    }

    let id: UUID
    let kind: Kind
    let value: String
}

struct ClipboardListSnapshot {
    let totalCount: Int
    let items: [ClipboardItem]
}

extension ClipboardDetection {
    var symbol: String {
        switch kind {
        case .url: "link"
        case .email: "envelope"
        case .phone: "phone"
        case .address: "mappin.and.ellipse"
        case .file: "folder"
        case .number: "number"
        case .text: "text.quote"
        }
    }

    var openTitle: String? {
        switch kind {
        case .url: "Open URL"
        case .email: "Send Email"
        case .phone: "Call"
        case .address: "Open in Maps"
        case .file: "Open in Finder"
        case .number: nil
        case .text: nil
        }
    }

    var openSymbol: String {
        switch kind {
        case .url: "safari"
        case .email: "paperplane"
        case .phone: "phone.arrow.up.right"
        case .address: "map"
        case .file: "folder"
        case .number: "arrow.up.right"
        case .text: "doc.on.doc"
        }
    }

    var openURL: URL? {
        switch kind {
        case .url:
            if value.range(of: #"^https?://"#, options: [.regularExpression, .caseInsensitive]) != nil {
                return URL(string: value)
            }
            return URL(string: "https://\(value)")
        case .email:
            return URL(string: "mailto:\(value)")
        case .phone:
            let cleaned = value.filter { $0.isNumber || $0 == "+" }
            return cleaned.isEmpty ? nil : URL(string: "tel:\(cleaned)")
        case .address:
            guard let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
            return URL(string: "http://maps.apple.com/?q=\(encoded)")
        case .file:
            return fileURL
        case .number:
            return nil
        case .text:
            return nil
        }
    }

    var fileURL: URL? {
        guard kind == .file else { return nil }
        let expandedPath = (value as NSString).expandingTildeInPath
        guard expandedPath.hasPrefix("/") else { return nil }
        return URL(fileURLWithPath: expandedPath)
    }
}
