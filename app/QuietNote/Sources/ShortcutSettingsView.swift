@preconcurrency import KeyboardShortcuts
import SwiftUI

struct ShortcutSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        ShortcutSettingsPanel(settings: settings, presentation: .sheet)
    }
}

struct ShortcutSettingsPanel: View {
    enum Presentation {
        case settings
        case sheet
    }

    @ObservedObject var settings: AppSettings
    let presentation: Presentation
    @State private var refreshToken = 0

    var body: some View {
        let copy = AppText(language: settings.language)
        let rows = shortcutRows(copy: copy)
        let conflicts = conflicts(in: rows)
        let conflictedShortcuts = Set(conflicts.map(\.shortcut))

        VStack(alignment: .leading, spacing: presentation == .sheet ? 16 : 13) {
            header(copy: copy, primaryShortcut: rows.first?.shortcut, hasConflict: !conflicts.isEmpty)

            if conflicts.isEmpty {
                statusLine(copy: copy, hasConflict: false)
            } else {
                conflictPanel(copy: copy, conflicts: conflicts)
            }

            VStack(spacing: 8) {
                ForEach(rows) { row in
                    shortcutRow(
                        copy: copy,
                        row: row,
                        isConflicted: row.shortcut.map { conflictedShortcuts.contains($0) } ?? false
                    )
                }
            }

            Text(copy.keyboardShortcutNote)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(presentation == .sheet ? 18 : 12)
        .background {
            RoundedRectangle(cornerRadius: presentation == .sheet ? 18 : 12, style: .continuous)
                .fill(Color.white.opacity(presentation == .sheet ? 0.16 : 0.10))
                .overlay {
                    RoundedRectangle(cornerRadius: presentation == .sheet ? 18 : 12, style: .continuous)
                        .stroke(Color.white.opacity(0.34), lineWidth: 1)
                }
        }
    }

    private func header(copy: AppText, primaryShortcut: KeyboardShortcuts.Shortcut?, hasConflict: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "keyboard.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.82))
                .frame(width: 44, height: 44)
                .background {
                    Circle()
                        .fill(Color.cyan.opacity(0.22))
                        .overlay(Circle().stroke(Color.white.opacity(0.52), lineWidth: 1))
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(copy.globalShortcuts)
                    .font(.system(size: presentation == .sheet ? 18 : 15, weight: .semibold))

                Text(verbatim: "\(displayShortcut(primaryShortcut, copy: copy)) · \(cleanLabel(copy.toggleNoteShortcut))")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            statusBadge(copy: copy, hasConflict: hasConflict)

            Button {
                HotKeyCenter.resetDefaultShortcuts()
                refreshToken += 1
            } label: {
                Label(copy.resetShortcuts, systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func statusLine(copy: AppText, hasConflict: Bool) -> some View {
        Label(
            hasConflict ? copy.shortcutConflictDetected : copy.shortcutNoConflict,
            systemImage: hasConflict ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
        )
        .font(.system(size: 12.5, weight: .semibold))
        .foregroundStyle(hasConflict ? Color.orange : Color.green)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
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
        HStack(spacing: 10) {
            Image(systemName: row.icon)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(isConflicted ? Color.orange : Color.black.opacity(0.76))
                .frame(width: 28, height: 28)
                .background {
                    Circle()
                        .fill((isConflicted ? Color.orange : Color.cyan).opacity(0.14))
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(cleanLabel(row.title))
                    .font(.system(size: 13.2, weight: row.isPrimary ? .semibold : .medium))
                    .foregroundStyle(Color.primary)

                Text(verbatim: "\(copy.shortcutDefaultPrefix) \(row.defaultShortcut)")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            KeyboardShortcuts.Recorder(for: row.name, onChange: { _ in
                refreshToken += 1
            })
            .frame(width: 122)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
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

    private func conflicts(in rows: [ShortcutRowState]) -> [ShortcutConflict] {
        var buckets: [KeyboardShortcuts.Shortcut: [ShortcutRowState]] = [:]
        for row in rows {
            guard let shortcut = row.shortcut else { continue }
            buckets[shortcut, default: []].append(row)
        }

        return buckets
            .filter { $0.value.count > 1 }
            .map { shortcut, rows in
                ShortcutConflict(
                    shortcut: shortcut,
                    shortcutText: "\(shortcut)",
                    actionNames: rows.map { cleanLabel($0.title) }
                )
            }
            .sorted { $0.shortcutText < $1.shortcutText }
    }

    private func displayShortcut(_ shortcut: KeyboardShortcuts.Shortcut?, copy: AppText) -> String {
        shortcut.map { "\($0)" } ?? copy.shortcutUnset
    }

    private func cleanLabel(_ title: String) -> String {
        title.trimmingCharacters(in: CharacterSet(charactersIn: "：: "))
    }

    private var conflictSeparator: String {
        settings.language == .chinese ? "、" : ", "
    }
}

private struct ShortcutRowState: Identifiable {
    let id: String
    let title: String
    let icon: String
    let name: KeyboardShortcuts.Name
    let defaultShortcut: KeyboardShortcuts.Shortcut
    let shortcut: KeyboardShortcuts.Shortcut?
    let isPrimary: Bool
}

private struct ShortcutConflict: Identifiable {
    let shortcut: KeyboardShortcuts.Shortcut
    let shortcutText: String
    let actionNames: [String]

    var id: String {
        shortcutText
    }
}
