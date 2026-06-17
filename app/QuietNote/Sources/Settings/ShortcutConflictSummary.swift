@preconcurrency import KeyboardShortcuts
import Foundation

struct ShortcutConflictSummary {
    let conflicts: [ShortcutConflict]
    private let conflictedShortcuts: Set<KeyboardShortcuts.Shortcut>

    init(rows: [ShortcutRowState]) {
        var buckets: [KeyboardShortcuts.Shortcut: [ShortcutRowState]] = [:]
        for row in rows {
            guard let shortcut = row.shortcut else { continue }
            buckets[shortcut, default: []].append(row)
        }

        conflicts = buckets
            .filter { $0.value.count > 1 }
            .map { shortcut, rows in
                ShortcutConflict(
                    shortcut: shortcut,
                    shortcutText: "\(shortcut)",
                    actionNames: rows.map { ShortcutLabelFormatter.cleanLabel($0.title) }
                )
            }
            .sorted { $0.shortcutText < $1.shortcutText }

        conflictedShortcuts = Set(conflicts.map(\.shortcut))
    }

    var hasConflict: Bool {
        !conflicts.isEmpty
    }

    func isConflicted(_ shortcut: KeyboardShortcuts.Shortcut?) -> Bool {
        guard let shortcut else { return false }
        return conflictedShortcuts.contains(shortcut)
    }
}

enum ShortcutLabelFormatter {
    private static let trimmedCharacters = CharacterSet(charactersIn: "：: ")

    static func cleanLabel(_ title: String) -> String {
        title.trimmingCharacters(in: trimmedCharacters)
    }
}

struct ShortcutRowState: Identifiable {
    let id: String
    let title: String
    let icon: String
    let name: KeyboardShortcuts.Name
    let defaultShortcut: KeyboardShortcuts.Shortcut
    let shortcut: KeyboardShortcuts.Shortcut?
    let isPrimary: Bool
}

struct ShortcutConflict: Identifiable {
    let shortcut: KeyboardShortcuts.Shortcut
    let shortcutText: String
    let actionNames: [String]

    var id: String {
        shortcutText
    }
}
