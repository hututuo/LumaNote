import XCTest
@testable import QuietNote

final class NoteDelayedInlineHelpControllerTests: XCTestCase {
    @MainActor
    func testHoverShowsHelpAfterDelay() async throws {
        let controller = NoteDelayedInlineHelpController()

        controller.setHovering(true, delay: 0.01)
        try await Task.sleep(for: .milliseconds(40))

        XCTAssertTrue(controller.isVisible)
    }

    @MainActor
    func testLeavingBeforeDelayCancelsShow() async throws {
        let controller = NoteDelayedInlineHelpController()

        controller.setHovering(true, delay: 0.03)
        controller.setHovering(false, delay: 0.03)
        try await Task.sleep(for: .milliseconds(70))

        XCTAssertFalse(controller.isVisible)
    }

    @MainActor
    func testCancelHidesVisibleHelpAndStopsPendingShow() async throws {
        let controller = NoteDelayedInlineHelpController()

        controller.setHovering(true, delay: 0.01)
        try await Task.sleep(for: .milliseconds(40))
        XCTAssertTrue(controller.isVisible)

        controller.setHovering(true, delay: 0.03)
        controller.cancel()
        try await Task.sleep(for: .milliseconds(70))

        XCTAssertFalse(controller.isVisible)
    }
}
