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
    init(
        onShowNote: @escaping @MainActor () -> Void,
        onHideNote: @escaping @MainActor () -> Void,
        onToggleClipboard: @escaping @MainActor () -> Void
    ) {
        if KeyboardShortcuts.getShortcut(for: .showQuietNote) == nil {
            let existingToggleShortcut = KeyboardShortcuts.getShortcut(for: .toggleQuietNote)
            KeyboardShortcuts.setShortcut(existingToggleShortcut ?? .init(.space, modifiers: [.option]), for: .showQuietNote)
        }
        if KeyboardShortcuts.getShortcut(for: .hideQuietNote) == nil {
            KeyboardShortcuts.setShortcut(.init(.escape, modifiers: [.option]), for: .hideQuietNote)
        }
        if KeyboardShortcuts.getShortcut(for: .toggleClipboardLibrary) == nil {
            KeyboardShortcuts.setShortcut(.init(.v, modifiers: [.option]), for: .toggleClipboardLibrary)
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
}
