import SwiftUI

struct NoteOverlayMetrics: Equatable {
    let width: CGFloat
    let height: CGFloat
    let centerX: CGFloat
    let centerY: CGFloat
}

enum NoteWindowOverlayLayout {
    static func moreMenuMetrics(
        in containerSize: CGSize,
        anchorFrame: CGRect,
        topDragPassthroughHeight: CGFloat
    ) -> NoteOverlayMetrics {
        let margin: CGFloat = 12
        let width = max(210, min(286, containerSize.width - margin * 2))
        let topClearance = topDragPassthroughHeight + 8
        let bottomClearance: CGFloat = 10
        let availableHeight = max(210, containerSize.height - topClearance - bottomClearance)
        let height = min(470, availableHeight)
        let anchor = anchorFrame == .zero
            ? CGRect(x: containerSize.width - 44, y: containerSize.height - 34, width: 24, height: 24)
            : anchorFrame

        let preferredX = anchor.maxX - width / 2
        let minX = margin + width / 2
        let maxX = containerSize.width - margin - width / 2
        let centerX = clamped(preferredX, min: minX, max: maxX)

        let preferredY = anchor.minY - 8 - height / 2
        let minY = topClearance + height / 2
        let maxY = containerSize.height - bottomClearance - height / 2
        let centerY = clamped(preferredY, min: minY, max: maxY)

        return NoteOverlayMetrics(width: width, height: height, centerX: centerX, centerY: centerY)
    }

    static func fileSwitcherMetrics(
        in containerSize: CGSize,
        anchorFrame: CGRect,
        documentCount: Int,
        topDragPassthroughHeight: CGFloat
    ) -> NoteOverlayMetrics {
        let margin: CGFloat = 12
        let width = max(218, min(310, containerSize.width - margin * 2))
        let documentCount = max(1, min(documentCount, 7))
        let topClearance = topDragPassthroughHeight + 8
        let bottomClearance: CGFloat = 10
        let maxHeight = max(150, containerSize.height - topClearance - bottomClearance)
        let height = min(maxHeight, 167 + CGFloat(documentCount) * 43)
        let anchor = anchorFrame == .zero
            ? CGRect(x: containerSize.width - 116, y: containerSize.height - 34, width: 24, height: 24)
            : anchorFrame

        let preferredX = anchor.midX
        let minX = margin + width / 2
        let maxX = containerSize.width - margin - width / 2
        let centerX = clamped(preferredX, min: minX, max: maxX)

        let preferredY = anchor.minY - 8 - height / 2
        let minY = topClearance + height / 2
        let maxY = containerSize.height - bottomClearance - height / 2
        let centerY = clamped(preferredY, min: minY, max: maxY)

        return NoteOverlayMetrics(width: width, height: height, centerX: centerX, centerY: centerY)
    }

    private static func clamped(_ value: CGFloat, min lowerBound: CGFloat, max upperBound: CGFloat) -> CGFloat {
        guard lowerBound <= upperBound else {
            return (lowerBound + upperBound) / 2
        }
        return Swift.min(Swift.max(value, lowerBound), upperBound)
    }
}

enum NoteWindowCoordinateSpace {
    static let name = "quietNoteWindow"
}

struct MoreButtonFramePreferenceKey: PreferenceKey {
    static let defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}

struct FileSwitchButtonFramePreferenceKey: PreferenceKey {
    static let defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}
