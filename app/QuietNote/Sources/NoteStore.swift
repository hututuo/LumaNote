import Combine
import Foundation

@MainActor
final class NoteStore: ObservableObject {
    @Published var markdown: String {
        didSet {
            if !isReplacingText {
                scheduleSave()
            }
        }
    }

    @Published private(set) var lastSavedText = "Saved"
    @Published private(set) var currentFileURL: URL
    @Published private(set) var recentFileURLs: [URL] = []

    private let defaultFileURL: URL
    private let defaults = UserDefaults.standard
    private var saveTask: Task<Void, Never>?
    private var isReplacingText = false

    var displayTitle: String {
        let lines = markdown.split(whereSeparator: \.isNewline)
        if let heading = lines.first(where: { line in
            line.trimmingCharacters(in: .whitespaces).hasPrefix("#")
        }) {
            let title = heading
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "# "))
            if !title.isEmpty {
                return title
            }
        }

        return currentFileURL.lastPathComponent
    }

    var currentFileName: String {
        currentFileURL.lastPathComponent
    }

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "QuietNote", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        defaultFileURL = support.appending(path: "note.md")

        let initialFileURL: URL
        if let savedPath = defaults.string(forKey: Keys.currentFilePath), !savedPath.isEmpty {
            initialFileURL = URL(fileURLWithPath: savedPath)
        } else {
            initialFileURL = defaultFileURL
        }
        currentFileURL = initialFileURL
        recentFileURLs = Self.loadRecentFileURLs(from: defaults)

        if let data = try? Data(contentsOf: initialFileURL),
           let text = String(data: data, encoding: .utf8),
           !text.isEmpty {
            markdown = text
            rememberRecentFile(initialFileURL)
        } else {
            markdown = """
            # Today

            - [ ] Write implementation plan
            - [ ] Test keyboard shortcut
            - [ ] Ship the build

            > Quiet is productive.

            Reference: [Apple HIG](https://developer.apple.com/design/human-interface-guidelines/)

            Quick snippet: `cmd + shift + n`
            """
        }
    }

    func saveNow() {
        saveTask?.cancel()
        do {
            try markdown.write(to: currentFileURL, atomically: true, encoding: .utf8)
            lastSavedText = "Saved just now"
        } catch {
            lastSavedText = "Save failed"
        }
    }

    func openFile(at url: URL) {
        saveNow()
        saveTask?.cancel()

        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            currentFileURL = url
            defaults.set(url.path, forKey: Keys.currentFilePath)
            rememberRecentFile(url)
            isReplacingText = true
            markdown = text
            isReplacingText = false
            lastSavedText = "Opened"
        } catch {
            lastSavedText = "Open failed"
        }
    }

    func saveAs(to url: URL) {
        saveTask?.cancel()
        currentFileURL = url
        defaults.set(url.path, forKey: Keys.currentFilePath)
        rememberRecentFile(url)
        saveNow()
    }

    func removeRecentFile(_ url: URL) {
        let path = url.standardizedFileURL.path
        recentFileURLs.removeAll { $0.standardizedFileURL.path == path }
        defaults.set(recentFileURLs.map(\.path), forKey: Keys.recentFilePaths)
    }

    private func scheduleSave() {
        lastSavedText = "Saving..."
        saveTask?.cancel()
        let text = markdown
        let url = currentFileURL
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            do {
                try text.write(to: url, atomically: true, encoding: .utf8)
                await MainActor.run { self?.lastSavedText = "Saved just now" }
            } catch {
                await MainActor.run { self?.lastSavedText = "Save failed" }
            }
        }
    }

    private func rememberRecentFile(_ url: URL) {
        let standardizedURL = url.standardizedFileURL
        let path = standardizedURL.path
        recentFileURLs.removeAll { $0.standardizedFileURL.path == path }
        recentFileURLs.insert(standardizedURL, at: 0)
        recentFileURLs = Array(recentFileURLs.prefix(8))
        defaults.set(recentFileURLs.map(\.path), forKey: Keys.recentFilePaths)
    }

    private static func loadRecentFileURLs(from defaults: UserDefaults) -> [URL] {
        let paths = defaults.stringArray(forKey: Keys.recentFilePaths) ?? []
        var seen: Set<String> = []
        return paths.compactMap { path in
            guard !path.isEmpty, FileManager.default.fileExists(atPath: path), seen.insert(path).inserted else {
                return nil
            }
            return URL(fileURLWithPath: path).standardizedFileURL
        }
    }

    private enum Keys {
        static let currentFilePath = "currentFilePath"
        static let recentFilePaths = "recentFilePaths"
    }
}
