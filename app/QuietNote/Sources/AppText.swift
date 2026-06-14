import Foundation

struct AppText {
    let language: AppLanguage

    var note: String { text("便签", "Note") }
    var opacity: String { text("便签透明度", "Note opacity") }
    var opacityHint: String { text("控制便签玻璃外壳有多明显。", "Controls how visible the note's glass shell is.") }
    var editorFontSize: String { text("字体大小", "Font size") }
    var editorFontSizeHint: String { text("控制正文 Markdown 的显示字号。", "Controls the Markdown editor text size.") }
    var glass: String { text("磨砂强度", "Frosted glass") }
    var glassHint: String { text("控制背景模糊、泛白和玻璃质感。", "Controls blur, haze, and the frosted glass feel.") }
    var themeColor: String { text("主题色", "Theme color") }
    var themeColorHint: String { text("控制按钮、滑杆和剪切板提取气泡的强调色。", "Controls the accent color for buttons, sliders, and extracted clipboard bubbles.") }
    var alwaysOnTop: String { text("保持置顶", "Always on top") }
    var disableAlwaysOnTop: String { text("取消置顶", "Disable always on top") }
    var autoHideControls: String { text("自动隐藏控件", "Auto-hide controls") }
    var keepControlsVisible: String { text("固定显示控件", "Keep controls visible") }
    var showControls: String { text("显示控件", "Show controls") }
    var dragNote: String { text("拖动便签", "Drag note") }
    var more: String { text("更多设置", "More settings") }
    var close: String { text("关闭", "Close") }
    var delete: String { text("删除", "Delete") }
    var openClipboardLibrary: String { text("打开剪切板库", "Open clipboard library") }
    var clipboardActions: String { text("剪切板识别动作", "Clipboard detection actions") }
    var shortcuts: String { text("快捷键", "Shortcuts") }
    var globalShortcuts: String { text("全局快捷键", "Global shortcuts") }
    var toggleNoteShortcut: String { text("呼出/隐藏便签：", "Show/hide note:") }
    var showNoteShortcut: String { text("只呼出便签：", "Show only:") }
    var hideNoteShortcut: String { text("只隐藏便签：", "Hide only:") }
    var clipboardShortcut: String { text("打开剪切板库：", "Open clipboard library:") }
    var languageLabel: String { text("语言", "Language") }
    var clipboard: String { text("剪切板", "Clipboard") }
    var monitorClipboard: String { text("本地监听剪切板", "Monitor clipboard locally") }
    var monitorLocally: String { text("本地监听", "Monitor locally") }
    var clear: String { text("清空", "Clear") }
    var clearClipboard: String { text("清空剪切板库", "Clear clipboard library") }
    var keyboardShortcutNote: String { text("快捷键保存在本机；系统或菜单冲突会在录入时提醒。", "Shortcuts are stored locally; system or menu conflicts are shown while recording.") }
    var resetShortcuts: String { text("恢复默认", "Reset Defaults") }
    var shortcutNoConflict: String { text("无冲突", "No conflicts") }
    var shortcutConflictDetected: String { text("发现冲突", "Conflict found") }
    var shortcutEntrySubtitle: String { text("冲突检测 / 恢复默认", "Conflict check / reset") }
    var shortcutDefaultPrefix: String { text("默认", "Default") }
    var shortcutUnset: String { text("未设置", "Not set") }
    var shortcutConflictHint: String { text("下面这些动作使用了同一个快捷键：", "These actions use the same shortcut:") }
    var appearance: String { text("外观", "Appearance") }
    var glassHintCompact: String { text("模糊 / 泛白 / 质感", "Blur / haze / texture") }
    var hideNote: String { text("隐藏便签", "Hide Note") }
    var launchAtLogin: String { text("开机自启", "Launch at login") }
    var launchAtLoginHint: String { text("使用 macOS 登录项服务；可能需要系统确认。", "Uses macOS Login Items; macOS may ask for confirmation.") }
    var launchAtLoginFailed: String { text("开机自启设置失败：", "Launch at login failed:") }
    var checkForUpdates: String { text("检查更新", "Check for updates") }
    var automaticallyCheckForUpdates: String { text("自动检查更新", "Check automatically") }
    var checkForUpdatesHint: String {
        text(
            "开启后会按系统更新周期自动检查；按钮可立即检查。",
            "When enabled, Sparkle checks on its schedule; the button checks now."
        )
    }
    var extracted: String { text("已提取", "Extracted") }
    var extractedClipboardPrefix: String { text("已提取：", "Extracted: ") }
    var detectedClipboardPrefix: String { text("提取到：", "Detected: ") }
    var listSeparator: String { text("、", ", ") }
    var copy: String { text("复制", "Copy") }
    var copyClipboardItem: String { text("复制这条剪切板记录", "Copy this clipboard item") }
    var deleteClipboardItem: String { text("删除这条剪切板记录", "Delete this clipboard item") }
    var openNoteFile: String { text("打开 Markdown 文件", "Open Markdown file") }
    var switchNoteFile: String { text("切换便签文件", "Switch note file") }
    var openNewFile: String { text("打开新文件", "Open new file") }
    var recentFiles: String { text("最近打开", "Recent files") }
    var noRecentFiles: String { text("没有最近文件", "No recent files") }
    var saveAsNoteFile: String { text("另存为 Markdown 文件", "Save as Markdown file") }
    var copyExtracted: String { text("复制提取内容", "Copy Extracted") }
    var showExtractedActions: String { text("显示提取内容动作", "Show extracted actions") }
    var noClipboardItems: String { text("没有剪切板记录", "No clipboard items") }
    var noClipboardDescription: String { text("在任意地方复制文本，QuietNote 会在本地保存。", "Copy text anywhere and QuietNote will save it locally.") }
    var searchClipboard: String { text("搜索本地剪切板", "Search local clipboard") }
    var onboardingTitle: String { text("欢迎使用 LumaNote", "Welcome to LumaNote") }
    var onboardingSubtitle: String { text("一张透明、灵动、常驻屏幕边缘的 Markdown 便签。", "A translucent Markdown sticky note that stays at the edge of your screen.") }
    var onboardingIntroTitle: String { text("它是什么", "What it is") }
    var onboardingIntroBody: String {
        text(
            "LumaNote 把实时 Markdown、透明玻璃便签、本地剪切板识别和全局快捷键放进一个小窗口里，适合长期贴在屏幕边上。",
            "LumaNote combines live Markdown, a glass sticky note, local clipboard detection, and global shortcuts in one small window."
        )
    }
    var onboardingRecommendedTitle: String { text("推荐先开启", "Recommended first") }
    var onboardingRecommendedBody: String {
        text(
            "自动更新保证你拿到最新修复；开机自启让便签不用每次手动打开。",
            "Automatic updates keep fixes coming, and launch at login makes the note ready after every restart."
        )
    }
    var onboardingEnableRecommended: String { text("开启推荐设置", "Enable recommended settings") }
    var onboardingShortcutTitle: String { text("设置快捷呼出和隐藏", "Set show and hide shortcuts") }
    var onboardingShortcutBody: String {
        text(
            "推荐至少保留一个“呼出/隐藏便签”的快捷键，这样窗口藏起来以后也能立刻找回。",
            "Keep at least one show/hide shortcut so the note is always easy to bring back."
        )
    }
    var onboardingReadyTitle: String { text("准备好了", "You're ready") }
    var onboardingReadyBody: String {
        text(
            "之后可以在底部工具栏继续调透明度、主题色、剪切板和更新设置。",
            "You can adjust opacity, theme color, clipboard, and update settings later from the bottom toolbar."
        )
    }
    var onboardingIntroStep: String { text("介绍", "Intro") }
    var onboardingShortcutStep: String { text("快捷键", "Shortcuts") }
    var onboardingReadyStep: String { text("完成", "Ready") }
    var onboardingBack: String { text("上一步", "Back") }
    var onboardingNext: String { text("下一步", "Next") }
    var onboardingFinish: String { text("开始使用", "Start using") }
    var onboardingSkip: String { text("跳过引导", "Skip onboarding") }
    var onboardingConfigured: String { text("已开启", "Enabled") }
    var onboardingNotConfigured: String { text("未开启", "Off") }

    func keepLatest(_ count: Int) -> String {
        text("保留最近 \(count) 条", "Keep latest \(count) items")
    }

    func keepCompact(_ count: Int) -> String {
        text("保留 \(count)", "Keep \(count)")
    }

    func shortcutConflictLine(shortcut: String, actions: String) -> String {
        text("\(shortcut)：\(actions)", "\(shortcut): \(actions)")
    }

    func switchToFile(_ filename: String) -> String {
        text("切换到 \(filename)", "Switch to \(filename)")
    }

    func clipboardKindName(_ kind: ClipboardDetection.Kind) -> String {
        switch kind {
        case .url: text("链接", "URL")
        case .email: text("邮箱", "Email")
        case .phone: text("电话", "Phone")
        case .address: text("地址", "Address")
        case .file: text("文件", "File")
        case .number: text("编号", "Code")
        case .text: text("文本", "Text")
        }
    }

    private func text(_ chinese: String, _ english: String) -> String {
        language == .chinese ? chinese : english
    }
}
