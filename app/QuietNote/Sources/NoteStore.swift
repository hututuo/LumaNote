import Combine
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

private enum NoteFileWriter {
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

@MainActor
final class NoteStore: ObservableObject {
    @Published var markdown: String {
        didSet {
            refreshDisplayTitle()
            if !isReplacingText {
                scheduleSave()
            }
        }
    }

    private(set) var lastSavedText = "Saved"
    @Published private(set) var currentFileURL: URL
    @Published private(set) var recentFileURLs: [URL] = []
    @Published private(set) var workspaces: [NoteWorkspace] = []
    @Published private(set) var activeWorkspaceID = UUID()
    @Published private(set) var displayTitle = ""

    private let defaultFileURL: URL
    private let defaults: UserDefaults
    private var saveTask: Task<Void, Never>?
    private var isReplacingText = false

    var currentFileName: String {
        currentFileURL.lastPathComponent
    }

    var activeWorkspaceName: String {
        activeWorkspace?.name ?? Self.defaultWorkspaceName
    }

    var activeWorkspaceFileURLs: [URL] {
        guard let workspace = activeWorkspace else { return [currentFileURL] }
        return fileURLs(for: workspace)
    }

    var canSwitchWorkspaceDocument: Bool {
        activeWorkspaceFileURLs.count > 1
    }

    init(defaults: UserDefaults = .standard, supportDirectory: URL? = nil) {
        self.defaults = defaults
        let support = supportDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "QuietNote", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        defaultFileURL = support.appending(path: "note.md")

        let initialFileURL: URL
        if let savedPath = defaults.string(forKey: Keys.currentFilePath), !savedPath.isEmpty {
            if FileManager.default.fileExists(atPath: savedPath) {
                initialFileURL = URL(fileURLWithPath: savedPath)
            } else {
                initialFileURL = defaultFileURL
                defaults.set(defaultFileURL.path, forKey: Keys.currentFilePath)
            }
        } else {
            initialFileURL = defaultFileURL
        }
        currentFileURL = initialFileURL.standardizedFileURL
        recentFileURLs = Self.loadRecentFileURLs(from: defaults)

        if FileManager.default.fileExists(atPath: initialFileURL.path),
           let data = try? Data(contentsOf: initialFileURL),
           let text = String(data: data, encoding: .utf8) {
            markdown = text
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

        workspaces = Self.loadWorkspaces(from: defaults)
        if workspaces.isEmpty {
            workspaces = [Self.makeDefaultWorkspace(currentFileURL: currentFileURL, recentFileURLs: recentFileURLs)]
        } else {
            workspaces = Self.normalizedWorkspaces(workspaces)
        }
        activeWorkspaceID = Self.loadActiveWorkspaceID(from: defaults, workspaces: workspaces)

        rememberRecentFile(currentFileURL)
        rememberFileInActiveWorkspace(currentFileURL, moveToFront: false)
        refreshDisplayTitle()
        persistWorkspaces()
    }

    func saveNow() {
        saveTask?.cancel()
        if NoteFileWriter.write(markdown, to: currentFileURL) {
            lastSavedText = "Saved just now"
        } else {
            lastSavedText = "Save failed"
        }
    }

    func openFile(at url: URL) {
        openFile(at: url, moveToFrontInWorkspace: true)
    }

    func openWorkspaceDocument(at url: URL) {
        openFile(at: url, moveToFrontInWorkspace: false)
    }

    private func openFile(at url: URL, moveToFrontInWorkspace: Bool) {
        saveNow()
        saveTask?.cancel()

        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            let standardizedURL = url.standardizedFileURL
            currentFileURL = standardizedURL
            defaults.set(standardizedURL.path, forKey: Keys.currentFilePath)
            rememberRecentFile(standardizedURL)
            rememberFileInActiveWorkspace(standardizedURL, moveToFront: moveToFrontInWorkspace)
            isReplacingText = true
            markdown = text
            isReplacingText = false
            refreshDisplayTitle()
            lastSavedText = "Opened"
        } catch {
            lastSavedText = "Open failed"
        }
    }

    func saveAs(to url: URL) {
        saveTask?.cancel()
        let standardizedURL = url.standardizedFileURL
        currentFileURL = standardizedURL
        defaults.set(standardizedURL.path, forKey: Keys.currentFilePath)
        rememberRecentFile(standardizedURL)
        rememberFileInActiveWorkspace(standardizedURL)
        refreshDisplayTitle()
        saveNow()
    }

    @discardableResult
    func createMarkdownFile(at url: URL, initialText: String = "") -> Bool {
        saveNow()
        saveTask?.cancel()

        let standardizedURL = url.standardizedFileURL
        guard NoteFileWriter.write(initialText, to: standardizedURL) else {
            lastSavedText = "Create failed"
            return false
        }

        currentFileURL = standardizedURL
        defaults.set(standardizedURL.path, forKey: Keys.currentFilePath)
        rememberRecentFile(standardizedURL)
        rememberFileInActiveWorkspace(standardizedURL)
        isReplacingText = true
        markdown = initialText
        isReplacingText = false
        refreshDisplayTitle()
        lastSavedText = "Created"
        return true
    }

    func removeRecentFile(_ url: URL) {
        let path = url.standardizedFileURL.path
        recentFileURLs.removeAll { $0.standardizedFileURL.path == path }
        defaults.set(recentFileURLs.map(\.path), forKey: Keys.recentFilePaths)
    }

    @discardableResult
    func switchToNextDocument() -> Bool {
        switchWorkspaceDocument(offset: 1)
    }

    @discardableResult
    func switchToPreviousDocument() -> Bool {
        switchWorkspaceDocument(offset: -1)
    }

    @discardableResult
    func switchWorkspaceDocument(offset: Int) -> Bool {
        let urls = activeWorkspaceFileURLs
        guard urls.count > 1 else { return false }

        let currentPath = currentFileURL.standardizedFileURL.path
        guard let currentIndex = urls.firstIndex(where: { $0.standardizedFileURL.path == currentPath }) else {
            rememberFileInActiveWorkspace(currentFileURL)
            return false
        }

        let nextIndex = (currentIndex + offset + urls.count) % urls.count
        let nextURL = urls[nextIndex]
        guard nextURL.standardizedFileURL.path != currentPath else { return false }

        openWorkspaceDocument(at: nextURL)
        return true
    }

    func createWorkspace(named rawName: String, includeCurrentFile: Bool = true) {
        let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmedName.isEmpty ? nextWorkspaceName() : trimmedName
        let currentPath = currentFileURL.standardizedFileURL.path
        let workspace = NoteWorkspace(
            name: name,
            filePaths: includeCurrentFile ? [currentPath] : [],
            currentFilePath: includeCurrentFile ? currentPath : nil
        )
        workspaces.append(workspace)
        activeWorkspaceID = workspace.id
        defaults.set(workspace.id.uuidString, forKey: Keys.activeWorkspaceID)
        persistWorkspaces()
    }

    func switchWorkspace(to workspaceID: NoteWorkspace.ID) {
        guard workspaceID != activeWorkspaceID,
              workspaces.contains(where: { $0.id == workspaceID })
        else { return }

        saveNow()
        activeWorkspaceID = workspaceID
        defaults.set(workspaceID.uuidString, forKey: Keys.activeWorkspaceID)

        guard let workspace = activeWorkspace else {
            persistWorkspaces()
            return
        }

        let targetURL = preferredURL(for: workspace)
        if let targetURL {
            openWorkspaceDocument(at: targetURL)
        } else {
            rememberFileInActiveWorkspace(currentFileURL, moveToFront: false)
            persistWorkspaces()
        }
    }

    func removeFileFromActiveWorkspace(_ url: URL) {
        guard let workspaceIndex = activeWorkspaceIndex else { return }
        let path = url.standardizedFileURL.path
        workspaces[workspaceIndex].filePaths.removeAll { $0 == path }

        if workspaces[workspaceIndex].currentFilePath == path {
            workspaces[workspaceIndex].currentFilePath = workspaces[workspaceIndex].filePaths.first
        }

        if workspaces[workspaceIndex].filePaths.isEmpty {
            rememberFileInActiveWorkspace(currentFileURL, moveToFront: false)
        } else if currentFileURL.standardizedFileURL.path == path,
                  let replacement = preferredURL(for: workspaces[workspaceIndex]) {
            openWorkspaceDocument(at: replacement)
            return
        }

        persistWorkspaces()
    }

    private func scheduleSave() {
        lastSavedText = "Saving..."
        saveTask?.cancel()
        let text = markdown
        let url = currentFileURL
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            let didSave = await NoteFileWriter.writeOffMain(text, to: url)
            guard !Task.isCancelled else { return }
            self?.lastSavedText = didSave ? "Saved just now" : "Save failed"
        }
    }

    private var activeWorkspaceIndex: Int? {
        workspaces.firstIndex { $0.id == activeWorkspaceID }
    }

    private var activeWorkspace: NoteWorkspace? {
        guard let activeWorkspaceIndex else { return nil }
        return workspaces[activeWorkspaceIndex]
    }

    private func rememberFileInActiveWorkspace(_ url: URL, moveToFront: Bool = true) {
        guard !workspaces.isEmpty else {
            workspaces = [Self.makeDefaultWorkspace(currentFileURL: url, recentFileURLs: recentFileURLs)]
            activeWorkspaceID = workspaces[0].id
            defaults.set(activeWorkspaceID.uuidString, forKey: Keys.activeWorkspaceID)
            persistWorkspaces()
            return
        }

        guard let workspaceIndex = activeWorkspaceIndex else {
            activeWorkspaceID = workspaces[0].id
            rememberFileInActiveWorkspace(url, moveToFront: moveToFront)
            return
        }

        let path = url.standardizedFileURL.path
        if let existingIndex = workspaces[workspaceIndex].filePaths.firstIndex(of: path) {
            if moveToFront {
                workspaces[workspaceIndex].filePaths.remove(at: existingIndex)
                workspaces[workspaceIndex].filePaths.insert(path, at: 0)
            }
        } else if moveToFront {
            workspaces[workspaceIndex].filePaths.insert(path, at: 0)
        } else {
            workspaces[workspaceIndex].filePaths.append(path)
        }
        workspaces[workspaceIndex].filePaths = Array(workspaces[workspaceIndex].filePaths.prefix(Self.maximumWorkspaceDocuments))
        workspaces[workspaceIndex].currentFilePath = path
        persistWorkspaces()
    }

    private func fileURLs(for workspace: NoteWorkspace) -> [URL] {
        var seen: Set<String> = []
        let currentPath = currentFileURL.standardizedFileURL.path
        return workspace.filePaths.compactMap { path in
            guard !path.isEmpty, seen.insert(path).inserted else { return nil }
            guard FileManager.default.fileExists(atPath: path) || path == currentPath else { return nil }
            return URL(fileURLWithPath: path).standardizedFileURL
        }
    }

    private func preferredURL(for workspace: NoteWorkspace) -> URL? {
        let urls = fileURLs(for: workspace)
        if let currentFilePath = workspace.currentFilePath,
           let currentURL = urls.first(where: { $0.standardizedFileURL.path == currentFilePath }) {
            return currentURL
        }
        return urls.first
    }

    private func refreshDisplayTitle() {
        let title = Self.title(for: markdown, currentFileURL: currentFileURL)
        if displayTitle != title {
            displayTitle = title
        }
    }

    private static func title(for markdown: String, currentFileURL: URL) -> String {
        var extractedTitle: String?
        markdown.enumerateLines { line, stop in
            guard line.trimmingCharacters(in: .whitespaces).hasPrefix("#") else { return }
            let title = line
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "# "))
            if !title.isEmpty {
                extractedTitle = title
                stop = true
            }
        }

        return extractedTitle ?? currentFileURL.lastPathComponent
    }

    private func rememberRecentFile(_ url: URL) {
        let standardizedURL = url.standardizedFileURL
        let path = standardizedURL.path
        recentFileURLs.removeAll { $0.standardizedFileURL.path == path }
        recentFileURLs.insert(standardizedURL, at: 0)
        recentFileURLs = Array(recentFileURLs.prefix(8))
        defaults.set(recentFileURLs.map(\.path), forKey: Keys.recentFilePaths)
    }

    private func nextWorkspaceName() -> String {
        let base = Self.defaultWorkspaceName
        let existingNames = Set(workspaces.map(\.name))
        var index = workspaces.count + 1
        while existingNames.contains("\(base) \(index)") {
            index += 1
        }
        return "\(base) \(index)"
    }

    private func persistWorkspaces() {
        workspaces = Self.normalizedWorkspaces(workspaces)
        if !workspaces.contains(where: { $0.id == activeWorkspaceID }), let firstID = workspaces.first?.id {
            activeWorkspaceID = firstID
            defaults.set(firstID.uuidString, forKey: Keys.activeWorkspaceID)
        }
        if let data = try? JSONEncoder().encode(workspaces) {
            defaults.set(data, forKey: Keys.workspaces)
        }
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

    private static func loadWorkspaces(from defaults: UserDefaults) -> [NoteWorkspace] {
        guard let data = defaults.data(forKey: Keys.workspaces),
              let workspaces = try? JSONDecoder().decode([NoteWorkspace].self, from: data)
        else { return [] }
        return normalizedWorkspaces(workspaces)
    }

    private static func loadActiveWorkspaceID(from defaults: UserDefaults, workspaces: [NoteWorkspace]) -> UUID {
        if let rawID = defaults.string(forKey: Keys.activeWorkspaceID),
           let id = UUID(uuidString: rawID),
           workspaces.contains(where: { $0.id == id }) {
            return id
        }
        return workspaces.first?.id ?? UUID()
    }

    private static func makeDefaultWorkspace(currentFileURL: URL, recentFileURLs: [URL]) -> NoteWorkspace {
        let paths = uniquePaths([currentFileURL] + recentFileURLs)
        return NoteWorkspace(
            name: defaultWorkspaceName,
            filePaths: paths,
            currentFilePath: currentFileURL.standardizedFileURL.path
        )
    }

    private static func normalizedWorkspaces(_ workspaces: [NoteWorkspace]) -> [NoteWorkspace] {
        workspaces.map { workspace in
            var copy = workspace
            copy.name = copy.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if copy.name.isEmpty {
                copy.name = defaultWorkspaceName
            }
            copy.filePaths = Array(uniquePaths(copy.filePaths.map { URL(fileURLWithPath: $0) }).prefix(maximumWorkspaceDocuments))
            if let currentFilePath = copy.currentFilePath,
               !copy.filePaths.contains(currentFilePath) {
                copy.currentFilePath = copy.filePaths.first
            }
            return copy
        }
    }

    private static func uniquePaths(_ urls: [URL]) -> [String] {
        var seen: Set<String> = []
        return urls.compactMap { url in
            let path = url.standardizedFileURL.path
            guard !path.isEmpty, seen.insert(path).inserted else { return nil }
            return path
        }
    }

    private static let defaultWorkspaceName = "默认工作区"
    private static let maximumWorkspaceDocuments = 24

    private enum Keys {
        static let currentFilePath = "currentFilePath"
        static let recentFilePaths = "recentFilePaths"
        static let workspaces = "noteWorkspaces.v1"
        static let activeWorkspaceID = "activeNoteWorkspaceID.v1"
    }
}
