@preconcurrency import KeyboardShortcuts
import SwiftUI

struct ShortcutSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    var settings: AppSettings

    private var closeIconColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.82 : 0.72)
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(closeIconColor)
                    .frame(width: 26, height: 26)
                    .background {
                        Circle()
                            .fill(Color.white.opacity(0.28))
                            .overlay(Circle().stroke(Color.white.opacity(0.48), lineWidth: 1))
                    }
            }
            .buttonStyle(.plain)
            .help(settings.localizedText.close)

            ShortcutSettingsPanel(settings: settings, presentation: .sheet)
        }
    }
}

struct ShortcutSettingsPanel: View {
    @Environment(\.colorScheme) private var colorScheme

    enum Presentation {
        case settings
        case sheet
    }

    var settings: AppSettings
    let presentation: Presentation
    @State private var refreshToken = 0

    private var iconInkColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.90 : 0.82)
    }

    private var rowIconInkColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.82 : 0.76)
    }

    var body: some View {
        let copy = settings.localizedText
        let rows = shortcutRows(copy: copy)
        let conflictSummary = ShortcutConflictSummary(rows: rows)

        VStack(alignment: .leading, spacing: presentation == .sheet ? 12 : 13) {
            header(copy: copy, primaryShortcut: rows.first?.shortcut, hasConflict: conflictSummary.hasConflict)

            if conflictSummary.conflicts.isEmpty {
                statusLine(copy: copy, hasConflict: false)
            } else {
                conflictPanel(copy: copy, conflicts: conflictSummary.conflicts)
            }

            VStack(spacing: 8) {
                ForEach(rows) { row in
                    shortcutRow(
                        copy: copy,
                        row: row,
                        isConflicted: conflictSummary.isConflicted(row.shortcut)
                    )
                }
            }

            Text(copy.keyboardShortcutNote)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(presentation == .sheet ? 14 : 12)
        .background {
            let shape = RoundedRectangle(cornerRadius: presentation == .sheet ? 16 : 12, style: .continuous)

            shape
                .fill(.regularMaterial)
                .opacity(presentation == .sheet ? 0.60 : 0)
                .overlay {
                    shape
                        .fill(Color.white.opacity(presentation == .sheet ? 0.10 : 0.10))
                }
                .overlay {
                    shape
                        .fill(settings.accentColor.opacity(presentation == .sheet ? 0.026 : 0))
                        .blendMode(.plusLighter)
                }
                .overlay {
                    shape
                        .stroke(Color.white.opacity(0.34), lineWidth: 1)
                }
        }
    }

    private func header(copy: AppText, primaryShortcut: KeyboardShortcuts.Shortcut?, hasConflict: Bool) -> some View {
        HStack(spacing: presentation == .sheet ? 9 : 12) {
            Image(systemName: "keyboard.fill")
                .font(.system(size: presentation == .sheet ? 19 : 22, weight: .semibold))
                .foregroundStyle(iconInkColor)
                .frame(width: presentation == .sheet ? 38 : 44, height: presentation == .sheet ? 38 : 44)
                .background {
                    Circle()
                        .fill(settings.accentColor.opacity(0.22))
                        .overlay(Circle().stroke(Color.white.opacity(0.52), lineWidth: 1))
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(copy.globalShortcuts)
                    .font(.system(size: presentation == .sheet ? 16 : 15, weight: .semibold))

                Text(verbatim: "\(displayShortcut(primaryShortcut, copy: copy)) · \(ShortcutLabelFormatter.cleanLabel(copy.toggleNoteShortcut))")
                    .font(.system(size: presentation == .sheet ? 12 : 12.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            if presentation == .settings {
                statusBadge(copy: copy, hasConflict: hasConflict)
            }

            Button {
                HotKeyCenter.resetDefaultShortcuts()
                refreshToken += 1
            } label: {
                Label(copy.resetShortcuts, systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help(copy.resetShortcuts)
        }
    }

    private func statusLine(copy: AppText, hasConflict: Bool) -> some View {
        Label(
            hasConflict ? copy.shortcutConflictDetected : copy.shortcutNoConflict,
            systemImage: hasConflict ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
        )
        .font(.system(size: 12.5, weight: .semibold))
        .foregroundStyle(hasConflict ? Color.orange : Color.green)
        .padding(.horizontal, presentation == .sheet ? 9 : 10)
        .padding(.vertical, presentation == .sheet ? 6 : 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            Capsule(style: .continuous)
                .fill((hasConflict ? Color.orange : Color.green).opacity(0.12))
        }
    }

    private func statusBadge(copy: AppText, hasConflict: Bool) -> some View {
        Label(
            hasConflict ? copy.shortcutConflictDetected : copy.shortcutNoConflict,
            systemImage: hasConflict ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
        )
        .labelStyle(.titleAndIcon)
        .font(.system(size: 11.5, weight: .semibold))
        .foregroundStyle(hasConflict ? Color.orange : Color.green)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background {
            Capsule(style: .continuous)
                .fill((hasConflict ? Color.orange : Color.green).opacity(0.13))
        }
    }

    private func conflictPanel(copy: AppText, conflicts: [ShortcutConflict]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(copy.shortcutConflictHint, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12.5, weight: .semibold))

            ForEach(conflicts) { conflict in
                Text(verbatim: copy.shortcutConflictLine(shortcut: conflict.shortcutText, actions: conflict.actionNames.joined(separator: conflictSeparator)))
                    .font(.system(size: 12.5, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(Color.orange)
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(0.12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.orange.opacity(0.22), lineWidth: 1)
                }
        }
    }

    private func shortcutRow(copy: AppText, row: ShortcutRowState, isConflicted: Bool) -> some View {
        HStack(spacing: presentation == .sheet ? 8 : 10) {
            Image(systemName: row.icon)
                .font(.system(size: presentation == .sheet ? 12.5 : 13.5, weight: .semibold))
                .foregroundStyle(isConflicted ? Color.orange : rowIconInkColor)
                .frame(width: presentation == .sheet ? 24 : 28, height: presentation == .sheet ? 24 : 28)
                .background {
                    Circle()
                        .fill((isConflicted ? Color.orange : settings.accentColor).opacity(0.14))
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(ShortcutLabelFormatter.cleanLabel(row.title))
                    .font(.system(size: presentation == .sheet ? 12.6 : 13.2, weight: row.isPrimary ? .semibold : .medium))
                    .foregroundStyle(Color.primary)

                Text(verbatim: "\(copy.shortcutDefaultPrefix) \(row.defaultShortcut)")
                    .font(.system(size: presentation == .sheet ? 10.8 : 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            KeyboardShortcuts.Recorder(for: row.name, onChange: { _ in
                refreshToken += 1
            })
            .frame(width: presentation == .sheet ? 108 : 122)
        }
        .padding(.horizontal, presentation == .sheet ? 8 : 10)
        .padding(.vertical, presentation == .sheet ? 7 : 8)
        .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(isConflicted ? Color.orange.opacity(0.11) : Color.white.opacity(0.12))
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(isConflicted ? Color.orange.opacity(0.34) : Color.white.opacity(0.24), lineWidth: 1)
                }
        }
    }

    private func shortcutRows(copy: AppText) -> [ShortcutRowState] {
        _ = refreshToken

        return [
            ShortcutRowState(
                id: "toggle",
                title: copy.toggleNoteShortcut,
                icon: "rectangle.on.rectangle",
                name: .toggleQuietNote,
                defaultShortcut: HotKeyCenter.toggleDefaultShortcut,
                shortcut: KeyboardShortcuts.getShortcut(for: .toggleQuietNote),
                isPrimary: true
            ),
            ShortcutRowState(
                id: "show",
                title: copy.showNoteShortcut,
                icon: "eye",
                name: .showQuietNote,
                defaultShortcut: HotKeyCenter.showOnlyDefaultShortcut,
                shortcut: KeyboardShortcuts.getShortcut(for: .showQuietNote),
                isPrimary: false
            ),
            ShortcutRowState(
                id: "hide",
                title: copy.hideNoteShortcut,
                icon: "eye.slash",
                name: .hideQuietNote,
                defaultShortcut: HotKeyCenter.hideDefaultShortcut,
                shortcut: KeyboardShortcuts.getShortcut(for: .hideQuietNote),
                isPrimary: false
            ),
            ShortcutRowState(
                id: "clipboard",
                title: copy.clipboardShortcut,
                icon: "clipboard",
                name: .toggleClipboardLibrary,
                defaultShortcut: HotKeyCenter.clipboardDefaultShortcut,
                shortcut: KeyboardShortcuts.getShortcut(for: .toggleClipboardLibrary),
                isPrimary: false
            )
        ]
    }

    private func displayShortcut(_ shortcut: KeyboardShortcuts.Shortcut?, copy: AppText) -> String {
        shortcut.map { "\($0)" } ?? copy.shortcutUnset
    }

    private var conflictSeparator: String {
        settings.language == .chinese ? "、" : ", "
    }
}
