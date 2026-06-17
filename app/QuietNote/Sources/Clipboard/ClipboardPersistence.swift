import Foundation

enum ClipboardPersistence {
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
