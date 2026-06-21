import AppKit
@preconcurrency import KeyboardShortcuts
import QuartzCore
import SwiftUI

struct NoteWindowView: View {
    @Environment(\.colorScheme) private var colorScheme
    var settings: AppSettings
    @Bindable var noteStore: NoteStore
    var clipboardStore: ClipboardStore

    let updateActions: UpdateCheckingActions
    let onClose: () -> Void

    @State private var overlayController = NoteWindowOverlayController()
    @State private var moreButtonFrame: CGRect = .zero
    @State private var fileSwitchButtonFrame: CGRect = .zero
    @State private var emphasisButtonFrame: CGRect = .zero
    @State private var clipboardSuggestion = NoteClipboardSuggestionController()
    @State private var chromeAutoHide = NoteChromeAutoHideController()
    @State private var documentSwipe = NoteDocumentSwipeCoordinator()
    @State private var contentEditorViewportSize: CGSize = .zero
    @State private var emphasisCommandSerial = 0
    @State private var emphasisCommand: MarkdownEmphasisCommand?
    @Namespace private var extractionIslandNamespace

    private var copy: AppText {
        settings.localizedText
    }

    private var glassMetrics: NoteGlassMetrics {
        NoteGlassMetrics(
            noteOpacity: settings.noteOpacity,
            glassStrength: settings.glassStrength,
            minimumNoteOpacity: AppSettings.minimumNoteOpacity
        )
    }

    private var chromePalette: NoteWindowChromePalette {
        NoteWindowChromePalette(colorScheme: colorScheme)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            NoteWindowShellBackground(
                glassMetrics: glassMetrics,
                accentColor: settings.accentColor
            )

            VStack(spacing: 0) {
                topBar

                content
                    .padding(.top, contentTopPadding)
                    .padding(.bottom, contentBottomInset)
            }

            bottomChromeControl
        }
        .clipShape(RoundedRectangle(cornerRadius: NoteWindowChromeLayout.shellCornerRadius, style: .continuous))
        .background {
            ZStack {
                WindowActivityMonitorView { _ in
                    markChromeActivity(revealIfCollapsed: false)
                }
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)

                DocumentSwipeMonitorView(
                    isEnabled: documentSwipeEnabled,
                    onProgress: { progress in
                        documentSwipe.updateProgress(progress, noteStore: noteStore)
                    },
                    onCancel: {
                        documentSwipe.cancel()
                    },
                    onNext: {
                        documentSwipe.commit(offset: 1, noteStore: noteStore) {
                            markChromeActivity(revealIfCollapsed: true, forceReschedule: true)
                        }
                    },
                    onPrevious: {
                        documentSwipe.commit(offset: -1, noteStore: noteStore) {
                            markChromeActivity(revealIfCollapsed: true, forceReschedule: true)
                        }
                    }
                )
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
            }
        }
        .overlay { activeInlineOverlay }
        .overlay {
            if !settings.hasCompletedOnboarding {
                OnboardingView(
                    settings: settings,
                    updateActions: updateActions
                ) {
                    markChromeActivity(forceReschedule: true)
                }
                .zIndex(80)
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
        .onPreferenceChange(EmphasisButtonFramePreferenceKey.self) { frame in
            emphasisButtonFrame = frame
        }
        .sheet(isPresented: shortcutSettingsPresented) {
            ShortcutSettingsView(settings: settings)
                .frame(width: NoteWindowChromeLayout.shortcutSheetWidth)
                .padding(NoteWindowChromeLayout.shortcutSheetPadding)
        }
        .onReceive(NotificationCenter.default.publisher(for: .quietNoteToggleClipboard)) { _ in
            withAnimation(.snappy(duration: NoteWindowTiming.overlayToggleAnimation)) {
                chromeAutoHide.controlsCollapsed = false
                toggleClipboardOverlay()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .quietNoteApplyOneTapEmphasis)) { _ in
            issueEmphasisCommand(settings.oneTapEmphasisStyles)
            markChromeActivity(revealIfCollapsed: true, forceReschedule: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            closeTransientOverlaysOnFocusLoss()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            closeTransientOverlaysOnFocusLoss()
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)) { notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier != Bundle.main.bundleIdentifier
            else { return }
            closeTransientOverlaysOnFocusLoss()
        }
        .onChange(of: activeOverlay) { _, overlay in
            if overlay == .shortcutSettings {
                chromeAutoHide.expandImmediately()
            }
        }
        .onChange(of: clipboardStore.latestDetectedItem?.id) { _, itemID in
            clipboardSuggestion.scheduleReset(for: itemID) {
                overlayController.closeExtractionActions()
            }
            markChromeActivity(revealIfCollapsed: false)
        }
        .onChange(of: bottomChromeShouldStayExpanded) { _, shouldStayExpanded in
            chromeAutoHide.handlePinnedStateChange(
                shouldStayExpanded: shouldStayExpanded,
                autoHideEnabled: settings.autoHideChrome
            )
        }
        .onChange(of: settings.autoHideChrome) { _, shouldAutoHide in
            chromeAutoHide.handleAutoHideSettingChange(
                isEnabled: shouldAutoHide,
                shouldStayExpanded: bottomChromeShouldStayExpanded
            )
        }
        .onChange(of: noteStore.markdown) { _, _ in
            markChromeActivity(revealIfCollapsed: false)
        }
        .task(id: documentSwipePrewarmKey) {
            await prewarmDocumentSwipePreviews()
        }
        .onAppear {
            markChromeActivity(forceReschedule: true)
        }
        .onDisappear {
            clipboardSuggestion.cancelTasks()
            chromeAutoHide.cancelTasks()
            documentSwipe.cancelTasks()
        }
        .animation(.snappy(duration: NoteWindowTiming.overlayToggleAnimation), value: activeOverlay)
        .animation(.snappy(duration: NoteWindowTiming.chromeStateAnimation), value: clipboardStore.latestDetectedItem?.id)
        .animation(.snappy(duration: NoteWindowTiming.chromeStateAnimation), value: clipboardSuggestion.hiddenItemID)
        .animation(.snappy(duration: NoteWindowTiming.chromeStateAnimation), value: chromeAutoHide.controlsCollapsed)
        .preferredColorScheme(settings.resolvedColorScheme)
    }

    @ViewBuilder
    private var activeInlineOverlay: some View {
        switch activeOverlay {
        case .clipboard:
            clipboardInlineOverlay
        case .more:
            moreInlineOverlay
        case .fileSwitcher:
            fileSwitcherInlineOverlay
        case .emphasis:
            emphasisInlineOverlay
        case .extractionActions:
            if let item = activeDetectedItem {
                extractionActionsInlineOverlay(item: item)
            }
        case .shortcutSettings, nil:
            EmptyView()
        }
    }

    @ViewBuilder
    private var clipboardInlineOverlay: some View {
        GeometryReader { proxy in
            let panelWidth = min(
                NoteWindowChromeLayout.clipboardPanelMaxWidth,
                max(
                    NoteWindowChromeLayout.clipboardPanelMinWidth,
                    proxy.size.width - NoteWindowChromeLayout.clipboardPanelHorizontalReserve
                )
            )
            let panelHeight = min(
                NoteWindowChromeLayout.clipboardPanelMaxHeight,
                max(
                    NoteWindowChromeLayout.clipboardPanelMinHeight,
                    proxy.size.height - NoteWindowChromeLayout.clipboardPanelVerticalReserve
                )
            )

            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: topDragPassthroughHeight)
                        .allowsHitTesting(false)

                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.snappy(duration: NoteWindowTiming.overlayToggleAnimation)) {
                                closeTransientOverlays()
                            }
                        }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                ClipboardLibraryView(settings: settings, store: clipboardStore)
                    .frame(width: panelWidth, height: panelHeight)
                    .floatingReadablePopupPanel(accentColor: settings.accentColor)
                    .padding(.top, NoteWindowChromeLayout.clipboardPanelTopPadding)
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
            let metrics = NoteWindowOverlayLayout.moreMenuMetrics(
                in: proxy.size,
                anchorFrame: moreButtonFrame,
                topDragPassthroughHeight: topDragPassthroughHeight
            )

            ZStack(alignment: .topLeading) {
                dismissBackdropWithTopDragPassthrough {
                        withAnimation(.snappy(duration: NoteWindowTiming.overlayDismissAnimation)) {
                            closeTransientOverlays()
                        }
                }

                MoreMenuView(
                    settings: settings,
                    clipboardStore: clipboardStore,
                    updateActions: updateActions,
                    showShortcutSettings: shortcutSettingsPresented,
                    onClose: {
                        closeTransientOverlays()
                        onClose()
                    }
                )
                .frame(width: metrics.width, height: metrics.height)
                .floatingReadablePopupPanel(accentColor: settings.accentColor)
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
            let metrics = NoteWindowOverlayLayout.fileSwitcherMetrics(
                in: proxy.size,
                anchorFrame: fileSwitchButtonFrame,
                documentCount: noteStore.activeWorkspaceFileURLs.count,
                topDragPassthroughHeight: topDragPassthroughHeight
            )

            ZStack(alignment: .topLeading) {
                dismissBackdropWithTopDragPassthrough {
                        withAnimation(.snappy(duration: NoteWindowTiming.overlayDismissAnimation)) {
                            closeTransientOverlays()
                        }
                }

                FileSwitcherView(
                    settings: settings,
                    noteStore: noteStore,
                    createMarkdownFile: {
                        withAnimation(.snappy(duration: NoteWindowTiming.overlayDismissAnimation)) {
                            closeTransientOverlays()
                        }
                        createMarkdownFile()
                    },
                    openExistingFile: {
                        withAnimation(.snappy(duration: NoteWindowTiming.overlayDismissAnimation)) {
                            closeTransientOverlays()
                        }
                        openNoteFile()
                    },
                    createWorkspace: {
                        createWorkspaceFromPanel()
                    },
                    switchWorkspace: { workspaceID in
                        withAnimation(.snappy(duration: NoteWindowTiming.overlayDismissAnimation)) {
                            closeTransientOverlays()
                        }
                        noteStore.switchWorkspace(to: workspaceID)
                    },
                    openWorkspaceFile: { url in
                        withAnimation(.snappy(duration: NoteWindowTiming.overlayDismissAnimation)) {
                            closeTransientOverlays()
                        }
                        noteStore.openWorkspaceDocument(at: url)
                    },
                    removeWorkspaceFile: { url in
                        noteStore.removeFileFromActiveWorkspace(url)
                    }
                )
                .frame(width: metrics.width, height: metrics.height)
                .floatingReadablePopupPanel(accentColor: settings.accentColor)
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

    @ViewBuilder
    private var emphasisInlineOverlay: some View {
        GeometryReader { proxy in
            let metrics = NoteWindowOverlayLayout.emphasisMetrics(
                in: proxy.size,
                anchorFrame: emphasisButtonFrame,
                topDragPassthroughHeight: topDragPassthroughHeight
            )

            ZStack(alignment: .topLeading) {
                dismissBackdropWithTopDragPassthrough {
                    withAnimation(.snappy(duration: NoteWindowTiming.overlayDismissAnimation)) {
                        closeTransientOverlays()
                    }
                }

                EmphasisFormattingPanelView(
                    settings: settings,
                    copy: copy,
                    applyStyles: { styles in
                        issueEmphasisCommand(styles)
                    }
                )
                .frame(width: metrics.width, height: metrics.height)
                .floatingReadablePopupPanel(accentColor: settings.accentColor)
                .position(x: metrics.centerX, y: metrics.centerY)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95, anchor: .bottom).combined(with: .opacity),
                    removal: .scale(scale: 0.985, anchor: .bottom).combined(with: .opacity)
                ))
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .zIndex(33)
        }
    }

    private func extractionActionsInlineOverlay(item: ClipboardItem) -> some View {
        GeometryReader { proxy in
            let panelWidth = min(
                NoteWindowChromeLayout.extractionPanelMaxWidth,
                max(
                    NoteWindowChromeLayout.extractionPanelMinWidth,
                    proxy.size.width - NoteWindowChromeLayout.extractionPanelHorizontalReserve
                )
            )
            let panelMaxHeight = min(
                NoteWindowChromeLayout.extractionPanelMaxHeight,
                max(
                    NoteWindowChromeLayout.extractionPanelMinHeight,
                    proxy.size.height - NoteWindowChromeLayout.extractionPanelVerticalReserve
                )
            )

            ZStack(alignment: .top) {
                dismissBackdropWithTopDragPassthrough {
                    withAnimation(.snappy(duration: NoteWindowTiming.overlayDismissAnimation)) {
                        closeTransientOverlays()
                    }
                }

                ClipboardExtractionActionsPanelView(
                    settings: settings,
                    item: item,
                    copy: copy,
                    maxHeight: panelMaxHeight,
                    copyDetection: { detection in
                        clipboardStore.copy(detection.value)
                    },
                    openDetection: { detection in
                        closeTransientOverlays()
                        clipboardStore.open(detection)
                    }
                )
                    .frame(width: panelWidth)
                    .frame(maxHeight: panelMaxHeight)
                    .padding(.top, NoteWindowChromeLayout.extractionPanelTopPadding)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.96, anchor: .top).combined(with: .opacity),
                        removal: .scale(scale: 0.985, anchor: .top).combined(with: .opacity)
                    ))
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .zIndex(34)
        }
    }

    private var topBar: some View {
        ZStack {
            WindowDragView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if topChromeCollapsed {
                collapsedTopChromeHandle
                    .padding(.top, NoteWindowChromeLayout.collapsedTopHandleTopPadding)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.72, anchor: .top).combined(with: .opacity),
                        removal: .scale(scale: 0.92, anchor: .top).combined(with: .opacity)
                    ))
            } else {
                NoteTopIslandView(
                    title: noteStore.displayTitle,
                    detectedItem: activeDetectedItem,
                    copy: copy,
                    glassMetrics: glassMetrics,
                    accentColor: settings.accentColor,
                    palette: chromePalette,
                    namespace: extractionIslandNamespace,
                    toggleClipboard: toggleClipboardOverlay,
                    toggleExtractionActions: toggleExtractionActionsOverlay
                )
                    .padding(.top, NoteWindowChromeLayout.expandedTopIslandTopPadding)
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

    private var content: some View {
        NoteContentEditorView(
            text: $noteStore.markdown,
            documentID: noteStore.currentFileURL.standardizedFileURL.path,
            contentRevision: noteStore.markdownRevision,
            documentPosition: noteStore.currentDocumentPosition,
            preview: documentSwipe.preview,
            swipeProgress: documentSwipe.progress,
            fontSize: settings.editorFontSize,
            accentColor: settings.accentNSColor,
            emphasisCommand: emphasisCommand,
            topFadeHeight: markdownTopFadeHeight,
            bottomFadeHeight: markdownBottomFadeHeight,
            contentLeadingInset: NoteWindowChromeLayout.contentLeadingPadding,
            contentTrailingInset: NoteWindowChromeLayout.contentTrailingPadding,
            onEditorViewportChange: { size in
                updateContentEditorViewportSize(size)
            }
        ) { position in
            noteStore.updateCurrentDocumentPosition(position)
        }
    }

    private var bottomRailHeight: CGFloat {
        NoteWindowChromeLayout.bottomRailHeight
    }

    private var collapsedBottomChromeHeight: CGFloat {
        NoteWindowChromeLayout.collapsedBottomChromeHeight
    }

    private var markdownBottomFadeHeight: CGFloat {
        bottomChromeCollapsed
            ? NoteWindowChromeLayout.collapsedMarkdownBottomFadeHeight
            : NoteWindowChromeLayout.expandedMarkdownBottomFadeHeight
    }

    private var markdownTopFadeHeight: CGFloat {
        topChromeCollapsed
            ? NoteWindowChromeLayout.collapsedMarkdownTopFadeHeight
            : NoteWindowChromeLayout.expandedMarkdownTopFadeHeight
    }

    private var contentBottomInset: CGFloat {
        bottomChromeCollapsed
            ? NoteWindowChromeLayout.collapsedContentBottomInset
            : bottomRailHeight
    }

    private var contentTopPadding: CGFloat {
        topChromeCollapsed
            ? NoteWindowChromeLayout.collapsedContentTopPadding
            : NoteWindowChromeLayout.expandedContentTopPadding
    }

    private var topBarHeight: CGFloat {
        topChromeCollapsed
            ? NoteWindowChromeLayout.collapsedTopBarHeight
            : NoteWindowChromeLayout.expandedTopBarHeight
    }

    private var topChromeCollapsed: Bool {
        settings.autoHideChrome && chromeAutoHide.controlsCollapsed && activeDetectedItem == nil && activeOverlay != .extractionActions
    }

    private var bottomChromeCollapsed: Bool {
        settings.autoHideChrome && chromeAutoHide.controlsCollapsed && !bottomChromeShouldStayExpanded
    }

    private var bottomChromeShouldStayExpanded: Bool {
        overlayController.keepsBottomChromeExpanded
    }

    private var documentSwipeEnabled: Bool {
        settings.hasCompletedOnboarding
            && noteStore.canSwitchWorkspaceDocument
            && !documentSwipe.isAnimating
            && activeOverlay == nil
    }

    private var documentSwipePrewarmKey: String {
        let workspacePaths = noteStore.activeWorkspaceFileURLs
            .map { $0.standardizedFileURL.path }
            .joined(separator: "\u{1F}")
        let viewportWidth = Int((contentEditorViewportSize.width * 100).rounded())
        let viewportHeight = Int((contentEditorViewportSize.height * 100).rounded())
        let fontSize = Int((settings.editorFontSize * 100).rounded())

        return [
            noteStore.currentFileURL.standardizedFileURL.path,
            workspacePaths,
            "\(viewportWidth)x\(viewportHeight)",
            "\(fontSize)",
            settings.themeColor.rawValue,
            settings.hasCompletedOnboarding ? "ready" : "onboarding"
        ].joined(separator: "\u{1E}")
    }

    private func updateContentEditorViewportSize(_ size: CGSize) {
        let normalizedSize = CGSize(
            width: max(0, size.width),
            height: max(0, size.height)
        )
        guard abs(normalizedSize.width - contentEditorViewportSize.width) > 0.5
            || abs(normalizedSize.height - contentEditorViewportSize.height) > 0.5
        else { return }

        contentEditorViewportSize = normalizedSize
    }

    private func prewarmDocumentSwipePreviews() async {
        guard settings.hasCompletedOnboarding,
              noteStore.canSwitchWorkspaceDocument,
              contentEditorViewportSize.width > 1,
              contentEditorViewportSize.height > 1
        else { return }

        await documentSwipe.prewarmAdjacentPreviews(
            noteStore: noteStore,
            viewportSize: contentEditorViewportSize,
            backingScale: NSScreen.main?.backingScaleFactor ?? 2,
            fontSize: settings.editorFontSize,
            accentColor: settings.accentNSColor
        )
    }

    private var topDragPassthroughHeight: CGFloat {
        NoteWindowChromeLayout.topDragPassthroughHeight
    }

    private var hasTransientOverlay: Bool {
        overlayController.hasInlinePanel
    }

    private var shortcutSettingsPresented: Binding<Bool> {
        Binding(
            get: {
                overlayController.isShortcutSettingsPresented
            },
            set: { isPresented in
                overlayController.setShortcutSettingsPresented(isPresented)
            }
        )
    }

    private var activeOverlay: NoteWindowTransientOverlay? {
        overlayController.activeOverlay
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

    private func closeTransientOverlays() {
        overlayController.closeInlinePanels()
    }

    private func closeTransientOverlaysOnFocusLoss() {
        guard hasTransientOverlay else { return }
        withAnimation(.snappy(duration: NoteWindowTiming.overlayDismissAnimation)) {
            closeTransientOverlays()
        }
    }

    private func toggleClipboardOverlay() {
        toggleOverlay(.clipboard)
    }

    private func toggleMoreOverlay() {
        toggleOverlay(.more)
    }

    private func toggleEmphasisOverlay() {
        toggleOverlay(.emphasis)
    }

    private func toggleFileSwitcherOverlay() {
        toggleOverlay(.fileSwitcher)
    }

    private func toggleExtractionActionsOverlay() {
        toggleOverlay(.extractionActions)
    }

    private func issueEmphasisCommand(_ styles: MarkdownEmphasisStyle) {
        let normalizedStyles = AppSettings.normalizedOneTapEmphasisStyles(styles.rawValue)
        emphasisCommandSerial &+= 1
        emphasisCommand = MarkdownEmphasisCommand(id: emphasisCommandSerial, styles: normalizedStyles)
    }

    private func toggleOverlay(_ overlay: NoteWindowTransientOverlay) {
        overlayController.toggle(overlay)
    }

    private func markChromeActivity(revealIfCollapsed: Bool = true, forceReschedule: Bool = false) {
        chromeAutoHide.markActivity(
            autoHideEnabled: settings.autoHideChrome,
            shouldStayExpanded: bottomChromeShouldStayExpanded,
            revealIfCollapsed: revealIfCollapsed,
            forceReschedule: forceReschedule
        )
    }

    private func revealChromeControls() {
        chromeAutoHide.revealControls(
            autoHideEnabled: settings.autoHideChrome,
            shouldStayExpanded: bottomChromeShouldStayExpanded
        )
    }

    @ViewBuilder
    private var bottomChromeControl: some View {
        if bottomChromeCollapsed {
            collapsedBottomChromeHandle
                .padding(.bottom, NoteWindowChromeLayout.collapsedBottomHandleBottomPadding)
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
        NoteCollapsedTopChromeHandleView(
            detection: activeDetectedItem?.detections.first,
            copy: copy,
            glassMetrics: glassMetrics,
            accentColor: settings.accentColor,
            palette: chromePalette,
            isPulsing: chromeAutoHide.hintPulse,
            revealControls: revealChromeControls
        )
    }

    private var collapsedBottomChromeHandle: some View {
        NoteCollapsedBottomChromeHandleView(
            noteOpacity: settings.noteOpacity,
            height: collapsedBottomChromeHeight,
            copy: copy,
            glassMetrics: glassMetrics,
            accentColor: settings.accentColor,
            palette: chromePalette,
            isPulsing: chromeAutoHide.hintPulse,
            revealControls: revealChromeControls
        )
    }

    private var bottomRail: some View {
        NoteBottomRailView(
            settings: settings,
            copy: copy,
            glassMetrics: glassMetrics,
            height: bottomRailHeight,
            toggleFileSwitcher: {
                withAnimation(.snappy(duration: NoteWindowTiming.overlayDismissAnimation)) {
                    toggleFileSwitcherOverlay()
                }
            },
            toggleEmphasis: {
                withAnimation(.snappy(duration: NoteWindowTiming.overlayDismissAnimation)) {
                    toggleEmphasisOverlay()
                }
            },
            saveAs: {
                saveNoteFileAs()
            },
            toggleAlwaysOnTop: {
                settings.alwaysOnTop.toggle()
            },
            toggleAutoHideChrome: {
                withAnimation(.snappy(duration: NoteWindowTiming.chromeExpandAnimation)) {
                    settings.autoHideChrome.toggle()
                    if !settings.autoHideChrome {
                        chromeAutoHide.controlsCollapsed = false
                    }
                }
            },
            toggleMore: {
                withAnimation(.snappy(duration: NoteWindowTiming.overlayDismissAnimation)) {
                    toggleMoreOverlay()
                }
            },
            close: {
                closeTransientOverlays()
                onClose()
            }
        )
    }

    private func openNoteFile() {
        NoteFilePanelActions.openNoteFile(noteStore: noteStore)
    }

    private func createMarkdownFile() {
        NoteFilePanelActions.createMarkdownFile(noteStore: noteStore, copy: copy)
    }

    private func saveNoteFileAs() {
        NoteFilePanelActions.saveNoteFileAs(noteStore: noteStore)
    }

    private func createWorkspaceFromPanel() {
        NoteFilePanelActions.createWorkspace(noteStore: noteStore, copy: copy)
    }

    private var activeDetectedItem: ClipboardItem? {
        clipboardSuggestion.activeItem(
            from: clipboardStore.latestDetectedItem,
            isSuppressedByOverlay: overlayController.hidesDetectedClipboardItem
        )
    }

}
