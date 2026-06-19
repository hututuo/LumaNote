import XCTest
@testable import QuietNote

final class NoteDocumentSwipeCoordinatorTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: "LumaNoteSwipeTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        suiteName = "LumaNoteSwipeTests.\(UUID().uuidString)"
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
    func testCancelClearsAnimatingStateWhenNoProgressRemains() {
        let coordinator = NoteDocumentSwipeCoordinator()
        coordinator.isAnimating = true
        coordinator.progress = 0
        coordinator.preview = NoteDocumentSwipePreview(
            id: "preview",
            url: URL(fileURLWithPath: "/tmp/preview.md"),
            offset: 1,
            text: "# Preview",
            position: nil,
            revision: 1
        )

        coordinator.cancel()

        XCTAssertFalse(coordinator.isAnimating)
        XCTAssertEqual(coordinator.progress, 0)
        XCTAssertNil(coordinator.preview)
    }

    @MainActor
    func testCancelTasksResetsSwipeTransientState() {
        let coordinator = NoteDocumentSwipeCoordinator()
        coordinator.isAnimating = true
        coordinator.progress = 0.75
        coordinator.preview = NoteDocumentSwipePreview(
            id: "preview",
            url: URL(fileURLWithPath: "/tmp/preview.md"),
            offset: -1,
            text: "# Preview",
            position: nil,
            revision: 1
        )

        coordinator.cancelTasks()

        XCTAssertFalse(coordinator.isAnimating)
        XCTAssertEqual(coordinator.progress, 0)
        XCTAssertNil(coordinator.preview)
    }

    @MainActor
    func testLoadedSwipePreviewUsesTargetDocumentPosition() async throws {
        let first = try makeNote(named: "first.md", title: "First")
        let second = try makeNote(named: "second.md", title: "Second")
        let store = NoteStore(defaults: defaults, supportDirectory: temporaryDirectory)
        let targetPosition = MarkdownDocumentPosition(selectedLocation: 9, selectedLength: 0, scrollY: 72)

        store.openFile(at: first)
        try await waitForCurrentFile(first, in: store)
        store.openFile(at: second)
        try await waitForCurrentFile(second, in: store)
        store.updateDocumentPosition(targetPosition, for: first)

        let coordinator = NoteDocumentSwipeCoordinator()
        coordinator.updateProgress(0.4, noteStore: store)

        for _ in 0..<80 where coordinator.preview == nil {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertEqual(coordinator.preview?.url.standardizedFileURL.path, first.standardizedFileURL.path)
        XCTAssertEqual(coordinator.preview?.position, targetPosition)
    }

    @MainActor
    func testCommitWaitsForLoadingPreviewBeforeSwitching() async throws {
        let first = try makeNote(named: "first.md", title: "First")
        let second = try makeNote(named: "second.md", title: "Second")
        let store = NoteStore(defaults: defaults, supportDirectory: temporaryDirectory)
        var didSwitch = false
        var previewContinuation: CheckedContinuation<(url: URL, text: String)?, Never>?
        let coordinator = NoteDocumentSwipeCoordinator(previewLoader: { _, _ in
            await withCheckedContinuation { continuation in
                previewContinuation = continuation
            }
        })

        store.openFile(at: first)
        try await waitForCurrentFile(first, in: store)
        store.openFile(at: second)
        try await waitForCurrentFile(second, in: store)

        coordinator.updateProgress(0.4, noteStore: store)
        for _ in 0..<80 where previewContinuation == nil {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertNotNil(previewContinuation)

        coordinator.commit(offset: 1, noteStore: store) {
            didSwitch = true
        }

        try await Task.sleep(nanoseconds: 220_000_000)
        XCTAssertFalse(didSwitch)
        XCTAssertEqual(store.currentFileURL.standardizedFileURL.path, second.standardizedFileURL.path)

        previewContinuation?.resume(returning: (url: first, text: "# First\n\nBody"))
        try await waitForCurrentFile(first, in: store)

        XCTAssertTrue(didSwitch)
        XCTAssertEqual(store.markdown, "# First\n\nBody")
        XCTAssertNil(coordinator.preview)
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
