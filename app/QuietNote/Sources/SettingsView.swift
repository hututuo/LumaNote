@preconcurrency import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var clipboardStore: ClipboardStore

    var body: some View {
        let copy = AppText(language: settings.language)

        Form {
            Section(copy.note) {
                Picker(copy.languageLabel, selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.segmented)

                LabeledContent(copy.opacity) {
                    HStack {
                        Slider(value: $settings.noteOpacity, in: AppSettings.minimumNoteOpacity...1)
                        Text("\(Int(settings.noteOpacity * 100))%")
                            .monospacedDigit()
                            .frame(width: 42, alignment: .trailing)
                    }
                }
                Text(copy.opacityHint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                LabeledContent(copy.glass) {
                    HStack {
                        Slider(value: $settings.glassStrength, in: 0...1)
                        Text("\(Int(settings.glassStrength * 100))%")
                            .monospacedDigit()
                            .frame(width: 42, alignment: .trailing)
                    }
                }
                Text(copy.glassHint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Toggle(copy.alwaysOnTop, isOn: $settings.alwaysOnTop)
            }

            Section(copy.shortcuts) {
                KeyboardShortcuts.Recorder(copy.showNoteShortcut, name: .showQuietNote)
                KeyboardShortcuts.Recorder(copy.hideNoteShortcut, name: .hideQuietNote)
                KeyboardShortcuts.Recorder(copy.clipboardShortcut, name: .toggleClipboardLibrary)
            }

            Section(copy.clipboard) {
                Toggle(copy.monitorClipboard, isOn: $settings.monitorClipboard)
                Stepper(copy.keepLatest(settings.clipboardLimit), value: $settings.clipboardLimit, in: 25...1000, step: 25)
                Button(copy.clearClipboard) {
                    clipboardStore.clear()
                }
            }
        }
        .formStyle(.grouped)
        .padding(18)
    }
}
