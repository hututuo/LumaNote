struct OnboardingLocalizedText: Equatable {
    let chinese: String
    let english: String

    func resolved(language: AppLanguage) -> String {
        language == .chinese ? chinese : english
    }
}

struct OnboardingFeatureItem: Equatable, Identifiable {
    let icon: String
    let title: OnboardingLocalizedText
    let detail: OnboardingLocalizedText

    var id: String {
        "\(icon)-\(title.chinese)"
    }
}

enum OnboardingPage: Int, CaseIterable, Identifiable {
    case intro
    case shortcuts
    case documents
    case ready

    var id: Int {
        rawValue
    }

    var previous: OnboardingPage? {
        Self(rawValue: rawValue - 1)
    }

    var next: OnboardingPage? {
        Self(rawValue: rawValue + 1)
    }

    func stepLabel(copy: AppText) -> String {
        switch self {
        case .intro: copy.onboardingIntroStep
        case .shortcuts: copy.onboardingShortcutStep
        case .documents: copy.onboardingDocumentsStep
        case .ready: copy.onboardingReadyStep
        }
    }

    var featureItems: [OnboardingFeatureItem] {
        switch self {
        case .intro: Self.introFeatureItems
        case .shortcuts: []
        case .documents: Self.documentFeatureItems
        case .ready: Self.readyFeatureItems
        }
    }

    var bottomToolbarTitle: OnboardingLocalizedText? {
        guard self == .ready else { return nil }
        return Self.readyBottomToolbarTitle
    }

    var bottomToolbarItems: [OnboardingFeatureItem] {
        guard self == .ready else { return [] }
        return Self.readyBottomToolbarItems
    }

    private static let introFeatureItems = [
        OnboardingFeatureItem(
            icon: "text.badge.checkmark",
            title: .init(chinese: "实时 Markdown", english: "Live Markdown"),
            detail: .init(
                chinese: "边写边渲染，内容仍保存为普通 Markdown。",
                english: "Styled while editing, saved as plain Markdown."
            )
        ),
        OnboardingFeatureItem(
            icon: "square.on.square",
            title: .init(chinese: "本地剪切板库", english: "Local clipboard library"),
            detail: .init(
                chinese: "复制内容后在本机保存并提取可用信息。",
                english: "Saves copied text locally and extracts useful snippets."
            )
        ),
        OnboardingFeatureItem(
            icon: "keyboard",
            title: .init(chinese: "快捷呼出", english: "Quick summon"),
            detail: .init(
                chinese: "用全局快捷键呼出或隐藏这张便签。",
                english: "Use global shortcuts to show or hide the note."
            )
        )
    ]

    private static let documentFeatureItems = [
        OnboardingFeatureItem(
            icon: "rectangle.stack",
            title: .init(chinese: "工作区整理", english: "Organize by workspace"),
            detail: .init(
                chinese: "把项目、日常、灵感等不同场景的 Markdown 分到不同工作区，切换时只看当前工作区的文档。",
                english: "Keep project, daily, and idea notes in separate workspaces so switching stays focused."
            )
        ),
        OnboardingFeatureItem(
            icon: "arrow.left.arrow.right",
            title: .init(chinese: "底部快速切换", english: "Quick switcher"),
            detail: .init(
                chinese: "点底部左右箭头按钮，可以选择工作区、新建 Markdown、打开文件，或在当前工作区里快速换文档。",
                english: "Use the bottom arrows button to choose a workspace, create Markdown, open a file, or switch within the current workspace."
            )
        ),
        OnboardingFeatureItem(
            icon: "hand.draw",
            title: .init(chinese: "左右滑切换文档", english: "Swipe between documents"),
            detail: .init(
                chinese: "在正文区域左右滑，可以跟手预览并切到同一工作区里的上一份或下一份文档。",
                english: "Swipe left or right in the editor to preview and switch to the previous or next document in the workspace."
            )
        )
    ]

    private static let readyFeatureItems = [
        OnboardingFeatureItem(
            icon: "list.clipboard",
            title: .init(chinese: "顶部剪切板胶囊", english: "Top clipboard capsule"),
            detail: .init(
                chinese: "复制内容里有电话、地址、邮箱或链接时，顶部胶囊会主动展开提示。",
                english: "When copied text contains a phone, address, email, or URL, the top capsule expands automatically."
            )
        ),
        OnboardingFeatureItem(
            icon: "sparkles",
            title: .init(chinese: "自动提取与一键动作", english: "Extraction and one-click actions"),
            detail: .init(
                chinese: "点开提取提示后，可以一键复制，也可以直接打开链接、地图、邮件或电话动作。",
                english: "Open the extraction hint to copy with one click or open URLs, Maps, email, and phone actions."
            )
        )
    ]

    private static let readyBottomToolbarTitle = OnboardingLocalizedText(
        chinese: "底部工具栏",
        english: "Bottom toolbar"
    )

    private static let readyBottomToolbarItems = [
        OnboardingFeatureItem(
            icon: "slider.horizontal.3",
            title: .init(chinese: "调透明度", english: "Adjust opacity"),
            detail: .init(
                chinese: "左侧滑杆控制便签玻璃外壳可见度，放在屏幕边上也不会太抢眼。",
                english: "The slider controls the note shell visibility so it can stay subtle at the screen edge."
            )
        ),
        OnboardingFeatureItem(
            icon: "arrow.left.arrow.right",
            title: .init(chinese: "切换文件与更多设置", english: "Switch files and settings"),
            detail: .init(
                chinese: "底部工具栏可以切换便签文件、另存为、置顶、固定控件、打开设置或关闭便签。",
                english: "Use it to switch files, save as, pin, keep controls visible, open settings, or hide the note."
            )
        )
    ]
}
