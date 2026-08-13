import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class ClipboardStore {
    nonisolated static let maximumClipboardItemBytes = 256 * 1024
    nonisolated static let maximumClipboardHistoryBytes = 8 * 1024 * 1024
    nonisolated static let maximumSearchIndexCharacters = 16 * 1024

    private(set) var items: [ClipboardItem] = []
    private(set) var latestSuggestion: ClipboardDetection?
    private(set) var latestDetectedItem: ClipboardItem?
    private(set) var persistenceStatus: ClipboardPersistence.LoadStatus = .missing
    private(set) var persistenceWarning: String?

    @ObservationIgnored private var settings: AppSettings?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var saveGeneration = 0
    @ObservationIgnored private var detectionTask: Task<Void, Never>?
    @ObservationIgnored private var detectionGeneration = 0
    @ObservationIgnored private var lastChangeCount: Int?
    @ObservationIgnored private var itemFingerprints: [UUID: UInt64] = [:]
    @ObservationIgnored private var itemSearchIndex: [UUID: String] = [:]
    @ObservationIgnored private var persistenceWriteBlocked = false
    @ObservationIgnored private let persistenceWriter: any ClipboardPersistenceWriting
    private let fileURL: URL

    init(
        settings: AppSettings? = nil,
        supportDirectory: URL? = nil,
        persistenceWriter: any ClipboardPersistenceWriting = ClipboardPersistenceWriter()
    ) {
        self.persistenceWriter = persistenceWriter
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

        // A stored true value is an existing user's explicit preference and is
        // intentionally preserved across upgrades. Fresh settings default to
        // false, so this branch cannot inspect the pasteboard during onboarding.
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

        let pasteboard = NSPasteboard.general
        lastChangeCount = pasteboard.changeCount
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
        lastChangeCount = nil
        if !items.isEmpty {
            saveNow()
        }
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

        // A corrupt source is never silently overwritten by an automatic save.
        // Clearing is an explicit destructive action, so preserve a forensic
        // copy first and then allow the new empty envelope to be written.
        if persistenceWriteBlocked {
            if let backupURL = ClipboardPersistence.preserveUnreadableFile(at: fileURL) {
                persistenceWarning = "Unreadable clipboard history was preserved at \(backupURL.lastPathComponent)."
            }
            persistenceWriteBlocked = false
            persistenceStatus = .loaded
        }
        saveNow(force: true)
    }

    private func capturePasteboard(force: Bool) {
        guard settings?.monitorClipboard == true else { return }

        let pasteboard = NSPasteboard.general
        guard force || pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        guard let rawText = pasteboard.string(forType: .string),
              let text = Self.boundedClipboardText(rawText),
              !text.isEmpty,
              !Self.isLikelyCorruptedClipboardText(text)
        else { return }

        enqueueClipboardText(text)
    }

    func captureTextForTesting(_ rawText: String) {
        guard let text = Self.boundedClipboardText(rawText),
              !text.isEmpty,
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

    /// Synchronously flush the latest in-memory snapshot. This is intentionally
    /// available to application termination and window-close paths.
    func saveNow() {
        saveNow(force: false)
    }

    func flush() async {
        saveNow()
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

        trim(to: settings?.clipboardLimit ?? AppSettings.defaultClipboardLimit, persist: false)
        if !items.contains(where: { $0.id == item.id }) {
            latestSuggestion = nil
            latestDetectedItem = nil
        }
        save()
    }

    private func cancelPendingDetection() {
        detectionGeneration &+= 1
        detectionTask?.cancel()
        detectionTask = nil
    }

    private func trim(to limit: Int, persist: Bool = true) {
        let normalizedLimit = max(0, limit)
        let bounded = boundedHistory(items, limit: normalizedLimit)
        guard bounded != items else { return }
        items = bounded
        rebuildItemCaches()
        if persist {
            save()
        }
    }

    private func load() {
        let result = ClipboardPersistence.loadResult(from: fileURL)
        persistenceStatus = result.status
        persistenceWarning = result.warning
        persistenceWriteBlocked = !result.canWrite
        // Load all records allowed by the persisted format first. A user's
        // saved clipboardLimit may be higher than the default; binding settings
        // must not silently discard those older records during migration.
        items = boundedHistory(result.items, limit: AppSettings.maximumClipboardLimit)
        rebuildItemCaches()
    }

    private func save(debounce: Bool = true) {
        guard !persistenceWriteBlocked else { return }
        guard !items.isEmpty || FileManager.default.fileExists(atPath: fileURL.path) else { return }

        saveGeneration &+= 1
        let generation = saveGeneration
        saveTask?.cancel()
        let snapshot = items
        let fileURL = fileURL
        let writer = persistenceWriter
        saveTask = Task { [weak self] in
            if debounce {
                do {
                    try await Task.sleep(for: .milliseconds(160))
                } catch {
                    return
                }
            }
            guard !Task.isCancelled else { return }
            let didSave = await ClipboardPersistence.saveOffMain(
                snapshot,
                to: fileURL,
                writer: writer,
                generation: generation
            )
            guard !Task.isCancelled,
                  let self,
                  self.saveGeneration == generation
            else { return }
            self.saveTask = nil
            if !didSave {
                self.persistenceWarning = "Clipboard history could not be saved."
            }
        }
    }

    private func saveNow(force: Bool) {
        guard force || !persistenceWriteBlocked else { return }
        guard force || !items.isEmpty || FileManager.default.fileExists(atPath: fileURL.path) else { return }

        saveGeneration &+= 1
        let generation = saveGeneration
        saveTask?.cancel()
        saveTask = nil
        let didSave = persistenceWriter.save(items, to: fileURL, generation: generation)
        if didSave {
            persistenceStatus = .loaded
        } else {
            persistenceWarning = "Clipboard history could not be saved."
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

    private func boundedHistory(_ source: [ClipboardItem], limit: Int) -> [ClipboardItem] {
        var result: [ClipboardItem] = []
        result.reserveCapacity(min(limit, source.count))
        var totalBytes = 0

        for item in source.prefix(limit) {
            let itemBytes = Self.estimatedStorageBytes(for: item)
            guard itemBytes <= Self.maximumClipboardItemBytes else { continue }
            guard totalBytes + itemBytes <= Self.maximumClipboardHistoryBytes else { break }
            result.append(item)
            totalBytes += itemBytes
        }
        return result
    }

    private static func boundedClipboardText(_ rawText: String) -> String? {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let maximumTextBytes = maximumClipboardItemBytes - 512
        guard trimmed.utf8.count > maximumTextBytes else { return trimmed }

        // String(decoding:) safely repairs a cut UTF-8 scalar; trim any repair
        // marker if it would exceed the byte budget.
        var clipped = String(decoding: trimmed.utf8.prefix(maximumTextBytes), as: UTF8.self)
        while clipped.utf8.count > maximumTextBytes, !clipped.isEmpty {
            clipped.removeLast()
        }
        return clipped.isEmpty ? nil : clipped
    }

    private static func estimatedStorageBytes(for item: ClipboardItem) -> Int {
        128
            + item.text.utf8.count
            + item.detections.reduce(into: 0) { result, detection in
                result += 64 + detection.value.utf8.count
            }
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
        let textPrefix = String(item.text.prefix(maximumSearchIndexCharacters))
        let detectionPrefix = item.detections
            .lazy
            .map(\.value)
            .joined(separator: " ")
        let combined = String("\(textPrefix) \(detectionPrefix)".prefix(maximumSearchIndexCharacters))
        return normalizedSearchText(combined)
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
