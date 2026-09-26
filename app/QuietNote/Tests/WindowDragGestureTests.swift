import XCTest
@testable import QuietNote

final class WindowDragGestureTests: XCTestCase {
    func testDoubleClickRequestsWindowZoom() {
        XCTAssertEqual(WindowDragMouseDownAction.action(forClickCount: 2), .zoom)
        XCTAssertEqual(WindowDragMouseDownAction.action(forClickCount: 3), .zoom)
    }

    func testSingleClickKeepsDragTracking() {
        XCTAssertEqual(WindowDragMouseDownAction.action(forClickCount: 1), .trackDragOrClick)
        XCTAssertEqual(WindowDragMouseDownAction.action(forClickCount: 0), .trackDragOrClick)
    }

    func testWindowMaximumSizeDoesNotCapZoomToSmallNoteWidth() {
        XCTAssertGreaterThanOrEqual(NoteWindowLayout.maximumSize.width, 1_920)
        XCTAssertGreaterThanOrEqual(NoteWindowLayout.maximumSize.height, 1_200)
    }
}
