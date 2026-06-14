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

    private func makeNote(named name: String, title: String) throws -> URL {
        let url = temporaryDirectory.appending(path: name)
        try "# \(title)\n\nBody".write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
