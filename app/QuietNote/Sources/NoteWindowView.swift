import AppKit
@preconcurrency import KeyboardShortcuts
import QuartzCore
import SwiftUI
import UniformTypeIdentifiers

struct NoteWindowView: View {
    @Environment(\.colorScheme) private var colorScheme
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
    @State private var chromeHintPulseTask: Task<Void, Never>?
    @State private var documentSwipeProgress: CGFloat = 0
    @State private var isDocumentSwipeAnimating = false
    @State private var documentSwipePreview: DocumentSwipePreview?
    @State private var documentSwipePreviewRevision = 0
    @Namespace private var extractionIslandNamespace

    private struct DocumentSwipePreview: Identifiable, Equatable {
        let id: String
        let offset: Int
        let text: String
        let revision: Int
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(shellMaterialOpacity)
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
            ZStack {
                WindowActivityMonitorView { _ in
                    markChromeActivity(revealIfCollapsed: false)
                }
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)

                DocumentSwipeMonitorView(
                    isEnabled: documentSwipeEnabled,
                    onProgress: { progress in
                        updateDocumentSwipeProgress(progress)
                    },
                    onCancel: {
                        cancelDocumentSwipe()
                    },
                    onNext: {
                        commitDocumentSwipe(offset: 1)
                    },
                    onPrevious: {
                        commitDocumentSwipe(offset: -1)
                    }
                )
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
            }
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
        .overlay {
            if showExtractionActions,
               let item = activeDetectedItem {
                extractionActionsInlineOverlay(item: item)
            }
        }
        .overlay {
            if !settings.hasCompletedOnboarding {
                OnboardingView(settings: settings) {
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
        .sheet(isPresented: $showShortcutSettings) {
            ShortcutSettingsView(settings: settings)
                .frame(width: 360)
                .padding(16)
        }
        .onReceive(NotificationCenter.default.publisher(for: .quietNoteToggleClipboard)) { _ in
            withAnimation(.snappy(duration: 0.16)) {
                chromeControlsCollapsed = false
                toggleClipboardOverlay()
            }
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
        .onChange(of: showShortcutSettings) { _, isPresented in
            if isPresented {
                chromeControlsCollapsed = false
                closeTransientOverlays()
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
            markChromeActivity(forceReschedule: true)
        }
        .onDisappear {
            suggestionResetTask?.cancel()
            chromeCollapseTask?.cancel()
            chromeHintPulseTask?.cancel()
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
                                closeTransientOverlays()
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
                            closeTransientOverlays()
                        }
                }

                MoreMenuView(
                    settings: settings,
                    clipboardStore: clipboardStore,
                    showShortcutSettings: $showShortcutSettings,
                    onClose: {
                        closeTransientOverlays()
                        onClose()
                    }
                )
                .frame(width: metrics.width, height: metrics.height)
                .background {
                    readablePopupPanelBackground()
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
                            closeTransientOverlays()
                        }
                }

                FileSwitcherView(
                    settings: settings,
                    noteStore: noteStore,
                    createMarkdownFile: {
                        withAnimation(.snappy(duration: 0.14)) {
                            closeTransientOverlays()
                        }
                        createMarkdownFile()
                    },
                    openExistingFile: {
                        withAnimation(.snappy(duration: 0.14)) {
                            closeTransientOverlays()
                        }
                        openNoteFile()
                    },
                    createWorkspace: {
                        createWorkspaceFromPanel()
                    },
                    switchWorkspace: { workspaceID in
                        withAnimation(.snappy(duration: 0.14)) {
                            closeTransientOverlays()
                        }
                        noteStore.switchWorkspace(to: workspaceID)
                    },
                    openWorkspaceFile: { url in
                        withAnimation(.snappy(duration: 0.14)) {
                            closeTransientOverlays()
                        }
                        noteStore.openWorkspaceDocument(at: url)
                    },
                    removeWorkspaceFile: { url in
                        noteStore.removeFileFromActiveWorkspace(url)
                    }
                )
                .frame(width: metrics.width, height: metrics.height)
                .background {
                    readablePopupPanelBackground()
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

    private func extractionActionsInlineOverlay(item: ClipboardItem) -> some View {
        GeometryReader { proxy in
            let panelWidth = min(310, max(238, proxy.size.width - 24))
            let panelMaxHeight = min(360, max(150, proxy.size.height - 54))

            ZStack(alignment: .top) {
                dismissBackdropWithTopDragPassthrough {
                    withAnimation(.snappy(duration: 0.14)) {
                        closeTransientOverlays()
                    }
                }

                extractionActionsPanel(item: item, maxHeight: panelMaxHeight)
                    .frame(width: panelWidth)
                    .frame(maxHeight: panelMaxHeight)
                    .padding(.top, 39)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.96, anchor: .top).combined(with: .opacity),
                        removal: .scale(scale: 0.985, anchor: .top).combined(with: .opacity)
                    ))
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .zIndex(34)
        }
    }

    private var readabilityLayer: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.white.opacity(shellHazeOpacity))
            .blendMode(.plusLighter)
    }

    private var themeTintLayer: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(settings.accentColor.opacity(shellTintOpacity))
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
            .opacity(min(0.98, 0.18 + shellVisibilityCurve * 0.56 + glassTextureCurve * 0.28))
    }

    private var topBar: some View {
        ZStack {
            WindowDragView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if topChromeCollapsed {
                collapsedTopChromeHandle
                    .padding(.top, 6)
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
        GeometryReader { proxy in
            ZStack {
                MarkdownRenderingEditor(
                    text: $noteStore.markdown,
                    contentRevision: noteStore.markdownRevision,
                    fontSize: settings.editorFontSize,
                    accentColor: settings.accentNSColor
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
                .offset(x: documentSwipeCurrentOffset(for: proxy.size.width))

                if let documentSwipePreview {
                    MarkdownRenderingEditor(
                        text: .constant(documentSwipePreview.text),
                        contentRevision: documentSwipePreview.revision,
                        fontSize: settings.editorFontSize,
                        accentColor: settings.accentNSColor
                    )
                    .id(documentSwipePreview.id)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .offset(x: documentSwipePreviewOffset(for: proxy.size.width, preview: documentSwipePreview))
                    .allowsHitTesting(false)
                }
            }
            .mask {
                markdownContentFadeMask
            }
        }
        .clipped()
    }

    private var bottomRailHeight: CGFloat {
        36
    }

    private var collapsedBottomChromeHeight: CGFloat {
        16
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
        topChromeCollapsed ? 18 : 35
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

    private var shellMaterialOpacity: Double {
        min(0.60, 0.08 + settings.noteOpacity * 0.40 + glassTextureCurve * 0.12)
    }

    private var shellHazeOpacity: Double {
        min(0.166, 0.006 + shellVisibilityCurve * 0.150 + glassTextureCurve * 0.010)
    }

    private var shellTintOpacity: Double {
        min(0.074, 0.005 + shellVisibilityCurve * 0.014 + glassTextureCurve * 0.055)
    }

    private var shellVisibilityCurve: Double {
        pow(settings.noteOpacity, 2.4)
    }

    private var glassTextureCurve: Double {
        pow(settings.glassStrength, 1.10)
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

    private var topChromeHelpDelay: TimeInterval {
        1.5
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

    private var documentSwipeEnabled: Bool {
        settings.hasCompletedOnboarding
            && noteStore.canSwitchWorkspaceDocument
            && !isDocumentSwipeAnimating
            && !showClipboard
            && !showMore
            && !showFileSwitcher
            && !showExtractionActions
            && !showShortcutSettings
    }

    private var topDragPassthroughHeight: CGFloat {
        38
    }

    private var hasTransientOverlay: Bool {
        showClipboard || showMore || showFileSwitcher || showExtractionActions
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
        showClipboard = false
        showMore = false
        showFileSwitcher = false
        showExtractionActions = false
    }

    private func closeTransientOverlaysOnFocusLoss() {
        guard hasTransientOverlay else { return }
        withAnimation(.snappy(duration: 0.14)) {
            closeTransientOverlays()
        }
    }

    private func toggleClipboardOverlay() {
        let shouldShow = !showClipboard
        closeTransientOverlays()
        showClipboard = shouldShow
    }

    private func toggleMoreOverlay() {
        let shouldShow = !showMore
        closeTransientOverlays()
        showMore = shouldShow
    }

    private func toggleFileSwitcherOverlay() {
        let shouldShow = !showFileSwitcher
        closeTransientOverlays()
        showFileSwitcher = shouldShow
    }

    private func toggleExtractionActionsOverlay() {
        let shouldShow = !showExtractionActions
        closeTransientOverlays()
        showExtractionActions = shouldShow
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

    private func updateDocumentSwipeProgress(_ progress: CGFloat) {
        guard !isDocumentSwipeAnimating else { return }
        guard abs(progress) > 0.001 else {
            cancelDocumentSwipe()
            return
        }

        let direction = progress > 0 ? 1 : -1
        prepareDocumentSwipePreview(offset: direction)
        guard documentSwipePreview?.offset == direction else {
            cancelDocumentSwipe()
            return
        }

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            documentSwipeProgress = progress
        }
    }

    private func cancelDocumentSwipe() {
        guard abs(documentSwipeProgress) > 0.001 else { return }
        withAnimation(.snappy(duration: 0.18)) {
            documentSwipeProgress = 0
        }
        clearDocumentSwipePreviewAfterDelay(0.20)
    }

    private func commitDocumentSwipe(offset: Int) {
        guard !isDocumentSwipeAnimating else { return }

        let direction = offset > 0 ? 1 : -1
        let signedDirection = CGFloat(direction)
        prepareDocumentSwipePreview(offset: direction)
        guard documentSwipePreview?.offset == direction else {
            cancelDocumentSwipe()
            return
        }

        isDocumentSwipeAnimating = true

        withAnimation(.snappy(duration: 0.16)) {
            documentSwipeProgress = signedDirection
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            let didSwitch = direction > 0
                ? noteStore.switchToNextDocument()
                : noteStore.switchToPreviousDocument()

            if didSwitch {
                markChromeActivity(revealIfCollapsed: true, forceReschedule: true)
                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    documentSwipeProgress = 0
                    documentSwipePreview = nil
                }
            } else {
                withAnimation(.snappy(duration: 0.18)) {
                    documentSwipeProgress = 0
                }
                clearDocumentSwipePreviewAfterDelay(0.20)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
                isDocumentSwipeAnimating = false
            }
        }
    }

    private func prepareDocumentSwipePreview(offset: Int) {
        guard offset != 0 else { return }
        if documentSwipePreview?.offset == offset {
            return
        }

        guard let preview = noteStore.workspaceDocumentPreview(offset: offset) else {
            documentSwipePreview = nil
            return
        }

        documentSwipePreviewRevision &+= 1
        documentSwipePreview = DocumentSwipePreview(
            id: "\(preview.url.standardizedFileURL.path)#\(documentSwipePreviewRevision)",
            offset: offset,
            text: preview.text,
            revision: documentSwipePreviewRevision
        )
    }

    private func clearDocumentSwipePreviewAfterDelay(_ delay: TimeInterval) {
        let previewID = documentSwipePreview?.id
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard documentSwipePreview?.id == previewID,
                  abs(documentSwipeProgress) <= 0.001,
                  !isDocumentSwipeAnimating
            else { return }
            documentSwipePreview = nil
        }
    }

    private func documentSwipeCurrentOffset(for width: CGFloat) -> CGFloat {
        -documentSwipeProgress * documentSwipeDistance(for: width)
    }

    private func documentSwipePreviewOffset(for width: CGFloat, preview: DocumentSwipePreview) -> CGFloat {
        let distance = documentSwipeDistance(for: width)
        return CGFloat(preview.offset) * distance - documentSwipeProgress * distance
    }

    private func documentSwipeDistance(for width: CGFloat) -> CGFloat {
        max(1, width)
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
            triggerChromeHintPulse()
        }
    }

    private func triggerChromeHintPulse() {
        chromeHintPulseTask?.cancel()
        chromeHintPulse = false
        chromeHintPulseTask = Task { @MainActor in
            withAnimation(.easeInOut(duration: 0.26)) {
                chromeHintPulse = true
            }
            try? await Task.sleep(for: .milliseconds(850))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.42)) {
                chromeHintPulse = false
            }
        }
    }

    private var islandTextColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.90 : 0.82)
    }

    private var islandIconColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.92 : 0.86)
    }

    private var detectedIslandTextColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.92 : 0.82)
    }

    private var detectedIslandIconColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.94 : 0.86)
    }

    private var islandSoftShadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.46) : Color.white.opacity(0.58)
    }

    private var detectedIslandHighlightColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.42) : Color.white.opacity(0.58)
    }

    private var controlInkColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.90 : 0.84)
    }

    private var controlStrongInkColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.94 : 0.86)
    }

    private var controlSoftInkColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.76 : 0.76)
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
                    Capsule(style: .continuous)
                        .fill(islandIconColor.opacity(0.56))
                        .frame(width: 17, height: 2)
                }
            }
            .allowsHitTesting(false)

            WindowClickDragView(onClick: {
                revealChromeControls()
            }, dragStartsImmediately: true)
        }
        .frame(width: width, height: 14)
        .modifier(ExtractionIslandButtonModifier(isExpanded: true, opacity: collapsedChromeOpacity, accentColor: settings.accentColor))
        .contentShape(Capsule(style: .continuous))
        .delayedInlineHelp(AppText(language: settings.language).showControls, delay: topChromeHelpDelay, yOffset: 24)
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

            WindowClickDragView(onClick: {
                revealChromeControls()
            }, dragStartsImmediately: true)
        }
        .frame(width: 58, height: collapsedBottomChromeHeight)
        .modifier(ExtractionIslandButtonModifier(isExpanded: true, opacity: collapsedChromeOpacity, accentColor: settings.accentColor))
        .contentShape(Capsule(style: .continuous))
        .help(AppText(language: settings.language).showControls)
    }

    private var collapsedHandlePulseOverlay: some View {
        Capsule(style: .continuous)
            .fill(settings.accentColor.opacity(chromeHintPulse ? 0.10 : 0.035))
            .scaleEffect(chromeHintPulse ? 1.04 : 0.98)
            .blur(radius: chromeHintPulse ? 2.4 : 1.2)
            .opacity(chromeHintPulse ? 0.62 : 0.28)
            .allowsHitTesting(false)
    }

    private var bottomRail: some View {
        let copy = AppText(language: settings.language)

        return GeometryReader { proxy in
            let progress = railCompactProgress(for: proxy.size.width)
            let spacing = 7 - progress * 3.5
            let horizontalPadding = 12 - progress * 6
            let sliderMinWidth = 84 - progress * 56
            let buttonSize = 23 - progress * 3
            let labelFontSize = 11.5 - progress * 1.2
            let percentWidth = 34 - progress * 5

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
                        toggleFileSwitcherOverlay()
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
                        toggleMoreOverlay()
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
                railButton(symbol: "xmark", help: copy.close, size: buttonSize, hitSize: max(30, buttonSize + 8)) {
                    closeTransientOverlays()
                    onClose()
                }
            }
            .padding(.horizontal, horizontalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: bottomRailHeight)
        .contentShape(Rectangle())
        .onTapGesture {}
        .background { bottomRailLiquidGlassBackground }
    }

    private var bottomRailLiquidGlassBackground: some View {
        let shape = RoundedRectangle(cornerRadius: bottomRailHeight / 2, style: .continuous)

        return ZStack {
            shape
                .fill(.regularMaterial)
                .opacity(0.08 + bottomRailOpacity * 0.72)

            shape
                .fill(
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
                )
                .blendMode(.plusLighter)

            shape
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

            shape
                .inset(by: 1)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.10 + bottomRailOpacity * 0.18),
                            .white.opacity(0.02 + bottomRailOpacity * 0.05),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.65
                )
                .blendMode(.plusLighter)
        }
        .clipShape(shape)
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

    private func createMarkdownFile() {
        let copy = AppText(language: settings.language)
        let panel = NSSavePanel()
        panel.allowedContentTypes = markdownContentTypes
        panel.directoryURL = noteStore.currentFileURL.deletingLastPathComponent()
        panel.nameFieldStringValue = copy.defaultMarkdownFileName
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            noteStore.createMarkdownFile(at: url)
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

    private func createWorkspaceFromPanel() {
        let copy = AppText(language: settings.language)
        let alert = NSAlert()
        alert.messageText = copy.newWorkspace
        alert.informativeText = copy.newWorkspacePrompt
        alert.alertStyle = .informational
        alert.addButton(withTitle: copy.newWorkspace)
        alert.addButton(withTitle: copy.close)

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        textField.stringValue = copy.workspaceDefaultName(noteStore.workspaces.count + 1)
        alert.accessoryView = textField

        if alert.runModal() == .alertFirstButtonReturn {
            noteStore.createWorkspace(named: textField.stringValue)
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
           !item.detections.isEmpty {
            extractionActionButton(item: item)
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
              !showClipboard,
              !showMore,
              !showFileSwitcher,
              !showShortcutSettings
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
        .delayedInlineHelp(AppText(language: settings.language).dragNote, delay: topChromeHelpDelay, yOffset: 28)
    }

    private func extractionActionButton(item: ClipboardItem) -> some View {
        let summary = extractedKindSummary(for: item.detections)

        return HStack(spacing: 0) {
            islandDragGrip()

            ZStack {
                Text(summary)
                    .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(detectedIslandTextColor)
                    .shadow(color: detectedIslandHighlightColor, radius: 1.6, y: 0.5)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .allowsHitTesting(false)

                WindowClickDragView {
                    withAnimation(.snappy(duration: 0.16)) {
                        toggleExtractionActionsOverlay()
                    }
                }
            }
            .frame(height: 26)
            .frame(maxWidth: .infinity, alignment: .center)

            detectedClipboardIslandButton
                .frame(width: 22, height: 22)
                .padding(.trailing, 4)
        }
        .padding(.leading, 2)
        .padding(.trailing, 0)
        .frame(width: 226, height: 26)
        .modifier(ExtractionIslandButtonModifier(isExpanded: true, opacity: islandOpacity, accentColor: settings.accentColor, isHighlighted: true))
        .matchedGeometryEffect(id: "extractionIsland", in: extractionIslandNamespace)
        .help(AppText(language: settings.language).clipboardActions)
    }

    private func extractedKindSummary(for detections: [ClipboardDetection]) -> String {
        let copy = AppText(language: settings.language)
        return kindSummary(for: detections, prefix: copy.extractedClipboardPrefix)
    }

    private func detectedKindSummary(for detections: [ClipboardDetection]) -> String {
        let copy = AppText(language: settings.language)
        return kindSummary(for: detections, prefix: copy.detectedClipboardPrefix)
    }

    private func kindSummary(for detections: [ClipboardDetection], prefix: String) -> String {
        let copy = AppText(language: settings.language)
        var seen: Set<ClipboardDetection.Kind> = []
        let names = detections.compactMap { detection -> String? in
            guard seen.insert(detection.kind).inserted else { return nil }
            return copy.clipboardKindName(detection.kind)
        }
        return prefix + names.joined(separator: copy.listSeparator)
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
                toggleClipboardOverlay()
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

    private func extractionActionsPanel(item: ClipboardItem, maxHeight: CGFloat) -> some View {
        let copy = AppText(language: settings.language)
        let summary = detectedKindSummary(for: item.detections)
        let panelBlue = Color(red: 0.36, green: 0.66, blue: 1.00)
        let listMaxHeight = max(88, maxHeight - 54)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(settings.accentColor)

                Text(summary)
                    .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(controlStrongInkColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            ScrollView(.vertical, showsIndicators: item.detections.count > 2) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(item.detections.enumerated()), id: \.element.id) { index, detection in
                        extractionDetectionRow(
                            detection,
                            isLast: index == item.detections.count - 1,
                            copy: copy
                        )
                    }
                }
            }
            .frame(maxHeight: listMaxHeight)
        }
        .padding(12)
        .background {
            readablePopupPanelBackground(materialOpacity: 0.60, whiteOpacity: 0.10, accentOpacity: 0.028)
        }
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(panelBlue.opacity(0.34), lineWidth: 1.1)
        }
        .shadow(color: panelBlue.opacity(0.10), radius: 8, y: 1)
    }

    private func readablePopupPanelBackground(
        cornerRadius: CGFloat = 15,
        materialOpacity: Double = 0.60,
        whiteOpacity: Double = 0.08,
        accentOpacity: Double = 0.024
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return shape
            .fill(.regularMaterial)
            .opacity(materialOpacity)
            .overlay {
                shape
                    .fill(Color.white.opacity(whiteOpacity))
            }
            .overlay {
                shape
                    .fill(settings.accentColor.opacity(accentOpacity))
                    .blendMode(.plusLighter)
            }
            .overlay {
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.18),
                                .white.opacity(0.05),
                                .black.opacity(0.025)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.plusLighter)
            }
    }

    private func extractionDetectionRow(_ detection: ClipboardDetection, isLast: Bool, copy: AppText) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: detection.symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 14, height: 16)
                        .padding(.top, 1)

                    Text(wrappingExtractionValue(detection.value))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(controlInkColor)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(settings.accentColor.opacity(0.035))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    settings.accentColor.opacity(0.36),
                                    .white.opacity(0.20),
                                    settings.accentColor.opacity(0.16)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.9
                        )
                }

                HStack(spacing: 8) {
                    Button {
                        clipboardStore.copy(detection.value)
                    } label: {
                        Label(copy.copy, systemImage: "doc.on.doc")
                    }
                    .help(copy.copyExtracted)

                    if let openTitle = detection.openTitle {
                        Button {
                            closeTransientOverlays()
                            clipboardStore.open(detection)
                        } label: {
                            Label(openTitle, systemImage: detection.openSymbol)
                        }
                        .help(openTitle)
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(controlSoftInkColor)
                .buttonStyle(.borderless)
            }
            .padding(.vertical, 8)

            if !isLast {
                Rectangle()
                    .fill(.white.opacity(0.16))
                    .frame(height: 1)
            }
        }
    }

    private func wrappingExtractionValue(_ value: String) -> String {
        let breakScalars = Set("/\\?&=#:-_@.,，;； ".unicodeScalars)
        var output = ""
        output.reserveCapacity(value.count + value.count / 4)
        for scalar in value.unicodeScalars {
            output.unicodeScalars.append(scalar)
            if breakScalars.contains(scalar) {
                output.unicodeScalars.append("\u{200B}")
            }
        }
        return output
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
        let documentCount = max(1, min(noteStore.activeWorkspaceFileURLs.count, 7))
        let topClearance = topDragPassthroughHeight + 8
        let bottomClearance: CGFloat = 10
        let maxHeight = max(150, containerSize.height - topClearance - bottomClearance)
        let height = min(maxHeight, 167 + CGFloat(documentCount) * 43)
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
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var settings: AppSettings
    @ObservedObject var noteStore: NoteStore

    let createMarkdownFile: () -> Void
    let openExistingFile: () -> Void
    let createWorkspace: () -> Void
    let switchWorkspace: (NoteWorkspace.ID) -> Void
    let openWorkspaceFile: (URL) -> Void
    let removeWorkspaceFile: (URL) -> Void

    private var copy: AppText {
        AppText(language: settings.language)
    }

    private var controlInkColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.90 : 0.84)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            workspacePicker

            fileActionButton(symbol: "doc.badge.plus", title: copy.createMarkdownFile, action: createMarkdownFile)
                .background(settings.accentColor.opacity(0.065), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .help(copy.createMarkdownFile)

            fileActionButton(symbol: "folder", title: copy.openExistingFile, action: openExistingFile)
                .background(.white.opacity(0.08 + settings.noteOpacity * 0.06), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .help(copy.openExistingFile)

            Rectangle()
                .fill(.white.opacity(0.16 + settings.noteOpacity * 0.16))
                .frame(height: 1)
                .padding(.horizontal, 2)

            if noteStore.activeWorkspaceFileURLs.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 11, weight: .semibold))
                    Text(copy.noWorkspaceDocuments)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .frame(height: 36)
            } else {
                HStack(spacing: 6) {
                    Text(copy.workspaceDocuments)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 0)

                    Text(copy.workspaceDocumentCount(noteStore.activeWorkspaceFileURLs.count))
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.top, 1)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 3) {
                        ForEach(noteStore.activeWorkspaceFileURLs, id: \.self) { url in
                            workspaceFileRow(url)
                        }
                    }
                }
            }
        }
        .padding(9)
    }

    private func fileActionButton(symbol: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: 12, weight: .semibold))

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var workspacePicker: some View {
        Menu {
            ForEach(noteStore.workspaces) { workspace in
                Button {
                    switchWorkspace(workspace.id)
                } label: {
                    Label(
                        workspace.name,
                        systemImage: workspace.id == noteStore.activeWorkspaceID ? "checkmark.circle.fill" : "rectangle.stack"
                    )
                }
            }
            Divider()
            Button(action: createWorkspace) {
                Label(copy.newWorkspace, systemImage: "plus")
            }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "rectangle.3.group")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(settings.accentColor)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(copy.workspace)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(.secondary)

                    Text(noteStore.activeWorkspaceName)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(controlInkColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(
            settings.accentColor.opacity(0.07),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .help(copy.switchWorkspace)
    }

    private func workspaceFileRow(_ url: URL) -> some View {
        HStack(spacing: 4) {
            Button {
                openWorkspaceFile(url)
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: isCurrent(url) ? "checkmark.circle.fill" : "doc.text")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isCurrent(url) ? settings.accentColor : .secondary)
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(url.lastPathComponent)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(controlInkColor)
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

            if !isCurrent(url) {
                Button {
                    removeWorkspaceFile(url)
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 20, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(copy.removeFromWorkspace)
            }
        }
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
    var isHighlighted = false

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
            .overlay {
                if isHighlighted {
                    DetectionIslandFlowLayer(
                        shape: islandShape,
                        accentColor: accentColor,
                        opacity: opacity
                    )
                }
            }
            .overlay(
                islandShape
                    .strokeBorder(
                        LinearGradient(
                            colors: borderColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isHighlighted ? 1.35 : 1
                    )
            )
            .overlay {
                if isHighlighted {
                    islandShape
                        .inset(by: 1.5)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    accentColor.opacity(0.42),
                                    .white.opacity(0.24),
                                    accentColor.opacity(0.18)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.55
                        )
                        .blendMode(.plusLighter)
                        .opacity(0.58 + opacity * 0.2)
                }
            }
            .shadow(color: isHighlighted ? accentColor.opacity(0.12 + opacity * 0.12) : .clear, radius: 8, y: 1)
            .shadow(color: .white.opacity(0.04 + opacity * 0.12), radius: 3, x: -1, y: -1)
            .shadow(color: .black.opacity(0.04 + opacity * 0.12), radius: isExpanded ? 12 : 8, y: 4)
    }

    private var borderColors: [Color] {
        if isHighlighted {
            [
                accentColor.opacity(0.48 + opacity * 0.2),
                .white.opacity(0.30 + opacity * 0.24),
                accentColor.opacity(0.28 + opacity * 0.18),
                .white.opacity(0.12 + opacity * 0.1),
                accentColor.opacity(0.44 + opacity * 0.18)
            ]
        } else {
            [
                .white.opacity((isExpanded ? 0.18 : 0.22) + opacity * (isExpanded ? 0.56 : 0.6)),
                accentColor.opacity(0.045 + opacity * 0.11),
                .white.opacity(0.08 + opacity * 0.14),
                .white.opacity(0.02 + opacity * 0.04)
            ]
        }
    }

    private var islandShape: AnyInsettableShape {
        if isExpanded {
            AnyInsettableShape(Capsule(style: .continuous))
        } else {
            AnyInsettableShape(Circle())
        }
    }
}

private extension View {
    func delayedInlineHelp(_ text: String, delay: TimeInterval, yOffset: CGFloat) -> some View {
        modifier(DelayedInlineHelpModifier(text: text, delay: delay, yOffset: yOffset))
    }
}

private struct DelayedInlineHelpModifier: ViewModifier {
    let text: String
    let delay: TimeInterval
    let yOffset: CGFloat

    @State private var isVisible = false
    @State private var showTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if isVisible {
                    Text(text)
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.84))
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.regularMaterial, in: Capsule(style: .continuous))
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(.white.opacity(0.34), lineWidth: 0.7)
                        )
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                        .offset(y: yOffset)
                        .transition(.scale(scale: 0.94, anchor: .top).combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
            .onHover { isHovering in
                showTask?.cancel()
                if isHovering {
                    showTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        guard !Task.isCancelled else { return }
                        withAnimation(.snappy(duration: 0.14)) {
                            isVisible = true
                        }
                    }
                } else {
                    withAnimation(.snappy(duration: 0.10)) {
                        isVisible = false
                    }
                }
            }
            .onDisappear {
                showTask?.cancel()
                isVisible = false
            }
    }
}

private struct DetectionIslandFlowLayer: View {
    let shape: AnyInsettableShape
    let accentColor: Color
    let opacity: Double

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                shape
                    .fill(accentColor.opacity(0.025 + opacity * 0.035))

                DetectionIslandFlowAnimationView(accentColor: accentColor, opacity: opacity)
                    .frame(width: width, height: height)
                    .mask(shape)
            }
            .frame(width: width, height: height)
            .mask(shape)
            .opacity(0.62 + opacity * 0.18)
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
        }
    }
}

private struct DetectionIslandFlowAnimationView: NSViewRepresentable {
    let accentColor: Color
    let opacity: Double

    func makeNSView(context: Context) -> DetectionIslandFlowNSView {
        DetectionIslandFlowNSView()
    }

    func updateNSView(_ nsView: DetectionIslandFlowNSView, context: Context) {
        nsView.configure(accentColor: NSColor(accentColor), opacity: opacity)
    }
}

private final class DetectionIslandFlowNSView: NSView {
    private let flowLayer = CAGradientLayer()
    private var currentAccentColor: NSColor = .systemCyan
    private var currentOpacity: Double = 0
    private var lastAnimationSize: CGSize = .zero

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        let rootLayer = CALayer()
        rootLayer.masksToBounds = true
        rootLayer.isGeometryFlipped = true
        layer = rootLayer

        flowLayer.type = .axial
        flowLayer.startPoint = CGPoint(x: 0, y: 0.5)
        flowLayer.endPoint = CGPoint(x: 1, y: 0.5)
        flowLayer.locations = [0, 0.22, 0.50, 0.78, 1]
        flowLayer.cornerRadius = 999
        flowLayer.shouldRasterize = true
        flowLayer.rasterizationScale = NSScreen.main?.backingScaleFactor ?? 2
        flowLayer.transform = CATransform3DMakeRotation(10 * .pi / 180, 0, 0, 1)
        rootLayer.addSublayer(flowLayer)
        updateColors()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        updateLayerGeometry(restartAnimationIfNeeded: false)
    }

    func configure(accentColor: NSColor, opacity: Double) {
        let rgbAccent = accentColor.usingColorSpace(.deviceRGB) ?? .systemCyan
        if !currentAccentColor.isEqual(rgbAccent) || abs(currentOpacity - opacity) > 0.001 {
            currentAccentColor = rgbAccent
            currentOpacity = opacity
            updateColors()
        }
        updateLayerGeometry(restartAnimationIfNeeded: false)
    }

    private func updateColors() {
        flowLayer.colors = [
            currentAccentColor.withAlphaComponent(0).cgColor,
            currentAccentColor.withAlphaComponent(0.08 + currentOpacity * 0.08).cgColor,
            NSColor.white.withAlphaComponent(0.11 + currentOpacity * 0.06).cgColor,
            currentAccentColor.withAlphaComponent(0.07 + currentOpacity * 0.06).cgColor,
            currentAccentColor.withAlphaComponent(0).cgColor
        ]
    }

    private func updateLayerGeometry(restartAnimationIfNeeded: Bool) {
        guard bounds.width > 1, bounds.height > 1 else { return }

        let sweepWidth = max(52, bounds.width * 0.68)
        let sweepHeight = max(34, bounds.height * 2.4)
        flowLayer.bounds = CGRect(x: 0, y: 0, width: sweepWidth, height: sweepHeight)
        flowLayer.position.y = bounds.midY

        let didSizeChange = lastAnimationSize != bounds.size
        if restartAnimationIfNeeded || didSizeChange || flowLayer.animation(forKey: "flowPosition") == nil {
            lastAnimationSize = bounds.size
            startFlowAnimation(sweepWidth: sweepWidth)
        }
    }

    private func startFlowAnimation(sweepWidth: CGFloat) {
        let fromX = -sweepWidth * 0.55
        let toX = bounds.width + sweepWidth * 0.55

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        flowLayer.position.x = fromX
        CATransaction.commit()

        let animation = CABasicAnimation(keyPath: "position.x")
        animation.fromValue = fromX
        animation.toValue = toX
        animation.duration = 3.2
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.isRemovedOnCompletion = false
        flowLayer.add(animation, forKey: "flowPosition")
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
