import SwiftUI

struct NoteWindowShellBackground: View {
    let glassMetrics: NoteGlassMetrics
    let accentColor: Color

    var body: some View {
        shellShape
            .fill(.ultraThinMaterial)
            .opacity(glassMetrics.shellMaterialOpacity)
            .overlay(readabilityLayer)
            .overlay(themeTintLayer)
            .overlay(borderLayer)
    }

    private var shellShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
    }

    private var readabilityLayer: some View {
        shellShape
            .fill(Color.white.opacity(glassMetrics.shellHazeOpacity))
            .blendMode(.plusLighter)
    }

    private var themeTintLayer: some View {
        shellShape
            .fill(accentColor.opacity(glassMetrics.shellTintOpacity))
            .blendMode(.plusLighter)
    }

    private var borderLayer: some View {
        shellShape
            .strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(0.72), .white.opacity(0.18), .black.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
            .opacity(glassMetrics.shellBorderOpacity)
    }
}
