import AppKit
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
