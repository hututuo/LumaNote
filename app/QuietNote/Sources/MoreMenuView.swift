@preconcurrency import KeyboardShortcuts
import SwiftUI

struct MoreMenuView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var clipboardStore: ClipboardStore
    @Binding var showShortcutSettings: Bool
    let onClose: () -> Void

    var body: some View {
        let copy = AppText(language: settings.language)

        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text(copy.appearance)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(Int(settings.glassStrength * 100))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $settings.glassStrength, in: 0...1)
                .tint(.cyan)

            Toggle(copy.alwaysOnTop, isOn: $settings.alwaysOnTop)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(copy.clipboard)
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("\(clipboardStore.items.count)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Toggle(copy.monitorLocally, isOn: $settings.monitorClipboard)

                Stepper(
                    copy.keepCompact(settings.clipboardLimit),
                    value: $settings.clipboardLimit,
                    in: 25...1000,
                    step: 25
                )
                .font(.system(size: 12.5))

                Button(role: .destructive) {
                    clipboardStore.clear()
                } label: {
                    Label(copy.clearClipboard, systemImage: "trash")
                }
                .buttonStyle(.plain)
                .disabled(clipboardStore.items.isEmpty)
            }

            Divider()

            Button {
                showShortcutSettings = true
            } label: {
                Label(copy.shortcuts, systemImage: "keyboard")
            }
            .buttonStyle(.plain)

            Button(role: .cancel, action: onClose) {
                Label(copy.hideNote, systemImage: "eye.slash")
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(.regularMaterial)
    }
}

struct ShortcutSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        let copy = AppText(language: settings.language)

        VStack(alignment: .leading, spacing: 18) {
            Text(copy.shortcuts)
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 12) {
                KeyboardShortcuts.Recorder(copy.showNoteShortcut, name: .showQuietNote)
                KeyboardShortcuts.Recorder(copy.hideNoteShortcut, name: .hideQuietNote)
                KeyboardShortcuts.Recorder(copy.clipboardShortcut, name: .toggleClipboardLibrary)
            }

            Text(copy.keyboardShortcutNote)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
