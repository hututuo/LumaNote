import Foundation

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
    static func write(_ text: String, to url: URL) -> Bool {
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }

    static func writeOffMain(_ text: String, to url: URL) async -> Bool {
        await Task.detached(priority: .utility) {
            write(text, to: url)
        }.value
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
}
