import Foundation
@preconcurrency import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    @MainActor static let toggleQuietNote = Self("toggleQuietNote")
    @MainActor static let showQuietNote = Self("showQuietNote")
    @MainActor static let hideQuietNote = Self("hideQuietNote")
    @MainActor static let toggleClipboardLibrary = Self("toggleClipboardLibrary")
}

@MainActor
final class HotKeyCenter {
    private static let didMigrateToggleShortcutKey = "HotKeyCenter.didMigrateToggleShortcut.v1"
    private static let legacyShowDefaultShortcut = KeyboardShortcuts.Shortcut(.space, modifiers: [.option])
    private static let toggleDefaultShortcut = KeyboardShortcuts.Shortcut(.space, modifiers: [.option])
    private static let showOnlyDefaultShortcut = KeyboardShortcuts.Shortcut(.space, modifiers: [.option, .shift])
    private static let hideDefaultShortcut = KeyboardShortcuts.Shortcut(.escape, modifiers: [.option])
    private static let clipboardDefaultShortcut = KeyboardShortcuts.Shortcut(.v, modifiers: [.option])

    init(
        onToggleNote: @escaping @MainActor () -> Void,
        onShowNote: @escaping @MainActor () -> Void,
        onHideNote: @escaping @MainActor () -> Void,
        onToggleClipboard: @escaping @MainActor () -> Void
    ) {
        Self.configureDefaultShortcuts()

        KeyboardShortcuts.onKeyUp(for: .toggleQuietNote) {
            Task { @MainActor in onToggleNote() }
        }
        KeyboardShortcuts.onKeyUp(for: .showQuietNote) {
            Task { @MainActor in onShowNote() }
        }
        KeyboardShortcuts.onKeyUp(for: .hideQuietNote) {
            Task { @MainActor in onHideNote() }
        }
        KeyboardShortcuts.onKeyUp(for: .toggleClipboardLibrary) {
            Task { @MainActor in onToggleClipboard() }
        }
    }

    private static func configureDefaultShortcuts() {
        let defaults = UserDefaults.standard
        let didMigrate = defaults.bool(forKey: didMigrateToggleShortcutKey)

        if KeyboardShortcuts.getShortcut(for: .toggleQuietNote) == nil {
            KeyboardShortcuts.setShortcut(toggleDefaultShortcut, for: .toggleQuietNote)
        }

        if KeyboardShortcuts.getShortcut(for: .showQuietNote) == nil {
            KeyboardShortcuts.setShortcut(showOnlyDefaultShortcut, for: .showQuietNote)
        } else if !didMigrate,
                  KeyboardShortcuts.getShortcut(for: .showQuietNote) == legacyShowDefaultShortcut {
            KeyboardShortcuts.setShortcut(showOnlyDefaultShortcut, for: .showQuietNote)
        }

        if KeyboardShortcuts.getShortcut(for: .hideQuietNote) == nil {
            KeyboardShortcuts.setShortcut(hideDefaultShortcut, for: .hideQuietNote)
        }
        if KeyboardShortcuts.getShortcut(for: .toggleClipboardLibrary) == nil {
            KeyboardShortcuts.setShortcut(clipboardDefaultShortcut, for: .toggleClipboardLibrary)
        }

        if !didMigrate {
            defaults.set(true, forKey: didMigrateToggleShortcutKey)
        }
    }
}
