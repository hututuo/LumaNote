import Foundation

struct AppText {
    let language: AppLanguage

    var note: String { text("便签", "Note") }
    var opacity: String { text("便签透明度", "Note opacity") }
    var opacityHint: String { text("控制便签玻璃外壳有多明显。", "Controls how visible the note's glass shell is.") }
    var glass: String { text("磨砂强度", "Frosted glass") }
    var glassHint: String { text("控制背景模糊、泛白和玻璃质感。", "Controls blur, haze, and the frosted glass feel.") }
    var alwaysOnTop: String { text("保持置顶", "Always on top") }
    var shortcuts: String { text("快捷键", "Shortcuts") }
    var showNoteShortcut: String { text("快捷呼出便签：", "Show note:") }
    var hideNoteShortcut: String { text("快捷关闭便签：", "Hide note:") }
    var clipboardShortcut: String { text("打开剪切板库：", "Open clipboard library:") }
    var languageLabel: String { text("语言", "Language") }
    var clipboard: String { text("剪切板", "Clipboard") }
    var monitorClipboard: String { text("本地监听剪切板", "Monitor clipboard locally") }
    var monitorLocally: String { text("本地监听", "Monitor locally") }
    var clear: String { text("清空", "Clear") }
    var clearClipboard: String { text("清空剪切板库", "Clear clipboard library") }
    var keyboardShortcutNote: String { text("快捷键会保存在本机；QuietNote 运行时全局生效。", "Shortcuts are stored locally and work globally while QuietNote is running.") }
    var appearance: String { text("玻璃质感", "Glass feel") }
    var glassHintCompact: String { text("模糊 / 泛白 / 质感", "Blur / haze / texture") }
    var hideNote: String { text("隐藏便签", "Hide Note") }
    var extracted: String { text("已提取", "Extracted") }
    var copy: String { text("复制", "Copy") }
    var openNoteFile: String { text("打开 Markdown 文件", "Open Markdown file") }
    var switchNoteFile: String { text("切换便签文件", "Switch note file") }
    var openNewFile: String { text("打开新文件", "Open new file") }
    var recentFiles: String { text("最近打开", "Recent files") }
    var noRecentFiles: String { text("没有最近文件", "No recent files") }
    var saveAsNoteFile: String { text("另存为 Markdown 文件", "Save as Markdown file") }
    var paste: String { text("粘贴", "Paste") }
    var copyExtracted: String { text("复制提取内容", "Copy Extracted") }
    var pasteExtracted: String { text("粘贴提取内容", "Paste Extracted") }
    var noClipboardItems: String { text("没有剪切板记录", "No clipboard items") }
    var noClipboardDescription: String { text("在任意地方复制文本，QuietNote 会在本地保存。", "Copy text anywhere and QuietNote will save it locally.") }
    var searchClipboard: String { text("搜索本地剪切板", "Search local clipboard") }

    func keepLatest(_ count: Int) -> String {
        text("保留最近 \(count) 条", "Keep latest \(count) items")
    }

    func keepCompact(_ count: Int) -> String {
        text("保留 \(count)", "Keep \(count)")
    }

    private func text(_ chinese: String, _ english: String) -> String {
        language == .chinese ? chinese : english
    }
}
