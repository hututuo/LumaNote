import Foundation
import Observation

@MainActor
@Observable
final class NoteStore {
    enum InitialLoadMode {
        case immediate
        case deferred
    }

    var markdown: String {
        didSet {
            markdownRevision &+= 1
            refreshDisplayTitle()
            if !isReplacingText {
                scheduleSave()
            }
        }
    }

    private(set) var lastSavedText = "Saved"
    private(set) var currentFileURL: URL
    private(set) var recentFileURLs: [URL] = []
    private(set) var workspaces: [NoteWorkspace] = []
    private(set) var activeWorkspaceID = UUID()
    private(set) var displayTitle = ""
    private(set) var markdownRevision = 0

    private let defaultFileURL: URL
    private let defaults: UserDefaults
    @ObservationIgnored
    private var saveTask: Task<Void, Never>?
    @ObservationIgnored
    private var saveGeneration = 0
    @ObservationIgnored
    private var openTask: Task<Void, Never>?
    @ObservationIgnored
    private var openGeneration = 0
    @ObservationIgnored
    private var initialLoadTask: Task<Void, Never>?
    @ObservationIgnored
    private var initialLoadGeneration = 0
    @ObservationIgnored
    private var initialLoadPlaceholderPath: String?
    @ObservationIgnored
    private var initialLoadPlaceholderRevision: Int?
    @ObservationIgnored
    private var isReplacingText = false
    @ObservationIgnored
    private var workspacePreviewCache: [String: DocumentPreviewCacheEntry] = [:]

    private struct DocumentPreviewCacheEntry {
        let modificationDate: Date?
        let text: String
    }

    var currentFileName: String {
        currentFileURL.lastPathComponent
    }

    var activeWorkspaceName: String {
        activeWorkspace?.name ?? NoteWorkspaceSupport.defaultWorkspaceName
    }

    var activeWorkspaceFileURLs: [URL] {
        guard let workspace = activeWorkspace else { return [currentFileURL] }
        return fileURLs(for: workspace)
    }

    var canSwitchWorkspaceDocument: Bool {
        activeWorkspaceFileURLs.count > 1
    }

    var cachedWorkspacePreviewCountForTesting: Int {
        workspacePreviewCache.count
    }

    var hasActiveInitialLoadPlaceholderForTesting: Bool {
        hasActiveInitialLoadPlaceholder
    }

    var hasPendingSaveForTesting: Bool {
        saveTask != nil
    }

    var hasPendingOpenForTesting: Bool {
        openTask != nil
    }

    func waitForPendingSaveForTesting() async {
        let task = saveTask
        await task?.value
    }

    func waitForPendingOpenForTesting() async {
        let task = openTask
        await task?.value
    }

    func hasCachedWorkspacePreviewForTesting(_ url: URL) -> Bool {
        workspacePreviewCache[url.standardizedFileURL.path] != nil
    }

    init(
        defaults: UserDefaults = .standard,
        supportDirectory: URL? = nil,
        initialLoadMode: InitialLoadMode = .immediate
    ) {
        self.defaults = defaults
        let support = supportDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "QuietNote", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        defaultFileURL = support.appending(path: "示例便签.md")
        let legacyDefaultFileURL = support.appending(path: "note.md")

        let initialFileURL: URL
        if let savedPath = defaults.string(forKey: NoteStoreDefaultsKey.currentFilePath), !savedPath.isEmpty {
            if FileManager.default.fileExists(atPath: savedPath) {
                initialFileURL = URL(fileURLWithPath: savedPath)
            } else {
                initialFileURL = defaultFileURL
                defaults.set(defaultFileURL.path, forKey: NoteStoreDefaultsKey.currentFilePath)
            }
        } else if FileManager.default.fileExists(atPath: legacyDefaultFileURL.path) {
            initialFileURL = legacyDefaultFileURL
        } else {
            initialFileURL = defaultFileURL
        }
        let standardizedInitialFileURL = initialFileURL.standardizedFileURL
        currentFileURL = standardizedInitialFileURL
        defaults.set(standardizedInitialFileURL.path, forKey: NoteStoreDefaultsKey.currentFilePath)
        recentFileURLs = NoteWorkspaceSupport.loadRecentFileURLs(from: defaults)

        let initialFileExists = FileManager.default.fileExists(atPath: initialFileURL.path)
        let shouldDeferInitialRead = initialLoadMode == .deferred && initialFileExists
        if shouldDeferInitialRead {
            markdown = ""
            lastSavedText = "Loading..."
        } else if initialFileExists,
                  let text = NoteFileReader.read(initialFileURL) {
            markdown = text
        } else {
            markdown = NoteDocumentMetadata.exampleMarkdown
            _ = NoteFileWriter.write(NoteDocumentMetadata.exampleMarkdown, to: currentFileURL)
        }

        workspaces = NoteWorkspaceSupport.loadWorkspaces(from: defaults)
        if workspaces.isEmpty {
            workspaces = [NoteWorkspaceSupport.makeDefaultWorkspace(currentFileURL: currentFileURL, recentFileURLs: recentFileURLs)]
        } else {
            workspaces = NoteWorkspaceSupport.normalizedWorkspaces(workspaces)
        }
        activeWorkspaceID = NoteWorkspaceSupport.loadActiveWorkspaceID(from: defaults, workspaces: workspaces)

        rememberRecentFile(currentFileURL)
        rememberFileInActiveWorkspace(currentFileURL, moveToFront: false)
        refreshDisplayTitle()
        persistWorkspaces()

        if shouldDeferInitialRead {
            loadInitialFileOffMain(from: standardizedInitialFileURL, placeholderRevision: markdownRevision)
        }
    }

    deinit {
        saveTask?.cancel()
        openTask?.cancel()
        initialLoadTask?.cancel()
    }

    func saveNow() {
        cancelPendingSave()
        if hasActiveInitialLoadPlaceholder {
            return
        }
        if NoteFileWriter.write(markdown, to: currentFileURL) {
            invalidateWorkspacePreview(for: currentFileURL)
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
        let standardizedURL = url.standardizedFileURL
        let targetPath = standardizedURL.path
        guard FileManager.default.fileExists(atPath: targetPath) else {
            lastSavedText = "Open failed"
            return
        }

        cancelPendingSave()
        cancelPendingOpen()

        let previousURL = currentFileURL
        let previousText = markdown
        let previousPath = previousURL.standardizedFileURL.path
        let shouldSavePrevious = !hasActiveInitialLoadPlaceholder
        if targetPath == previousPath {
            if shouldSavePrevious {
                saveNow()
            }
            return
        }

        cancelInitialLoad()
        lastSavedText = "Opening..."
        openGeneration &+= 1
        let generation = openGeneration
        openTask = Task { [weak self] in
            let didSavePrevious: Bool
            let text: String?
            if shouldSavePrevious {
                async let savedPrevious = NoteFileWriter.writeOffMain(previousText, to: previousURL)
                async let loadedText = NoteFileReader.readOffMain(standardizedURL)
                (didSavePrevious, text) = await (savedPrevious, loadedText)
            } else {
                didSavePrevious = true
                text = await NoteFileReader.readOffMain(standardizedURL)
            }

            guard !Task.isCancelled,
                  let self,
                  self.openGeneration == generation
            else { return }

            if didSavePrevious {
                self.invalidateWorkspacePreview(for: previousURL)
            }

            guard let text else {
                self.lastSavedText = "Open failed"
                self.openTask = nil
                return
            }

            self.applyOpenedFile(
                text: text,
                url: standardizedURL,
                moveToFrontInWorkspace: moveToFrontInWorkspace
            )
            self.openTask = nil
        }
    }

    func saveAs(to url: URL) {
        cancelPendingSave()
        cancelPendingOpen()
        cancelInitialLoad()
        let standardizedURL = url.standardizedFileURL
        invalidateWorkspacePreview(for: standardizedURL)
        currentFileURL = standardizedURL
        defaults.set(standardizedURL.path, forKey: NoteStoreDefaultsKey.currentFilePath)
        rememberRecentFile(standardizedURL)
        rememberFileInActiveWorkspace(standardizedURL)
        refreshDisplayTitle()
        saveNow()
    }

    @discardableResult
    func createMarkdownFile(at url: URL, initialText: String = "") -> Bool {
        saveNow()
        cancelPendingSave()
        cancelPendingOpen()
        cancelInitialLoad()

        let standardizedURL = url.standardizedFileURL
        guard NoteFileWriter.write(initialText, to: standardizedURL) else {
            lastSavedText = "Create failed"
            return false
        }

        invalidateWorkspacePreview(for: standardizedURL)
        currentFileURL = standardizedURL
        defaults.set(standardizedURL.path, forKey: NoteStoreDefaultsKey.currentFilePath)
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
        workspacePreviewCache[path] = nil
        defaults.set(recentFileURLs.map(\.path), forKey: NoteStoreDefaultsKey.recentFilePaths)
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
        guard let nextURL = workspaceDocumentURL(offset: offset) else {
            let currentPath = currentFileURL.standardizedFileURL.path
            let urls = activeWorkspaceFileURLs
            if !urls.contains(where: { $0.standardizedFileURL.path == currentPath }) {
                rememberFileInActiveWorkspace(currentFileURL)
            }
            return false
        }

        openWorkspaceDocument(at: nextURL)
        return true
    }

    func workspaceDocumentURL(offset: Int) -> URL? {
        let urls = activeWorkspaceFileURLs
        guard urls.count > 1 else { return nil }

        let currentPath = currentFileURL.standardizedFileURL.path
        guard let currentIndex = urls.firstIndex(where: { $0.standardizedFileURL.path == currentPath }) else { return nil }

        let nextIndex = (currentIndex + offset + urls.count) % urls.count
        let nextURL = urls[nextIndex]
        guard nextURL.standardizedFileURL.path != currentPath else { return nil }

        return nextURL
    }

    func loadWorkspaceDocumentPreview(offset: Int) async -> (url: URL, text: String)? {
        guard let url = workspaceDocumentURL(offset: offset) else { return nil }

        let path = url.standardizedFileURL.path
        let modificationDate = fileModificationDate(for: url)
        if let cached = workspacePreviewCache[path],
           cached.modificationDate == modificationDate {
            return (url, cached.text)
        }

        guard let text = await NoteFileReader.readOffMain(url),
              workspaceDocumentURL(offset: offset)?.standardizedFileURL.path == path
        else { return nil }

        workspacePreviewCache[path] = DocumentPreviewCacheEntry(modificationDate: modificationDate, text: text)
        return (url, text)
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
        defaults.set(workspace.id.uuidString, forKey: NoteStoreDefaultsKey.activeWorkspaceID)
        persistWorkspaces()
    }

    func switchWorkspace(to workspaceID: NoteWorkspace.ID) {
        guard workspaceID != activeWorkspaceID,
              workspaces.contains(where: { $0.id == workspaceID })
        else { return }

        activeWorkspaceID = workspaceID
        defaults.set(workspaceID.uuidString, forKey: NoteStoreDefaultsKey.activeWorkspaceID)

        guard let workspace = activeWorkspace else {
            saveNow()
            persistWorkspaces()
            return
        }

        let targetURL = preferredURL(for: workspace)
        if let targetURL {
            openWorkspaceDocument(at: targetURL)
        } else {
            saveNow()
            rememberFileInActiveWorkspace(currentFileURL, moveToFront: false)
            persistWorkspaces()
        }
    }

    func removeFileFromActiveWorkspace(_ url: URL) {
        guard let workspaceIndex = activeWorkspaceIndex else { return }
        let path = url.standardizedFileURL.path
        workspaces[workspaceIndex].filePaths.removeAll { $0 == path }
        workspacePreviewCache[path] = nil

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
        cancelInitialLoad()
        lastSavedText = "Saving..."
        saveGeneration &+= 1
        let generation = saveGeneration
        saveTask?.cancel()
        let text = markdown
        let url = currentFileURL
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            let didSave = await NoteFileWriter.writeOffMain(text, to: url)
            guard !Task.isCancelled,
                  let self,
                  self.saveGeneration == generation
            else { return }
            if didSave {
                self.invalidateWorkspacePreview(for: url)
            }
            self.lastSavedText = didSave ? "Saved just now" : "Save failed"
            self.saveTask = nil
        }
    }

    private func cancelPendingSave() {
        saveGeneration &+= 1
        saveTask?.cancel()
        saveTask = nil
    }

    private func cancelPendingOpen() {
        openGeneration &+= 1
        openTask?.cancel()
        openTask = nil
    }

    private func loadInitialFileOffMain(from url: URL, placeholderRevision: Int) {
        initialLoadGeneration &+= 1
        let generation = initialLoadGeneration
        let path = url.standardizedFileURL.path
        initialLoadPlaceholderPath = path
        initialLoadPlaceholderRevision = placeholderRevision
        initialLoadTask?.cancel()
        initialLoadTask = Task { [weak self] in
            let text = await NoteFileReader.readOffMain(url)
            guard !Task.isCancelled,
                  let self,
                  self.initialLoadGeneration == generation,
                  self.currentFileURL.standardizedFileURL.path == url.standardizedFileURL.path,
                  self.markdownRevision == placeholderRevision
            else {
                self?.finishInitialLoad(generation: generation)
                return
            }

            guard let text else {
                self.lastSavedText = "Open failed"
                self.finishInitialLoad(generation: generation)
                return
            }

            self.isReplacingText = true
            self.markdown = text
            self.isReplacingText = false
            self.refreshDisplayTitle()
            self.lastSavedText = "Opened"
            self.finishInitialLoad(generation: generation)
        }
    }

    private var hasActiveInitialLoadPlaceholder: Bool {
        guard let path = initialLoadPlaceholderPath,
              let revision = initialLoadPlaceholderRevision
        else { return false }
        return currentFileURL.standardizedFileURL.path == path && markdownRevision == revision
    }

    private func cancelInitialLoad() {
        guard initialLoadTask != nil || initialLoadPlaceholderPath != nil else { return }
        initialLoadGeneration &+= 1
        initialLoadTask?.cancel()
        initialLoadTask = nil
        initialLoadPlaceholderPath = nil
        initialLoadPlaceholderRevision = nil
    }

    private func finishInitialLoad(generation: Int) {
        guard initialLoadGeneration == generation else { return }
        initialLoadTask = nil
        initialLoadPlaceholderPath = nil
        initialLoadPlaceholderRevision = nil
    }

    private func applyOpenedFile(text: String, url: URL, moveToFrontInWorkspace: Bool) {
        invalidateWorkspacePreview(for: url)
        currentFileURL = url
        defaults.set(url.path, forKey: NoteStoreDefaultsKey.currentFilePath)
        rememberRecentFile(url)
        rememberFileInActiveWorkspace(url, moveToFront: moveToFrontInWorkspace)
        isReplacingText = true
        markdown = text
        isReplacingText = false
        refreshDisplayTitle()
        lastSavedText = "Opened"
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
            workspaces = [NoteWorkspaceSupport.makeDefaultWorkspace(currentFileURL: url, recentFileURLs: recentFileURLs)]
            activeWorkspaceID = workspaces[0].id
            defaults.set(activeWorkspaceID.uuidString, forKey: NoteStoreDefaultsKey.activeWorkspaceID)
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
        workspaces[workspaceIndex].filePaths = Array(workspaces[workspaceIndex].filePaths.prefix(NoteWorkspaceSupport.maximumWorkspaceDocuments))
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

    private func fileModificationDate(for url: URL) -> Date? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.standardizedFileURL.path)
        return attributes?[.modificationDate] as? Date
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
        let title = NoteDocumentMetadata.displayTitle(for: markdown, currentFileURL: currentFileURL)
        if displayTitle != title {
            displayTitle = title
        }
    }

    private func rememberRecentFile(_ url: URL) {
        let standardizedURL = url.standardizedFileURL
        let path = standardizedURL.path
        recentFileURLs.removeAll { $0.standardizedFileURL.path == path }
        recentFileURLs.insert(standardizedURL, at: 0)
        recentFileURLs = Array(recentFileURLs.prefix(8))
        defaults.set(recentFileURLs.map(\.path), forKey: NoteStoreDefaultsKey.recentFilePaths)
    }

    private func nextWorkspaceName() -> String {
        let base = NoteWorkspaceSupport.defaultWorkspaceName
        let existingNames = Set(workspaces.map(\.name))
        var index = workspaces.count + 1
        while existingNames.contains("\(base) \(index)") {
            index += 1
        }
        return "\(base) \(index)"
    }

    private func persistWorkspaces() {
        workspaces = NoteWorkspaceSupport.normalizedWorkspaces(workspaces)
        pruneWorkspacePreviewCache()
        if !workspaces.contains(where: { $0.id == activeWorkspaceID }), let firstID = workspaces.first?.id {
            activeWorkspaceID = firstID
            defaults.set(firstID.uuidString, forKey: NoteStoreDefaultsKey.activeWorkspaceID)
        }
        if let data = try? JSONEncoder().encode(workspaces) {
            defaults.set(data, forKey: NoteStoreDefaultsKey.workspaces)
        }
    }

    private func invalidateWorkspacePreview(for url: URL) {
        workspacePreviewCache[url.standardizedFileURL.path] = nil
    }

    private func pruneWorkspacePreviewCache() {
        guard !workspacePreviewCache.isEmpty else { return }
        let workspacePaths = Set(workspaces.flatMap(\.filePaths))
        workspacePreviewCache = workspacePreviewCache.filter { workspacePaths.contains($0.key) }
    }

}
