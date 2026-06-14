import AppKit
import Combine
import Foundation

struct ClipboardItem: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let text: String
    let createdAt: Date
    let detections: [ClipboardDetection]

    var preview: String {
        text.replacingOccurrences(of: "\n", with: " ")
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

private enum ClipboardPersistence {
    static func load(from fileURL: URL) -> [ClipboardItem]? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode([ClipboardItem].self, from: data)
    }

    static func save(_ items: [ClipboardItem], to fileURL: URL) -> Bool {
        guard let data = try? JSONEncoder().encode(items) else { return false }
        do {
            try data.write(to: fileURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    static func saveOffMain(_ items: [ClipboardItem], to fileURL: URL) async -> Bool {
        await Task.detached(priority: .utility) {
            save(items, to: fileURL)
        }.value
    }
}

@MainActor
final class ClipboardStore: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []
    @Published private(set) var latestSuggestion: ClipboardDetection?
    @Published private(set) var latestDetectedItem: ClipboardItem?

    private var settings: AppSettings?
    private var timer: Timer?
    private var saveTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []
    private var lastChangeCount = NSPasteboard.general.changeCount
    private var itemFingerprints: [UUID: UInt64] = [:]
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
            .dropFirst()
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
        if detection.kind == .file, let url = detection.fileURL {
            NSWorkspace.shared.activateFileViewerSelecting([url])
            return
        }
        guard let url = detection.openURL else { return }
        NSWorkspace.shared.open(url)
    }

    func delete(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        itemFingerprints[item.id] = nil
        if latestDetectedItem?.id == item.id {
            latestDetectedItem = nil
            latestSuggestion = nil
        }
        save(debounce: false)
    }

    func clear() {
        items.removeAll()
        itemFingerprints.removeAll()
        latestSuggestion = nil
        latestDetectedItem = nil
        save(debounce: false)
    }

    private func capturePasteboard(force: Bool) {
        guard settings?.monitorClipboard == true else { return }

        let pasteboard = NSPasteboard.general
        guard force || pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        guard let text = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty
        else { return }

        let fingerprint = Self.contentFingerprint(for: text)
        if let existingIndex = items.firstIndex(where: { item in
            itemFingerprints[item.id] == fingerprint && item.text == text
        }) {
            let refreshed = ClipboardItem(
                id: items[existingIndex].id,
                text: text,
                createdAt: items[existingIndex].createdAt,
                detections: ClipboardDetector.detect(in: text)
            )
            items.remove(at: existingIndex)
            items.insert(refreshed, at: 0)
            itemFingerprints[refreshed.id] = fingerprint
            latestSuggestion = refreshed.detections.first
            latestDetectedItem = refreshed.detections.isEmpty ? nil : refreshed
            save()
            return
        }

        let detections = ClipboardDetector.detect(in: text)
        let item = ClipboardItem(id: UUID(), text: text, createdAt: Date(), detections: detections)
        items.insert(item, at: 0)
        itemFingerprints[item.id] = fingerprint
        latestSuggestion = detections.first
        latestDetectedItem = detections.isEmpty ? nil : item

        trim(to: settings?.clipboardLimit ?? 200)
        save()
    }

    private func trim(to limit: Int) {
        guard items.count > limit else { return }
        items = Array(items.prefix(limit))
        rebuildFingerprints()
        save()
    }

    private func load() {
        items = ClipboardPersistence.load(from: fileURL) ?? []
        rebuildFingerprints()
    }

    private func save(debounce: Bool = true) {
        saveTask?.cancel()
        let snapshot = items
        let fileURL = fileURL
        saveTask = Task {
            if debounce {
                try? await Task.sleep(for: .milliseconds(160))
            }
            guard !Task.isCancelled else { return }
            _ = await ClipboardPersistence.saveOffMain(snapshot, to: fileURL)
        }
    }

    private func rebuildFingerprints() {
        itemFingerprints = Dictionary(
            uniqueKeysWithValues: items.map { item in
                (item.id, Self.contentFingerprint(for: item.text))
            }
        )
    }

    private static func contentFingerprint(for text: String) -> UInt64 {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }

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
