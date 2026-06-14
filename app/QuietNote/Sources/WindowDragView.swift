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

    func makeCoordinator() -> Coordinator {
        Coordinator(onClick: onClick)
    }

    func makeNSView(context: Context) -> ClickDragNSView {
        ClickDragNSView(coordinator: context.coordinator)
    }

    func updateNSView(_ nsView: ClickDragNSView, context: Context) {
        context.coordinator.onClick = onClick
    }

    final class Coordinator {
        var onClick: () -> Void

        init(onClick: @escaping () -> Void) {
            self.onClick = onClick
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
    private var mouseDownEvent: NSEvent?
    private var didDrag = false

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
        mouseDownEvent = event
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !didDrag, let mouseDownEvent else {
            return
        }

        didDrag = true
        window?.performDrag(with: mouseDownEvent)
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            mouseDownEvent = nil
            didDrag = false
        }

        if !didDrag {
            coordinator.onClick()
        }
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
