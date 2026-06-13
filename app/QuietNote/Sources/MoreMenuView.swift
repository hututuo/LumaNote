import Foundation
import SwiftUI

struct MoreMenuView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var clipboardStore: ClipboardStore
    @Binding var showShortcutSettings: Bool
    let onClose: () -> Void

    var body: some View {
        let copy = AppText(language: settings.language)

        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 15) {
                Text(copy.appearance)
                    .font(.system(size: 13, weight: .semibold))

                compactSliderRow(
                    title: copy.editorFontSize,
                    value: String(format: "%.1fpt", settings.editorFontSize)
                ) {
                    Slider(
                        value: $settings.editorFontSize,
                        in: AppSettings.minimumEditorFontSize...AppSettings.maximumEditorFontSize,
                        step: 0.5
                    )
                    .tint(.cyan)
                }

                compactSliderRow(
                    title: copy.glass,
                    value: "\(Int(settings.glassStrength * 100))%"
                ) {
                    VStack(alignment: .leading, spacing: 5) {
                        Slider(value: $settings.glassStrength, in: 0...1)
                            .tint(.cyan)

                        Text(copy.glassHintCompact)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(copy.launchAtLogin, isOn: $settings.launchAtLogin)
                if let error = settings.launchAtLoginError {
                    Text(copy.launchAtLoginFailed + error)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.red)
                }

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
                    HStack(spacing: 10) {
                        Image(systemName: "keyboard.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.78))
                            .frame(width: 30, height: 30)
                            .background {
                                Circle()
                                    .fill(Color.cyan.opacity(0.18))
                                    .overlay(Circle().stroke(Color.white.opacity(0.46), lineWidth: 1))
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(copy.globalShortcuts)
                                .font(.system(size: 13, weight: .semibold))
                            Text(copy.shortcutEntrySubtitle)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.26), lineWidth: 1)
                            }
                    }
                }
                .buttonStyle(.plain)

                Divider()

                UpdateCheckButtonView(settings: settings, compact: true)

                Button(role: .cancel, action: onClose) {
                    Label(copy.hideNote, systemImage: "eye.slash")
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
        .background(Color.clear)
    }

    private func compactSliderRow<Control: View>(
        title: String,
        value: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                Spacer()
                Text(value)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            control()
        }
    }
}
