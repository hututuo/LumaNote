import SwiftUI

struct NoteBottomRailView: View {
    @Bindable var settings: AppSettings

    let copy: AppText
    let glassMetrics: NoteGlassMetrics
    let height: CGFloat
    let toggleFileSwitcher: () -> Void
    let saveAs: () -> Void
    let toggleAlwaysOnTop: () -> Void
    let toggleAutoHideChrome: () -> Void
    let toggleMore: () -> Void
    let close: () -> Void

    var body: some View {
        GeometryReader { proxy in
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

                Slider(value: $settings.noteOpacity, in: AppSettings.minimumNoteOpacity...AppSettings.maximumNoteOpacity)
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
                    toggleFileSwitcher()
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
                    saveAs()
                }
                railButton(
                    symbol: settings.alwaysOnTop ? "pin.fill" : "pin",
                    help: settings.alwaysOnTop ? copy.disableAlwaysOnTop : copy.alwaysOnTop,
                    size: buttonSize
                ) {
                    toggleAlwaysOnTop()
                }
                railButton(
                    symbol: settings.autoHideChrome ? "eye.slash" : "eye",
                    help: settings.autoHideChrome ? copy.autoHideControls : copy.keepControlsVisible,
                    size: buttonSize
                ) {
                    toggleAutoHideChrome()
                }
                railButton(symbol: "ellipsis", help: copy.more, size: buttonSize, hitSize: max(30, buttonSize + 8)) {
                    toggleMore()
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
                    close()
                }
            }
            .padding(.horizontal, horizontalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: height)
        .contentShape(Rectangle())
        .onTapGesture {}
        .background { liquidGlassBackground }
    }

    private var liquidGlassBackground: some View {
        let shape = RoundedRectangle(cornerRadius: height / 2, style: .continuous)

        return ZStack {
            shape
                .fill(.regularMaterial)
                .opacity(0.08 + glassMetrics.bottomRailOpacity * 0.72)

            shape
                .fill(
                    LinearGradient(
                        colors: [
                            settings.accentColor.opacity(0.006 + glassMetrics.bottomRailOpacity * 0.028),
                            .white.opacity(0.025 + glassMetrics.bottomRailOpacity * 0.075),
                            .white.opacity(0.006 + glassMetrics.bottomRailOpacity * 0.018),
                            .black.opacity(0.012 + glassMetrics.bottomRailOpacity * 0.028)
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
                            .white.opacity(0.18 + glassMetrics.bottomRailOpacity * 0.56),
                            settings.accentColor.opacity(0.06 + glassMetrics.bottomRailOpacity * 0.12),
                            .white.opacity(0.08 + glassMetrics.bottomRailOpacity * 0.14),
                            .white.opacity(0.02 + glassMetrics.bottomRailOpacity * 0.04)
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
                            .white.opacity(0.10 + glassMetrics.bottomRailOpacity * 0.18),
                            .white.opacity(0.02 + glassMetrics.bottomRailOpacity * 0.05),
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
        .shadow(color: .white.opacity(0.025 + glassMetrics.bottomRailOpacity * 0.07), radius: 1.2, x: -0.5, y: -0.5)
        .shadow(color: .black.opacity(0.025 + glassMetrics.bottomRailOpacity * 0.055), radius: 2, y: 1)
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
                    .fill(.white.opacity(0.03 + glassMetrics.bottomRailOpacity * 0.08))
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
}
