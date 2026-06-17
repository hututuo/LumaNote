import AppKit
import Foundation
import Observation
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

enum AppAppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }

    func displayName(language: AppLanguage) -> String {
        switch (language, self) {
        case (.chinese, .system): "跟随系统"
        case (.chinese, .light): "亮色"
        case (.chinese, .dark): "暗色"
        case (.english, .system): "System"
        case (.english, .light): "Light"
        case (.english, .dark): "Dark"
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

    var nsColor: NSColor {
        switch self {
        case .aqua: NSColor(calibratedRed: 0.10, green: 0.72, blue: 0.86, alpha: 1)
        case .sky: NSColor(calibratedRed: 0.28, green: 0.50, blue: 1.00, alpha: 1)
        case .mint: NSColor(calibratedRed: 0.10, green: 0.72, blue: 0.48, alpha: 1)
        case .violet: NSColor(calibratedRed: 0.58, green: 0.42, blue: 0.95, alpha: 1)
        case .rose: NSColor(calibratedRed: 0.95, green: 0.34, blue: 0.58, alpha: 1)
        case .amber: NSColor(calibratedRed: 0.98, green: 0.58, blue: 0.16, alpha: 1)
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
@Observable
final class AppSettings {
    nonisolated static let minimumNoteOpacity = 0.01
    nonisolated static let maximumNoteOpacity = 1.0
    nonisolated static let defaultNoteOpacity = 0.60
    nonisolated static let minimumGlassStrength = 0.0
    nonisolated static let maximumGlassStrength = 1.0
    nonisolated static let defaultGlassStrength = 0.20
    nonisolated static let minimumEditorFontSize = 11.0
    nonisolated static let maximumEditorFontSize = 28.0
    nonisolated static let defaultEditorFontSize = 15.5
    nonisolated static let minimumClipboardLimit = 25
    nonisolated static let maximumClipboardLimit = 1000
    nonisolated static let defaultClipboardLimit = 200

    var noteOpacity: Double {
        didSet {
            let normalizedOpacity = Self.normalizedNoteOpacity(noteOpacity)
            if noteOpacity != normalizedOpacity {
                noteOpacity = normalizedOpacity
            }
            defaults.set(noteOpacity, forKey: Keys.noteOpacity)
        }
    }

    var glassStrength: Double {
        didSet {
            let normalizedStrength = Self.normalizedGlassStrength(glassStrength)
            if glassStrength != normalizedStrength {
                glassStrength = normalizedStrength
            }
            defaults.set(glassStrength, forKey: Keys.glassStrength)
        }
    }

    var themeColor: AppThemeColor {
        didSet { defaults.set(themeColor.rawValue, forKey: Keys.themeColor) }
    }

    var appearanceMode: AppAppearanceMode {
        didSet {
            defaults.set(appearanceMode.rawValue, forKey: Keys.appearanceMode)
            refreshResolvedColorScheme()
            applyAppearanceMode()
            appearanceModeDidChange?(appearanceMode)
        }
    }

    private(set) var resolvedColorScheme: ColorScheme?

    var editorFontSize: Double {
        didSet {
            let normalizedSize = Self.normalizedEditorFontSize(editorFontSize)
            if editorFontSize != normalizedSize {
                editorFontSize = normalizedSize
            }
            defaults.set(editorFontSize, forKey: Keys.editorFontSize)
        }
    }

    var alwaysOnTop: Bool {
        didSet {
            defaults.set(alwaysOnTop, forKey: Keys.alwaysOnTop)
            alwaysOnTopDidChange?(alwaysOnTop)
        }
    }

    var autoHideChrome: Bool {
        didSet { defaults.set(autoHideChrome, forKey: Keys.autoHideChrome) }
    }

    private(set) var launchAtLoginError: String?
    private var launchAtLoginRefreshToken = 0

    var monitorClipboard: Bool {
        didSet {
            defaults.set(monitorClipboard, forKey: Keys.monitorClipboard)
            monitorClipboardDidChange?(monitorClipboard)
        }
    }

    var clipboardLimit: Int {
        didSet {
            let normalizedLimit = Self.normalizedClipboardLimit(clipboardLimit)
            if clipboardLimit != normalizedLimit {
                clipboardLimit = normalizedLimit
            }
            defaults.set(clipboardLimit, forKey: Keys.clipboardLimit)
            clipboardLimitDidChange?(clipboardLimit)
        }
    }

    var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: Keys.language) }
    }

    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }

    @ObservationIgnored var alwaysOnTopDidChange: ((Bool) -> Void)?
    @ObservationIgnored var appearanceModeDidChange: ((AppAppearanceMode) -> Void)?
    @ObservationIgnored var monitorClipboardDidChange: ((Bool) -> Void)?
    @ObservationIgnored var clipboardLimitDidChange: ((Int) -> Void)?

    private let defaults = UserDefaults.standard
    var accentColor: Color {
        themeColor.color
    }

    var accentNSColor: NSColor {
        themeColor.nsColor
    }

    var localizedText: AppText {
        AppText(language: language)
    }

    var launchAtLogin: Bool {
        _ = launchAtLoginRefreshToken
        return LaunchAtLoginController.isEnabled
    }

    var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { self.launchAtLogin },
            set: { self.setLaunchAtLogin($0) }
        )
    }

    init() {
        noteOpacity = Self.normalizedNoteOpacity(defaults.object(forKey: Keys.noteOpacity) as? Double ?? Self.defaultNoteOpacity)
        glassStrength = Self.normalizedGlassStrength(defaults.object(forKey: Keys.glassStrength) as? Double ?? Self.defaultGlassStrength)
        themeColor = AppThemeColor(rawValue: defaults.string(forKey: Keys.themeColor) ?? "") ?? .aqua
        let storedAppearanceMode = AppAppearanceMode(rawValue: defaults.string(forKey: Keys.appearanceMode) ?? "") ?? .system
        appearanceMode = storedAppearanceMode
        resolvedColorScheme = Self.resolvedColorScheme(for: storedAppearanceMode)
        editorFontSize = Self.normalizedEditorFontSize(defaults.object(forKey: Keys.editorFontSize) as? Double ?? Self.defaultEditorFontSize)
        alwaysOnTop = defaults.object(forKey: Keys.alwaysOnTop) as? Bool ?? true
        autoHideChrome = defaults.object(forKey: Keys.autoHideChrome) as? Bool ?? true
        launchAtLoginError = nil
        monitorClipboard = defaults.object(forKey: Keys.monitorClipboard) as? Bool ?? true
        clipboardLimit = Self.normalizedClipboardLimit(defaults.object(forKey: Keys.clipboardLimit) as? Int ?? Self.defaultClipboardLimit)
        language = AppLanguage(rawValue: defaults.string(forKey: Keys.language) ?? "") ?? .chinese
        hasCompletedOnboarding = defaults.object(forKey: Keys.hasCompletedOnboarding) as? Bool ?? false
        applyAppearanceMode()
        observeSystemAppearanceChanges()
    }

    func refreshLaunchAtLoginStatus() {
        launchAtLoginRefreshToken &+= 1
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        switch LaunchAtLoginController.setEnabled(enabled) {
        case .success:
            launchAtLoginError = nil
            launchAtLoginRefreshToken &+= 1
        case .failure(let error):
            launchAtLoginError = error.localizedDescription
            launchAtLoginRefreshToken &+= 1
        }
    }

    private func applyAppearanceMode() {
        NSApp.appearance = appearanceMode.nsAppearance
        NSApp.windows.forEach { window in
            window.appearance = appearanceMode.nsAppearance
            window.contentView?.appearance = appearanceMode.nsAppearance
            window.contentView?.needsLayout = true
            window.contentView?.needsDisplay = true
        }
    }

    private func observeSystemAppearanceChanges() {
        _ = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.appearanceMode == .system else { return }
                self.refreshResolvedColorScheme()
                self.applyAppearanceMode()
            }
        }
    }

    private func refreshResolvedColorScheme() {
        resolvedColorScheme = Self.resolvedColorScheme(for: appearanceMode)
    }

    private static func resolvedColorScheme(for mode: AppAppearanceMode) -> ColorScheme? {
        switch mode {
        case .system: currentSystemColorScheme
        case .light: .light
        case .dark: .dark
        }
    }

    private static var currentSystemColorScheme: ColorScheme {
        UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark" ? .dark : .light
    }

    nonisolated static func normalizedClipboardLimit(_ limit: Int) -> Int {
        min(max(limit, minimumClipboardLimit), maximumClipboardLimit)
    }

    nonisolated static func normalizedNoteOpacity(_ opacity: Double) -> Double {
        guard !opacity.isNaN else { return defaultNoteOpacity }
        return min(max(opacity, minimumNoteOpacity), maximumNoteOpacity)
    }

    nonisolated static func normalizedGlassStrength(_ strength: Double) -> Double {
        guard !strength.isNaN else { return defaultGlassStrength }
        return min(max(strength, minimumGlassStrength), maximumGlassStrength)
    }

    nonisolated static func normalizedEditorFontSize(_ fontSize: Double) -> Double {
        guard !fontSize.isNaN else { return defaultEditorFontSize }
        return min(max(fontSize, minimumEditorFontSize), maximumEditorFontSize)
    }

    private enum Keys {
        static let noteOpacity = "noteOpacity"
        static let glassStrength = "glassStrength"
        static let themeColor = "themeColor"
        static let appearanceMode = "appearanceMode"
        static let editorFontSize = "editorFontSize"
        static let alwaysOnTop = "alwaysOnTop"
        static let autoHideChrome = "autoHideChrome"
        static let monitorClipboard = "monitorClipboard"
        static let clipboardLimit = "clipboardLimit"
        static let language = "language"
        static let hasCompletedOnboarding = "hasCompletedOnboarding.v1"
    }
}
