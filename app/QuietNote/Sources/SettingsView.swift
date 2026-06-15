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

                Picker(copy.appearanceMode, selection: $settings.appearanceMode) {
                    ForEach(AppAppearanceMode.allCases) { mode in
                        Text(mode.displayName(language: settings.language)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                Text(copy.appearanceModeHint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                LabeledContent(copy.opacity) {
                    HStack {
                        Slider(value: $settings.noteOpacity, in: AppSettings.minimumNoteOpacity...1)
                            .tint(settings.accentColor)
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
                        .tint(settings.accentColor)
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
                            .tint(settings.accentColor)
                        Text("\(Int(settings.glassStrength * 100))%")
                            .monospacedDigit()
                            .frame(width: 42, alignment: .trailing)
                    }
                }
                Text(copy.glassHint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                LabeledContent(copy.themeColor) {
                    ThemeColorPicker(selection: $settings.themeColor, language: settings.language)
                }
                Text(copy.themeColorHint)
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
                ShortcutSettingsPanel(settings: settings, presentation: .settings)
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
                .help(copy.clearClipboard)
            }
        }
        .formStyle(.grouped)
        .padding(18)
        .preferredColorScheme(settings.resolvedColorScheme)
        .onAppear {
            settings.refreshLaunchAtLoginStatus()
        }
    }
}
