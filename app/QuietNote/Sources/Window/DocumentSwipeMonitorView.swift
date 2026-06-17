import AppKit
import SwiftUI

struct DocumentSwipeMonitorView: NSViewRepresentable {
    var isEnabled: Bool
    var onProgress: (CGFloat) -> Void = { _ in }
    var onCancel: () -> Void = {}
    var onNext: () -> Void
    var onPrevious: () -> Void

    func makeNSView(context: Context) -> DocumentSwipeMonitorNSView {
        let view = DocumentSwipeMonitorNSView()
        view.isEnabled = isEnabled
        view.onProgress = onProgress
        view.onCancel = onCancel
        view.onNext = onNext
        view.onPrevious = onPrevious
        return view
    }

    func updateNSView(_ nsView: DocumentSwipeMonitorNSView, context: Context) {
        nsView.isEnabled = isEnabled
        nsView.onProgress = onProgress
        nsView.onCancel = onCancel
        nsView.onNext = onNext
        nsView.onPrevious = onPrevious
    }
}

final class DocumentSwipeMonitorNSView: NSView {
    var isEnabled = true {
        didSet {
            if !isEnabled, gestureMode == .horizontal {
                onCancel()
            }
            if !isEnabled {
                resetGesture()
            }
        }
    }
    var onProgress: (CGFloat) -> Void = { _ in }
    var onCancel: () -> Void = {}
    var onNext: () -> Void = {}
    var onPrevious: () -> Void = {}

    private var eventMonitor: Any?
    private var accumulatedX: CGFloat = 0
    private var accumulatedY: CGFloat = 0
    private var gestureMode: GestureMode = .undecided
    private var lastTriggerDate = Date.distantPast
    private var lastPublishedProgress: CGFloat = 0
    private var lastProgressUpdate = Date.distantPast
    private var idleFinishGeneration = 0
    private var idleFinishTask: Task<Void, Never>?
    private var gestureStartDate = Date.distantPast
    private var gestureSampleCount = 0
    private var didTriggerQuickSwipe = false

    private let triggerThreshold: CGFloat = 55
    private let lockThreshold: CGFloat = 8
    private let progressTravelThreshold: CGFloat = 220
    private let dominanceRatio: CGFloat = 1.55
    private let lockDominanceRatio: CGFloat = 1.22
    private let quickSwipeInitialWindow: TimeInterval = 0.16
    private let quickSwipeMaxSamples = 4
    private let quickSwipeDeltaThreshold: CGFloat = 18
    private let quickSwipeDominanceRatio: CGFloat = 2.1
    private let triggerCooldown: TimeInterval = 0.46
    private let progressUpdateInterval: TimeInterval = 1.0 / 120.0
    private let progressEpsilon: CGFloat = 0.012
    private let gestureIdleTimeout: TimeInterval = 0.18

    deinit {
        MainActor.assumeIsolated {
            removeEventMonitor()
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            removeEventMonitor()
        } else {
            installEventMonitor()
        }
    }

    private func installEventMonitor() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .swipe]) { [weak self] event in
            guard let self else { return event }
            return self.handle(event)
        }
    }

    private func removeEventMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
        resetGesture()
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        guard isEnabled, event.window === window else { return event }

        switch event.type {
        case .scrollWheel:
            return handleScrollWheel(event) ? nil : event
        case .swipe:
            return handleSwipe(event) ? nil : event
        default:
            return event
        }
    }

    private func handleScrollWheel(_ event: NSEvent) -> Bool {
        guard event.momentumPhase.isEmpty else { return gestureMode == .horizontal }
        guard event.hasPreciseScrollingDeltas || !event.phase.isEmpty else { return false }

        if event.phase.contains(.began) || event.phase.contains(.mayBegin) {
            resetGesture()
        }

        if didTriggerQuickSwipe {
            if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
                resetGesture()
            } else {
                scheduleIdleFinish()
            }
            return true
        }

        // AppKit's horizontal scroll delta is opposite to the page travel users expect here.
        // Keep the internal convention as: positive X means next document, current page moves left.
        let deltaX = -event.scrollingDeltaX
        let deltaY = event.scrollingDeltaY

        if abs(deltaX) > 0.1 || abs(deltaY) > 0.1 {
            if gestureSampleCount == 0 {
                gestureStartDate = Date()
            }
            gestureSampleCount += 1
            accumulatedX += deltaX
            accumulatedY += deltaY
            updateGestureModeIfNeeded()
        }

        if shouldTriggerQuickSwipe(deltaX: deltaX) {
            let direction: Direction = accumulatedX > 0 ? .next : .previous
            onProgress(direction.progress)
            trigger(direction)
            accumulatedX = 0
            accumulatedY = 0
            lastPublishedProgress = 0
            gestureMode = .horizontal
            didTriggerQuickSwipe = true
            return true
        }

        if gestureMode == .horizontal {
            publishProgressIfNeeded()
        }

        let shouldConsume = gestureMode == .horizontal

        if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            finishScrollGesture()
        } else if gestureMode == .horizontal {
            scheduleIdleFinish()
        }

        return shouldConsume
    }

    private func handleSwipe(_ event: NSEvent) -> Bool {
        let deltaX = -event.deltaX
        guard abs(deltaX) > 0.1 else { return false }
        let direction: Direction = deltaX > 0 ? .next : .previous
        onProgress(direction.progress)
        trigger(direction)
        resetGesture()
        return true
    }

    private func trigger(_ direction: Direction) {
        let now = Date()
        guard now.timeIntervalSince(lastTriggerDate) >= triggerCooldown else {
            onCancel()
            return
        }

        lastTriggerDate = now

        switch direction {
        case .next:
            onNext()
        case .previous:
            onPrevious()
        }
    }

    private func updateGestureModeIfNeeded() {
        guard gestureMode == .undecided else { return }

        let horizontalDistance = abs(accumulatedX)
        let verticalDistance = abs(accumulatedY)

        if horizontalDistance >= lockThreshold,
           horizontalDistance >= max(1, verticalDistance) * lockDominanceRatio {
            gestureMode = .horizontal
            publishProgressIfNeeded(force: true)
        } else if verticalDistance >= lockThreshold,
                  verticalDistance > max(1, horizontalDistance) * 1.1 {
            gestureMode = .vertical
        }
    }

    private func shouldTriggerQuickSwipe(deltaX: CGFloat) -> Bool {
        guard gestureMode == .horizontal else { return false }
        guard gestureSampleCount > 0, gestureSampleCount <= quickSwipeMaxSamples else { return false }
        guard Date().timeIntervalSince(gestureStartDate) <= quickSwipeInitialWindow else { return false }

        let horizontalDistance = abs(accumulatedX)
        let verticalDistance = abs(accumulatedY)
        guard horizontalDistance >= triggerThreshold else { return false }
        guard abs(deltaX) >= quickSwipeDeltaThreshold else { return false }
        guard horizontalDistance >= max(1, verticalDistance) * quickSwipeDominanceRatio else { return false }

        return true
    }

    private func finishScrollGesture() {
        defer { resetGesture() }

        guard gestureMode == .horizontal else { return }
        guard !didTriggerQuickSwipe else { return }

        let horizontalDistance = abs(accumulatedX)
        let verticalDistance = abs(accumulatedY)
        if horizontalDistance >= triggerThreshold,
           horizontalDistance >= max(1, verticalDistance) * dominanceRatio {
            trigger(accumulatedX > 0 ? .next : .previous)
        } else {
            onCancel()
        }
    }

    private func publishProgressIfNeeded(force: Bool = false) {
        let rawProgress = accumulatedX / progressTravelThreshold
        let progress = min(max(rawProgress, -1.12), 1.12)
        let now = Date()
        guard force
                || abs(progress - lastPublishedProgress) >= progressEpsilon
                || now.timeIntervalSince(lastProgressUpdate) >= progressUpdateInterval
        else { return }

        lastPublishedProgress = progress
        lastProgressUpdate = now
        onProgress(progress)
    }

    private func scheduleIdleFinish() {
        idleFinishGeneration &+= 1
        let generation = idleFinishGeneration
        idleFinishTask?.cancel()

        let delay = gestureIdleTimeout
        idleFinishTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled,
                  let self,
                  self.idleFinishGeneration == generation
            else { return }
            self.idleFinishTask = nil
            self.finishScrollGesture()
        }
    }

    private func resetGesture() {
        idleFinishGeneration &+= 1
        idleFinishTask?.cancel()
        idleFinishTask = nil
        accumulatedX = 0
        accumulatedY = 0
        gestureMode = .undecided
        lastPublishedProgress = 0
        gestureStartDate = Date.distantPast
        gestureSampleCount = 0
        didTriggerQuickSwipe = false
    }

    private enum Direction {
        case next
        case previous

        var progress: CGFloat {
            switch self {
            case .next: 1
            case .previous: -1
            }
        }
    }

    private enum GestureMode {
        case undecided
        case horizontal
        case vertical
    }
}
