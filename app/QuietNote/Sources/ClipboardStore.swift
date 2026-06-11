import AppKit
import Combine
import Foundation

struct ClipboardItem: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let createdAt: Date
    let detections: [ClipboardDetection]

    var preview: String {
        text.replacingOccurrences(of: "\n", with: " ")
    }
}

struct ClipboardDetection: Codable, Identifiable, Equatable {
    enum Kind: String, Codable, CaseIterable {
        case url = "URL"
        case email = "Email"
        case phone = "Phone"
        case address = "Address"
        case number = "Number"
        case text = "Text"
    }

    let id: UUID
    let kind: Kind
    let value: String
}

@MainActor
final class ClipboardStore: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []
    @Published private(set) var latestSuggestion: ClipboardDetection?
    @Published private(set) var latestDetectedItem: ClipboardItem?

    private var settings: AppSettings?
    private var timer: Timer?
    private var cancellables: Set<AnyCancellable> = []
    private var lastChangeCount = NSPasteboard.general.changeCount
    private let fileURL: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "QuietNote", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        fileURL = support.appending(path: "clipboard.json")
        load()
    }

    func configure(settings: AppSettings) {
        self.settings = settings
        cancellables.removeAll()

        settings.$monitorClipboard
            .removeDuplicates()
            .sink { [weak self] isEnabled in
                guard let self else { return }
                if isEnabled {
                    self.startMonitoring()
                } else {
                    self.stopMonitoring()
                }
            }
            .store(in: &cancellables)

        settings.$clipboardLimit
            .removeDuplicates()
            .sink { [weak self] limit in
                self?.trim(to: limit)
            }
            .store(in: &cancellables)

        if settings.monitorClipboard {
            startMonitoring()
        }
    }

    func startMonitoring() {
        timer?.invalidate()
        capturePasteboard(force: true)

        let timer = Timer(timeInterval: 0.65, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.capturePasteboard(force: false)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        lastChangeCount = NSPasteboard.general.changeCount
    }

    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func open(_ detection: ClipboardDetection) {
        guard let url = detection.openURL else { return }
        NSWorkspace.shared.open(url)
    }

    func delete(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        if latestDetectedItem?.id == item.id {
            latestDetectedItem = nil
            latestSuggestion = nil
        }
        save()
    }

    func clear() {
        items.removeAll()
        latestSuggestion = nil
        latestDetectedItem = nil
        save()
    }

    private func capturePasteboard(force: Bool) {
        guard settings?.monitorClipboard == true else { return }

        let pasteboard = NSPasteboard.general
        guard force || pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        guard let text = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty
        else { return }

        if let existingIndex = items.firstIndex(where: { $0.text == text }) {
            let refreshed = ClipboardItem(
                id: items[existingIndex].id,
                text: text,
                createdAt: items[existingIndex].createdAt,
                detections: ClipboardDetector.detect(in: text)
            )
            items.remove(at: existingIndex)
            items.insert(refreshed, at: 0)
            latestSuggestion = refreshed.detections.first
            latestDetectedItem = refreshed.detections.isEmpty ? nil : refreshed
            save()
            return
        }

        let detections = ClipboardDetector.detect(in: text)
        let item = ClipboardItem(id: UUID(), text: text, createdAt: Date(), detections: detections)
        items.insert(item, at: 0)
        latestSuggestion = detections.first
        latestDetectedItem = detections.isEmpty ? nil : item

        trim(to: settings?.clipboardLimit ?? 200)
        save()
    }

    private func trim(to limit: Int) {
        guard items.count > limit else { return }
        items = Array(items.prefix(limit))
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data)
        else { return }
        items = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

}

extension ClipboardDetection {
    var symbol: String {
        switch kind {
        case .url: "link"
        case .email: "envelope"
        case .phone: "phone"
        case .address: "mappin.and.ellipse"
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
        case .number:
            return nil
        case .text:
            return nil
        }
    }
}
