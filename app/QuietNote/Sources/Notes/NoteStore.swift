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
                cancelPendingOpen()
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
    private let fileOperations: NoteFileOperations
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
    @ObservationIgnored
    private var documentPositions: [String: MarkdownDocumentPosition] = [:]
    @ObservationIgnored
    private var filePersistenceStates: [String: FilePersistenceState] = [:]

    private enum FileLoadStatus {
        case deferred
        case loaded
        case failed
    }

    private struct FilePersistenceState {
        var identity: NoteFileModificationIdentity?
        var status: FileLoadStatus
        var baselineRevision: Int
    }

    private enum SaveOutcome: Equatable {
        case saved
        case failed
        case conflict
        case blocked
    }

    private enum FileReadOutcome {
        case success(text: String, identity: NoteFileModificationIdentity?)
        case failed(identity: NoteFileModificationIdentity?)
    }

    private struct DocumentPreviewCacheEntry {
        let identity: NoteFileModificationIdentity?
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

    var currentDocumentPosition: MarkdownDocumentPosition? {
        documentPosition(for: currentFileURL)
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

    func waitForInitialLoadForTesting() async {
        let task = initialLoadTask
        await task?.value
    }

    func hasCachedWorkspacePreviewForTesting(_ url: URL) -> Bool {
        workspacePreviewCache[url.standardizedFileURL.path] != nil
    }

    func documentPosition(for url: URL) -> MarkdownDocumentPosition? {
        documentPositions[url.standardizedFileURL.path]
    }

    func updateCurrentDocumentPosition(_ position: MarkdownDocumentPosition) {
        updateDocumentPosition(position, for: currentFileURL)
    }

    func updateDocumentPosition(_ position: MarkdownDocumentPosition, for url: URL) {
        let path = url.standardizedFileURL.path
        guard documentPositions[path] != position else { return }
        documentPositions[path] = position
        persistDocumentPositions()
    }

    init(
        defaults: UserDefaults = .standard,
        supportDirectory: URL? = nil,
        initialLoadMode: InitialLoadMode = .immediate,
        fileOperations: NoteFileOperations = .live
    ) {
        self.defaults = defaults
        self.fileOperations = fileOperations
        let support = supportDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "QuietNote", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        defaultFileURL = support.appending(path: "示例便签.md")
        if let data = defaults.data(forKey: NoteStoreDefaultsKey.documentPositions),
           let positions = try? JSONDecoder().decode([String: MarkdownDocumentPosition].self, from: data) {
            documentPositions = positions
        }
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
        // Initialize the observed document before using instance helpers below.
        // The initial contents are assigned in the load/create branches that
        // follow, but Swift requires the stored property to be initialized
        // before `self` can be passed to `readFileSynchronously`.
        markdown = ""
        defaults.set(standardizedInitialFileURL.path, forKey: NoteStoreDefaultsKey.currentFilePath)
        recentFileURLs = NoteWorkspaceSupport.loadRecentFileURLs(from: defaults)

        let initialFileExists = FileManager.default.fileExists(atPath: initialFileURL.path)
        let shouldDeferInitialRead = initialLoadMode == .deferred && initialFileExists
        if shouldDeferInitialRead {
            markdown = ""
            filePersistenceStates[standardizedInitialFileURL.path] = FilePersistenceState(
                identity: fileOperations.modificationIdentity(for: standardizedInitialFileURL),
                status: .deferred,
                baselineRevision: markdownRevision
            )
            lastSavedText = "Loading..."
        } else if initialFileExists {
            switch readFileSynchronously(from: standardizedInitialFileURL) {
            case let .success(text, identity):
                markdown = text
                filePersistenceStates[standardizedInitialFileURL.path] = FilePersistenceState(
                    identity: identity,
                    status: .loaded,
                    baselineRevision: markdownRevision
                )
            case let .failed(identity):
                // Keep an empty, recoverable in-memory document, but never
                // replace bytes that could not be decoded or read.
                markdown = ""
                filePersistenceStates[standardizedInitialFileURL.path] = FilePersistenceState(
                    identity: identity,
                    status: .failed,
                    baselineRevision: markdownRevision
                )
                lastSavedText = "Open failed"
            }
        } else {
            markdown = NoteDocumentMetadata.exampleMarkdown
            let expectedIdentity = fileOperations.modificationIdentity(for: standardizedInitialFileURL)
            let result = fileOperations.writeIfIdentityMatches(
                NoteDocumentMetadata.exampleMarkdown,
                to: standardizedInitialFileURL,
                expectedIdentity: expectedIdentity
            )
            let identity: NoteFileModificationIdentity?
            if case let .saved(savedIdentity) = result {
                identity = savedIdentity
            } else {
                identity = expectedIdentity
                lastSavedText = "Save failed"
            }
            filePersistenceStates[standardizedInitialFileURL.path] = FilePersistenceState(
                identity: identity,
                status: .loaded,
                baselineRevision: markdownRevision
            )
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

    @discardableResult
    func saveNow() -> Bool {
        cancelPendingSave()
        // A synchronous save is an explicit boundary: an older open task must
        // not resume later and replace the document after this snapshot has
        // been written.
        cancelPendingOpen()
        if hasActiveInitialLoadPlaceholder {
            return false
        }
        let outcome = saveCurrentSnapshot(
            text: markdown,
            url: currentFileURL,
            revision: markdownRevision
        )
        applySaveOutcome(outcome, for: currentFileURL)
        return outcome == .saved
    }

    func openFile(at url: URL) {
        openFile(at: url, moveToFrontInWorkspace: true)
    }

    func openWorkspaceDocument(at url: URL) {
        openFile(at: url, moveToFrontInWorkspace: false)
    }

    private func openFile(
        at url: URL,
        moveToFrontInWorkspace: Bool,
        preloadedText: String? = nil
    ) {
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
        let previousRevision = markdownRevision
        let previousPath = previousURL.standardizedFileURL.path
        let shouldSavePrevious = !hasActiveInitialLoadPlaceholder && !isCurrentFileLoadUnusableWithoutEdits
        if targetPath == previousPath {
            if shouldSavePrevious {
                saveNow()
            }
            return
        }

        let targetIdentity = fileOperations.modificationIdentity(for: standardizedURL)
        cancelInitialLoad(preservePlaceholder: !shouldSavePrevious)

        if let preloadedText {
            if shouldSavePrevious {
                let outcome = saveCurrentSnapshot(
                    text: previousText,
                    url: previousURL,
                    revision: previousRevision
                )
                guard outcome == .saved else {
                    applySaveOutcome(outcome, for: previousURL)
                    return
                }
            }

            guard fileOperations.modificationIdentity(for: standardizedURL) == targetIdentity else {
                lastSavedText = "Open failed"
                return
            }

            applyOpenedFile(
                text: preloadedText,
                url: standardizedURL,
                identity: targetIdentity,
                moveToFrontInWorkspace: moveToFrontInWorkspace
            )
            return
        }

        lastSavedText = "Opening..."
        openGeneration &+= 1
        let generation = openGeneration
        openTask = Task { [weak self] in
            guard let self else { return }

            if shouldSavePrevious {
                let outcome = await self.saveCurrentSnapshotOffMain(
                    text: previousText,
                    url: previousURL,
                    revision: previousRevision
                )
                guard !Task.isCancelled,
                      self.openGeneration == generation,
                      self.currentFileURL.standardizedFileURL.path == previousPath,
                      self.markdownRevision == previousRevision
                else { return }

                guard outcome == .saved else {
                    self.applySaveOutcome(outcome, for: previousURL)
                    self.openTask = nil
                    return
                }
            }

            let readOutcome = await self.readFileOffMain(from: standardizedURL)
            guard !Task.isCancelled,
                  self.openGeneration == generation,
                  self.currentFileURL.standardizedFileURL.path == previousPath,
                  self.markdownRevision == previousRevision
            else { return }

            guard case let .success(text, identity) = readOutcome else {
                self.lastSavedText = "Open failed"
                self.openTask = nil
                return
            }

            self.applyOpenedFile(
                text: text,
                url: standardizedURL,
                identity: identity,
                moveToFrontInWorkspace: moveToFrontInWorkspace
            )
            self.openTask = nil
        }
    }

    func saveAs(to url: URL) {
        cancelPendingSave()
        cancelPendingOpen()

        guard !hasActiveInitialLoadPlaceholder else {
            lastSavedText = "Save blocked"
            return
        }

        let standardizedURL = url.standardizedFileURL
        let targetPath = standardizedURL.path
        let currentPath = currentFileURL.standardizedFileURL.path
        let targetIdentity = filePersistenceStates[targetPath]?.identity
            ?? fileOperations.modificationIdentity(for: standardizedURL)

        let outcome: SaveOutcome
        if targetPath == currentPath {
            outcome = saveCurrentSnapshot(
                text: markdown,
                url: currentFileURL,
                revision: markdownRevision
            )
        } else {
            outcome = writeSnapshot(
                text: markdown,
                url: standardizedURL,
                revision: markdownRevision,
                expectedIdentity: targetIdentity
            )
        }

        guard outcome == .saved else {
            applySaveOutcome(outcome, for: currentFileURL)
            return
        }

        cancelInitialLoad()
        invalidateWorkspacePreview(for: standardizedURL)
        currentFileURL = standardizedURL
        defaults.set(standardizedURL.path, forKey: NoteStoreDefaultsKey.currentFilePath)
        rememberRecentFile(standardizedURL)
        rememberFileInActiveWorkspace(standardizedURL)
        refreshDisplayTitle()
        lastSavedText = "Saved just now"
    }

    @discardableResult
    func createMarkdownFile(at url: URL, initialText: String = "") -> Bool {
        // A deferred/failed initial read represents an existing file whose
        // bytes we have not safely loaded. Creating a new document is still a
        // valid explicit action, but must never save the empty/failed
        // placeholder back to that existing file first.
        if !isCurrentFileLoadUnusableWithoutEdits, !saveNow() {
            return false
        }
        cancelPendingSave()
        cancelPendingOpen()
        cancelInitialLoad()

        let standardizedURL = url.standardizedFileURL
        let expectedIdentity = fileOperations.modificationIdentity(for: standardizedURL)
        let result = writeSnapshot(
            text: initialText,
            url: standardizedURL,
            revision: markdownRevision,
            expectedIdentity: expectedIdentity
        )
        guard case .saved = result else {
            lastSavedText = result == .conflict ? "Create conflict" : "Create failed"
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
        documentPositions[path] = nil
        persistDocumentPositions()
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
    func switchWorkspaceDocument(
        offset: Int,
        preloadedPreview: (url: URL, text: String)? = nil
    ) -> Bool {
        guard let nextURL = workspaceDocumentURL(offset: offset) else {
            let currentPath = currentFileURL.standardizedFileURL.path
            let urls = activeWorkspaceFileURLs
            if !urls.contains(where: { $0.standardizedFileURL.path == currentPath }) {
                rememberFileInActiveWorkspace(currentFileURL)
            }
            return false
        }

        let matchingPreloadedText: String?
        if let preloadedPreview,
           preloadedPreview.url.standardizedFileURL.path == nextURL.standardizedFileURL.path {
            matchingPreloadedText = preloadedPreview.text
        } else {
            matchingPreloadedText = nil
        }

        openFile(
            at: nextURL,
            moveToFrontInWorkspace: false,
            preloadedText: matchingPreloadedText
        )
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
        let identity = fileOperations.modificationIdentity(for: url)
        if let cached = workspacePreviewCache[path],
           cached.identity == identity {
            return (url, cached.text)
        }

        guard case let .success(text, loadedIdentity) = await readFileOffMain(from: url),
              workspaceDocumentURL(offset: offset)?.standardizedFileURL.path == path
        else { return nil }

        workspacePreviewCache[path] = DocumentPreviewCacheEntry(identity: loadedIdentity, text: text)
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

    private func expectedIdentityForSave(of url: URL, revision: Int) -> NoteFileModificationIdentity? {
        let path = url.standardizedFileURL.path
        if let state = filePersistenceStates[path] {
            return state.identity
        }
        // A URL can enter a workspace before it has ever been loaded. Treat
        // the identity observed at save request time as the expected version
        // instead of silently replacing an unknown external file.
        return fileOperations.modificationIdentity(for: url)
    }

    private func saveCurrentSnapshot(text: String, url: URL, revision: Int) -> SaveOutcome {
        let path = url.standardizedFileURL.path
        if let state = filePersistenceStates[path],
           (state.status == .deferred || state.status == .failed),
           state.baselineRevision == revision {
            return .blocked
        }

        let expectedIdentity = expectedIdentityForSave(of: url, revision: revision)
        return writeSnapshot(
            text: text,
            url: url,
            revision: revision,
            expectedIdentity: expectedIdentity
        )
    }

    private func saveCurrentSnapshotOffMain(text: String, url: URL, revision: Int) async -> SaveOutcome {
        let path = url.standardizedFileURL.path
        if let state = filePersistenceStates[path],
           (state.status == .deferred || state.status == .failed),
           state.baselineRevision == revision {
            return .blocked
        }

        let expectedIdentity = expectedIdentityForSave(of: url, revision: revision)
        let writeToken = beginWrite(for: url)
        let result = await fileOperations.writeIfIdentityMatchesOffMain(
            text,
            to: url,
            expectedIdentity: expectedIdentity,
            token: writeToken
        )
        if case let .saved(identity) = result {
            recordSuccessfulWrite(for: url, identity: identity, revision: revision, token: writeToken)
        }
        return mapWriteResult(result)
    }

    private func writeSnapshot(
        text: String,
        url: URL,
        revision: Int,
        expectedIdentity: NoteFileModificationIdentity?
    ) -> SaveOutcome {
        let writeToken = beginWrite(for: url)
        let result = fileOperations.writeIfIdentityMatches(
            text,
            to: url,
            expectedIdentity: expectedIdentity,
            token: writeToken
        )
        if case let .saved(identity) = result {
            recordSuccessfulWrite(for: url, identity: identity, revision: revision, token: writeToken)
        }
        return mapWriteResult(result)
    }

    private func beginWrite(for url: URL) -> Int {
        fileOperations.beginWrite(for: url)
    }

    private func recordSuccessfulWrite(
        for url: URL,
        identity: NoteFileModificationIdentity?,
        revision: Int,
        token: Int
    ) {
        // A cancelled off-main write may finish after a newer write has
        // already replaced the file. Do not let that stale completion roll
        // the in-memory baseline back to the older identity.
        guard fileOperations.isLatestWrite(token, for: url),
              fileOperations.modificationIdentity(for: url) == identity
        else { return }
        let path = url.standardizedFileURL.path
        filePersistenceStates[path] = FilePersistenceState(
            identity: identity,
            status: .loaded,
            baselineRevision: revision
        )
    }

    private func mapWriteResult(_ result: NoteFileWriteResult) -> SaveOutcome {
        switch result {
        case .saved:
            return .saved
        case .failed:
            return .failed
        case .conflict:
            return .conflict
        }
    }

    private func statusText(for result: NoteFileWriteResult) -> String {
        switch result {
        case .saved:
            return "Saved just now"
        case .failed:
            return "Save failed"
        case .conflict:
            return "Save conflict"
        }
    }

    private func applySaveOutcome(_ outcome: SaveOutcome, for url: URL) {
        switch outcome {
        case .saved:
            invalidateWorkspacePreview(for: url)
            lastSavedText = "Saved just now"
        case .failed:
            lastSavedText = "Save failed"
        case .conflict:
            lastSavedText = "Save conflict"
        case .blocked:
            lastSavedText = "Save blocked"
        }
    }

    private func readFileSynchronously(from url: URL) -> FileReadOutcome {
        let before = fileOperations.modificationIdentity(for: url)
        guard let text = fileOperations.read(url) else {
            return .failed(identity: before)
        }
        let after = fileOperations.modificationIdentity(for: url)
        guard before == after else {
            return .failed(identity: after)
        }
        return .success(text: text, identity: after)
    }

    private func readFileOffMain(from url: URL) async -> FileReadOutcome {
        let before = fileOperations.modificationIdentity(for: url)
        guard let text = await fileOperations.readOffMain(url) else {
            return .failed(identity: before)
        }
        let after = fileOperations.modificationIdentity(for: url)
        guard before == after else {
            return .failed(identity: after)
        }
        return .success(text: text, identity: after)
    }

    private func scheduleSave() {
        cancelInitialLoad()
        lastSavedText = "Saving..."
        saveGeneration &+= 1
        let generation = saveGeneration
        saveTask?.cancel()
        let text = markdown
        let url = currentFileURL
        let revision = markdownRevision
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            guard let self,
                  self.saveGeneration == generation,
                  self.currentFileURL.standardizedFileURL.path == url.standardizedFileURL.path,
                  self.markdownRevision == revision
            else { return }

            let path = url.standardizedFileURL.path
            if let state = self.filePersistenceStates[path],
               (state.status == .deferred || state.status == .failed),
               state.baselineRevision == revision {
                self.lastSavedText = "Save blocked"
                self.saveTask = nil
                return
            }

            let expectedIdentity = self.expectedIdentityForSave(of: url, revision: revision)
            let writeToken = self.beginWrite(for: url)
            let result = await self.fileOperations.writeIfIdentityMatchesOffMain(
                text,
                to: url,
                expectedIdentity: expectedIdentity,
                token: writeToken
            )
            if case let .saved(identity) = result {
                self.recordSuccessfulWrite(for: url, identity: identity, revision: revision, token: writeToken)
            }
            guard !Task.isCancelled,
                  self.saveGeneration == generation,
                  self.currentFileURL.standardizedFileURL.path == url.standardizedFileURL.path,
                  self.markdownRevision == revision
            else { return }

            if case .saved = result {
                self.invalidateWorkspacePreview(for: url)
            }
            self.lastSavedText = self.statusText(for: result)
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
            let outcome = await self?.readFileOffMain(from: url)
            guard !Task.isCancelled,
                  let self,
                  self.initialLoadGeneration == generation,
                  self.currentFileURL.standardizedFileURL.path == url.standardizedFileURL.path,
                  self.markdownRevision == placeholderRevision
            else {
                self?.finishInitialLoad(generation: generation)
                return
            }

            guard let outcome else {
                self.lastSavedText = "Open failed"
                self.filePersistenceStates[path] = FilePersistenceState(
                    identity: self.fileOperations.modificationIdentity(for: url),
                    status: .failed,
                    baselineRevision: self.markdownRevision
                )
                self.finishInitialLoad(generation: generation)
                return
            }

            guard case let .success(text, identity) = outcome else {
                self.lastSavedText = "Open failed"
                let failedIdentity: NoteFileModificationIdentity?
                if case let .failed(identity) = outcome {
                    failedIdentity = identity
                } else {
                    failedIdentity = self.fileOperations.modificationIdentity(for: url)
                }
                self.filePersistenceStates[path] = FilePersistenceState(
                    identity: failedIdentity,
                    status: .failed,
                    baselineRevision: self.markdownRevision
                )
                self.finishInitialLoad(generation: generation)
                return
            }

            self.isReplacingText = true
            self.markdown = text
            self.isReplacingText = false
            self.filePersistenceStates[path] = FilePersistenceState(
                identity: identity,
                status: .loaded,
                baselineRevision: self.markdownRevision
            )
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

    private var isCurrentFileLoadUnusableWithoutEdits: Bool {
        let path = currentFileURL.standardizedFileURL.path
        guard let state = filePersistenceStates[path],
              state.baselineRevision == markdownRevision
        else { return false }
        return state.status == .deferred || state.status == .failed
    }

    private func cancelInitialLoad(preservePlaceholder: Bool = false) {
        guard initialLoadTask != nil || initialLoadPlaceholderPath != nil else { return }
        initialLoadGeneration &+= 1
        initialLoadTask?.cancel()
        initialLoadTask = nil
        if !preservePlaceholder {
            initialLoadPlaceholderPath = nil
            initialLoadPlaceholderRevision = nil
        }
    }

    private func finishInitialLoad(generation: Int) {
        guard initialLoadGeneration == generation else { return }
        initialLoadTask = nil
        initialLoadPlaceholderPath = nil
        initialLoadPlaceholderRevision = nil
    }

    private func applyOpenedFile(
        text: String,
        url: URL,
        identity: NoteFileModificationIdentity?,
        moveToFrontInWorkspace: Bool
    ) {
        cancelInitialLoad()
        invalidateWorkspacePreview(for: url)
        currentFileURL = url
        defaults.set(url.path, forKey: NoteStoreDefaultsKey.currentFilePath)
        rememberRecentFile(url)
        rememberFileInActiveWorkspace(url, moveToFront: moveToFrontInWorkspace)
        isReplacingText = true
        markdown = text
        isReplacingText = false
        filePersistenceStates[url.standardizedFileURL.path] = FilePersistenceState(
            identity: identity,
            status: .loaded,
            baselineRevision: markdownRevision
        )
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

    private func persistDocumentPositions() {
        if let data = try? JSONEncoder().encode(documentPositions) {
            defaults.set(data, forKey: NoteStoreDefaultsKey.documentPositions)
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
