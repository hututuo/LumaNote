import AppKit
import SwiftUI

struct NoteWindowMetrics: Equatable {
    let backingScale: CGFloat
    let appearanceIdentity: String
    let isLiveResizing: Bool
}

/// Lightweight AppKit bridge for the actual note window. Screen-global scale
/// is not reliable when the panel crosses displays, so swipe previews use this
/// window-local identity instead.
struct NoteWindowMetricsBridge: NSViewRepresentable {
    let onChange: (NoteWindowMetrics) -> Void

    func makeNSView(context: Context) -> MetricsView {
        let view = MetricsView(onChange: onChange)
        view.frame = .zero
        return view
    }

    func updateNSView(_ nsView: MetricsView, context: Context) {
        nsView.onChange = onChange
        nsView.report()
    }

    final class MetricsView: NSView {
        var onChange: (NoteWindowMetrics) -> Void
        private weak var observedWindow: NSWindow?

        init(onChange: @escaping (NoteWindowMetrics) -> Void) {
            self.onChange = onChange
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) {
            onChange = { _ in }
            super.init(coder: coder)
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window !== observedWindow else {
                report()
                return
            }
            removeWindowObservers()
            observedWindow = window
            if let window {
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(windowWillStartLiveResize(_:)),
                    name: NSWindow.willStartLiveResizeNotification,
                    object: window
                )
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(windowDidEndLiveResize(_:)),
                    name: NSWindow.didEndLiveResizeNotification,
                    object: window
                )
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(windowDidChangeBackingProperties(_:)),
                    name: NSWindow.didChangeBackingPropertiesNotification,
                    object: window
                )
            }
            report()
        }

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            if newWindow !== observedWindow {
                removeWindowObservers()
            }
            super.viewWillMove(toWindow: newWindow)
        }

        deinit {
            // `deinit` is nonisolated for actor-isolated NSView subclasses;
            // unregister directly instead of calling the main-actor helper.
            NotificationCenter.default.removeObserver(self)
        }

        @objc private func windowWillStartLiveResize(_ notification: Notification) {
            report(isLiveResizing: true)
        }

        @objc private func windowDidEndLiveResize(_ notification: Notification) {
            report(isLiveResizing: false)
        }

        @objc private func windowDidChangeBackingProperties(_ notification: Notification) {
            report()
        }

        override func viewDidChangeEffectiveAppearance() {
            super.viewDidChangeEffectiveAppearance()
            report()
        }

        func report(isLiveResizing override: Bool? = nil) {
            let scale = max(1, window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2)
            let appearanceIdentity = window?.effectiveAppearance.name.rawValue ?? ""
            let isLiveResizing = override ?? window?.inLiveResize ?? false
            onChange(NoteWindowMetrics(
                backingScale: scale,
                appearanceIdentity: appearanceIdentity,
                isLiveResizing: isLiveResizing
            ))
        }

        private func removeWindowObservers() {
            guard let observedWindow else { return }
            NotificationCenter.default.removeObserver(self, name: nil, object: observedWindow)
            self.observedWindow = nil
        }
    }
}

enum NoteDocumentSwipePrewarmLayout {
    static let viewportQuantization: CGFloat = 8

    static func quantizedViewportSize(_ size: CGSize) -> CGSize {
        func quantize(_ value: CGFloat) -> CGFloat {
            guard value > 0 else { return 0 }
            return (value / viewportQuantization).rounded() * viewportQuantization
        }
        return CGSize(width: quantize(size.width), height: quantize(size.height))
    }
}
