import AppKit
@preconcurrency import KeyboardShortcuts
import SwiftUI

struct NoteWindowView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var noteStore: NoteStore
    @ObservedObject var clipboardStore: ClipboardStore

    let onClose: () -> Void

    @State private var showClipboard = false
    @State private var showMore = false
    @State private var showShortcutSettings = false
    @State private var showExtractionActions = false
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
                    .padding(.horizontal, 18)
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
        .popover(isPresented: $showMore, arrowEdge: .bottom) {
            MoreMenuView(
                settings: settings,
                clipboardStore: clipboardStore,
                showShortcutSettings: $showShortcutSettings,
                onClose: onClose
            )
            .frame(width: 286)
        }
        .sheet(isPresented: $showShortcutSettings) {
            ShortcutSettingsView(settings: settings)
                .frame(width: 420)
                .padding(22)
        }
        .onReceive(NotificationCenter.default.publisher(for: .quietNoteToggleClipboard)) { _ in
            showClipboard.toggle()
        }
        .onChange(of: clipboardStore.latestDetectedItem?.id) { _, itemID in
            scheduleSuggestionReset(for: itemID)
        }
        .onDisappear {
            suggestionResetTask?.cancel()
        }
        .animation(.snappy(duration: 0.16), value: showClipboard)
        .animation(.snappy(duration: 0.24), value: clipboardStore.latestDetectedItem?.id)
        .animation(.snappy(duration: 0.24), value: hiddenSuggestionID)
    }

    @ViewBuilder
    private var clipboardInlineOverlay: some View {
        GeometryReader { proxy in
            if showClipboard {
                let panelWidth = min(360, max(286, proxy.size.width - 28))
                let panelHeight = min(390, max(260, proxy.size.height - 92))

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
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 30)
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
        HStack(spacing: 8) {
            Text("1")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Slider(value: $settings.noteOpacity, in: AppSettings.minimumNoteOpacity...1)
                .tint(.cyan)
                .frame(minWidth: 96)

            Text("100")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Text("\(Int(settings.noteOpacity * 100))%")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .frame(width: 36, alignment: .trailing)

            railButton(symbol: "list.clipboard", help: "Clipboard") {
                showClipboard.toggle()
            }
            railButton(symbol: settings.alwaysOnTop ? "pin.fill" : "pin", help: "Pin") {
                settings.alwaysOnTop.toggle()
            }
            railButton(symbol: "ellipsis", help: "More") {
                showMore.toggle()
            }
        }
        .padding(.horizontal, 14)
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

    private func railButton(symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .background(.white.opacity(0.12 + settings.noteOpacity * 0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .help(help)
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
            showClipboard.toggle()
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

    private var resizeHint: some View {
        Image(systemName: "line.diagonal")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary.opacity(0.6))
            .padding(7)
            .allowsHitTesting(false)
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
                                .black.opacity(0.03 + opacity * 0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .overlay(alignment: .topLeading) {
                islandShape
                    .trim(from: 0.06, to: isExpanded ? 0.24 : 0.34)
                    .stroke(.white.opacity((isExpanded ? 0.12 : 0.16) + opacity * (isExpanded ? 0.33 : 0.39)), lineWidth: 1.2)
                    .padding(isExpanded ? 2 : 3)
            }
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
