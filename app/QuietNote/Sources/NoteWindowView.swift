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
    @Namespace private var extractionIslandNamespace

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(shellOpacity)
                .overlay(readabilityLayer)
                .overlay(borderLayer)

            VStack(spacing: 0) {
                topBar

                content
                    .padding(.leading, 18)
                    .padding(.trailing, 5)
                    .padding(.top, 10)
                    .padding(.bottom, 8)

                bottomRail
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            resizeHint
        }
        .overlay {
            clipboardInlineOverlay
        }
        .overlay {
            moreInlineOverlay
        }
        .overlay {
            fileSwitcherInlineOverlay
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
                .frame(width: 420)
                .padding(22)
        }
        .onReceive(NotificationCenter.default.publisher(for: .quietNoteToggleClipboard)) { _ in
            withAnimation(.snappy(duration: 0.16)) {
                showMore = false
                showFileSwitcher = false
                showExtractionActions = false
                showClipboard.toggle()
            }
        }
        .onChange(of: showShortcutSettings) { _, isPresented in
            if isPresented {
                showMore = false
            }
        }
        .onChange(of: clipboardStore.latestDetectedItem?.id) { _, itemID in
            scheduleSuggestionReset(for: itemID)
        }
        .onDisappear {
            suggestionResetTask?.cancel()
        }
        .animation(.snappy(duration: 0.16), value: showClipboard)
        .animation(.snappy(duration: 0.16), value: showMore)
        .animation(.snappy(duration: 0.16), value: showFileSwitcher)
        .animation(.snappy(duration: 0.24), value: clipboardStore.latestDetectedItem?.id)
        .animation(.snappy(duration: 0.24), value: hiddenSuggestionID)
    }

    @ViewBuilder
    private var clipboardInlineOverlay: some View {
        GeometryReader { proxy in
            if showClipboard {
                let panelWidth = min(360, max(238, proxy.size.width - 20))
                let panelHeight = min(390, max(178, proxy.size.height - 74))

                ZStack(alignment: .top) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.snappy(duration: 0.16)) {
                                showClipboard = false
                            }
                        }

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
                        .padding(.top, 34)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.96, anchor: .top).combined(with: .opacity),
                            removal: .scale(scale: 0.985, anchor: .top).combined(with: .opacity)
                        ))
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .zIndex(30)
            }
        }
        .allowsHitTesting(showClipboard)
    }

    @ViewBuilder
    private var moreInlineOverlay: some View {
        GeometryReader { proxy in
            if showMore {
                let metrics = moreOverlayMetrics(in: proxy.size)

                ZStack(alignment: .topLeading) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
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
        .allowsHitTesting(showMore)
    }

    @ViewBuilder
    private var fileSwitcherInlineOverlay: some View {
        GeometryReader { proxy in
            if showFileSwitcher {
                let metrics = fileSwitcherOverlayMetrics(in: proxy.size)

                ZStack(alignment: .topLeading) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
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
        .allowsHitTesting(showFileSwitcher)
    }

    private var readabilityLayer: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.white.opacity(0.025 + settings.noteOpacity * (0.14 + settings.glassStrength * 0.16)))
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

            extractionIsland
                .padding(.top, 7)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 35)
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
        MarkdownRenderingEditor(text: $noteStore.markdown)
    }

    private var shellOpacity: Double {
        max(0.08, settings.noteOpacity)
    }

    private var controlChromeOpacity: Double {
        0.34 + settings.noteOpacity * 0.42
    }

    private var islandOpacity: Double {
        max(0.05, settings.noteOpacity)
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
                    .tint(.cyan)
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
                railButton(symbol: settings.alwaysOnTop ? "pin.fill" : "pin", help: "Pin", size: buttonSize) {
                    settings.alwaysOnTop.toggle()
                }
                railButton(symbol: "ellipsis", help: "More", size: buttonSize) {
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
        .frame(height: 36)
        .background {
            Rectangle()
                .fill(.thinMaterial)
                .opacity(controlChromeOpacity)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.white.opacity(0.16 + settings.noteOpacity * 0.22))
                .frame(height: 1)
        }
    }

    private func railCompactProgress(for width: CGFloat) -> CGFloat {
        let fullWidth = NoteWindowLayout.initialSize.width
        let compactWidth = NoteWindowLayout.minimumSize.width
        guard width < fullWidth, fullWidth > compactWidth else {
            return 0
        }
        return min(max((fullWidth - width) / (fullWidth - compactWidth), 0), 1)
    }

    private func railButton(symbol: String, help: String, size: CGFloat = 24, action: @escaping () -> Void) -> some View {
        let cornerRadius = max(6, size * 0.29)

        return Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.54, weight: .semibold))
                .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .background(
            .white.opacity(0.12 + settings.noteOpacity * 0.08),
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
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
                .font(.system(size: 11, weight: .semibold))
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
        .modifier(ExtractionIslandButtonModifier(isExpanded: true, opacity: islandOpacity))
        .matchedGeometryEffect(id: "extractionIsland", in: extractionIslandNamespace)
        .help("Drag note")
    }

    private func extractionActionButton(item: ClipboardItem, first: ClipboardDetection) -> some View {
        HStack(spacing: 0) {
            islandDragGrip()

            ZStack {
                HStack(spacing: 7) {
                    Image(systemName: first.symbol)
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 14, height: 22)

                    Text(first.kind.rawValue)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)

                    Text(first.value)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 92, alignment: .leading)

                    if item.detections.count > 1 {
                        Text("+\(item.detections.count - 1)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.white.opacity(0.16), in: Capsule())
                    }
                }
                .allowsHitTesting(false)

                WindowClickDragView {
                    showExtractionActions.toggle()
                }
            }
            .frame(height: 26)
            .frame(maxWidth: 168, alignment: .leading)

            clipboardIslandButton
                .padding(.trailing, 4)
        }
        .padding(.leading, 2)
        .padding(.trailing, 0)
        .frame(height: 26, alignment: .leading)
        .fixedSize(horizontal: true, vertical: false)
        .frame(maxWidth: 226, alignment: .leading)
        .modifier(ExtractionIslandButtonModifier(isExpanded: true, opacity: islandOpacity))
        .matchedGeometryEffect(id: "extractionIsland", in: extractionIslandNamespace)
        .help("Clipboard actions")
        .popover(isPresented: $showExtractionActions, arrowEdge: .top) {
            extractionActionsPopover(item: item)
                .frame(width: 310)
        }
    }

    private var clipboardIslandButton: some View {
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
        .foregroundStyle(.primary.opacity(0.72))
        .background(.white.opacity(0.03 + islandOpacity * 0.08), in: Circle())
        .help("Clipboard")
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

                        Button {
                            showExtractionActions = false
                            clipboardStore.paste(detection.value)
                        } label: {
                            Label(copy.paste, systemImage: "arrow.turn.down.left")
                        }

                        if let openTitle = detection.openTitle {
                            Button {
                                showExtractionActions = false
                                clipboardStore.open(detection)
                            } label: {
                                Label(openTitle, systemImage: detection.openSymbol)
                            }
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
        let height = max(178, min(360, containerSize.height - 58))
        let anchor = moreButtonFrame == .zero
            ? CGRect(x: containerSize.width - 44, y: containerSize.height - 34, width: 24, height: 24)
            : moreButtonFrame

        let preferredX = anchor.maxX - width / 2
        let minX = margin + width / 2
        let maxX = containerSize.width - margin - width / 2
        let centerX = clamped(preferredX, min: minX, max: maxX)

        let preferredY = anchor.minY - 8 - height / 2
        let minY = margin + height / 2
        let maxY = containerSize.height - margin - height / 2
        let centerY = clamped(preferredY, min: minY, max: maxY)

        return (width, height, centerX, centerY)
    }

    private func fileSwitcherOverlayMetrics(in containerSize: CGSize) -> (width: CGFloat, height: CGFloat, centerX: CGFloat, centerY: CGFloat) {
        let margin: CGFloat = 12
        let width = max(218, min(310, containerSize.width - margin * 2))
        let recentCount = max(1, min(noteStore.recentFileURLs.count, 7))
        let maxHeight = max(178, containerSize.height - 48)
        let height = min(maxHeight, 84 + CGFloat(recentCount) * 43)
        let anchor = fileSwitchButtonFrame == .zero
            ? CGRect(x: containerSize.width - 116, y: containerSize.height - 34, width: 24, height: 24)
            : fileSwitchButtonFrame

        let preferredX = anchor.midX
        let minX = margin + width / 2
        let maxX = containerSize.width - margin - width / 2
        let centerX = clamped(preferredX, min: minX, max: maxX)

        let preferredY = anchor.minY - 8 - height / 2
        let minY = margin + height / 2
        let maxY = containerSize.height - margin - height / 2
        let centerY = clamped(preferredY, min: minY, max: maxY)

        return (width, height, centerX, centerY)
    }

    private func clamped(_ value: CGFloat, min lowerBound: CGFloat, max upperBound: CGFloat) -> CGFloat {
        guard lowerBound <= upperBound else {
            return (lowerBound + upperBound) / 2
        }
        return Swift.min(Swift.max(value, lowerBound), upperBound)
    }

    private var resizeHint: some View {
        Image(systemName: "line.diagonal")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary.opacity(0.6))
            .padding(7)
            .allowsHitTesting(false)
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
                    .foregroundStyle(isCurrent(url) ? Color.cyan : .secondary)
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
            isCurrent(url) ? Color.cyan.opacity(0.08) : Color.white.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
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
            .overlay(
                islandShape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity((isExpanded ? 0.18 : 0.22) + opacity * (isExpanded ? 0.56 : 0.6)),
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
