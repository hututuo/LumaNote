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
    static let toggleDefaultShortcut = KeyboardShortcuts.Shortcut(.space, modifiers: [.option])
    static let showOnlyDefaultShortcut = KeyboardShortcuts.Shortcut(.space, modifiers: [.option, .shift])
    static let hideDefaultShortcut = KeyboardShortcuts.Shortcut(.escape, modifiers: [.option])
    static let clipboardDefaultShortcut = KeyboardShortcuts.Shortcut(.v, modifiers: [.option])

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
        let plan = defaultShortcutPlan(
            didMigrate: didMigrate,
            toggleShortcut: KeyboardShortcuts.getShortcut(for: .toggleQuietNote),
            showShortcut: KeyboardShortcuts.getShortcut(for: .showQuietNote),
            hideShortcut: KeyboardShortcuts.getShortcut(for: .hideQuietNote),
            clipboardShortcut: KeyboardShortcuts.getShortcut(for: .toggleClipboardLibrary)
        )

        if let shortcut = plan.toggleShortcut {
            KeyboardShortcuts.setShortcut(shortcut, for: .toggleQuietNote)
        }
        if let shortcut = plan.showShortcut {
            KeyboardShortcuts.setShortcut(shortcut, for: .showQuietNote)
        }
        if let shortcut = plan.hideShortcut {
            KeyboardShortcuts.setShortcut(shortcut, for: .hideQuietNote)
        }
        if let shortcut = plan.clipboardShortcut {
            KeyboardShortcuts.setShortcut(shortcut, for: .toggleClipboardLibrary)
        }

        if plan.shouldMarkMigrated {
            defaults.set(true, forKey: didMigrateToggleShortcutKey)
        }
    }

    static func defaultShortcutPlan(
        didMigrate: Bool,
        toggleShortcut: KeyboardShortcuts.Shortcut?,
        showShortcut: KeyboardShortcuts.Shortcut?,
        hideShortcut: KeyboardShortcuts.Shortcut?,
        clipboardShortcut: KeyboardShortcuts.Shortcut?
    ) -> HotKeyDefaultShortcutPlan {
        HotKeyDefaultShortcutPlan(
            toggleShortcut: toggleShortcut == nil ? toggleDefaultShortcut : nil,
            showShortcut: defaultShowOnlyShortcut(didMigrate: didMigrate, currentShortcut: showShortcut),
            hideShortcut: hideShortcut == nil ? hideDefaultShortcut : nil,
            clipboardShortcut: clipboardShortcut == nil ? clipboardDefaultShortcut : nil,
            shouldMarkMigrated: !didMigrate
        )
    }

    private static func defaultShowOnlyShortcut(
        didMigrate: Bool,
        currentShortcut: KeyboardShortcuts.Shortcut?
    ) -> KeyboardShortcuts.Shortcut? {
        if currentShortcut == nil {
            return showOnlyDefaultShortcut
        }
        if !didMigrate, currentShortcut == legacyShowDefaultShortcut {
            return showOnlyDefaultShortcut
        }
        return nil
    }

    static func resetDefaultShortcuts() {
        KeyboardShortcuts.setShortcut(toggleDefaultShortcut, for: .toggleQuietNote)
        KeyboardShortcuts.setShortcut(showOnlyDefaultShortcut, for: .showQuietNote)
        KeyboardShortcuts.setShortcut(hideDefaultShortcut, for: .hideQuietNote)
        KeyboardShortcuts.setShortcut(clipboardDefaultShortcut, for: .toggleClipboardLibrary)
    }
}

struct HotKeyDefaultShortcutPlan: Equatable {
    let toggleShortcut: KeyboardShortcuts.Shortcut?
    let showShortcut: KeyboardShortcuts.Shortcut?
    let hideShortcut: KeyboardShortcuts.Shortcut?
    let clipboardShortcut: KeyboardShortcuts.Shortcut?
    let shouldMarkMigrated: Bool
}
