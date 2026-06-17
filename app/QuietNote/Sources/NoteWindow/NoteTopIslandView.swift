import SwiftUI

struct NoteWindowChromePalette {
    let colorScheme: ColorScheme

    var islandTextColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.90 : 0.82)
    }

    var islandIconColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.92 : 0.86)
    }

    var detectedIslandTextColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.92 : 0.82)
    }

    var detectedIslandIconColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.94 : 0.86)
    }

    var islandSoftShadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.46) : Color.white.opacity(0.58)
    }

    var detectedIslandHighlightColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.42) : Color.white.opacity(0.58)
    }
}

struct NoteTopIslandView: View {
    let title: String
    let detectedItem: ClipboardItem?
    let copy: AppText
    let glassMetrics: NoteGlassMetrics
    let accentColor: Color
    let palette: NoteWindowChromePalette
    let namespace: Namespace.ID
    let toggleClipboard: () -> Void
    let toggleExtractionActions: () -> Void

    var body: some View {
        if let detectedItem,
           !detectedItem.detections.isEmpty {
            extractionActionButton(item: detectedItem)
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

    private var titleIsland: some View {
        ZStack {
            WindowClickDragView {}

            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(palette.islandTextColor)
                .shadow(color: palette.islandSoftShadowColor, radius: 1.2, y: 0.5)
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
        .modifier(ExtractionIslandButtonModifier(isExpanded: true, opacity: glassMetrics.islandOpacity, accentColor: accentColor))
        .matchedGeometryEffect(id: "extractionIsland", in: namespace)
        .delayedInlineHelp(copy.dragNote, delay: NoteWindowTiming.topChromeHelpDelay, yOffset: 28)
    }

    private func extractionActionButton(item: ClipboardItem) -> some View {
        let summary = copy.clipboardKindSummary(for: item.detections, prefix: copy.extractedClipboardPrefix)

        return HStack(spacing: 0) {
            islandDragGrip()

            ZStack {
                Text(summary)
                    .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(palette.detectedIslandTextColor)
                    .shadow(color: palette.detectedIslandHighlightColor, radius: 1.6, y: 0.5)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .allowsHitTesting(false)

                WindowClickDragView {
                    withAnimation(.snappy(duration: NoteWindowTiming.overlayToggleAnimation)) {
                        toggleExtractionActions()
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
        .modifier(ExtractionIslandButtonModifier(isExpanded: true, opacity: glassMetrics.islandOpacity, accentColor: accentColor, isHighlighted: true))
        .matchedGeometryEffect(id: "extractionIsland", in: namespace)
        .help(copy.clipboardActions)
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

    private var clipboardIslandButton: some View {
        clipboardIslandButtonView(
            foregroundColor: palette.islandIconColor,
            shadowColor: .black.opacity(0.2)
        )
    }

    private var detectedClipboardIslandButton: some View {
        clipboardIslandButtonView(
            foregroundColor: palette.detectedIslandIconColor,
            shadowColor: palette.detectedIslandHighlightColor
        )
    }

    private func clipboardIslandButtonView(foregroundColor: Color, shadowColor: Color) -> some View {
        Button {
            withAnimation(.snappy(duration: NoteWindowTiming.overlayToggleAnimation)) {
                toggleClipboard()
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
        .background(.white.opacity(0.03 + glassMetrics.islandOpacity * 0.08), in: Circle())
        .help(copy.openClipboardLibrary)
    }
}
