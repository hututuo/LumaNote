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
            clipboardShortcut: nil
        )

        XCTAssertEqual(plan.toggleShortcut, HotKeyCenter.toggleDefaultShortcut)
        XCTAssertEqual(plan.showShortcut, HotKeyCenter.showOnlyDefaultShortcut)
        XCTAssertEqual(plan.hideShortcut, HotKeyCenter.hideDefaultShortcut)
        XCTAssertEqual(plan.clipboardShortcut, HotKeyCenter.clipboardDefaultShortcut)
        XCTAssertTrue(plan.shouldMarkMigrated)
    }

    func testDefaultShortcutPlanMigratesLegacyShowOnlyShortcutOnce() {
        let plan = HotKeyCenter.defaultShortcutPlan(
            didMigrate: false,
            toggleShortcut: HotKeyCenter.toggleDefaultShortcut,
            showShortcut: KeyboardShortcuts.Shortcut(.space, modifiers: [.option]),
            hideShortcut: HotKeyCenter.hideDefaultShortcut,
            clipboardShortcut: HotKeyCenter.clipboardDefaultShortcut
        )

        XCTAssertNil(plan.toggleShortcut)
        XCTAssertEqual(plan.showShortcut, HotKeyCenter.showOnlyDefaultShortcut)
        XCTAssertNil(plan.hideShortcut)
        XCTAssertNil(plan.clipboardShortcut)
        XCTAssertTrue(plan.shouldMarkMigrated)
    }

    func testDefaultShortcutPlanPreservesExistingShortcutsAfterMigration() {
        let plan = HotKeyCenter.defaultShortcutPlan(
            didMigrate: true,
            toggleShortcut: HotKeyCenter.toggleDefaultShortcut,
            showShortcut: KeyboardShortcuts.Shortcut(.space, modifiers: [.option]),
            hideShortcut: HotKeyCenter.hideDefaultShortcut,
            clipboardShortcut: HotKeyCenter.clipboardDefaultShortcut
        )

        XCTAssertNil(plan.toggleShortcut)
        XCTAssertNil(plan.showShortcut)
        XCTAssertNil(plan.hideShortcut)
        XCTAssertNil(plan.clipboardShortcut)
        XCTAssertFalse(plan.shouldMarkMigrated)
    }
}
