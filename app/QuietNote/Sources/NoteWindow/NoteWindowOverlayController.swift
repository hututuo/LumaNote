import SwiftUI

@MainActor
@Observable
final class NoteWindowOverlayController {
    var activeOverlay: NoteWindowTransientOverlay?

    var hasInlinePanel: Bool {
        activeOverlay?.isInlinePanel == true
    }

    var keepsBottomChromeExpanded: Bool {
        activeOverlay?.keepsBottomChromeExpanded == true
    }

    var hidesDetectedClipboardItem: Bool {
        activeOverlay?.hidesDetectedClipboardItem == true
    }

    var isShortcutSettingsPresented: Bool {
        activeOverlay == .shortcutSettings
    }

    func setShortcutSettingsPresented(_ isPresented: Bool) {
        if isPresented {
            activeOverlay = .shortcutSettings
        } else if activeOverlay == .shortcutSettings {
            activeOverlay = nil
        }
    }

    func toggle(_ overlay: NoteWindowTransientOverlay) {
        activeOverlay = activeOverlay == overlay ? nil : overlay
    }

    func closeInlinePanels() {
        if hasInlinePanel {
            activeOverlay = nil
        }
    }

    func closeExtractionActions() {
        if activeOverlay == .extractionActions {
            activeOverlay = nil
        }
    }
}
