import Foundation
import SwiftUI

struct FileSwitcherView: View {
    @Environment(\.colorScheme) private var colorScheme
    var settings: AppSettings
    @Bindable var noteStore: NoteStore

    let createMarkdownFile: () -> Void
    let openExistingFile: () -> Void
    let createWorkspace: () -> Void
    let switchWorkspace: (NoteWorkspace.ID) -> Void
    let openWorkspaceFile: (URL) -> Void
    let removeWorkspaceFile: (URL) -> Void

    private var copy: AppText {
        settings.localizedText
    }

    private var controlInkColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.90 : 0.84)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            workspacePicker

            fileActionButton(symbol: "doc.badge.plus", title: copy.createMarkdownFile, action: createMarkdownFile)
                .background(settings.accentColor.opacity(0.065), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .help(copy.createMarkdownFile)

            fileActionButton(symbol: "folder", title: copy.openExistingFile, action: openExistingFile)
                .background(.white.opacity(0.08 + settings.noteOpacity * 0.06), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .help(copy.openExistingFile)

            Rectangle()
                .fill(.white.opacity(0.16 + settings.noteOpacity * 0.16))
                .frame(height: 1)
                .padding(.horizontal, 2)

            if noteStore.activeWorkspaceFileURLs.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 11, weight: .semibold))
                    Text(copy.noWorkspaceDocuments)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .frame(height: 36)
            } else {
                HStack(spacing: 6) {
                    Text(copy.workspaceDocuments)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 0)

                    Text(copy.workspaceDocumentCount(noteStore.activeWorkspaceFileURLs.count))
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.top, 1)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 3) {
                        ForEach(noteStore.activeWorkspaceFileURLs, id: \.self) { url in
                            workspaceFileRow(url)
                        }
                    }
                }
            }
        }
        .padding(9)
    }

    private func fileActionButton(symbol: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: 12, weight: .semibold))

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var workspacePicker: some View {
        Menu {
            ForEach(noteStore.workspaces) { workspace in
                Button {
                    switchWorkspace(workspace.id)
                } label: {
                    Label(
                        workspace.name,
                        systemImage: workspace.id == noteStore.activeWorkspaceID ? "checkmark.circle.fill" : "rectangle.stack"
                    )
                }
            }
            Divider()
            Button(action: createWorkspace) {
                Label(copy.newWorkspace, systemImage: "plus")
            }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "rectangle.3.group")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(settings.accentColor)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(copy.workspace)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(.secondary)

                    Text(noteStore.activeWorkspaceName)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(controlInkColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(
            settings.accentColor.opacity(0.07),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .help(copy.switchWorkspace)
    }

    private func workspaceFileRow(_ url: URL) -> some View {
        HStack(spacing: 4) {
            Button {
                openWorkspaceFile(url)
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: isCurrent(url) ? "checkmark.circle.fill" : "doc.text")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isCurrent(url) ? settings.accentColor : .secondary)
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(url.lastPathComponent)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(controlInkColor)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Text(shortPath(for: url))
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 8)
                .frame(height: 39)
                .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
            .background(
                isCurrent(url) ? settings.accentColor.opacity(0.08) : Color.white.opacity(0.04),
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .help(copy.switchToFile(url.lastPathComponent))

            if !isCurrent(url) {
                Button {
                    removeWorkspaceFile(url)
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 20, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(copy.removeFromWorkspace)
            }
        }
    }

    private func isCurrent(_ url: URL) -> Bool {
        noteStore.currentFileURL.standardizedFileURL.path == url.standardizedFileURL.path
    }

    private func shortPath(for url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = url.deletingLastPathComponent().path
        if path == home {
            return "~"
        }
        if path.hasPrefix(home + "/") {
            return "~/" + String(path.dropFirst(home.count + 1))
        }
        return path
    }
}
