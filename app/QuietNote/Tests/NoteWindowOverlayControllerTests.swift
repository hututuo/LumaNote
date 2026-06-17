import XCTest
@testable import QuietNote

final class NoteWindowOverlayControllerTests: XCTestCase {
    @MainActor
    func testToggleOpensClosesAndReplacesOverlay() {
        let controller = NoteWindowOverlayController()

        controller.toggle(.clipboard)
        XCTAssertEqual(controller.activeOverlay, .clipboard)

        controller.toggle(.clipboard)
        XCTAssertNil(controller.activeOverlay)

        controller.toggle(.clipboard)
        controller.toggle(.more)
        XCTAssertEqual(controller.activeOverlay, .more)
    }

    @MainActor
    func testCloseInlinePanelsKeepsShortcutSheet() {
        let controller = NoteWindowOverlayController()

        controller.toggle(.fileSwitcher)
        controller.closeInlinePanels()
        XCTAssertNil(controller.activeOverlay)

        controller.setShortcutSettingsPresented(true)
        controller.closeInlinePanels()
        XCTAssertEqual(controller.activeOverlay, .shortcutSettings)
    }

    @MainActor
    func testShortcutSettingsBindingBehavior() {
        let controller = NoteWindowOverlayController()

        controller.setShortcutSettingsPresented(true)
        XCTAssertTrue(controller.isShortcutSettingsPresented)
        XCTAssertTrue(controller.keepsBottomChromeExpanded)
        XCTAssertTrue(controller.hidesDetectedClipboardItem)

        controller.setShortcutSettingsPresented(false)
        XCTAssertNil(controller.activeOverlay)
    }

    @MainActor
    func testCloseExtractionActionsOnlyClosesExtractionOverlay() {
        let controller = NoteWindowOverlayController()

        controller.toggle(.extractionActions)
        controller.closeExtractionActions()
        XCTAssertNil(controller.activeOverlay)

        controller.toggle(.clipboard)
        controller.closeExtractionActions()
        XCTAssertEqual(controller.activeOverlay, .clipboard)
    }
}
