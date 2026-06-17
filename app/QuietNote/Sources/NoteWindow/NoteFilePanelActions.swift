import AppKit
import UniformTypeIdentifiers

@MainActor
enum NoteFilePanelActions {
    static func openNoteFile(noteStore: NoteStore) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = markdownContentTypes
        panel.directoryURL = noteStore.currentFileURL.deletingLastPathComponent()

        if panel.runModal() == .OK, let url = panel.url {
            noteStore.openFile(at: url)
        }
    }

    static func createMarkdownFile(noteStore: NoteStore, copy: AppText) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = markdownContentTypes
        panel.directoryURL = noteStore.currentFileURL.deletingLastPathComponent()
        panel.nameFieldStringValue = copy.defaultMarkdownFileName
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            noteStore.createMarkdownFile(at: url)
        }
    }

    static func saveNoteFileAs(noteStore: NoteStore) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = markdownContentTypes
        panel.directoryURL = noteStore.currentFileURL.deletingLastPathComponent()
        panel.nameFieldStringValue = noteStore.currentFileName

        if panel.runModal() == .OK, let url = panel.url {
            noteStore.saveAs(to: url)
        }
    }

    static func createWorkspace(noteStore: NoteStore, copy: AppText) {
        let alert = NSAlert()
        alert.messageText = copy.newWorkspace
        alert.informativeText = copy.newWorkspacePrompt
        alert.alertStyle = .informational
        alert.addButton(withTitle: copy.newWorkspace)
        alert.addButton(withTitle: copy.close)

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        textField.stringValue = copy.workspaceDefaultName(noteStore.workspaces.count + 1)
        alert.accessoryView = textField

        if alert.runModal() == .alertFirstButtonReturn {
            noteStore.createWorkspace(named: textField.stringValue)
        }
    }

    private static var markdownContentTypes: [UTType] {
        [
            UTType(filenameExtension: "md"),
            UTType(filenameExtension: "markdown"),
            .plainText,
            .text
        ].compactMap { $0 }
    }
}
