import Foundation

enum NoteStoreDefaultsKey {
    static let currentFilePath = "currentFilePath"
    static let recentFilePaths = "recentFilePaths"
    static let workspaces = "noteWorkspaces.v1"
    static let activeWorkspaceID = "activeNoteWorkspaceID.v1"
}

enum NoteWorkspaceSupport {
    static let defaultWorkspaceName = "默认工作区"
    static let maximumWorkspaceDocuments = 24

    static func loadRecentFileURLs(from defaults: UserDefaults) -> [URL] {
        let paths = defaults.stringArray(forKey: NoteStoreDefaultsKey.recentFilePaths) ?? []
        var seen: Set<String> = []
        return paths.compactMap { path in
            guard !path.isEmpty, FileManager.default.fileExists(atPath: path), seen.insert(path).inserted else {
                return nil
            }
            return URL(fileURLWithPath: path).standardizedFileURL
        }
    }

    static func loadWorkspaces(from defaults: UserDefaults) -> [NoteWorkspace] {
        guard let data = defaults.data(forKey: NoteStoreDefaultsKey.workspaces),
              let workspaces = try? JSONDecoder().decode([NoteWorkspace].self, from: data)
        else { return [] }
        return normalizedWorkspaces(workspaces)
    }

    static func loadActiveWorkspaceID(from defaults: UserDefaults, workspaces: [NoteWorkspace]) -> UUID {
        if let rawID = defaults.string(forKey: NoteStoreDefaultsKey.activeWorkspaceID),
           let id = UUID(uuidString: rawID),
           workspaces.contains(where: { $0.id == id }) {
            return id
        }
        return workspaces.first?.id ?? UUID()
    }

    static func makeDefaultWorkspace(currentFileURL: URL, recentFileURLs: [URL]) -> NoteWorkspace {
        let paths = uniquePaths([currentFileURL] + recentFileURLs)
        return NoteWorkspace(
            name: defaultWorkspaceName,
            filePaths: paths,
            currentFilePath: currentFileURL.standardizedFileURL.path
        )
    }

    static func normalizedWorkspaces(_ workspaces: [NoteWorkspace]) -> [NoteWorkspace] {
        workspaces.map { workspace in
            var copy = workspace
            copy.name = copy.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if copy.name.isEmpty {
                copy.name = defaultWorkspaceName
            }
            copy.filePaths = Array(uniquePaths(copy.filePaths.map { URL(fileURLWithPath: $0) }).prefix(maximumWorkspaceDocuments))
            if let currentFilePath = copy.currentFilePath,
               !copy.filePaths.contains(currentFilePath) {
                copy.currentFilePath = copy.filePaths.first
            }
            return copy
        }
    }

    private static func uniquePaths(_ urls: [URL]) -> [String] {
        var seen: Set<String> = []
        return urls.compactMap { url in
            let path = url.standardizedFileURL.path
            guard !path.isEmpty, seen.insert(path).inserted else { return nil }
            return path
        }
    }
}
