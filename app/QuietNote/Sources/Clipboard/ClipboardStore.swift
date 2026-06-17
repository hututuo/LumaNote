import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class ClipboardStore {
    private(set) var items: [ClipboardItem] = []
    private(set) var latestSuggestion: ClipboardDetection?
    private(set) var latestDetectedItem: ClipboardItem?

    @ObservationIgnored private var settings: AppSettings?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var saveGeneration = 0
    @ObservationIgnored private var detectionTask: Task<Void, Never>?
    @ObservationIgnored private var detectionGeneration = 0
    @ObservationIgnored private var lastChangeCount = NSPasteboard.general.changeCount
    @ObservationIgnored private var itemFingerprints: [UUID: UInt64] = [:]
    @ObservationIgnored private var itemSearchIndex: [UUID: String] = [:]
    private let fileURL: URL

    init(settings: AppSettings? = nil, supportDirectory: URL? = nil) {
        let support = supportDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "QuietNote", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        fileURL = support.appending(path: "clipboard.json")
        load()
        if let settings {
            bind(settings: settings)
        }
    }

    private func bind(settings: AppSettings) {
        self.settings = settings
        settings.monitorClipboardDidChange = { [weak self] isEnabled in
            guard let self else { return }
            if isEnabled {
                self.startMonitoring()
            } else {
                self.stopMonitoring()
            }
        }

        settings.clipboardLimitDidChange = { [weak self] limit in
            self?.trim(to: limit)
        }

        if settings.monitorClipboard {
            startMonitoring()
        }
    }

    func startMonitoring() {
        guard settings?.monitorClipboard == true else {
            stopMonitoring()
            return
        }
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
        cancelPendingDetection()
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

    func visibleItems(matching rawQuery: String, limit: Int) -> ClipboardListSnapshot {
        let normalizedQuery = Self.normalizedSearchText(rawQuery.trimmingCharacters(in: .whitespacesAndNewlines))
        let itemLimit = max(0, limit)
        guard !normalizedQuery.isEmpty else {
            return ClipboardListSnapshot(
                totalCount: items.count,
                items: Array(items.prefix(itemLimit))
            )
        }

        var visibleItems: [ClipboardItem] = []
        visibleItems.reserveCapacity(min(itemLimit, items.count))
        var totalCount = 0

        for item in items where indexedSearchText(for: item).contains(normalizedQuery) {
            totalCount += 1
            if visibleItems.count < itemLimit {
                visibleItems.append(item)
            }
        }

        return ClipboardListSnapshot(totalCount: totalCount, items: visibleItems)
    }

    func delete(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        itemFingerprints[item.id] = nil
        itemSearchIndex[item.id] = nil
        if latestDetectedItem?.id == item.id {
            latestDetectedItem = nil
            latestSuggestion = nil
        }
        save(debounce: false)
    }

    func clear() {
        cancelPendingDetection()
        items.removeAll()
        itemFingerprints.removeAll()
        itemSearchIndex.removeAll()
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
              !text.isEmpty,
              !Self.isLikelyCorruptedClipboardText(text)
        else { return }

        enqueueClipboardText(text)
    }

    func captureTextForTesting(_ rawText: String) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty,
              !Self.isLikelyCorruptedClipboardText(text)
        else { return }
        enqueueClipboardText(text)
    }

    func waitForPendingDetectionForTesting() async {
        let task = detectionTask
        await task?.value
    }

    func waitForPendingSaveForTesting() async {
        let task = saveTask
        await task?.value
    }

    var hasPendingSaveForTesting: Bool {
        saveTask != nil
    }

    var isMonitoringForTesting: Bool {
        timer != nil
    }

    func trimForTesting(to limit: Int) {
        trim(to: limit)
    }

    private func enqueueClipboardText(_ text: String) {
        detectionGeneration &+= 1
        let generation = detectionGeneration
        detectionTask?.cancel()
        detectionTask = Task { [weak self] in
            async let fingerprint = Self.contentFingerprintOffMain(for: text)
            async let detections = ClipboardDetector.detectOffMain(in: text)
            let result = await (fingerprint, detections)

            guard !Task.isCancelled,
                  let self,
                  self.detectionGeneration == generation
            else { return }

            self.applyDetectedClipboardText(
                text: text,
                fingerprint: result.0,
                detections: result.1
            )
            self.detectionTask = nil
        }
    }

    private func applyDetectedClipboardText(
        text: String,
        fingerprint: UInt64,
        detections: [ClipboardDetection]
    ) {
        if let existingIndex = items.firstIndex(where: { item in
            itemFingerprints[item.id] == fingerprint && item.text == text
        }) {
            let refreshed = ClipboardItem(
                id: items[existingIndex].id,
                text: text,
                createdAt: items[existingIndex].createdAt,
                detections: detections
            )
            items.remove(at: existingIndex)
            items.insert(refreshed, at: 0)
            itemFingerprints[refreshed.id] = fingerprint
            itemSearchIndex[refreshed.id] = nil
            latestSuggestion = refreshed.detections.first
            latestDetectedItem = refreshed.detections.isEmpty ? nil : refreshed
            save()
            return
        }

        let item = ClipboardItem(id: UUID(), text: text, createdAt: Date(), detections: detections)
        items.insert(item, at: 0)
        itemFingerprints[item.id] = fingerprint
        latestSuggestion = detections.first
        latestDetectedItem = detections.isEmpty ? nil : item

        trim(to: settings?.clipboardLimit ?? 200)
        save()
    }

    private func cancelPendingDetection() {
        detectionGeneration &+= 1
        detectionTask?.cancel()
        detectionTask = nil
    }

    private func trim(to limit: Int) {
        let normalizedLimit = max(0, limit)
        guard items.count > normalizedLimit else { return }
        items = Array(items.prefix(normalizedLimit))
        rebuildItemCaches()
        save()
    }

    private func load() {
        items = ClipboardPersistence.load(from: fileURL) ?? []
        rebuildItemCaches()
    }

    private func save(debounce: Bool = true) {
        saveGeneration &+= 1
        let generation = saveGeneration
        saveTask?.cancel()
        let snapshot = items
        let fileURL = fileURL
        saveTask = Task { [weak self] in
            if debounce {
                try? await Task.sleep(for: .milliseconds(160))
            }
            guard !Task.isCancelled else { return }
            _ = await ClipboardPersistence.saveOffMain(snapshot, to: fileURL)
            guard !Task.isCancelled,
                  self?.saveGeneration == generation
            else { return }
            self?.saveTask = nil
        }
    }

    private func rebuildItemCaches() {
        itemFingerprints = Dictionary(
            uniqueKeysWithValues: items.map { item in
                (item.id, Self.contentFingerprint(for: item.text))
            }
        )
        itemSearchIndex.removeAll()
    }

    nonisolated private static func contentFingerprint(for text: String) -> UInt64 {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }

    nonisolated private static func contentFingerprintOffMain(for text: String) async -> UInt64 {
        await Task.detached(priority: .utility) {
            contentFingerprint(for: text)
        }.value
    }

    private func indexedSearchText(for item: ClipboardItem) -> String {
        if let searchText = itemSearchIndex[item.id] {
            return searchText
        }
        let searchText = Self.searchableText(for: item)
        itemSearchIndex[item.id] = searchText
        return searchText
    }

    private static func searchableText(for item: ClipboardItem) -> String {
        let detectedValues = item.detections.map(\.value).joined(separator: " ")
        return normalizedSearchText("\(item.text) \(detectedValues)")
    }

    private static func normalizedSearchText(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }

    private static func isLikelyCorruptedClipboardText(_ text: String) -> Bool {
        let replacementCount = text.reduce(into: 0) { count, character in
            if character == "\u{FFFD}" {
                count += 1
            }
        }
        guard replacementCount >= 8 else { return false }
        return Double(replacementCount) / Double(max(text.count, 1)) >= 0.02
    }
}
