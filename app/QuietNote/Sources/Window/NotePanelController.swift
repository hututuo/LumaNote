import AppKit
import SwiftUI

enum NoteWindowLayout {
    static let initialSize = NSSize(width: 360, height: 660)
    static let minimumSize = NSSize(width: 270, height: 270)
    static let maximumSize = NSSize(width: 640, height: 980)
}

@MainActor
final class NotePanelController {
    private let settings: AppSettings
    private let noteStore: NoteStore
    private let clipboardStore: ClipboardStore
    private let panel: NSPanel
    private var visibilityAnimationGeneration = 0

    init(
        settings: AppSettings,
        noteStore: NoteStore,
        clipboardStore: ClipboardStore,
        updateActions: UpdateCheckingActions
    ) {
        self.settings = settings
        self.noteStore = noteStore
        self.clipboardStore = clipboardStore

        panel = NSPanel(
            contentRect: NSRect(
                x: 980,
                y: 180,
                width: NoteWindowLayout.initialSize.width,
                height: NoteWindowLayout.initialSize.height
            ),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.title = "QuietNote"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.hasShadow = true
        panel.appearance = settings.appearanceMode.nsAppearance
        panel.level = settings.alwaysOnTop ? .floating : .normal
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.minSize = NoteWindowLayout.minimumSize
        panel.contentMinSize = NoteWindowLayout.minimumSize
        panel.maxSize = NoteWindowLayout.maximumSize
        panel.alphaValue = 1
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        let root = NoteWindowView(
            settings: settings,
            noteStore: noteStore,
            clipboardStore: clipboardStore,
            updateActions: updateActions,
            onClose: { [weak noteStore, weak panel] in
                noteStore?.saveNow()
                panel?.orderOut(nil)
            }
        )
        let hosting = NSHostingView(rootView: root)
        hosting.translatesAutoresizingMaskIntoConstraints = true
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting

        settings.alwaysOnTopDidChange = { [weak panel] value in
            panel?.level = value ? .floating : .normal
        }

        settings.appearanceModeDidChange = { [weak panel] value in
            panel?.appearance = value.nsAppearance
        }
    }

    func show(animated: Bool = true) {
        visibilityAnimationGeneration += 1
        guard !panel.isVisible else {
            panel.alphaValue = 1
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        panel.alphaValue = animated ? 0 : 1
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        guard animated else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    func hide(animated: Bool = true) {
        guard panel.isVisible else { return }
        visibilityAnimationGeneration += 1
        let generation = visibilityAnimationGeneration
        noteStore.saveNow()

        guard animated else {
            panel.orderOut(nil)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self, weak panel] in
            Task { @MainActor in
                guard self?.visibilityAnimationGeneration == generation else { return }
                panel?.orderOut(nil)
                panel?.alphaValue = 1
            }
        }
    }

    func toggle() {
        panel.isVisible ? hide() : show()
    }

    func toggleClipboard() {
        show()
        NotificationCenter.default.post(name: .quietNoteToggleClipboard, object: nil)
    }
}

extension Notification.Name {
    static let quietNoteToggleClipboard = Notification.Name("quietNoteToggleClipboard")
}
