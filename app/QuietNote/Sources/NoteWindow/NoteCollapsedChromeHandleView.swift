import SwiftUI

struct NoteCollapsedTopChromeHandleView: View {
    let detection: ClipboardDetection?
    let copy: AppText
    let glassMetrics: NoteGlassMetrics
    let accentColor: Color
    let palette: NoteWindowChromePalette
    let isPulsing: Bool
    let revealControls: () -> Void

    var body: some View {
        ZStack {
            CollapsedChromePulseOverlay(accentColor: accentColor, isPulsing: isPulsing)

            HStack(spacing: 4) {
                if let detection {
                    Image(systemName: detection.symbol)
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(palette.detectedIslandIconColor)
                } else {
                    Capsule(style: .continuous)
                        .fill(palette.islandIconColor.opacity(0.56))
                        .frame(width: 17, height: 2)
                }
            }
            .allowsHitTesting(false)

            WindowClickDragView(onClick: revealControls, dragStartsImmediately: true)
        }
        .frame(width: detection == nil ? 42 : 50, height: 14)
        .modifier(ExtractionIslandButtonModifier(isExpanded: true, opacity: glassMetrics.collapsedChromeOpacity, accentColor: accentColor))
        .contentShape(Capsule(style: .continuous))
        .delayedInlineHelp(copy.showControls, delay: NoteWindowTiming.topChromeHelpDelay, yOffset: 24)
    }
}

struct NoteCollapsedBottomChromeHandleView: View {
    let noteOpacity: Double
    let height: CGFloat
    let copy: AppText
    let glassMetrics: NoteGlassMetrics
    let accentColor: Color
    let palette: NoteWindowChromePalette
    let isPulsing: Bool
    let revealControls: () -> Void

    var body: some View {
        ZStack {
            CollapsedChromePulseOverlay(accentColor: accentColor, isPulsing: isPulsing)

            HStack(spacing: 5) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 8.5, weight: .bold))

                Text("\(Int(noteOpacity * 100))%")
                    .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(palette.islandIconColor)
            .shadow(color: palette.islandSoftShadowColor, radius: 1, y: 0.4)
            .allowsHitTesting(false)

            WindowClickDragView(onClick: revealControls, dragStartsImmediately: true)
        }
        .frame(width: 58, height: height)
        .modifier(ExtractionIslandButtonModifier(isExpanded: true, opacity: glassMetrics.collapsedChromeOpacity, accentColor: accentColor))
        .contentShape(Capsule(style: .continuous))
        .help(copy.showControls)
    }
}

private struct CollapsedChromePulseOverlay: View {
    let accentColor: Color
    let isPulsing: Bool

    var body: some View {
        Capsule(style: .continuous)
            .fill(accentColor.opacity(isPulsing ? 0.10 : 0.035))
            .scaleEffect(isPulsing ? 1.04 : 0.98)
            .blur(radius: isPulsing ? 2.4 : 1.2)
            .opacity(isPulsing ? 0.62 : 0.28)
            .allowsHitTesting(false)
    }
}
