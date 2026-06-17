import XCTest
@testable import QuietNote

final class NoteDocumentSwipeCoordinatorTests: XCTestCase {
    @MainActor
    func testCancelClearsAnimatingStateWhenNoProgressRemains() {
        let coordinator = NoteDocumentSwipeCoordinator()
        coordinator.isAnimating = true
        coordinator.progress = 0
        coordinator.preview = NoteDocumentSwipePreview(
            id: "preview",
            offset: 1,
            text: "# Preview",
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
            offset: -1,
            text: "# Preview",
            revision: 1
        )

        coordinator.cancelTasks()

        XCTAssertFalse(coordinator.isAnimating)
        XCTAssertEqual(coordinator.progress, 0)
        XCTAssertNil(coordinator.preview)
    }
}
