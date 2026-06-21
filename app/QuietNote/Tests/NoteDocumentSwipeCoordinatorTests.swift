import AppKit
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
        XCTAssertEqual(coordinator.progress, 0, "The current page should not slide away before the target preview exists.")

        coordinator.commit(offset: 1, noteStore: store) {
            didSwitch = true
        }

        try await Task.sleep(nanoseconds: 220_000_000)
        XCTAssertFalse(didSwitch)
        XCTAssertEqual(coordinator.progress, 0, "Commit animation should wait for the target preview instead of animating into blank space.")
        XCTAssertEqual(store.currentFileURL.standardizedFileURL.path, second.standardizedFileURL.path)

        previewContinuation?.resume(returning: (url: first, text: "# First\n\nBody"))
        try await waitForCurrentFile(first, in: store)

        XCTAssertTrue(didSwitch)
        XCTAssertEqual(store.markdown, "# First\n\nBody")
        XCTAssertNil(coordinator.preview)
    }

    @MainActor
    func testProgressWaitsForPreviewBeforeMovingPages() async throws {
        let first = try makeNote(named: "first.md", title: "First")
        let second = try makeNote(named: "second.md", title: "Second")
        let store = NoteStore(defaults: defaults, supportDirectory: temporaryDirectory)
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

        coordinator.updateProgress(0.35, noteStore: store)
        for _ in 0..<80 where previewContinuation == nil {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertNil(coordinator.preview)
        XCTAssertEqual(coordinator.progress, 0, "Loading previews should not expose the empty background during a swipe.")

        previewContinuation?.resume(returning: (url: first, text: "# First\n\nBody"))
        for _ in 0..<80 where coordinator.preview == nil {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        coordinator.updateProgress(0.35, noteStore: store)

        XCTAssertEqual(coordinator.preview?.url.standardizedFileURL.path, first.standardizedFileURL.path)
        XCTAssertEqual(coordinator.progress, 0.35, accuracy: 0.001)
    }

    @MainActor
    func testLoadingPreviewAppliesLatestProgressWhenReady() async throws {
        let first = try makeNote(named: "first.md", title: "First")
        let second = try makeNote(named: "second.md", title: "Second")
        let store = NoteStore(defaults: defaults, supportDirectory: temporaryDirectory)
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

        coordinator.updateProgress(0.18, noteStore: store)
        coordinator.updateProgress(0.35, noteStore: store)
        for _ in 0..<80 where previewContinuation == nil {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(coordinator.progress, 0)

        previewContinuation?.resume(returning: (url: first, text: "# First\n\nBody"))
        for _ in 0..<80 where coordinator.progress == 0 {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertEqual(coordinator.preview?.url.standardizedFileURL.path, first.standardizedFileURL.path)
        XCTAssertEqual(coordinator.progress, 0.35, accuracy: 0.001)
    }

    @MainActor
    func testPrewarmedPreviewLetsFirstProgressMoveImmediately() async throws {
        let first = try makeNote(named: "first.md", title: "First")
        let second = try makeNote(named: "second.md", title: "Second")
        let store = NoteStore(defaults: defaults, supportDirectory: temporaryDirectory)
        var loadCalls = 0
        let coordinator = NoteDocumentSwipeCoordinator(previewLoader: { offset, _ in
            loadCalls += 1
            return offset == 1
                ? (url: first, text: "# First\n\nBody")
                : nil
        })

        store.openFile(at: first)
        try await waitForCurrentFile(first, in: store)
        store.openFile(at: second)
        try await waitForCurrentFile(second, in: store)

        await coordinator.prewarmAdjacentPreviews(
            noteStore: store,
            viewportSize: CGSize(width: 240, height: 160),
            backingScale: 1,
            fontSize: 15.5,
            accentColor: .systemCyan
        )
        let loadCallsAfterPrewarm = loadCalls

        coordinator.updateProgress(0.35, noteStore: store)

        XCTAssertEqual(coordinator.preview?.url.standardizedFileURL.path, first.standardizedFileURL.path)
        XCTAssertNotNil(coordinator.preview?.preRenderedImage)
        XCTAssertEqual(coordinator.progress, 0.35, accuracy: 0.001)
        XCTAssertEqual(loadCalls, loadCallsAfterPrewarm, "Swipe start should reuse the prewarmed preview instead of loading during the gesture.")
    }

    @MainActor
    func testPrewarmingDoesNotRenderSameWrappedTargetTwice() async throws {
        let first = try makeNote(named: "first.md", title: "First")
        let second = try makeNote(named: "second.md", title: "Second")
        let store = NoteStore(defaults: defaults, supportDirectory: temporaryDirectory)
        var loadCalls = 0
        let coordinator = NoteDocumentSwipeCoordinator(previewLoader: { _, _ in
            loadCalls += 1
            return (url: first, text: "# First\n\nBody")
        })

        store.openFile(at: first)
        try await waitForCurrentFile(first, in: store)
        store.createWorkspace(named: "Swipe Pair")
        store.openFile(at: second)
        try await waitForCurrentFile(second, in: store)

        await coordinator.prewarmAdjacentPreviews(
            noteStore: store,
            viewportSize: CGSize(width: 240, height: 160),
            backingScale: 1,
            fontSize: 15.5,
            accentColor: .systemCyan
        )

        XCTAssertEqual(loadCalls, 1, "A two-document workspace wraps both swipe directions to the same file, so it should be prewarmed once.")
    }

    @MainActor
    func testPrewarmedPreviewInvalidatesWhenTargetDocumentPositionChanges() async throws {
        let first = try makeNote(named: "first.md", title: "First")
        let second = try makeNote(named: "second.md", title: "Second")
        let store = NoteStore(defaults: defaults, supportDirectory: temporaryDirectory)
        var loadCalls = 0
        let coordinator = NoteDocumentSwipeCoordinator(previewLoader: { _, _ in
            loadCalls += 1
            return (url: first, text: "# First\n\nBody")
        })
        let oldPosition = MarkdownDocumentPosition(selectedLocation: 2, selectedLength: 0, scrollY: 12)
        let newPosition = MarkdownDocumentPosition(selectedLocation: 8, selectedLength: 0, scrollY: 80)

        store.openFile(at: first)
        try await waitForCurrentFile(first, in: store)
        store.openFile(at: second)
        try await waitForCurrentFile(second, in: store)
        store.updateDocumentPosition(oldPosition, for: first)

        await coordinator.prewarmAdjacentPreviews(
            noteStore: store,
            viewportSize: CGSize(width: 240, height: 160),
            backingScale: 1,
            fontSize: 15.5,
            accentColor: .systemCyan
        )
        let loadCallsAfterPrewarm = loadCalls

        store.updateDocumentPosition(newPosition, for: first)
        coordinator.updateProgress(0.35, noteStore: store)
        for _ in 0..<80 where coordinator.preview == nil {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertEqual(coordinator.preview?.position, newPosition)
        XCTAssertGreaterThan(loadCalls, loadCallsAfterPrewarm)
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
