import Foundation

struct NoteFileModificationIdentity: Equatable, Sendable {
    let modificationDate: Date?
    let size: UInt64?
}

enum NoteFileWriteResult: Equatable, Sendable {
    case saved(NoteFileModificationIdentity?)
    case failed
    case conflict
}

private final class NoteFileWriteCoordinator: @unchecked Sendable {
    private let queue: DispatchQueue
    private let tokenLock = NSLock()
    private var nextToken = 0
    private var latestTokenByPath: [String: Int] = [:]

    init(label: String) {
        queue = DispatchQueue(label: label)
    }

    func beginWrite(for url: URL) -> Int {
        tokenLock.lock()
        defer { tokenLock.unlock() }
        nextToken &+= 1
        latestTokenByPath[url.standardizedFileURL.path] = nextToken
        return nextToken
    }

    func write(
        token: Int,
        for url: URL,
        operation: @escaping @Sendable () -> NoteFileWriteResult
    ) -> NoteFileWriteResult {
        queue.sync {
            guard isLatest(token, for: url) else { return .failed }
            return operation()
        }
    }

    func writeOffMain(
        token: Int,
        for url: URL,
        operation: @escaping @Sendable () -> NoteFileWriteResult
    ) async -> NoteFileWriteResult {
        await withCheckedContinuation { continuation in
            queue.async {
                guard self.isLatest(token, for: url) else {
                    continuation.resume(returning: .failed)
                    return
                }
                continuation.resume(returning: operation())
            }
        }
    }

    func isLatest(_ token: Int, for url: URL) -> Bool {
        tokenLock.lock()
        defer { tokenLock.unlock() }
        return latestTokenByPath[url.standardizedFileURL.path] == token
    }
}

/// The file boundary used by `NoteStore`.
///
/// The closures are deliberately synchronous for writes.  NoteStore is a
/// main-actor model and a synchronous, serialized write gives saveNow/hide/
/// terminate one unambiguous ordering: the last snapshot submitted by the
/// model is the last snapshot written to disk.  Reads still have an async
/// helper so opening a large document does not have to block the model actor.
struct NoteFileOperations: @unchecked Sendable {
    typealias Reader = @Sendable (URL) -> String?
    typealias Writer = @Sendable (String, URL) -> Bool
    typealias IdentityReader = @Sendable (URL) -> NoteFileModificationIdentity?
    typealias ConditionalWriter = @Sendable (String, URL, NoteFileModificationIdentity?) -> NoteFileWriteResult

    let reader: Reader
    let writer: Writer
    let identityReader: IdentityReader
    let conditionalWriter: ConditionalWriter
    private let coordinator: NoteFileWriteCoordinator

    init(
        reader: @escaping Reader,
        writer: @escaping Writer,
        identityReader: @escaping IdentityReader,
        conditionalWriter: ConditionalWriter? = nil
    ) {
        self.reader = reader
        self.writer = writer
        self.identityReader = identityReader
        self.coordinator = NoteFileWriteCoordinator(label: "com.lumanote.note-file-operations")
        self.conditionalWriter = conditionalWriter ?? { text, url, expectedIdentity in
            guard identityReader(url) == expectedIdentity else { return .conflict }
            guard writer(text, url) else { return .failed }
            return .saved(identityReader(url))
        }
    }

    static let live = NoteFileOperations(
        reader: { NoteFileReader.read($0) },
        writer: { NoteFileWriter.write($0, to: $1) },
        identityReader: { NoteFileReader.modificationIdentity($0) },
        conditionalWriter: { text, url, expectedIdentity in
            NoteFileWriter.writeIfIdentityMatches(text, to: url, expectedIdentity: expectedIdentity)
        }
    )

    func read(_ url: URL) -> String? {
        reader(url)
    }

    func readOffMain(_ url: URL) async -> String? {
        let reader = reader
        return await Task.detached(priority: .userInitiated) {
            reader(url)
        }.value
    }

    func write(_ text: String, to url: URL) -> Bool {
        writer(text, url)
    }

    func writeIfIdentityMatches(
        _ text: String,
        to url: URL,
        expectedIdentity: NoteFileModificationIdentity?
    ) -> NoteFileWriteResult {
        let token = coordinator.beginWrite(for: url)
        return writeIfIdentityMatches(text, to: url, expectedIdentity: expectedIdentity, token: token)
    }

    func beginWrite(for url: URL) -> Int {
        coordinator.beginWrite(for: url)
    }

    func isLatestWrite(_ token: Int, for url: URL) -> Bool {
        coordinator.isLatest(token, for: url)
    }

    func writeIfIdentityMatches(
        _ text: String,
        to url: URL,
        expectedIdentity: NoteFileModificationIdentity?,
        token: Int
    ) -> NoteFileWriteResult {
        let operation = conditionalWriter
        return coordinator.write(token: token, for: url) {
            operation(text, url, expectedIdentity)
        }
    }

    func writeIfIdentityMatchesOffMain(
        _ text: String,
        to url: URL,
        expectedIdentity: NoteFileModificationIdentity?
    ) async -> NoteFileWriteResult {
        let token = coordinator.beginWrite(for: url)
        return await writeIfIdentityMatchesOffMain(
            text,
            to: url,
            expectedIdentity: expectedIdentity,
            token: token
        )
    }

    func writeIfIdentityMatchesOffMain(
        _ text: String,
        to url: URL,
        expectedIdentity: NoteFileModificationIdentity?,
        token: Int
    ) async -> NoteFileWriteResult {
        let operation = conditionalWriter
        return await coordinator.writeOffMain(token: token, for: url) {
            operation(text, url, expectedIdentity)
        }
    }

    func modificationIdentity(for url: URL) -> NoteFileModificationIdentity? {
        identityReader(url)
    }
}

struct NoteWorkspace: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var filePaths: [String]
    var currentFilePath: String?

    init(id: UUID = UUID(), name: String, filePaths: [String], currentFilePath: String? = nil) {
        self.id = id
        self.name = name
        self.filePaths = filePaths
        self.currentFilePath = currentFilePath
    }
}

enum NoteFileWriter {
    private static let queue = DispatchQueue(label: "com.lumanote.note-file-writer")

    static func write(_ text: String, to url: URL) -> Bool {
        queue.sync {
            writeDirect(text, to: url)
        }
    }

    static func writeOffMain(_ text: String, to url: URL) async -> Bool {
        // Keep the compatibility API genuinely off-main while the shared
        // writer queue still provides deterministic serialization.
        await Task.detached(priority: .utility) {
            write(text, to: url)
        }.value
    }

    static func writeIfIdentityMatches(
        _ text: String,
        to url: URL,
        expectedIdentity: NoteFileModificationIdentity?
    ) -> NoteFileWriteResult {
        queue.sync {
            guard NoteFileReader.modificationIdentity(url) == expectedIdentity else {
                return .conflict
            }
            guard writeDirect(text, to: url) else { return .failed }
            return .saved(NoteFileReader.modificationIdentity(url))
        }
    }

    private static func writeDirect(_ text: String, to url: URL) -> Bool {
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }
}

enum NoteFileReader {
    static func read(_ url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func readOffMain(_ url: URL) async -> String? {
        await Task.detached(priority: .userInitiated) {
            read(url)
        }.value
    }

    static func modificationIdentity(_ url: URL) -> NoteFileModificationIdentity? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.standardizedFileURL.path)
        guard let attributes else { return nil }

        let modificationDate = attributes[.modificationDate] as? Date
        let size: UInt64?
        if let number = attributes[.size] as? NSNumber {
            size = number.uint64Value
        } else if let value = attributes[.size] as? UInt64 {
            size = value
        } else if let value = attributes[.size] as? Int {
            size = value >= 0 ? UInt64(value) : nil
        } else {
            size = nil
        }

        guard modificationDate != nil || size != nil else { return nil }
        return NoteFileModificationIdentity(modificationDate: modificationDate, size: size)
    }
}
