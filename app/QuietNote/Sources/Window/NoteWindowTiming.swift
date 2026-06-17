import Foundation

enum NoteWindowTiming {
    static let overlayToggleAnimation = 0.16
    static let overlayDismissAnimation = 0.14
    static let chromeExpandAnimation = 0.18
    static let chromeRevealAnimation = 0.20
    static let chromeStateAnimation = 0.24
    static let autoHideDelay = 4.0
    static let autoHideIdleTolerance = 0.18
    static let autoHideActivityThrottle = 0.22
    static let autoHideCollapseAnimation = 0.26
    static let topChromeHelpDelay = 1.5

    static let documentSwipeCommitAnimation = 0.16
    static let documentSwipeCancelAnimation = 0.18
    static let documentSwipePreviewClearDelay = 0.20
    static let documentSwipeUnlockDelay = 0.04

    static let collapsedHandlePulseInAnimation = 0.26
    static let collapsedHandlePulseHoldMilliseconds: UInt64 = 850
    static let collapsedHandlePulseOutAnimation = 0.42

    static let suggestionVisibleSeconds = 60.0
}
