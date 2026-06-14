import AppKit
import SwiftUI

struct DocumentSwipeMonitorView: NSViewRepresentable {
    var isEnabled: Bool
    var onNext: () -> Void
    var onPrevious: () -> Void

    func makeNSView(context: Context) -> DocumentSwipeMonitorNSView {
        let view = DocumentSwipeMonitorNSView()
        view.isEnabled = isEnabled
        view.onNext = onNext
        view.onPrevious = onPrevious
        return view
    }

    func updateNSView(_ nsView: DocumentSwipeMonitorNSView, context: Context) {
        nsView.isEnabled = isEnabled
        nsView.onNext = onNext
        nsView.onPrevious = onPrevious
    }
}

final class DocumentSwipeMonitorNSView: NSView {
    var isEnabled = true
    var onNext: () -> Void = {}
    var onPrevious: () -> Void = {}

    private var eventMonitor: Any?
    private var accumulatedX: CGFloat = 0
    private var accumulatedY: CGFloat = 0
    private var didTriggerInGesture = false
    private var lastTriggerDate = Date.distantPast

    private let triggerThreshold: CGFloat = 78
    private let dominanceRatio: CGFloat = 1.55
    private let triggerCooldown: TimeInterval = 0.46

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
            self?.handle(event)
            return event
        }
    }

    private func removeEventMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
        resetGesture()
    }

    private func handle(_ event: NSEvent) {
        guard isEnabled, event.window === window else { return }

        switch event.type {
        case .scrollWheel:
            handleScrollWheel(event)
        case .swipe:
            handleSwipe(event)
        default:
            break
        }
    }

    private func handleScrollWheel(_ event: NSEvent) {
        guard event.momentumPhase.isEmpty else { return }
        guard event.hasPreciseScrollingDeltas || !event.phase.isEmpty else { return }

        if event.phase.contains(.began) || event.phase.contains(.mayBegin) {
            resetGesture()
        }

        let deltaX = event.scrollingDeltaX
        let deltaY = event.scrollingDeltaY
        guard abs(deltaX) > 0.1 else {
            resetIfGestureEnded(event)
            return
        }

        accumulatedX += deltaX
        accumulatedY += deltaY

        let horizontalDistance = abs(accumulatedX)
        let verticalDistance = abs(accumulatedY)
        if !didTriggerInGesture,
           horizontalDistance >= triggerThreshold,
           horizontalDistance >= verticalDistance * dominanceRatio {
            trigger(accumulatedX > 0 ? .next : .previous)
        }

        resetIfGestureEnded(event)
    }

    private func handleSwipe(_ event: NSEvent) {
        let deltaX = event.deltaX
        guard abs(deltaX) > 0.1 else { return }
        trigger(deltaX > 0 ? .next : .previous)
    }

    private func trigger(_ direction: Direction) {
        let now = Date()
        guard now.timeIntervalSince(lastTriggerDate) >= triggerCooldown else { return }

        didTriggerInGesture = true
        lastTriggerDate = now

        switch direction {
        case .next:
            onNext()
        case .previous:
            onPrevious()
        }
    }

    private func resetIfGestureEnded(_ event: NSEvent) {
        if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            resetGesture()
        }
    }

    private func resetGesture() {
        accumulatedX = 0
        accumulatedY = 0
        didTriggerInGesture = false
    }

    private enum Direction {
        case next
        case previous
    }
}
