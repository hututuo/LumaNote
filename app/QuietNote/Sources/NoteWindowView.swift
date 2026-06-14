import AppKit
@preconcurrency import KeyboardShortcuts
import SwiftUI
import UniformTypeIdentifiers

struct NoteWindowView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var noteStore: NoteStore
    @ObservedObject var clipboardStore: ClipboardStore

    let onClose: () -> Void

    @State private var showClipboard = false
    @State private var showMore = false
    @State private var showFileSwitcher = false
    @State private var showShortcutSettings = false
    @State private var showExtractionActions = false
    @State private var moreButtonFrame: CGRect = .zero
    @State private var fileSwitchButtonFrame: CGRect = .zero
    @State private var hiddenSuggestionID: ClipboardItem.ID?
    @State private var suggestionResetTask: Task<Void, Never>?
    @State private var chromeControlsCollapsed = false
    @State private var chromeCollapseTask: Task<Void, Never>?
    @State private var lastChromeActivityAt = Date.distantPast
    @State private var chromeHintPulse = false
    @Namespace private var extractionIslandNamespace

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(shellOpacity)
                .overlay(readabilityLayer)
                .overlay(themeTintLayer)
                .overlay(borderLayer)

            VStack(spacing: 0) {
                topBar

                content
                    .padding(.leading, 10)
                    .padding(.trailing, 5)
                    .padding(.top, contentTopPadding)
                    .padding(.bottom, contentBottomInset)
            }

            bottomChromeControl
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .background {
            WindowActivityMonitorView { _ in
                markChromeActivity(revealIfCollapsed: false)
            }
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
        }
        .overlay {
            if showClipboard {
                clipboardInlineOverlay
            }
        }
        .overlay {
            if showMore {
                moreInlineOverlay
            }
        }
        .overlay {
            if showFileSwitcher {
                fileSwitcherInlineOverlay
            }
        }
        .frame(
            minWidth: NoteWindowLayout.minimumSize.width,
            minHeight: NoteWindowLayout.minimumSize.height
        )
        .coordinateSpace(name: NoteWindowCoordinateSpace.name)
        .onPreferenceChange(MoreButtonFramePreferenceKey.self) { frame in
            moreButtonFrame = frame
        }
        .onPreferenceChange(FileSwitchButtonFramePreferenceKey.self) { frame in
            fileSwitchButtonFrame = frame
        }
        .sheet(isPresented: $showShortcutSettings) {
            ShortcutSettingsView(settings: settings)
                .frame(width: 360)
                .padding(16)
        }
        .onReceive(NotificationCenter.default.publisher(for: .quietNoteToggleClipboard)) { _ in
            withAnimation(.snappy(duration: 0.16)) {
                chromeControlsCollapsed = false
                showMore = false
                showFileSwitcher = false
                showExtractionActions = false
                showClipboard.toggle()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            closeClipboardOnFocusLoss()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            closeClipboardOnFocusLoss()
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)) { notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier != Bundle.main.bundleIdentifier
            else { return }
            closeClipboardOnFocusLoss()
        }
        .onChange(of: showShortcutSettings) { _, isPresented in
            if isPresented {
                chromeControlsCollapsed = false
                showMore = false
            }
        }
        .onChange(of: clipboardStore.latestDetectedItem?.id) { _, itemID in
            scheduleSuggestionReset(for: itemID)
            markChromeActivity(revealIfCollapsed: false)
        }
        .onChange(of: bottomChromeShouldStayExpanded) { _, shouldStayExpanded in
            if shouldStayExpanded {
                chromeCollapseTask?.cancel()
                withAnimation(.snappy(duration: 0.18)) {
                    chromeControlsCollapsed = false
                }
            } else {
                markChromeActivity(forceReschedule: true)
            }
        }
        .onChange(of: settings.autoHideChrome) { _, shouldAutoHide in
            if shouldAutoHide {
                markChromeActivity(forceReschedule: true)
            } else {
                chromeCollapseTask?.cancel()
                withAnimation(.snappy(duration: 0.18)) {
                    chromeControlsCollapsed = false
                }
            }
        }
        .onChange(of: noteStore.markdown) { _, _ in
            markChromeActivity(revealIfCollapsed: false)
        }
        .onAppear {
            startChromeHintPulse()
            markChromeActivity(forceReschedule: true)
        }
        .onDisappear {
            suggestionResetTask?.cancel()
            chromeCollapseTask?.cancel()
        }
        .animation(.snappy(duration: 0.16), value: showClipboard)
        .animation(.snappy(duration: 0.16), value: showMore)
        .animation(.snappy(duration: 0.16), value: showFileSwitcher)
        .animation(.snappy(duration: 0.24), value: clipboardStore.latestDetectedItem?.id)
        .animation(.snappy(duration: 0.24), value: hiddenSuggestionID)
        .animation(.snappy(duration: 0.24), value: chromeControlsCollapsed)
    }

    @ViewBuilder
    private var clipboardInlineOverlay: some View {
        GeometryReader { proxy in
            let panelWidth = min(360, max(238, proxy.size.width - 20))
            let panelHeight = min(390, max(178, proxy.size.height - 74))

            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: topDragPassthroughHeight)
                        .allowsHitTesting(false)

                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.snappy(duration: 0.16)) {
                                showClipboard = false
                            }
                        }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                ClipboardLibraryView(settings: settings, store: clipboardStore)
                    .frame(width: panelWidth, height: panelHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.62), .white.opacity(0.18), .black.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
                    .padding(.top, 40)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.96, anchor: .top).combined(with: .opacity),
                        removal: .scale(scale: 0.985, anchor: .top).combined(with: .opacity)
                    ))
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .zIndex(30)
        }
    }

    @ViewBuilder
    private var moreInlineOverlay: some View {
        GeometryReader { proxy in
            let metrics = moreOverlayMetrics(in: proxy.size)

            ZStack(alignment: .topLeading) {
                dismissBackdropWithTopDragPassthrough {
                        withAnimation(.snappy(duration: 0.14)) {
                            showMore = false
                        }
                }

                MoreMenuView(
                    settings: settings,
                    clipboardStore: clipboardStore,
                    showShortcutSettings: $showShortcutSettings,
                    onClose: {
                        showMore = false
                        onClose()
                    }
                )
                .frame(width: metrics.width, height: metrics.height)
                .background {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(.regularMaterial)
                        .opacity(0.62 + settings.noteOpacity * 0.24)
                }
                .background {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.12 + settings.noteOpacity * 0.18))
                }
                .background {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Color.white.opacity(0.055 + settings.noteOpacity * 0.08))
                        .blendMode(.plusLighter)
                }
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.62), .white.opacity(0.18), .black.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.2), radius: 18, y: 8)
                .position(x: metrics.centerX, y: metrics.centerY)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95, anchor: .bottomTrailing).combined(with: .opacity),
                    removal: .scale(scale: 0.985, anchor: .bottomTrailing).combined(with: .opacity)
                ))
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .zIndex(32)
        }
    }

    @ViewBuilder
    private var fileSwitcherInlineOverlay: some View {
        GeometryReader { proxy in
            let metrics = fileSwitcherOverlayMetrics(in: proxy.size)

            ZStack(alignment: .topLeading) {
                dismissBackdropWithTopDragPassthrough {
                        withAnimation(.snappy(duration: 0.14)) {
                            showFileSwitcher = false
                        }
                }

                FileSwitcherView(
                    settings: settings,
                    noteStore: noteStore,
                    openNewFile: {
                        withAnimation(.snappy(duration: 0.14)) {
                            showFileSwitcher = false
                        }
                        openNoteFile()
                    },
                    openRecentFile: { url in
                        withAnimation(.snappy(duration: 0.14)) {
                            showFileSwitcher = false
                        }
                        noteStore.openFile(at: url)
                    }
                )
                .frame(width: metrics.width, height: metrics.height)
                .background {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(.regularMaterial)
                        .opacity(0.1 + settings.noteOpacity * 0.78)
                }
                .background {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Color.white.opacity(0.035 + settings.noteOpacity * 0.08))
                        .blendMode(.plusLighter)
                }
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.62), .white.opacity(0.18), .black.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.2), radius: 18, y: 8)
                .position(x: metrics.centerX, y: metrics.centerY)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95, anchor: .bottom).combined(with: .opacity),
                    removal: .scale(scale: 0.985, anchor: .bottom).combined(with: .opacity)
                ))
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .zIndex(31)
        }
    }

    private var readabilityLayer: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.white.opacity(0.025 + settings.noteOpacity * (0.14 + settings.glassStrength * 0.16)))
            .blendMode(.plusLighter)
    }

    private var themeTintLayer: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(settings.accentColor.opacity(0.004 + settings.noteOpacity * (0.014 + settings.glassStrength * 0.026)))
            .blendMode(.plusLighter)
    }

    private var borderLayer: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(0.72), .white.opacity(0.18), .black.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
            .opacity(0.2 + settings.noteOpacity * 0.55)
    }

    private var topBar: some View {
        ZStack {
            WindowDragView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if topChromeCollapsed {
                collapsedTopChromeHandle
                    .padding(.top, 5)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.72, anchor: .top).combined(with: .opacity),
                        removal: .scale(scale: 0.92, anchor: .top).combined(with: .opacity)
                    ))
            } else {
                extractionIsland
                    .padding(.top, 7)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.92, anchor: .center).combined(with: .opacity),
                        removal: .scale(scale: 0.82, anchor: .center).combined(with: .opacity)
                    ))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: topBarHeight)
        .contentShape(Rectangle())
    }

    private var islandGrip: some View {
        VStack(spacing: 1.8) {
            Capsule()
                .fill(.primary.opacity(0.2))
                .frame(width: 16, height: 1.4)
            Capsule()
                .fill(.primary.opacity(0.15))
                .frame(width: 12, height: 1.4)
            Capsule()
                .fill(.primary.opacity(0.1))
                .frame(width: 8, height: 1.4)
        }
        .frame(width: 24, height: 24)
        .allowsHitTesting(false)
    }

    private func islandDragGrip(width: CGFloat = 30) -> some View {
        ZStack {
            islandGrip
                .frame(width: width, height: 24)

            WindowDragView()
                .frame(width: width, height: 26)
        }
        .frame(width: width, height: 26)
    }

    private var content: some View {
        MarkdownRenderingEditor(text: $noteStore.markdown, fontSize: settings.editorFontSize)
            .mask {
                markdownContentFadeMask
            }
    }

    private var bottomRailHeight: CGFloat {
        36
    }

    private var collapsedBottomChromeHeight: CGFloat {
        18
    }

    private var markdownBottomFadeHeight: CGFloat {
        bottomChromeCollapsed ? 8 : 26
    }

    private var markdownTopFadeHeight: CGFloat {
        topChromeCollapsed ? 6 : 16
    }

    private var contentBottomInset: CGFloat {
        bottomChromeCollapsed ? 2 : bottomRailHeight
    }

    private var contentTopPadding: CGFloat {
        topChromeCollapsed ? 0 : 10
    }

    private var topBarHeight: CGFloat {
        topChromeCollapsed ? 12 : 35
    }

    private var markdownContentFadeMask: some View {
        GeometryReader { proxy in
            let maxFadeHeight = max(0, proxy.size.height / 2)
            let topFadeHeight = min(markdownTopFadeHeight, maxFadeHeight)
            let bottomFadeHeight = min(markdownBottomFadeHeight, maxFadeHeight)

            ZStack(alignment: .trailing) {
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [.white.opacity(0), .white],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: topFadeHeight)

                    Rectangle()
                        .fill(.white)

                    LinearGradient(
                        colors: [.white, .white.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: bottomFadeHeight)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)

                Rectangle()
                    .fill(.white)
                    .frame(width: 12)
            }
        }
    }

    private var shellOpacity: Double {
        max(0.08, settings.noteOpacity)
    }

    private var islandOpacity: Double {
        max(0.05, settings.noteOpacity)
    }

    private var bottomRailOpacity: Double {
        let lowerBound = AppSettings.minimumNoteOpacity
        let progress = (settings.noteOpacity - lowerBound) / (1 - lowerBound)
        let clampedProgress = min(max(progress, 0), 1)
        return 0.075 + clampedProgress * 0.425
    }

    private var collapsedChromeOpacity: Double {
        max(0.035, settings.noteOpacity * 0.18)
    }

    private var chromeAutoHideDelay: TimeInterval {
        4.0
    }

    private var topChromeCollapsed: Bool {
        settings.autoHideChrome && chromeControlsCollapsed && activeDetectedItem == nil && !showExtractionActions
    }

    private var bottomChromeCollapsed: Bool {
        settings.autoHideChrome && chromeControlsCollapsed && !bottomChromeShouldStayExpanded
    }

    private var bottomChromeShouldStayExpanded: Bool {
        showClipboard || showMore || showFileSwitcher || showShortcutSettings
    }

    private var topDragPassthroughHeight: CGFloat {
        38
    }

    private func dismissBackdropWithTopDragPassthrough(onDismiss: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: topDragPassthroughHeight)
                .allowsHitTesting(false)

            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func closeClipboardOnFocusLoss() {
        guard showClipboard else { return }
        withAnimation(.snappy(duration: 0.14)) {
            showClipboard = false
        }
    }

    private func markChromeActivity(revealIfCollapsed: Bool = true, forceReschedule: Bool = false) {
        guard settings.autoHideChrome else {
            chromeCollapseTask?.cancel()
            if chromeControlsCollapsed {
                chromeControlsCollapsed = false
            }
            return
        }

        let now = Date()
        let wasCollapsed = chromeControlsCollapsed
        let shouldReschedule = forceReschedule || now.timeIntervalSince(lastChromeActivityAt) > 0.22 || wasCollapsed
        lastChromeActivityAt = now

        if wasCollapsed {
            guard revealIfCollapsed else { return }
            withAnimation(.snappy(duration: 0.2)) {
                chromeControlsCollapsed = false
            }
        }

        if bottomChromeShouldStayExpanded {
            chromeCollapseTask?.cancel()
            return
        }

        if shouldReschedule {
            scheduleChromeAutoCollapse()
        }
    }

    private func revealChromeControls() {
        markChromeActivity(revealIfCollapsed: true, forceReschedule: true)
    }

    private func scheduleChromeAutoCollapse() {
        chromeCollapseTask?.cancel()
        guard settings.autoHideChrome else { return }
        guard !bottomChromeShouldStayExpanded else { return }

        let delay = chromeAutoHideDelay
        chromeCollapseTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            guard !bottomChromeShouldStayExpanded else { return }

            let idleTime = Date().timeIntervalSince(lastChromeActivityAt)
            guard idleTime >= delay - 0.18 else {
                scheduleChromeAutoCollapse()
                return
            }

            withAnimation(.snappy(duration: 0.26)) {
                chromeControlsCollapsed = true
            }
        }
    }

    private func startChromeHintPulse() {
        guard !chromeHintPulse else { return }
        withAnimation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true)) {
            chromeHintPulse = true
        }
    }

    private var islandTextColor: Color {
        Color.black.opacity(0.82)
    }

    private var islandIconColor: Color {
        Color.black.opacity(0.86)
    }

    private var detectedIslandTextColor: Color {
        Color.black.opacity(0.82)
    }

    private var detectedIslandIconColor: Color {
        Color.black.opacity(0.86)
    }

    private var islandSoftShadowColor: Color {
        Color.white.opacity(0.58)
    }

    private var detectedIslandHighlightColor: Color {
        Color.white.opacity(0.58)
    }

    @ViewBuilder
    private var bottomChromeControl: some View {
        if bottomChromeCollapsed {
            collapsedBottomChromeHandle
                .padding(.bottom, 5)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .scale(scale: 0.88, anchor: .bottom).combined(with: .opacity)
                ))
        } else {
            bottomRail
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
        }
    }

    private var collapsedTopChromeHandle: some View {
        let detection = activeDetectedItem?.detections.first
        let width: CGFloat = detection == nil ? 42 : 50

        return ZStack {
            collapsedHandlePulseOverlay

            HStack(spacing: 4) {
                if let detection {
                    Image(systemName: detection.symbol)
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(detectedIslandIconColor)
                } else {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule(style: .continuous)
                            .fill(islandIconColor.opacity(0.7 - Double(index) * 0.14))
                            .frame(width: index == 1 ? 7 : 5, height: 2)
                    }
                }
            }
            .allowsHitTesting(false)

            WindowClickDragView {
                revealChromeControls()
            }
        }
        .frame(width: width, height: 18)
        .modifier(ExtractionIslandButtonModifier(isExpanded: true, opacity: collapsedChromeOpacity, accentColor: settings.accentColor))
        .contentShape(Capsule(style: .continuous))
        .help(AppText(language: settings.language).showControls)
    }

    private var collapsedBottomChromeHandle: some View {
        ZStack {
            collapsedHandlePulseOverlay

            HStack(spacing: 5) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 8.5, weight: .bold))

                Text("\(Int(settings.noteOpacity * 100))%")
                    .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(islandIconColor)
            .shadow(color: islandSoftShadowColor, radius: 1, y: 0.4)
            .allowsHitTesting(false)

            WindowClickDragView {
                revealChromeControls()
            }
        }
        .frame(width: 58, height: collapsedBottomChromeHeight)
        .modifier(ExtractionIslandButtonModifier(isExpanded: true, opacity: collapsedChromeOpacity, accentColor: settings.accentColor))
        .contentShape(Capsule(style: .continuous))
        .help(AppText(language: settings.language).showControls)
    }

    private var collapsedHandlePulseOverlay: some View {
        Capsule(style: .continuous)
            .strokeBorder(.white.opacity(chromeHintPulse ? 0.42 : 0.16), lineWidth: 1)
            .scaleEffect(chromeHintPulse ? 1.08 : 0.96)
            .opacity(chromeHintPulse ? 0.95 : 0.42)
            .allowsHitTesting(false)
    }

    private var bottomRail: some View {
        let copy = AppText(language: settings.language)

        return GeometryReader { proxy in
            let progress = railCompactProgress(for: proxy.size.width)
            let spacing = 8 - progress * 3
            let horizontalPadding = 14 - progress * 6
            let sliderMinWidth = 96 - progress * 54
            let buttonSize = 24 - progress * 2
            let labelFontSize = 12 - progress
            let percentWidth = 36 - progress * 4

            HStack(spacing: spacing) {
                Text("1")
                    .font(.system(size: labelFontSize, weight: .medium))
                    .foregroundStyle(.secondary)

                Slider(value: $settings.noteOpacity, in: AppSettings.minimumNoteOpacity...1)
                    .tint(settings.accentColor)
                    .frame(minWidth: sliderMinWidth)
                    .layoutPriority(1)

                Text("100")
                    .font(.system(size: labelFontSize, weight: .medium))
                    .foregroundStyle(.secondary)

                Text("\(Int(settings.noteOpacity * 100))%")
                    .font(.system(size: labelFontSize, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .frame(width: percentWidth, alignment: .trailing)

                railButton(symbol: "arrow.left.arrow.right", help: copy.switchNoteFile, size: buttonSize) {
                    withAnimation(.snappy(duration: 0.14)) {
                        showClipboard = false
                        showMore = false
                        showExtractionActions = false
                        showFileSwitcher.toggle()
                    }
                }
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: FileSwitchButtonFramePreferenceKey.self,
                            value: proxy.frame(in: .named(NoteWindowCoordinateSpace.name))
                        )
                    }
                )
                railButton(symbol: "square.and.arrow.down", help: copy.saveAsNoteFile, size: buttonSize) {
                    saveNoteFileAs()
                }
                railButton(
                    symbol: settings.alwaysOnTop ? "pin.fill" : "pin",
                    help: settings.alwaysOnTop ? copy.disableAlwaysOnTop : copy.alwaysOnTop,
                    size: buttonSize
                ) {
                    settings.alwaysOnTop.toggle()
                }
                railButton(
                    symbol: settings.autoHideChrome ? "eye.slash" : "eye",
                    help: settings.autoHideChrome ? copy.autoHideControls : copy.keepControlsVisible,
                    size: buttonSize
                ) {
                    withAnimation(.snappy(duration: 0.18)) {
                        settings.autoHideChrome.toggle()
                        if !settings.autoHideChrome {
                            chromeControlsCollapsed = false
                        }
                    }
                }
                railButton(symbol: "ellipsis", help: copy.more, size: buttonSize, hitSize: max(30, buttonSize + 8)) {
                    withAnimation(.snappy(duration: 0.14)) {
                        showClipboard = false
                        showExtractionActions = false
                        showFileSwitcher = false
                        showMore.toggle()
                    }
                }
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: MoreButtonFramePreferenceKey.self,
                            value: proxy.frame(in: .named(NoteWindowCoordinateSpace.name))
                        )
                    }
                )
            }
            .padding(.horizontal, horizontalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: bottomRailHeight)
        .contentShape(Rectangle())
        .onTapGesture {}
        .background { bottomRailLiquidGlassBackground }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.white.opacity(0.08 + bottomRailOpacity * 0.14))
                .frame(height: 1)
        }
    }

    private var bottomRailLiquidGlassBackground: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)
                .opacity(0.08 + bottomRailOpacity * 0.72)

            LinearGradient(
                colors: [
                    settings.accentColor.opacity(0.006 + bottomRailOpacity * 0.028),
                    .white.opacity(0.025 + bottomRailOpacity * 0.075),
                    .white.opacity(0.006 + bottomRailOpacity * 0.018),
                    .black.opacity(0.012 + bottomRailOpacity * 0.028)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.plusLighter)

            Rectangle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.18 + bottomRailOpacity * 0.56),
                            settings.accentColor.opacity(0.06 + bottomRailOpacity * 0.12),
                            .white.opacity(0.08 + bottomRailOpacity * 0.14),
                            .white.opacity(0.02 + bottomRailOpacity * 0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: .white.opacity(0.04 + bottomRailOpacity * 0.12), radius: 3, x: -1, y: -1)
        .shadow(color: .black.opacity(0.04 + bottomRailOpacity * 0.12), radius: 10, y: 4)
    }

    private func railCompactProgress(for width: CGFloat) -> CGFloat {
        let fullWidth = NoteWindowLayout.initialSize.width
        let compactWidth = NoteWindowLayout.minimumSize.width
        guard width < fullWidth, fullWidth > compactWidth else {
            return 0
        }
        return min(max((fullWidth - width) / (fullWidth - compactWidth), 0), 1)
    }

    private func railButton(symbol: String, help: String, size: CGFloat = 24, hitSize: CGFloat? = nil, action: @escaping () -> Void) -> some View {
        let cornerRadius = max(6, size * 0.29)
        let tappableSize = max(size, hitSize ?? size)

        return Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.white.opacity(0.03 + bottomRailOpacity * 0.08))
                    .frame(width: size, height: size)

                Image(systemName: symbol)
                    .font(.system(size: size * 0.54, weight: .semibold))
                    .frame(width: size, height: size)
            }
            .frame(width: tappableSize, height: tappableSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func openNoteFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = markdownContentTypes
        panel.directoryURL = noteStore.currentFileURL.deletingLastPathComponent()

        if panel.runModal() == .OK, let url = panel.url {
            noteStore.openFile(at: url)
        }
    }

    private func saveNoteFileAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = markdownContentTypes
        panel.directoryURL = noteStore.currentFileURL.deletingLastPathComponent()
        panel.nameFieldStringValue = noteStore.currentFileName

        if panel.runModal() == .OK, let url = panel.url {
            noteStore.saveAs(to: url)
        }
    }

    private var markdownContentTypes: [UTType] {
        [
            UTType(filenameExtension: "md"),
            UTType(filenameExtension: "markdown"),
            .plainText,
            .text
        ].compactMap { $0 }
    }

    @ViewBuilder
    private var extractionIsland: some View {
        if let item = activeDetectedItem,
           let first = item.detections.first {
            extractionActionButton(item: item, first: first)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.84, anchor: .center).combined(with: .opacity),
                    removal: .scale(scale: 0.92, anchor: .center).combined(with: .opacity)
                ))
        } else {
            titleIsland
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9, anchor: .center).combined(with: .opacity),
                    removal: .scale(scale: 0.94, anchor: .center).combined(with: .opacity)
                ))
        }
    }

    private var activeDetectedItem: ClipboardItem? {
        guard let item = clipboardStore.latestDetectedItem,
              item.id != hiddenSuggestionID,
              !showClipboard
        else { return nil }
        return item
    }

    private var titleIsland: some View {
        ZStack {
            WindowClickDragView {}

            Text(noteStore.displayTitle)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(islandTextColor)
                .shadow(color: islandSoftShadowColor, radius: 1.2, y: 0.5)
                .lineLimit(1)
                .truncationMode(.middle)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 126)
                .allowsHitTesting(false)

            HStack(spacing: 0) {
                islandDragGrip()

                Spacer(minLength: 0)

                clipboardIslandButton
            }
            .padding(.leading, 2)
            .padding(.trailing, 4)
        }
        .frame(width: 190, height: 26)
        .modifier(ExtractionIslandButtonModifier(isExpanded: true, opacity: islandOpacity, accentColor: settings.accentColor))
        .matchedGeometryEffect(id: "extractionIsland", in: extractionIslandNamespace)
        .help(AppText(language: settings.language).dragNote)
    }

    private func extractionActionButton(item: ClipboardItem, first: ClipboardDetection) -> some View {
        HStack(spacing: 0) {
            islandDragGrip()

            ZStack {
                HStack(spacing: 7) {
                    Image(systemName: first.symbol)
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(detectedIslandIconColor)
                        .shadow(color: detectedIslandHighlightColor, radius: 1.4, y: 0.5)
                        .frame(width: 14, height: 22)

                    Text(first.value)
                        .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(detectedIslandTextColor)
                        .shadow(color: detectedIslandHighlightColor, radius: 1.6, y: 0.5)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 122, alignment: .leading)

                    if item.detections.count > 1 {
                        Text("+\(item.detections.count - 1)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(detectedIslandTextColor)
                            .shadow(color: detectedIslandHighlightColor, radius: 1.2, y: 0.4)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.white.opacity(0.28), in: Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(.black.opacity(0.06), lineWidth: 0.5)
                            )
                    }
                }
                .allowsHitTesting(false)

                WindowClickDragView {
                    showExtractionActions.toggle()
                }
            }
            .frame(height: 26)
            .frame(maxWidth: 168, alignment: .leading)

            detectedClipboardIslandButton
                .padding(.trailing, 4)
        }
        .padding(.leading, 2)
        .padding(.trailing, 0)
        .frame(height: 26, alignment: .leading)
        .fixedSize(horizontal: true, vertical: false)
        .frame(maxWidth: 226, alignment: .leading)
        .modifier(ExtractionIslandButtonModifier(isExpanded: true, opacity: islandOpacity, accentColor: settings.accentColor))
        .matchedGeometryEffect(id: "extractionIsland", in: extractionIslandNamespace)
        .help(AppText(language: settings.language).clipboardActions)
        .popover(isPresented: $showExtractionActions, arrowEdge: .top) {
            extractionActionsPopover(item: item)
                .frame(width: 310)
        }
    }

    private var clipboardIslandButton: some View {
        clipboardIslandButtonView(
            foregroundColor: islandIconColor,
            shadowColor: .black.opacity(0.2)
        )
    }

    private var detectedClipboardIslandButton: some View {
        clipboardIslandButtonView(
            foregroundColor: detectedIslandIconColor,
            shadowColor: detectedIslandHighlightColor
        )
    }

    private func clipboardIslandButtonView(foregroundColor: Color, shadowColor: Color) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.16)) {
                showMore = false
                showFileSwitcher = false
                showExtractionActions = false
                showClipboard.toggle()
            }
        } label: {
            Image(systemName: "list.clipboard")
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 22, height: 22)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(foregroundColor)
        .shadow(color: shadowColor, radius: 1, y: 0.5)
        .background(.white.opacity(0.03 + islandOpacity * 0.08), in: Circle())
        .help(AppText(language: settings.language).openClipboardLibrary)
    }

    private func extractionActionsPopover(item: ClipboardItem) -> some View {
        let copy = AppText(language: settings.language)

        return VStack(alignment: .leading, spacing: 10) {
            Text(copy.extracted)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            ForEach(item.detections) { detection in
                VStack(alignment: .leading, spacing: 7) {
                    Label {
                        Text(detection.value)
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: detection.symbol)
                    }
                    .font(.system(size: 12, weight: .medium))

                    HStack(spacing: 8) {
                        Button {
                            clipboardStore.copy(detection.value)
                        } label: {
                            Label(copy.copy, systemImage: "doc.on.doc")
                        }
                        .help(copy.copyExtracted)

                        if let openTitle = detection.openTitle {
                            Button {
                                showExtractionActions = false
                                clipboardStore.open(detection)
                            } label: {
                                Label(openTitle, systemImage: detection.openSymbol)
                            }
                            .help(openTitle)
                        }
                    }
                    .font(.system(size: 11, weight: .medium))
                    .buttonStyle(.borderless)
                }
                .padding(9)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
        }
        .padding(12)
        .background(.regularMaterial)
    }

    private func scheduleSuggestionReset(for itemID: ClipboardItem.ID?) {
        suggestionResetTask?.cancel()
        hiddenSuggestionID = nil

        guard let itemID else { return }
        suggestionResetTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(60))
            guard !Task.isCancelled else { return }
            hiddenSuggestionID = itemID
            showExtractionActions = false
        }
    }

    private func moreOverlayMetrics(in containerSize: CGSize) -> (width: CGFloat, height: CGFloat, centerX: CGFloat, centerY: CGFloat) {
        let margin: CGFloat = 12
        let width = max(210, min(286, containerSize.width - margin * 2))
        let topClearance = topDragPassthroughHeight + 8
        let bottomClearance: CGFloat = 10
        let availableHeight = max(210, containerSize.height - topClearance - bottomClearance)
        let height = min(470, availableHeight)
        let anchor = moreButtonFrame == .zero
            ? CGRect(x: containerSize.width - 44, y: containerSize.height - 34, width: 24, height: 24)
            : moreButtonFrame

        let preferredX = anchor.maxX - width / 2
        let minX = margin + width / 2
        let maxX = containerSize.width - margin - width / 2
        let centerX = clamped(preferredX, min: minX, max: maxX)

        let preferredY = anchor.minY - 8 - height / 2
        let minY = topClearance + height / 2
        let maxY = containerSize.height - bottomClearance - height / 2
        let centerY = clamped(preferredY, min: minY, max: maxY)

        return (width, height, centerX, centerY)
    }

    private func fileSwitcherOverlayMetrics(in containerSize: CGSize) -> (width: CGFloat, height: CGFloat, centerX: CGFloat, centerY: CGFloat) {
        let margin: CGFloat = 12
        let width = max(218, min(310, containerSize.width - margin * 2))
        let recentCount = max(1, min(noteStore.recentFileURLs.count, 7))
        let topClearance = topDragPassthroughHeight + 8
        let bottomClearance: CGFloat = 10
        let maxHeight = max(150, containerSize.height - topClearance - bottomClearance)
        let height = min(maxHeight, 84 + CGFloat(recentCount) * 43)
        let anchor = fileSwitchButtonFrame == .zero
            ? CGRect(x: containerSize.width - 116, y: containerSize.height - 34, width: 24, height: 24)
            : fileSwitchButtonFrame

        let preferredX = anchor.midX
        let minX = margin + width / 2
        let maxX = containerSize.width - margin - width / 2
        let centerX = clamped(preferredX, min: minX, max: maxX)

        let preferredY = anchor.minY - 8 - height / 2
        let minY = topClearance + height / 2
        let maxY = containerSize.height - bottomClearance - height / 2
        let centerY = clamped(preferredY, min: minY, max: maxY)

        return (width, height, centerX, centerY)
    }

    private func clamped(_ value: CGFloat, min lowerBound: CGFloat, max upperBound: CGFloat) -> CGFloat {
        guard lowerBound <= upperBound else {
            return (lowerBound + upperBound) / 2
        }
        return Swift.min(Swift.max(value, lowerBound), upperBound)
    }
}

private enum NoteWindowCoordinateSpace {
    static let name = "quietNoteWindow"
}

private struct MoreButtonFramePreferenceKey: PreferenceKey {
    static let defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}

private struct FileSwitchButtonFramePreferenceKey: PreferenceKey {
    static let defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}

private struct FileSwitcherView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var noteStore: NoteStore

    let openNewFile: () -> Void
    let openRecentFile: (URL) -> Void

    private var copy: AppText {
        AppText(language: settings.language)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Button(action: openNewFile) {
                HStack(spacing: 9) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 18)

                    Text(copy.openNewFile)
                        .font(.system(size: 12, weight: .semibold))

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .frame(height: 34)
                .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
            .background(.white.opacity(0.08 + settings.noteOpacity * 0.06), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .help(copy.openNewFile)

            Rectangle()
                .fill(.white.opacity(0.16 + settings.noteOpacity * 0.16))
                .frame(height: 1)
                .padding(.horizontal, 2)

            if noteStore.recentFileURLs.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 11, weight: .semibold))
                    Text(copy.noRecentFiles)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .frame(height: 36)
            } else {
                Text(copy.recentFiles)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.top, 1)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 3) {
                        ForEach(noteStore.recentFileURLs, id: \.self) { url in
                            recentFileButton(url)
                        }
                    }
                }
            }
        }
        .padding(9)
    }

    private func recentFileButton(_ url: URL) -> some View {
        Button {
            openRecentFile(url)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: isCurrent(url) ? "checkmark.circle.fill" : "doc.text")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isCurrent(url) ? settings.accentColor : .secondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(url.lastPathComponent)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text(shortPath(for: url))
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(height: 39)
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(
            isCurrent(url) ? settings.accentColor.opacity(0.08) : Color.white.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .help(copy.switchToFile(url.lastPathComponent))
    }

    private func isCurrent(_ url: URL) -> Bool {
        noteStore.currentFileURL.standardizedFileURL.path == url.standardizedFileURL.path
    }

    private func shortPath(for url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = url.deletingLastPathComponent().path
        if path == home {
            return "~"
        }
        if path.hasPrefix(home + "/") {
            return "~/" + String(path.dropFirst(home.count + 1))
        }
        return path
    }
}

private struct ExtractionIslandButtonModifier: ViewModifier {
    let isExpanded: Bool
    let opacity: Double
    let accentColor: Color

    func body(content: Content) -> some View {
        content
            .buttonStyle(.plain)
            .foregroundStyle(.primary.opacity(0.86))
            .background {
                islandShape
                    .fill(.regularMaterial)
                    .opacity(0.08 + opacity * 0.72)
            }
            .background(
                islandShape
                    .fill(Color.white.opacity((isExpanded ? 0.025 : 0.04) + opacity * (isExpanded ? 0.075 : 0.1)))
                    .blendMode(.plusLighter)
            )
            .background(
                islandShape
                    .fill(accentColor.opacity(0.004 + opacity * 0.024))
                    .blendMode(.plusLighter)
            )
            .overlay(
                islandShape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity((isExpanded ? 0.18 : 0.22) + opacity * (isExpanded ? 0.56 : 0.6)),
                                accentColor.opacity(0.045 + opacity * 0.11),
                                .white.opacity(0.08 + opacity * 0.14),
                                .white.opacity(0.02 + opacity * 0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .white.opacity(0.04 + opacity * 0.12), radius: 3, x: -1, y: -1)
            .shadow(color: .black.opacity(0.04 + opacity * 0.12), radius: isExpanded ? 12 : 8, y: 4)
    }

    private var islandShape: AnyInsettableShape {
        if isExpanded {
            AnyInsettableShape(Capsule(style: .continuous))
        } else {
            AnyInsettableShape(Circle())
        }
    }
}

private struct AnyInsettableShape: InsettableShape {
    private let pathBuilder: @Sendable (CGRect) -> Path
    private let insetBuilder: @Sendable (CGFloat) -> AnyInsettableShape

    init<S: InsettableShape>(_ shape: S) {
        pathBuilder = { rect in
            shape.path(in: rect)
        }
        insetBuilder = { amount in
            AnyInsettableShape(shape.inset(by: amount))
        }
    }

    func path(in rect: CGRect) -> Path {
        pathBuilder(rect)
    }

    func inset(by amount: CGFloat) -> AnyInsettableShape {
        insetBuilder(amount)
    }
}
