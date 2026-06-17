import XCTest
@testable import QuietNote

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
