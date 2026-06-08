import Combine
import Foundation

@MainActor
final class NoteStore: ObservableObject {
    @Published var markdown: String {
        didSet { scheduleSave() }
    }

    @Published private(set) var lastSavedText = "Saved"

    private let fileURL: URL
    private var saveTask: Task<Void, Never>?

    var displayTitle: String {
        let lines = markdown.split(whereSeparator: \.isNewline)
        if let heading = lines.first(where: { line in
            line.trimmingCharacters(in: .whitespaces).hasPrefix("#")
        }) {
            let title = heading
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "# "))
            if !title.isEmpty {
                return title
            }
        }

        return fileURL.lastPathComponent
    }

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "QuietNote", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        fileURL = support.appending(path: "note.md")

        if let data = try? Data(contentsOf: fileURL),
           let text = String(data: data, encoding: .utf8),
           !text.isEmpty {
            markdown = text
        } else {
            markdown = """
            # Today

            - [ ] Write implementation plan
            - [ ] Test keyboard shortcut
            - [ ] Ship the build

            > Quiet is productive.

            Reference: [Apple HIG](https://developer.apple.com/design/human-interface-guidelines/)

            Quick snippet: `cmd + shift + n`
            """
        }
    }

    func saveNow() {
        do {
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
            lastSavedText = "Saved just now"
        } catch {
            lastSavedText = "Save failed"
        }
    }

    private func scheduleSave() {
        lastSavedText = "Saving..."
        saveTask?.cancel()
        let text = markdown
        let url = fileURL
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            do {
                try text.write(to: url, atomically: true, encoding: .utf8)
                await MainActor.run { self?.lastSavedText = "Saved just now" }
            } catch {
                await MainActor.run { self?.lastSavedText = "Save failed" }
            }
        }
    }
}
