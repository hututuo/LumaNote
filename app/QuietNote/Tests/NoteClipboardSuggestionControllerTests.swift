import XCTest
@testable import QuietNote

final class NoteClipboardSuggestionControllerTests: XCTestCase {
    @MainActor
    func testActiveItemReturnsLatestDetectedItem() {
        let controller = NoteClipboardSuggestionController()
        let item = makeItem()

        XCTAssertEqual(controller.activeItem(from: item, isSuppressedByOverlay: false)?.id, item.id)
    }

    @MainActor
    func testActiveItemHidesExpiredItemAndOverlaySuppressedItem() {
        let controller = NoteClipboardSuggestionController()
        let item = makeItem()

        controller.hiddenItemID = item.id

        XCTAssertNil(controller.activeItem(from: item, isSuppressedByOverlay: false))
        XCTAssertNil(controller.activeItem(from: makeItem(), isSuppressedByOverlay: true))
    }

    @MainActor
    func testScheduledResetHidesItemAndRunsExpireCallback() async throws {
        let controller = NoteClipboardSuggestionController()
        let item = makeItem()
        var didExpire = false

        controller.scheduleReset(for: item.id, delay: .milliseconds(10)) {
            didExpire = true
        }

        try await Task.sleep(for: .milliseconds(40))

        XCTAssertEqual(controller.hiddenItemID, item.id)
        XCTAssertTrue(didExpire)
    }

    @MainActor
    func testCancelTasksStopsPendingReset() async throws {
        let controller = NoteClipboardSuggestionController()
        let item = makeItem()
        var didExpire = false

        controller.scheduleReset(for: item.id, delay: .milliseconds(20)) {
            didExpire = true
        }
        controller.cancelTasks()

        try await Task.sleep(for: .milliseconds(50))

        XCTAssertNil(controller.hiddenItemID)
        XCTAssertFalse(didExpire)
    }

    private func makeItem(id: UUID = UUID()) -> ClipboardItem {
        ClipboardItem(
            id: id,
            text: "电话：13800138000",
            createdAt: Date(),
            detections: [
                ClipboardDetection(id: UUID(), kind: .phone, value: "13800138000")
            ]
        )
    }
}
