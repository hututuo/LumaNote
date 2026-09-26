import KeyboardShortcuts
import XCTest
@testable import QuietNote

@MainActor
final class HotKeyCenterTests: XCTestCase {
    func testDefaultShortcutPlanFillsMissingShortcutsAndMarksMigration() {
        let plan = HotKeyCenter.defaultShortcutPlan(
            didMigrate: false,
            toggleShortcut: nil,
            showShortcut: nil,
            hideShortcut: nil,
            clipboardShortcut: nil,
            emphasisShortcut: nil
        )

        XCTAssertEqual(plan.toggleShortcut, HotKeyCenter.toggleDefaultShortcut)
        XCTAssertEqual(plan.showShortcut, HotKeyCenter.showOnlyDefaultShortcut)
        XCTAssertEqual(plan.hideShortcut, HotKeyCenter.hideDefaultShortcut)
        XCTAssertEqual(plan.clipboardShortcut, HotKeyCenter.clipboardDefaultShortcut)
        XCTAssertEqual(plan.emphasisShortcut, HotKeyCenter.emphasisDefaultShortcut)
        XCTAssertTrue(plan.shouldMarkMigrated)
    }

    func testDefaultShortcutPlanMigratesLegacyShowOnlyShortcutOnce() {
        let plan = HotKeyCenter.defaultShortcutPlan(
            didMigrate: false,
            toggleShortcut: HotKeyCenter.toggleDefaultShortcut,
            showShortcut: KeyboardShortcuts.Shortcut(.space, modifiers: [.option]),
            hideShortcut: HotKeyCenter.hideDefaultShortcut,
            clipboardShortcut: HotKeyCenter.clipboardDefaultShortcut,
            emphasisShortcut: HotKeyCenter.emphasisDefaultShortcut
        )

        XCTAssertNil(plan.toggleShortcut)
        XCTAssertEqual(plan.showShortcut, HotKeyCenter.showOnlyDefaultShortcut)
        XCTAssertNil(plan.hideShortcut)
        XCTAssertNil(plan.clipboardShortcut)
        XCTAssertNil(plan.emphasisShortcut)
        XCTAssertTrue(plan.shouldMarkMigrated)
    }

    func testDefaultShortcutPlanPreservesExistingShortcutsAfterMigration() {
        let plan = HotKeyCenter.defaultShortcutPlan(
            didMigrate: true,
            toggleShortcut: HotKeyCenter.toggleDefaultShortcut,
            showShortcut: KeyboardShortcuts.Shortcut(.space, modifiers: [.option]),
            hideShortcut: HotKeyCenter.hideDefaultShortcut,
            clipboardShortcut: HotKeyCenter.clipboardDefaultShortcut,
            emphasisShortcut: HotKeyCenter.emphasisDefaultShortcut
        )

        XCTAssertNil(plan.toggleShortcut)
        XCTAssertNil(plan.showShortcut)
        XCTAssertNil(plan.hideShortcut)
        XCTAssertNil(plan.clipboardShortcut)
        XCTAssertNil(plan.emphasisShortcut)
        XCTAssertFalse(plan.shouldMarkMigrated)
    }
}
