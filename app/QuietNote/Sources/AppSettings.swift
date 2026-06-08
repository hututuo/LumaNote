import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case chinese = "zh"
    case english = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chinese: "中文"
        case .english: "English"
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    nonisolated static let minimumNoteOpacity = 0.01
    nonisolated static let defaultNoteOpacity = 0.60
    nonisolated static let defaultGlassStrength = 0.10

    @Published var noteOpacity: Double {
        didSet {
            if noteOpacity < Self.minimumNoteOpacity {
                noteOpacity = Self.minimumNoteOpacity
            }
            defaults.set(noteOpacity, forKey: Keys.noteOpacity)
        }
    }

    @Published var glassStrength: Double {
        didSet { defaults.set(glassStrength, forKey: Keys.glassStrength) }
    }

    @Published var alwaysOnTop: Bool {
        didSet { defaults.set(alwaysOnTop, forKey: Keys.alwaysOnTop) }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            guard !isSyncingLaunchAtLogin, launchAtLogin != oldValue else { return }
            applyLaunchAtLogin(launchAtLogin, fallback: oldValue)
        }
    }

    @Published private(set) var launchAtLoginError: String?

    @Published var monitorClipboard: Bool {
        didSet { defaults.set(monitorClipboard, forKey: Keys.monitorClipboard) }
    }

    @Published var clipboardLimit: Int {
        didSet { defaults.set(clipboardLimit, forKey: Keys.clipboardLimit) }
    }

    @Published var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: Keys.language) }
    }

    private let defaults = UserDefaults.standard
    private var isSyncingLaunchAtLogin = false

    init() {
        noteOpacity = max(Self.minimumNoteOpacity, defaults.object(forKey: Keys.noteOpacity) as? Double ?? Self.defaultNoteOpacity)
        glassStrength = defaults.object(forKey: Keys.glassStrength) as? Double ?? Self.defaultGlassStrength
        alwaysOnTop = defaults.object(forKey: Keys.alwaysOnTop) as? Bool ?? true
        launchAtLogin = LaunchAtLoginController.isEnabled
        launchAtLoginError = nil
        monitorClipboard = defaults.object(forKey: Keys.monitorClipboard) as? Bool ?? true
        clipboardLimit = defaults.object(forKey: Keys.clipboardLimit) as? Int ?? 200
        language = AppLanguage(rawValue: defaults.string(forKey: Keys.language) ?? "") ?? .chinese
    }

    func refreshLaunchAtLoginStatus() {
        isSyncingLaunchAtLogin = true
        launchAtLogin = LaunchAtLoginController.isEnabled
        isSyncingLaunchAtLogin = false
    }

    private func applyLaunchAtLogin(_ enabled: Bool, fallback: Bool) {
        switch LaunchAtLoginController.setEnabled(enabled) {
        case .success:
            launchAtLoginError = nil
        case .failure(let error):
            isSyncingLaunchAtLogin = true
            launchAtLogin = fallback
            isSyncingLaunchAtLogin = false
            launchAtLoginError = error.localizedDescription
        }
    }

    private enum Keys {
        static let noteOpacity = "noteOpacity"
        static let glassStrength = "glassStrength"
        static let alwaysOnTop = "alwaysOnTop"
        static let monitorClipboard = "monitorClipboard"
        static let clipboardLimit = "clipboardLimit"
        static let language = "language"
    }
}
