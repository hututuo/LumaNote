import AppKit
import Sparkle
import SwiftUI

@main
struct QuietNoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(
                settings: appDelegate.settings,
                clipboardStore: appDelegate.clipboardStore
            )
            .frame(width: 460)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    appDelegate.checkForUpdates()
                }
                .help("Check for updates")
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings()
    let noteStore = NoteStore()
    let clipboardStore = ClipboardStore()
    let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    private var panelController: NotePanelController?
    private var hotKeyCenter: HotKeyCenter?
    private var statusItem: NSStatusItem?

    func applicationWillFinishLaunching(_ notification: Notification) {
        configureTooltipTiming()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        let controller = NotePanelController(
            settings: settings,
            noteStore: noteStore,
            clipboardStore: clipboardStore
        )
        panelController = controller
        controller.show(animated: false)

        hotKeyCenter = HotKeyCenter(
            onToggleNote: { [weak controller] in controller?.toggle() },
            onShowNote: { [weak controller] in controller?.show() },
            onHideNote: { [weak controller] in controller?.hide() },
            onToggleClipboard: { [weak controller] in controller?.toggleClipboard() }
        )

        configureStatusItem()
        clipboardStore.configure(settings: settings)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panelController?.show()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        noteStore.saveNow()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "LumaNote")
        item.button?.toolTip = "LumaNote"

        let menu = NSMenu()
        menu.addItem(menuItem(title: "Show/Hide Note", action: #selector(toggleNoteFromMenu), toolTip: "Show or hide LumaNote"))
        menu.addItem(menuItem(title: "Show Note", action: #selector(showNoteFromMenu), toolTip: "Show LumaNote"))
        menu.addItem(menuItem(title: "Hide Note", action: #selector(hideNoteFromMenu), toolTip: "Hide LumaNote"))
        menu.addItem(menuItem(title: "Clipboard Library", action: #selector(toggleClipboardFromMenu), toolTip: "Open clipboard library"))
        menu.addItem(.separator())
        menu.addItem(menuItem(title: "Check for Updates...", action: #selector(checkForUpdatesFromMenu), toolTip: "Check for updates"))
        menu.addItem(menuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",", toolTip: "Open settings"))
        menu.addItem(menuItem(title: "Quit LumaNote", action: #selector(quit), keyEquivalent: "q", toolTip: "Quit LumaNote"))
        item.menu = menu

        statusItem = item
    }

    private func menuItem(title: String, action: Selector, keyEquivalent: String = "", toolTip: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.toolTip = toolTip
        return item
    }

    private func configureTooltipTiming() {
        UserDefaults.standard.set(150, forKey: "NSInitialToolTipDelay")
    }

    @objc private func toggleNoteFromMenu() {
        panelController?.toggle()
    }

    @objc private func showNoteFromMenu() {
        panelController?.show()
    }

    @objc private func hideNoteFromMenu() {
        panelController?.hide()
    }

    @objc private func toggleClipboardFromMenu() {
        panelController?.toggleClipboard()
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc func checkForUpdatesFromMenu() {
        checkForUpdates()
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    var canCheckForUpdates: Bool {
        updaterController.updater.canCheckForUpdates
    }

    var automaticallyChecksForUpdates: Bool {
        updaterController.updater.automaticallyChecksForUpdates
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        updaterController.updater.automaticallyChecksForUpdates = enabled
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
