import XCTest
@testable import QuietNote

final class NoteChromeAutoHideControllerTests: XCTestCase {
    @MainActor
    func testDisablingAutoHideExpandsCollapsedControls() {
        let controller = NoteChromeAutoHideController()
        controller.controlsCollapsed = true

        controller.handleAutoHideSettingChange(isEnabled: false, shouldStayExpanded: false)

        XCTAssertFalse(controller.controlsCollapsed)
    }

    @MainActor
    func testPinnedPanelExpandsCollapsedControls() {
        let controller = NoteChromeAutoHideController()
        controller.controlsCollapsed = true

        controller.handlePinnedStateChange(shouldStayExpanded: true, autoHideEnabled: true)

        XCTAssertFalse(controller.controlsCollapsed)
    }
}
