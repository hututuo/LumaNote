enum NoteWindowTransientOverlay: Equatable {
    case clipboard
    case more
    case fileSwitcher
    case emphasis
    case extractionActions
    case shortcutSettings

    var isInlinePanel: Bool {
        self != .shortcutSettings
    }

    var keepsBottomChromeExpanded: Bool {
        switch self {
        case .clipboard, .more, .fileSwitcher, .emphasis, .shortcutSettings:
            true
        case .extractionActions:
            false
        }
    }

    var hidesDetectedClipboardItem: Bool {
        switch self {
        case .clipboard, .more, .fileSwitcher, .emphasis, .shortcutSettings:
            true
        case .extractionActions:
            false
        }
    }
}
