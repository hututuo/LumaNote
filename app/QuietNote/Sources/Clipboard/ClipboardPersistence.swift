import Foundation

enum ClipboardPersistence {
    static let currentVersion = 1
    static let maximumReadableFileBytes = 16 * 1024 * 1024

    enum LoadStatus: Equatable, Sendable {
        case missing
        case loaded
        case migratedLegacy
        case partiallyRecovered(skippedItems: Int)
        case corrupted
    }

    struct LoadResult: Sendable {
        let items: [ClipboardItem]
        let status: LoadStatus
        let warning: String?

        var canWrite: Bool {
            status != .corrupted
        }
    }

    private struct Envelope: Codable {
        let version: Int
        let items: [ClipboardItem]
    }

    /// Compatibility entry point retained for callers that only need the items.
    /// Store uses `loadResult(from:)` so a corrupt file is never mistaken for an
    /// empty history and subsequently overwritten.
    static func load(from fileURL: URL) -> [ClipboardItem]? {
        let result = loadResult(from: fileURL)
        guard result.status != .corrupted, result.status != .missing else { return nil }
        return result.items
    }

    static func loadResult(from fileURL: URL) -> LoadResult {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return LoadResult(items: [], status: .missing, warning: nil)
        }

        let data: Data
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            if let byteCount = attributes[.size] as? NSNumber,
               byteCount.intValue > maximumReadableFileBytes {
                return LoadResult(
                    items: [],
                    status: .corrupted,
                    warning: "Clipboard history is larger than the safe readable limit. The original file was left untouched."
                )
            }
            data = try Data(contentsOf: fileURL)
        } catch {
            return LoadResult(
                items: [],
                status: .corrupted,
                warning: "Clipboard history could not be read. The original file was left untouched."
            )
        }

        guard !data.isEmpty else {
            return LoadResult(
                items: [],
                status: .corrupted,
                warning: "Clipboard history is empty or invalid. The original file was left untouched."
            )
        }

        let topLevel: Any
        do {
            topLevel = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            return LoadResult(
                items: [],
                status: .corrupted,
                warning: "Clipboard history contains invalid JSON. The original file was left untouched."
            )
        }

        let rawItems: [Any]
        let status: LoadStatus

        if let envelope = topLevel as? [String: Any] {
            guard let version = envelope["version"] as? Int,
                  (1...currentVersion).contains(version),
                  let envelopeItems = envelope["items"] as? [Any]
            else {
                return LoadResult(
                    items: [],
                    status: .corrupted,
                    warning: "Clipboard history uses an unsupported format. The original file was left untouched."
                )
            }
            rawItems = envelopeItems
            status = .loaded
        } else if let legacyItems = topLevel as? [Any] {
            rawItems = legacyItems
            status = .migratedLegacy
        } else {
            return LoadResult(
                items: [],
                status: .corrupted,
                warning: "Clipboard history has an unsupported JSON shape. The original file was left untouched."
            )
        }

        let decoder = JSONDecoder()
        var decodedItems: [ClipboardItem] = []
        decodedItems.reserveCapacity(rawItems.count)
        var skippedItems = 0

        for rawItem in rawItems {
            guard JSONSerialization.isValidJSONObject(rawItem),
                  let itemData = try? JSONSerialization.data(withJSONObject: rawItem),
                  let item = try? decoder.decode(ClipboardItem.self, from: itemData)
            else {
                skippedItems += 1
                continue
            }
            decodedItems.append(item)
        }

        if skippedItems > 0 {
            return LoadResult(
                items: decodedItems,
                status: .partiallyRecovered(skippedItems: skippedItems),
                warning: "Some clipboard records were unreadable and were kept out of the active history."
            )
        }

        return LoadResult(items: decodedItems, status: status, warning: nil)
    }

    static func save(_ items: [ClipboardItem], to fileURL: URL) -> Bool {
        let envelope = Envelope(version: currentVersion, items: items)
        guard let data = try? JSONEncoder().encode(envelope) else { return false }
        do {
            try data.write(to: fileURL, options: .atomic)
            // `Data.write(..., .atomic)` replaces the destination with a new
            // temporary file. Its mode is affected by the process umask (and
            // does not inherit an existing destination's mode), so tighten the
            // final inode explicitly after every save. Clipboard history is
            // sensitive local data and must remain owner-readable/writable only.
            try FileManager.default.setAttributes(
                [.posixPermissions: NSNumber(value: 0o600)],
                ofItemAtPath: fileURL.path
            )
            return true
        } catch {
            return false
        }
    }

    static func saveOffMain(
        _ items: [ClipboardItem],
        to fileURL: URL,
        writer: ClipboardPersistenceWriting,
        generation: Int
    ) async -> Bool {
        await Task.detached(priority: .utility) {
            writer.save(items, to: fileURL, generation: generation)
        }.value
    }

    /// Preserve an unreadable source before an explicit user reset replaces it.
    /// Automatic saves never call this method; they leave the source untouched.
    static func preserveUnreadableFile(at fileURL: URL) -> URL? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let backupURL = fileURL.appendingPathExtension("corrupt")
        do {
            if FileManager.default.fileExists(atPath: backupURL.path) {
                try FileManager.default.removeItem(at: backupURL)
            }
            try FileManager.default.copyItem(at: fileURL, to: backupURL)
            return backupURL
        } catch {
            return nil
        }
    }
}

protocol ClipboardPersistenceWriting: Sendable {
    func save(_ items: [ClipboardItem], to fileURL: URL, generation: Int) -> Bool
}

/// A serial writer with a monotonic generation guard. Cancellation of a Swift
/// Task cannot cancel a synchronous filesystem operation that already entered a
/// detached task, so the guard is the final protection against an old snapshot
/// being written after a newer clear/delete/trim.
final class ClipboardPersistenceWriter: ClipboardPersistenceWriting, @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.lumanote.clipboard-persistence", qos: .utility)
    private var latestGeneration = 0

    func save(_ items: [ClipboardItem], to fileURL: URL, generation: Int) -> Bool {
        queue.sync {
            guard generation >= latestGeneration else { return true }
            latestGeneration = generation
            return ClipboardPersistence.save(items, to: fileURL)
        }
    }
}
