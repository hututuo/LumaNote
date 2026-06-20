import SwiftUI

struct NoteBottomRailLayoutMetrics {
    let progress: CGFloat
    let spacing: CGFloat
    let horizontalPadding: CGFloat
    let sliderWidth: CGFloat
    let buttonSize: CGFloat
    let utilityButtonHitSize: CGFloat
    let labelFontSize: CGFloat
    let percentWidth: CGFloat
    let opacityEndpointLabelWidth: CGFloat
    let allowsFlexibleOpacityExpansion: Bool
    let buttonCount: Int

    var opacityGroupWidth: CGFloat {
        sliderWidth
            + percentWidth
            + spacing
    }

    var buttonClusterWidth: CGFloat {
        let regularButtonCount = buttonCount - 2
        return CGFloat(regularButtonCount) * buttonSize
            + 2 * utilityButtonHitSize
            + CGFloat(buttonCount - 1) * spacing
    }

    var estimatedMinimumContentWidth: CGFloat {
        horizontalPadding * 2 + opacityGroupWidth + spacing + buttonClusterWidth
    }
}

enum NoteBottomRailLayout {
    static func metrics(for width: CGFloat) -> NoteBottomRailLayoutMetrics {
        let progress = compactProgress(for: width)
        let spacing = 5 - progress * 3
        let horizontalPadding = 10 - progress * 6
        let buttonSize = 22 - progress * 3.5

        return NoteBottomRailLayoutMetrics(
            progress: progress,
            spacing: spacing,
            horizontalPadding: horizontalPadding,
            sliderWidth: 66 - progress * 14,
            buttonSize: buttonSize,
            utilityButtonHitSize: 26 - progress * 3,
            labelFontSize: 11.2 - progress * 1.1,
            percentWidth: 32 - progress * 6,
            opacityEndpointLabelWidth: 0,
            allowsFlexibleOpacityExpansion: true,
            buttonCount: 7
        )
    }

    private static func compactProgress(for width: CGFloat) -> CGFloat {
        let fullWidth = NoteWindowLayout.initialSize.width
        let compactWidth = NoteWindowLayout.minimumSize.width
        guard width < fullWidth, fullWidth > compactWidth else {
            return 0
        }
        return min(max((fullWidth - width) / (fullWidth - compactWidth), 0), 1)
    }
}
