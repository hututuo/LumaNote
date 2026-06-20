import CoreGraphics
import XCTest
@testable import QuietNote

final class DocumentSwipeGestureAxisStateTests: XCTestCase {
    func testHorizontalLockIgnoresLaterVerticalDriftWhenCommitting() {
        var state = DocumentSwipeGestureAxisState()

        state.add(deltaX: 14, deltaY: 8)
        XCTAssertEqual(state.mode, .horizontal)

        state.add(deltaX: 46, deltaY: 70)

        XCTAssertTrue(state.shouldCommitHorizontal())
        XCTAssertEqual(state.progress, 60.0 / 220.0, accuracy: 0.001)
    }

    func testVerticalDominantStartDoesNotBecomeHorizontalCommit() {
        var state = DocumentSwipeGestureAxisState()

        state.add(deltaX: 6, deltaY: 12)
        XCTAssertEqual(state.mode, .vertical)

        state.add(deltaX: 70, deltaY: 0)

        XCTAssertFalse(state.shouldCommitHorizontal())
    }
}
