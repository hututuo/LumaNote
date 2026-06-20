import CoreGraphics
import Foundation

enum DocumentSwipeGestureMode {
    case undecided
    case horizontal
    case vertical
}

struct DocumentSwipeGestureAxisState {
    private(set) var accumulatedX: CGFloat = 0
    private(set) var accumulatedY: CGFloat = 0
    private(set) var mode: DocumentSwipeGestureMode = .undecided

    private var verticalDistanceAtHorizontalLock: CGFloat?

    private let lockThreshold: CGFloat
    private let lockDominanceRatio: CGFloat
    private let verticalLockDominanceRatio: CGFloat
    private let progressTravelThreshold: CGFloat
    private let progressLimit: CGFloat
    private let triggerThreshold: CGFloat
    private let dominanceRatio: CGFloat

    init(
        lockThreshold: CGFloat = 8,
        lockDominanceRatio: CGFloat = 1.22,
        verticalLockDominanceRatio: CGFloat = 1.1,
        progressTravelThreshold: CGFloat = 220,
        progressLimit: CGFloat = 1.12,
        triggerThreshold: CGFloat = 55,
        dominanceRatio: CGFloat = 1.55
    ) {
        self.lockThreshold = lockThreshold
        self.lockDominanceRatio = lockDominanceRatio
        self.verticalLockDominanceRatio = verticalLockDominanceRatio
        self.progressTravelThreshold = progressTravelThreshold
        self.progressLimit = progressLimit
        self.triggerThreshold = triggerThreshold
        self.dominanceRatio = dominanceRatio
    }

    var progress: CGFloat {
        progress(travelThreshold: progressTravelThreshold, limit: progressLimit)
    }

    mutating func add(deltaX: CGFloat, deltaY: CGFloat) {
        accumulatedX += deltaX
        accumulatedY += deltaY
        updateModeIfNeeded()
    }

    mutating func reset() {
        accumulatedX = 0
        accumulatedY = 0
        mode = .undecided
        verticalDistanceAtHorizontalLock = nil
    }

    mutating func holdHorizontalAfterTrigger() {
        reset()
        mode = .horizontal
        verticalDistanceAtHorizontalLock = 0
    }

    func progress(travelThreshold: CGFloat, limit: CGFloat = 1.12) -> CGFloat {
        let rawProgress = accumulatedX / travelThreshold
        return min(max(rawProgress, -limit), limit)
    }

    func shouldCommitHorizontal(
        triggerThreshold: CGFloat? = nil,
        dominanceRatio: CGFloat? = nil
    ) -> Bool {
        guard mode == .horizontal else { return false }
        let horizontalDistance = abs(accumulatedX)
        let threshold = triggerThreshold ?? self.triggerThreshold
        guard horizontalDistance >= threshold else { return false }

        let ratio = dominanceRatio ?? self.dominanceRatio
        return horizontalDistance >= max(1, verticalDistanceForHorizontalDecision) * ratio
    }

    func hasQuickSwipeDominance(
        triggerThreshold: CGFloat,
        currentDeltaX: CGFloat,
        currentDeltaThreshold: CGFloat,
        dominanceRatio: CGFloat
    ) -> Bool {
        guard mode == .horizontal else { return false }
        let horizontalDistance = abs(accumulatedX)
        guard horizontalDistance >= triggerThreshold else { return false }
        guard abs(currentDeltaX) >= currentDeltaThreshold else { return false }
        return horizontalDistance >= max(1, verticalDistanceForHorizontalDecision) * dominanceRatio
    }

    private var verticalDistanceForHorizontalDecision: CGFloat {
        min(abs(accumulatedY), verticalDistanceAtHorizontalLock ?? abs(accumulatedY))
    }

    private mutating func updateModeIfNeeded() {
        guard mode == .undecided else { return }

        let horizontalDistance = abs(accumulatedX)
        let verticalDistance = abs(accumulatedY)

        if horizontalDistance >= lockThreshold,
           horizontalDistance >= max(1, verticalDistance) * lockDominanceRatio {
            mode = .horizontal
            verticalDistanceAtHorizontalLock = verticalDistance
        } else if verticalDistance >= lockThreshold,
                  verticalDistance > max(1, horizontalDistance) * verticalLockDominanceRatio {
            mode = .vertical
        }
    }
}
