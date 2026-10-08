import XCTest
@testable import QuietNote

final class NoteDelayedInlineHelpControllerTests: XCTestCase {
    @MainActor
    func testHoverShowsHelpAfterDelay() async throws {
        let controller = NoteDelayedInlineHelpController()

        controller.setHovering(true, delay: 0.01)
        try await waitForHelpToBecomeVisible(controller)

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
        try await waitForHelpToBecomeVisible(controller)
        XCTAssertTrue(controller.isVisible)

        controller.setHovering(true, delay: 0.03)
        controller.cancel()
        try await Task.sleep(for: .milliseconds(70))

        XCTAssertFalse(controller.isVisible)
    }

    @MainActor
    private func waitForHelpToBecomeVisible(_ controller: NoteDelayedInlineHelpController) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(1))
        while !controller.isVisible && clock.now < deadline {
            let nextPoll = min(clock.now.advanced(by: .milliseconds(5)), deadline)
            try await clock.sleep(until: nextPoll)
        }
    }
}
