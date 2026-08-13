import XCTest
@testable import QuietNote

private final class NoteStoreTestFileController: @unchecked Sendable {
    private let lock = NSLock()
    private var failedPaths: Set<String> = []
    private(set) var writes: [(path: String, text: String)] = []

    func failWrites(to url: URL) {
        lock.lock()
        failedPaths.insert(url.standardizedFileURL.path)
        lock.unlock()
    }

    func operations() -> NoteFileOperations {
        NoteFileOperations(
            reader: { NoteFileReader.read($0) },
            writer: { [weak self] text, url in
                guard let self else { return false }
                return self.write(text, to: url, expectedIdentity: NoteFileReader.modificationIdentity(url))
            },
            identityReader: { NoteFileReader.modificationIdentity($0) },
            conditionalWriter: { [weak self] text, url, expectedIdentity in
                guard let self else { return .failed }
                return self.writeResult(text, to: url, expectedIdentity: expectedIdentity)
            }
        )
    }

    private func write(
        _ text: String,
        to url: URL,
        expectedIdentity: NoteFileModificationIdentity?
    ) -> Bool {
        if case .saved = writeResult(text, to: url, expectedIdentity: expectedIdentity) {
            return true
        }
        return false
    }

    private func writeResult(
        _ text: String,
        to url: URL,
        expectedIdentity: NoteFileModificationIdentity?
    ) -> NoteFileWriteResult {
        lock.lock()
        defer { lock.unlock() }

        let path = url.standardizedFileURL.path
        guard !failedPaths.contains(path) else { return .failed }
        guard NoteFileReader.modificationIdentity(url) == expectedIdentity else { return .conflict }
        guard NoteFileWriter.write(text, to: url) else { return .failed }
        writes.append((path: path, text: text))
        return .saved(NoteFileReader.modificationIdentity(url))
    }
}

final class NoteStoreWorkspaceTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: "LumaNoteTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        suiteName = "LumaNoteTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        if let suiteName {
            defaults?.removePersistentDomain(forName: suiteName)
        }
        temporaryDirectory = nil
        defaults = nil
        suiteName = nil
        try super.tearDownWithError()
    }

    @MainActor
    func testFirstLaunchCreatesExampleMarkdownFile() throws {
        let store = NoteStore(defaults: defaults, supportDirectory: temporaryDirectory)
        let expectedURL = temporaryDirectory.appending(path: "示例便签.md")

        XCTAssertEqual(store.currentFileURL.standardizedFileURL.path, expectedURL.standardizedFileURL.path)
        XCTAssertEqual(store.currentFileName, "示例便签.md")
        XCTAssertEqual(store.displayTitle, "LumaNote 示例便签")
        XCTAssertTrue(store.markdown.contains("# LumaNote 示例便签"))
        XCTAssertTrue(store.markdown.contains("- [ ] 试着输入一条新待办"))
        XCTAssertTrue(store.markdown.contains("- [x] Markdown 会实时渲染"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedURL.path))
        XCTAssertEqual(try String(contentsOf: expectedURL, encoding: .utf8), store.markdown)
        XCTAssertTrue(store.activeWorkspaceFileURLs.contains { $0.standardizedFileURL.path == expectedURL.standardizedFileURL.path })
    }

    @MainActor
    func testFirstLaunchKeepsLegacyDefaultNoteIfItExists() throws {
        let legacyURL = try makeNote(named: "note.md", title: "Old Note")
        let store = NoteStore(defaults: defaults, supportDirectory: temporaryDirectory)

        XCTAssertEqual(store.currentFileURL.standardizedFileURL.path, legacyURL.standardizedFileURL.path)
        XCTAssertEqual(store.displayTitle, "Old Note")
        XCTAssertEqual(store.markdown, "# Old Note\n\nBody")
        XCTAssertFalse(FileManager.default.fileExists(atPath: temporaryDirectory.appending(path: "示例便签.md").path))
    }

    @MainActor
    func testDeferredInitialLoadReadsExistingNoteAfterInit() async throws {
        let legacyURL = try makeNote(named: "note.md", title: "Old Note")
        let store = NoteStore(
            defaults: defaults,
            supportDirectory: temporaryDirectory,
            initialLoadMode: .deferred
        )

        XCTAssertEqual(store.currentFileURL.standardizedFileURL.path, legacyURL.standardizedFileURL.path)
        XCTAssertEqual(store.markdown, "")
        XCTAssertEqual(store.displayTitle, "note.md")

        let expectedMarkdown = "# Old Note\n\nBody"
        for _ in 0..<40 where store.markdown != expectedMarkdown {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertEqual(store.markdown, expectedMarkdown)
        XCTAssertEqual(store.displayTitle, "Old Note")
    }

    @MainActor
    func testSaveDuringDeferredInitialLoadDoesNotOverwriteExistingNote() throws {
        let legacyURL = try makeNote(named: "note.md", title: "Old Note")
        let store = NoteStore(
            defaults: defaults,
            supportDirectory: temporaryDirectory,
            initialLoadMode: .deferred
        )

        XCTAssertTrue(store.hasActiveInitialLoadPlaceholderForTesting)
        store.saveNow()

        XCTAssertEqual(try String(contentsOf: legacyURL, encoding: .utf8), "# Old Note\n\nBody")
    }

    @MainActor
    func testEditDuringDeferredInitialLoadSavesOnlyExplicitUserText() async throws {
        let legacyURL = try makeNote(named: "note.md", title: "Old Note")
        let store = NoteStore(
            defaults: defaults,
            supportDirectory: temporaryDirectory,
            initialLoadMode: .deferred
        )

        store.markdown = "# User edit\n\nBody"
        XCTAssertTrue(store.saveNow())
        await store.waitForInitialLoadForTesting()

        XCTAssertEqual(try String(contentsOf: legacyURL, encoding: .utf8), "# User edit\n\nBody")
        XCTAssertEqual(store.markdown, "# User edit\n\nBody")
    }

    @MainActor
    func testInvalidUTF8IsPreservedWhenSaveNowRuns() throws {
        let invalidURL = temporaryDirectory.appending(path: "invalid.md")
        let invalidData = Data([0x23, 0x20, 0xFF, 0xFE, 0x0A])
        try invalidData.write(to: invalidURL)
        defaults.set(invalidURL.path, forKey: NoteStoreDefaultsKey.currentFilePath)

        let store = NoteStore(defaults: defaults, supportDirectory: temporaryDirectory)

        XCTAssertEqual(store.markdown, "")
        XCTAssertFalse(store.saveNow())
        XCTAssertEqual(try Data(contentsOf: invalidURL), invalidData)
        XCTAssertEqual(store.lastSavedText, "Save blocked")
    }

    @MainActor
    func testOpenAfterInvalidInitialReadDoesNotOverwriteOrBlockOtherFile() async throws {
        let invalidURL = temporaryDirectory.appending(path: "invalid.md")
        let invalidData = Data([0x23, 0x20, 0xFF, 0xFE, 0x0A])
        try invalidData.write(to: invalidURL)
        let secondURL = try makeNote(named: "second.md", title: "Second")
        defaults.set(invalidURL.path, forKey: NoteStoreDefaultsKey.currentFilePath)

        let store = NoteStore(defaults: defaults, supportDirectory: temporaryDirectory)
        store.openFile(at: secondURL)
        await store.waitForPendingOpenForTesting()

        XCTAssertEqual(store.currentFileURL.standardizedFileURL.path, secondURL.standardizedFileURL.path)
        XCTAssertEqual(store.markdown, "# Second\n\nBody")
        XCTAssertEqual(try Data(contentsOf: invalidURL), invalidData)
    }

    @MainActor
    func testCreateDuringDeferredInitialLoadDoesNotOverwriteExistingNote() async throws {
        let legacyURL = try makeNote(named: "note.md", title: "Old Note")
        let createdURL = temporaryDirectory.appending(path: "created.md")
        let store = NoteStore(
            defaults: defaults,
            supportDirectory: temporaryDirectory,
            initialLoadMode: .deferred
        )

        XCTAssertTrue(store.createMarkdownFile(at: createdURL, initialText: "# New note\n"))
        await store.waitForInitialLoadForTesting()

        XCTAssertEqual(store.currentFileURL.standardizedFileURL.path, createdURL.standardizedFileURL.path)
        XCTAssertEqual(try String(contentsOf: createdURL, encoding: .utf8), "# New note\n")
        XCTAssertEqual(try String(contentsOf: legacyURL, encoding: .utf8), "# Old Note\n\nBody")
    }

    @MainActor
    func testDebouncedWritesKeepLatestSnapshot() async throws {
        let controller = NoteStoreTestFileController()
        let store = NoteStore(
            defaults: defaults,
            supportDirectory: temporaryDirectory,
            fileOperations: controller.operations()
        )

        store.markdown = "# First\n\nBody"
        store.markdown = "# Latest\n\nBody"
        await store.waitForPendingSaveForTesting()

        XCTAssertEqual(try String(contentsOf: store.currentFileURL, encoding: .utf8), "# Latest\n\nBody")
        XCTAssertEqual(controller.writes.last?.text, "# Latest\n\nBody")
    }

    @MainActor
    func testOpeningAnotherFileDuringDeferredInitialLoadDoesNotOverwriteExistingNote() async throws {
        let legacyURL = try makeNote(named: "note.md", title: "Old Note")
        let secondURL = try makeNote(named: "second.md", title: "Second")
        let store = NoteStore(
            defaults: defaults,
            supportDirectory: temporaryDirectory,
            initialLoadMode: .deferred
        )

        XCTAssertTrue(store.hasActiveInitialLoadPlaceholderForTesting)
        store.openFile(at: secondURL)
        try await waitForCurrentFile(secondURL, in: store)

        XCTAssertEqual(try String(contentsOf: legacyURL, encoding: .utf8), "# Old Note\n\nBody")
        XCTAssertEqual(store.markdown, "# Second\n\nBody")
    }

    @MainActor
    func testScheduledSaveTaskClearsAfterCompletion() async throws {
        let store = NoteStore(defaults: defaults, supportDirectory: temporaryDirectory)

        store.markdown = "# Saved Later\n\nBody"
        XCTAssertTrue(store.hasPendingSaveForTesting)
        await store.waitForPendingSaveForTesting()

        XCTAssertFalse(store.hasPendingSaveForTesting)
        XCTAssertEqual(try String(contentsOf: store.currentFileURL, encoding: .utf8), "# Saved Later\n\nBody")
    }

    @MainActor
    func testOpenTaskClearsAfterCompletion() async throws {
        let secondURL = try makeNote(named: "second.md", title: "Second")
        let store = NoteStore(defaults: defaults, supportDirectory: temporaryDirectory)

        store.openFile(at: secondURL)
        await store.waitForPendingOpenForTesting()

        XCTAssertFalse(store.hasPendingOpenForTesting)
        XCTAssertEqual(store.currentFileURL.standardizedFileURL.path, secondURL.standardizedFileURL.path)
        XCTAssertEqual(store.markdown, "# Second\n\nBody")
    }

    @MainActor
    func testOpenSaveFailureKeepsCurrentDocumentAndMemoryEdits() async throws {
        let firstURL = try makeNote(named: "first.md", title: "First")
        let secondURL = try makeNote(named: "second.md", title: "Second")
        let controller = NoteStoreTestFileController()
        let store = NoteStore(
            defaults: defaults,
            supportDirectory: temporaryDirectory,
            fileOperations: controller.operations()
        )

        store.openFile(at: firstURL)
        await store.waitForPendingOpenForTesting()
        store.markdown = "# Unsaved first\n\nKeep me"
        controller.failWrites(to: firstURL)

        store.openFile(at: secondURL)
        await store.waitForPendingOpenForTesting()

        XCTAssertEqual(store.currentFileURL.standardizedFileURL.path, firstURL.standardizedFileURL.path)
        XCTAssertEqual(store.markdown, "# Unsaved first\n\nKeep me")
        XCTAssertEqual(try String(contentsOf: secondURL, encoding: .utf8), "# Second\n\nBody")
    }

    @MainActor
    func testPreloadedSwitchSaveFailureDoesNotDiscardCurrentDocument() async throws {
        let firstURL = try makeNote(named: "first.md", title: "First")
        let secondURL = try makeNote(named: "second.md", title: "Second")
        let controller = NoteStoreTestFileController()
        let store = NoteStore(
            defaults: defaults,
            supportDirectory: temporaryDirectory,
            fileOperations: controller.operations()
        )

        store.openFile(at: firstURL)
        await store.waitForPendingOpenForTesting()
        store.openFile(at: secondURL)
        await store.waitForPendingOpenForTesting()
        store.markdown = "# Unsaved second\n\nKeep me"
        controller.failWrites(to: secondURL)

        XCTAssertTrue(store.switchWorkspaceDocument(
            offset: 1,
            preloadedPreview: (url: firstURL, text: "# First\n\nBody")
        ))

        XCTAssertEqual(store.currentFileURL.standardizedFileURL.path, secondURL.standardizedFileURL.path)
        XCTAssertEqual(store.markdown, "# Unsaved second\n\nKeep me")
    }

    @MainActor
    func testSaveAsFailureKeepsOriginalURLAndContent() async throws {
        let firstURL = try makeNote(named: "first.md", title: "First")
        let targetURL = temporaryDirectory.appending(path: "target.md")
        let controller = NoteStoreTestFileController()
        let store = NoteStore(
            defaults: defaults,
            supportDirectory: temporaryDirectory,
            fileOperations: controller.operations()
        )

        store.openFile(at: firstURL)
        await store.waitForPendingOpenForTesting()
        controller.failWrites(to: targetURL)
        store.markdown = "# Keep original\n\nBody"
        store.saveAs(to: targetURL)

        XCTAssertEqual(store.currentFileURL.standardizedFileURL.path, firstURL.standardizedFileURL.path)
        XCTAssertEqual(store.markdown, "# Keep original\n\nBody")
        XCTAssertFalse(FileManager.default.fileExists(atPath: targetURL.path))
    }

    @MainActor
    func testSaveAsSwitchesOnlyAfterTargetWriteSucceeds() async throws {
        let firstURL = try makeNote(named: "first.md", title: "First")
        let targetURL = temporaryDirectory.appending(path: "target.md")
        let store = NoteStore(defaults: defaults, supportDirectory: temporaryDirectory)

        store.openFile(at: firstURL)
        await store.waitForPendingOpenForTesting()
        store.markdown = "# Saved copy\n\nBody"
        store.saveAs(to: targetURL)

        XCTAssertEqual(store.currentFileURL.standardizedFileURL.path, targetURL.standardizedFileURL.path)
        XCTAssertEqual(try String(contentsOf: targetURL, encoding: .utf8), "# Saved copy\n\nBody")
    }

    @MainActor
    func testExternalModificationIsDetectedBeforeSaveAndSamePathOpen() async throws {
        let firstURL = try makeNote(named: "first.md", title: "First")
        let store = NoteStore(defaults: defaults, supportDirectory: temporaryDirectory)
        store.openFile(at: firstURL)
        await store.waitForPendingOpenForTesting()

        try "# External version\n\nDo not overwrite".write(to: firstURL, atomically: true, encoding: .utf8)
        store.markdown = "# Local version\n\nKeep in memory"
        XCTAssertFalse(store.saveNow())
        XCTAssertEqual(try String(contentsOf: firstURL, encoding: .utf8), "# External version\n\nDo not overwrite")

        store.openFile(at: firstURL)
        XCTAssertEqual(store.markdown, "# Local version\n\nKeep in memory")
        XCTAssertEqual(try String(contentsOf: firstURL, encoding: .utf8), "# External version\n\nDo not overwrite")
    }

    @MainActor
    func testSwitchesBetweenDocumentsInActiveWorkspace() async throws {
        let first = try makeNote(named: "first.md", title: "First")
        let second = try makeNote(named: "second.md", title: "Second")
        let store = NoteStore(defaults: defaults, supportDirectory: temporaryDirectory)

        store.openFile(at: first)
        try await waitForCurrentFile(first, in: store)
        store.openFile(at: second)
        try await waitForCurrentFile(second, in: store)

        XCTAssertEqual(store.displayTitle, "Second")
        XCTAssertTrue(store.switchToNextDocument())
        try await waitForCurrentFile(first, in: store)
        XCTAssertEqual(store.currentFileURL.standardizedFileURL.path, first.standardizedFileURL.path)
        XCTAssertEqual(store.displayTitle, "First")
        XCTAssertTrue(store.switchToPreviousDocument())
        try await waitForCurrentFile(second, in: store)
        XCTAssertEqual(store.currentFileURL.standardizedFileURL.path, second.standardizedFileURL.path)
    }

    @MainActor
    func testSwitchingWithPreloadedPreviewDisplaysNewDocumentImmediately() async throws {
        let first = try makeNote(named: "first.md", title: "First")
        let second = try makeNote(named: "second.md", title: "Second")
        let store = NoteStore(defaults: defaults, supportDirectory: temporaryDirectory)

        store.openFile(at: first)
        try await waitForCurrentFile(first, in: store)
        store.openFile(at: second)
        try await waitForCurrentFile(second, in: store)

        XCTAssertTrue(store.switchWorkspaceDocument(
            offset: 1,
            preloadedPreview: (url: first, text: "# First\n\nBody")
        ))

        XCTAssertEqual(store.currentFileURL.standardizedFileURL.path, first.standardizedFileURL.path)
        XCTAssertEqual(store.markdown, "# First\n\nBody")
        XCTAssertEqual(store.displayTitle, "First")

        await store.waitForPendingOpenForTesting()
        XCTAssertFalse(store.hasPendingOpenForTesting)
    }

    @MainActor
    func testDocumentPositionIsStoredPerFileAndReloaded() throws {
        let first = try makeNote(named: "first.md", title: "First")
        let second = try makeNote(named: "second.md", title: "Second")
        let store = NoteStore(defaults: defaults, supportDirectory: temporaryDirectory)
        let firstPosition = MarkdownDocumentPosition(selectedLocation: 12, selectedLength: 0, scrollY: 80)
        let secondPosition = MarkdownDocumentPosition(selectedLocation: 4, selectedLength: 0, scrollY: 20)

        store.updateDocumentPosition(firstPosition, for: first)
        store.updateDocumentPosition(secondPosition, for: second)

        XCTAssertEqual(store.documentPosition(for: first), firstPosition)
        XCTAssertEqual(store.documentPosition(for: second), secondPosition)

        let reloadedStore = NoteStore(defaults: defaults, supportDirectory: temporaryDirectory)
        XCTAssertEqual(reloadedStore.documentPosition(for: first), firstPosition)
        XCTAssertEqual(reloadedStore.documentPosition(for: second), secondPosition)
    }

    @MainActor
    func testSwitchingWorkspaceRestoresWorkspaceCurrentDocument() async throws {
        let first = try makeNote(named: "first.md", title: "First")
        let second = try makeNote(named: "second.md", title: "Second")
        let store = NoteStore(defaults: defaults, supportDirectory: temporaryDirectory)

        store.openFile(at: first)
        try await waitForCurrentFile(first, in: store)
        let defaultWorkspaceID = store.activeWorkspaceID
        store.createWorkspace(named: "Client A")
        let clientWorkspaceID = store.activeWorkspaceID
        store.openFile(at: second)
        try await waitForCurrentFile(second, in: store)

        store.switchWorkspace(to: defaultWorkspaceID)
        try await waitForCurrentFile(first, in: store)
        XCTAssertEqual(store.currentFileURL.standardizedFileURL.path, first.standardizedFileURL.path)
        XCTAssertEqual(store.activeWorkspaceID, defaultWorkspaceID)

        store.switchWorkspace(to: clientWorkspaceID)
        try await waitForCurrentFile(second, in: store)
        XCTAssertEqual(store.currentFileURL.standardizedFileURL.path, second.standardizedFileURL.path)
        XCTAssertEqual(store.activeWorkspaceID, clientWorkspaceID)
    }

    @MainActor
    func testCreatesBlankMarkdownFileInActiveWorkspace() throws {
        let url = temporaryDirectory.appending(path: "new-note.md")
        let store = NoteStore(defaults: defaults, supportDirectory: temporaryDirectory)

        XCTAssertTrue(store.createMarkdownFile(at: url))
        XCTAssertEqual(store.currentFileURL.standardizedFileURL.path, url.standardizedFileURL.path)
        XCTAssertEqual(store.markdown, "")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "")
        XCTAssertTrue(store.activeWorkspaceFileURLs.contains { $0.standardizedFileURL.path == url.standardizedFileURL.path })

        let reloadedStore = NoteStore(defaults: defaults, supportDirectory: temporaryDirectory)
        XCTAssertEqual(reloadedStore.currentFileURL.standardizedFileURL.path, url.standardizedFileURL.path)
        XCTAssertEqual(reloadedStore.markdown, "")
    }

    @MainActor
    func testRemovingWorkspaceFileClearsPreviewCache() async throws {
        let first = try makeNote(named: "first.md", title: "First")
        let second = try makeNote(named: "second.md", title: "Second")
        let store = NoteStore(defaults: defaults, supportDirectory: temporaryDirectory)

        store.openFile(at: first)
        try await waitForCurrentFile(first, in: store)
        store.openFile(at: second)
        try await waitForCurrentFile(second, in: store)

        let preview = await store.loadWorkspaceDocumentPreview(offset: 1)
        XCTAssertEqual(preview?.url.standardizedFileURL.path, first.standardizedFileURL.path)
        XCTAssertTrue(store.hasCachedWorkspacePreviewForTesting(first))
        XCTAssertEqual(store.cachedWorkspacePreviewCountForTesting, 1)

        store.removeFileFromActiveWorkspace(first)

        XCTAssertFalse(store.hasCachedWorkspacePreviewForTesting(first))
        XCTAssertEqual(store.cachedWorkspacePreviewCountForTesting, 0)
    }

    private func makeNote(named name: String, title: String) throws -> URL {
        let url = temporaryDirectory.appending(path: name)
        try "# \(title)\n\nBody".write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @MainActor
    private func waitForCurrentFile(_ url: URL, in store: NoteStore) async throws {
        let path = url.standardizedFileURL.path
        for _ in 0..<80 where store.currentFileURL.standardizedFileURL.path != path {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(store.currentFileURL.standardizedFileURL.path, path)
    }
}
