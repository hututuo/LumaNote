@preconcurrency import AppKit
import SwiftUI

struct WindowDragView: NSViewRepresentable {
    func makeNSView(context: Context) -> DragNSView {
        DragNSView()
    }

    func updateNSView(_ nsView: DragNSView, context: Context) {}
}

struct WindowClickDragView: NSViewRepresentable {
    var onClick: () -> Void
    var dragStartsImmediately = false

    func makeCoordinator() -> Coordinator {
        Coordinator(onClick: onClick, dragStartsImmediately: dragStartsImmediately)
    }

    func makeNSView(context: Context) -> ClickDragNSView {
        ClickDragNSView(coordinator: context.coordinator)
    }

    func updateNSView(_ nsView: ClickDragNSView, context: Context) {
        context.coordinator.onClick = onClick
        context.coordinator.dragStartsImmediately = dragStartsImmediately
    }

    final class Coordinator {
        var onClick: () -> Void
        var dragStartsImmediately: Bool

        init(onClick: @escaping () -> Void, dragStartsImmediately: Bool) {
            self.onClick = onClick
            self.dragStartsImmediately = dragStartsImmediately
        }
    }
}

struct WindowActivityMonitorView: NSViewRepresentable {
    var onActivity: (_ shouldRevealChrome: Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onActivity: onActivity)
    }

    func makeNSView(context: Context) -> ActivityMonitorNSView {
        let view = ActivityMonitorNSView(coordinator: context.coordinator)
        context.coordinator.installMonitor()
        return view
    }

    func updateNSView(_ nsView: ActivityMonitorNSView, context: Context) {
        context.coordinator.onActivity = onActivity
        context.coordinator.installMonitor()
    }

    static func dismantleNSView(_ nsView: ActivityMonitorNSView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    final class Coordinator {
        var onActivity: (_ shouldRevealChrome: Bool) -> Void
        var windowNumber = 0

        private var monitor: Any?
        private var lastPointerActivityAt = Date.distantPast

        init(onActivity: @escaping (_ shouldRevealChrome: Bool) -> Void) {
            self.onActivity = onActivity
        }

        deinit {
            removeMonitor()
        }

        func installMonitor() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [
                .leftMouseDown,
                .rightMouseDown,
                .otherMouseDown,
                .leftMouseDragged,
                .rightMouseDragged,
                .otherMouseDragged,
                .mouseMoved,
                .scrollWheel,
                .keyDown
            ]) { [weak self] event in
                self?.handle(event)
                return event
            }
        }

        func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }

        private func handle(_ event: NSEvent) {
            guard windowNumber != 0, event.windowNumber == windowNumber else {
                return
            }

            if event.type == .mouseMoved {
                let now = Date()
                guard now.timeIntervalSince(lastPointerActivityAt) > 0.12 else {
                    return
                }
                lastPointerActivityAt = now
                onActivity(false)
                return
            }

            onActivity(true)
        }
    }
}

final class DragNSView: NSView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

final class ClickDragNSView: NSView {
    private let coordinator: WindowClickDragView.Coordinator

    init(coordinator: WindowClickDragView.Coordinator) {
        self.coordinator = coordinator
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else {
            coordinator.onClick()
            return
        }

        let startingFrame = window.frame
        let startingLocation = window.convertPoint(toScreen: event.locationInWindow)
        let dragThreshold: CGFloat = coordinator.dragStartsImmediately ? 0.6 : 3.0

        while true {
            guard let nextEvent = window.nextEvent(
                matching: [.leftMouseDragged, .leftMouseUp],
                until: .distantFuture,
                inMode: .eventTracking,
                dequeue: true
            ) else {
                return
            }

            switch nextEvent.type {
            case .leftMouseDragged:
                let currentLocation = window.convertPoint(toScreen: nextEvent.locationInWindow)
                guard startingLocation.distance(to: currentLocation) >= dragThreshold else {
                    continue
                }

                window.performDrag(with: event)
                return

            case .leftMouseUp:
                let endingLocation = window.convertPoint(toScreen: nextEvent.locationInWindow)
                let windowMoved = startingFrame.origin.distance(to: window.frame.origin) > 0.75
                let pointerMoved = startingLocation.distance(to: endingLocation) >= dragThreshold
                if !windowMoved && !pointerMoved {
                    coordinator.onClick()
                }
                return

            default:
                continue
            }
        }
    }

    override func mouseDragged(with event: NSEvent) {
        window?.performDrag(with: event)
    }

    override func mouseUp(with event: NSEvent) {}
}

private extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        abs(x - point.x) + abs(y - point.y)
    }
}

final class ActivityMonitorNSView: NSView {
    private let coordinator: WindowActivityMonitorView.Coordinator

    init(coordinator: WindowActivityMonitorView.Coordinator) {
        self.coordinator = coordinator
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        coordinator.windowNumber = window?.windowNumber ?? 0
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
