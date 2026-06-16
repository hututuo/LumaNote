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
    func testSwitchesBetweenDocumentsInActiveWorkspace() throws {
        let first = try makeNote(named: "first.md", title: "First")
        let second = try makeNote(named: "second.md", title: "Second")
        let store = NoteStore(defaults: defaults, supportDirectory: temporaryDirectory)

        store.openFile(at: first)
        store.openFile(at: second)

        XCTAssertEqual(store.displayTitle, "Second")
        XCTAssertTrue(store.switchToNextDocument())
        XCTAssertEqual(store.currentFileURL.standardizedFileURL.path, first.standardizedFileURL.path)
        XCTAssertEqual(store.displayTitle, "First")
        XCTAssertTrue(store.switchToPreviousDocument())
        XCTAssertEqual(store.currentFileURL.standardizedFileURL.path, second.standardizedFileURL.path)
    }

    @MainActor
    func testSwitchingWorkspaceRestoresWorkspaceCurrentDocument() throws {
        let first = try makeNote(named: "first.md", title: "First")
        let second = try makeNote(named: "second.md", title: "Second")
        let store = NoteStore(defaults: defaults, supportDirectory: temporaryDirectory)

        store.openFile(at: first)
        let defaultWorkspaceID = store.activeWorkspaceID
        store.createWorkspace(named: "Client A")
        let clientWorkspaceID = store.activeWorkspaceID
        store.openFile(at: second)

        store.switchWorkspace(to: defaultWorkspaceID)
        XCTAssertEqual(store.currentFileURL.standardizedFileURL.path, first.standardizedFileURL.path)
        XCTAssertEqual(store.activeWorkspaceID, defaultWorkspaceID)

        store.switchWorkspace(to: clientWorkspaceID)
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

    private func makeNote(named name: String, title: String) throws -> URL {
        let url = temporaryDirectory.appending(path: name)
        try "# \(title)\n\nBody".write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
