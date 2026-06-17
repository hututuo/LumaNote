enum NoteWindowTransientOverlay: Equatable {
    case clipboard
    case more
    case fileSwitcher
    case extractionActions
    case shortcutSettings

    var isInlinePanel: Bool {
        self != .shortcutSettings
    }

    var keepsBottomChromeExpanded: Bool {
        switch self {
        case .clipboard, .more, .fileSwitcher, .shortcutSettings:
            true
        case .extractionActions:
            false
        }
    }

    var hidesDetectedClipboardItem: Bool {
        switch self {
        case .clipboard, .more, .fileSwitcher, .shortcutSettings:
            true
        case .extractionActions:
            false
        }
    }
}
