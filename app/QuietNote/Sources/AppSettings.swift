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

enum AppThemeColor: String, CaseIterable, Identifiable {
    case aqua
    case sky
    case mint
    case violet
    case rose
    case amber

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .aqua: Color(red: 0.10, green: 0.72, blue: 0.86)
        case .sky: Color(red: 0.28, green: 0.50, blue: 1.00)
        case .mint: Color(red: 0.10, green: 0.72, blue: 0.48)
        case .violet: Color(red: 0.58, green: 0.42, blue: 0.95)
        case .rose: Color(red: 0.95, green: 0.34, blue: 0.58)
        case .amber: Color(red: 0.98, green: 0.58, blue: 0.16)
        }
    }

    func displayName(language: AppLanguage) -> String {
        switch (language, self) {
        case (.chinese, .aqua): "水色"
        case (.chinese, .sky): "蓝色"
        case (.chinese, .mint): "薄荷"
        case (.chinese, .violet): "紫色"
        case (.chinese, .rose): "玫瑰"
        case (.chinese, .amber): "琥珀"
        case (.english, .aqua): "Aqua"
        case (.english, .sky): "Sky"
        case (.english, .mint): "Mint"
        case (.english, .violet): "Violet"
        case (.english, .rose): "Rose"
        case (.english, .amber): "Amber"
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    nonisolated static let minimumNoteOpacity = 0.01
    nonisolated static let defaultNoteOpacity = 0.60
    nonisolated static let defaultGlassStrength = 0.10
    nonisolated static let minimumEditorFontSize = 11.0
    nonisolated static let maximumEditorFontSize = 28.0
    nonisolated static let defaultEditorFontSize = 15.5

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

    @Published var themeColor: AppThemeColor {
        didSet { defaults.set(themeColor.rawValue, forKey: Keys.themeColor) }
    }

    @Published var editorFontSize: Double {
        didSet {
            if editorFontSize < Self.minimumEditorFontSize {
                editorFontSize = Self.minimumEditorFontSize
            } else if editorFontSize > Self.maximumEditorFontSize {
                editorFontSize = Self.maximumEditorFontSize
            }
            defaults.set(editorFontSize, forKey: Keys.editorFontSize)
        }
    }

    @Published var alwaysOnTop: Bool {
        didSet { defaults.set(alwaysOnTop, forKey: Keys.alwaysOnTop) }
    }

    @Published var autoHideChrome: Bool {
        didSet { defaults.set(autoHideChrome, forKey: Keys.autoHideChrome) }
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

    var accentColor: Color {
        themeColor.color
    }

    init() {
        noteOpacity = max(Self.minimumNoteOpacity, defaults.object(forKey: Keys.noteOpacity) as? Double ?? Self.defaultNoteOpacity)
        glassStrength = defaults.object(forKey: Keys.glassStrength) as? Double ?? Self.defaultGlassStrength
        themeColor = AppThemeColor(rawValue: defaults.string(forKey: Keys.themeColor) ?? "") ?? .aqua
        let storedFontSize = defaults.object(forKey: Keys.editorFontSize) as? Double ?? Self.defaultEditorFontSize
        editorFontSize = min(max(storedFontSize, Self.minimumEditorFontSize), Self.maximumEditorFontSize)
        alwaysOnTop = defaults.object(forKey: Keys.alwaysOnTop) as? Bool ?? true
        autoHideChrome = defaults.object(forKey: Keys.autoHideChrome) as? Bool ?? true
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
        static let themeColor = "themeColor"
        static let editorFontSize = "editorFontSize"
        static let alwaysOnTop = "alwaysOnTop"
        static let autoHideChrome = "autoHideChrome"
        static let monitorClipboard = "monitorClipboard"
        static let clipboardLimit = "clipboardLimit"
        static let language = "language"
    }
}
