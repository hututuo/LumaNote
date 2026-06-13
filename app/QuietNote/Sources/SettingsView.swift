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

                LabeledContent(copy.editorFontSize) {
                    HStack {
                        Slider(
                            value: $settings.editorFontSize,
                            in: AppSettings.minimumEditorFontSize...AppSettings.maximumEditorFontSize,
                            step: 0.5
                        )
                        Text("\(settings.editorFontSize, specifier: "%.1f")pt")
                            .monospacedDigit()
                            .frame(width: 54, alignment: .trailing)
                    }
                }
                Text(copy.editorFontSizeHint)
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

                Toggle(copy.launchAtLogin, isOn: $settings.launchAtLogin)
                Text(copy.launchAtLoginHint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let error = settings.launchAtLoginError {
                    Text(copy.launchAtLoginFailed + error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section(copy.shortcuts) {
                KeyboardShortcuts.Recorder(copy.toggleNoteShortcut, name: .toggleQuietNote)
                KeyboardShortcuts.Recorder(copy.showNoteShortcut, name: .showQuietNote)
                KeyboardShortcuts.Recorder(copy.hideNoteShortcut, name: .hideQuietNote)
                KeyboardShortcuts.Recorder(copy.clipboardShortcut, name: .toggleClipboardLibrary)
            }

            Section(copy.checkForUpdates) {
                UpdateCheckButtonView(settings: settings)
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
        .onAppear {
            settings.refreshLaunchAtLoginStatus()
        }
    }
}
