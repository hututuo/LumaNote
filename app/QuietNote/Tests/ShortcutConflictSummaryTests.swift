import KeyboardShortcuts
import XCTest
@testable import QuietNote

@MainActor
final class ShortcutConflictSummaryTests: XCTestCase {
    func testSummaryIgnoresNilAndUniqueShortcuts() {
        let rows = [
            shortcutRow(id: "toggle", title: "呼出便签：", shortcut: HotKeyCenter.toggleDefaultShortcut),
            shortcutRow(id: "show", title: "显示便签", shortcut: HotKeyCenter.showOnlyDefaultShortcut),
            shortcutRow(id: "hide", title: "隐藏便签", shortcut: nil)
        ]

        let summary = ShortcutConflictSummary(rows: rows)

        XCTAssertFalse(summary.hasConflict)
        XCTAssertTrue(summary.conflicts.isEmpty)
        XCTAssertFalse(summary.isConflicted(HotKeyCenter.toggleDefaultShortcut))
        XCTAssertFalse(summary.isConflicted(nil))
    }

    func testSummaryGroupsDuplicateShortcutsAndCleansLabels() {
        let duplicate = HotKeyCenter.toggleDefaultShortcut
        let rows = [
            shortcutRow(id: "toggle", title: "呼出便签：", shortcut: duplicate),
            shortcutRow(id: "hide", title: "隐藏便签:", shortcut: duplicate),
            shortcutRow(id: "clipboard", title: "剪切板", shortcut: HotKeyCenter.clipboardDefaultShortcut)
        ]

        let summary = ShortcutConflictSummary(rows: rows)

        XCTAssertTrue(summary.hasConflict)
        XCTAssertEqual(summary.conflicts.count, 1)
        XCTAssertEqual(summary.conflicts.first?.shortcutText, "\(duplicate)")
        XCTAssertEqual(summary.conflicts.first?.actionNames, ["呼出便签", "隐藏便签"])
        XCTAssertTrue(summary.isConflicted(duplicate))
        XCTAssertFalse(summary.isConflicted(HotKeyCenter.clipboardDefaultShortcut))
    }

    func testSummarySortsMultipleConflictsByShortcutText() {
        let first = KeyboardShortcuts.Shortcut(.a, modifiers: [.option])
        let second = KeyboardShortcuts.Shortcut(.z, modifiers: [.option])
        let rows = [
            shortcutRow(id: "a1", title: "A1", shortcut: first),
            shortcutRow(id: "z1", title: "Z1", shortcut: second),
            shortcutRow(id: "z2", title: "Z2", shortcut: second),
            shortcutRow(id: "a2", title: "A2", shortcut: first)
        ]

        let summary = ShortcutConflictSummary(rows: rows)

        XCTAssertEqual(summary.conflicts.map(\.shortcutText), ["\(first)", "\(second)"].sorted())
    }

    private func shortcutRow(
        id: String,
        title: String,
        shortcut: KeyboardShortcuts.Shortcut?
    ) -> ShortcutRowState {
        ShortcutRowState(
            id: id,
            title: title,
            icon: "keyboard",
            name: .toggleQuietNote,
            defaultShortcut: HotKeyCenter.toggleDefaultShortcut,
            shortcut: shortcut,
            isPrimary: id == "toggle"
        )
    }
}
