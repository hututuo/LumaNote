import AppKit

final class MarkdownScrollView: NSScrollView {
    private let scrollIndicator = MarkdownScrollIndicatorView()
    private var isRefreshingScrollIndicator = false
    private var cachedDocumentHeight: CGFloat?
    private var lastViewportWidth: CGFloat = 0
    private var lastViewportHeight: CGFloat = 0
    private var liveResizeState = MarkdownScrollViewLiveResizeState()
    private weak var observedWindow: NSWindow?
    private static let bottomBreathingSpaceRatio: CGFloat = 2.0 / 3.0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        installScrollIndicator()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        installScrollIndicator()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override var documentView: NSView? {
        didSet {
            observeScrollGeometry()
            refreshScrollIndicator()
        }
    }

    override func scrollWheel(with event: NSEvent) {
        scrollIndicator.markActive()
        super.scrollWheel(with: event)
        refreshScrollIndicator()
    }

    override func layout() {
        super.layout()
        invalidateDocumentHeightIfNeeded()
        layoutScrollIndicator()
        refreshScrollIndicator()
    }

    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        finishLiveResizeIfNeeded()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        observeWindowLiveResize()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow !== observedWindow {
            removeWindowLiveResizeObserver()
        }
        super.viewWillMove(toWindow: newWindow)
    }

    private var isLiveResizingForLayout: Bool {
        liveResizeState.isLiveResizing(viewInLiveResize: inLiveResize)
    }

    private func observeWindowLiveResize() {
        guard window !== observedWindow else { return }
        removeWindowLiveResizeObserver()
        observedWindow = window
        guard let window else { return }
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
    }

    private func removeWindowLiveResizeObserver() {
        guard let observedWindow else { return }
        NotificationCenter.default.removeObserver(
            self,
            name: NSWindow.willStartLiveResizeNotification,
            object: observedWindow
        )
        NotificationCenter.default.removeObserver(
            self,
            name: NSWindow.didEndLiveResizeNotification,
            object: observedWindow
        )
        self.observedWindow = nil
    }

    @objc private func windowWillStartLiveResize(_ notification: Notification) {
        liveResizeState.windowLiveResizeDidStart()
    }

    @objc private func windowDidEndLiveResize(_ notification: Notification) {
        finishLiveResizeIfNeeded()
    }

    private func finishLiveResizeIfNeeded() {
        guard liveResizeState.windowLiveResizeDidEnd() else { return }
        invalidateDocumentHeight()
        refreshScrollIndicator()
    }

    func invalidateDocumentHeight() {
        cachedDocumentHeight = nil
    }

    var markdownTextView: NSTextView? {
        (documentView as? MarkdownDocumentView)?.textView ?? documentView as? NSTextView
    }

    func setMarkdownTextView(_ textView: NSTextView) {
        documentView = MarkdownDocumentView(textView: textView)
        refreshScrollIndicator()
    }

    func refreshScrollIndicator() {
        guard !isRefreshingScrollIndicator else { return }
        isRefreshingScrollIndicator = true
        defer { isRefreshingScrollIndicator = false }

        layoutScrollIndicator()
        invalidateDocumentHeightIfNeeded()

        guard let documentView else {
            scrollIndicator.isHidden = true
            return
        }

        let viewportHeight = max(1, contentView.bounds.height)
        let hadCachedDocumentHeight = cachedDocumentHeight != nil
        let shouldDeferLiveResizeLayout = liveResizeState.shouldDeferMeasurement(
            hasCachedDocumentHeight: hadCachedDocumentHeight,
            isInLiveResize: isLiveResizingForLayout
        )
        let documentHeight: CGFloat
        if let cachedDocumentHeight, shouldDeferLiveResizeLayout {
            documentHeight = cachedDocumentHeight
        } else if let cachedDocumentHeight {
            documentHeight = cachedDocumentHeight
        } else {
            documentHeight = measuredDocumentHeight(for: documentView, viewportHeight: viewportHeight)
            cachedDocumentHeight = documentHeight
        }
        if !liveResizeState.shouldDeferDocumentFrameUpdate(
            hasCachedDocumentHeight: hadCachedDocumentHeight,
            isInLiveResize: isLiveResizingForLayout
        ) {
            updateDocumentFrame(for: documentView, documentHeight: documentHeight)
        }
        guard documentHeight > viewportHeight + 1 else {
            scrollIndicator.isHidden = true
            return
        }

        let maxOffset = max(1, documentHeight - viewportHeight)
        let offset = min(max(scrollOffset(for: documentView, documentHeight: documentHeight), 0), maxOffset)
        let progress = offset / maxOffset
        let thumbHeight = max(24, viewportHeight / documentHeight * scrollIndicator.bounds.height)

        scrollIndicator.isHidden = false
        scrollIndicator.update(progress: progress, thumbHeight: thumbHeight)
    }

    private func installScrollIndicator() {
        drawsBackground = false
        addSubview(scrollIndicator, positioned: .above, relativeTo: nil)
        observeScrollGeometry()
    }

    private func observeScrollGeometry() {
        NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSView.frameDidChangeNotification, object: nil)

        contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scrollGeometryDidChange(_:)),
            name: NSView.boundsDidChangeNotification,
            object: contentView
        )

        documentView?.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scrollGeometryDidChange(_:)),
            name: NSView.frameDidChangeNotification,
            object: documentView
        )
    }

    private func layoutScrollIndicator() {
        let width: CGFloat = 5
        let x = max(0, bounds.width - width + 3)
        let y = contentView.frame.minY + 2
        let height = max(0, contentView.frame.height - 4)
        scrollIndicator.frame = NSRect(x: x, y: y, width: width, height: height)
    }

    private func measuredDocumentHeight(for documentView: NSView, viewportHeight: CGFloat) -> CGFloat {
        guard let textView = (documentView as? MarkdownDocumentView)?.textView ?? documentView as? NSTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer
        else {
            return max(viewportHeight, documentView.bounds.height, documentView.frame.height)
        }

        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        let textHeight = ceil(usedRect.maxY + textView.textContainerInset.height * 2)
        let bottomBreathingSpace = viewportHeight * Self.bottomBreathingSpaceRatio
        let documentHeight = max(viewportHeight, textHeight + bottomBreathingSpace)
        if let documentView = documentView as? MarkdownDocumentView {
            documentView.updateTextFrame(
                width: contentView.bounds.width,
                height: max(textHeight, min(viewportHeight, documentHeight))
            )
        }
        return documentHeight
    }

    private func updateDocumentFrame(for documentView: NSView, documentHeight: CGFloat) {
        guard documentHeight.isFinite, documentHeight > 0 else { return }
        let targetWidth = max(1, contentView.bounds.width)
        let targetHeight = max(contentView.bounds.height, documentHeight)
        guard abs(documentView.frame.width - targetWidth) > 0.5
            || abs(documentView.frame.height - targetHeight) > 0.5
        else { return }

        var frame = documentView.frame
        frame.size.width = targetWidth
        frame.size.height = targetHeight
        documentView.frame = frame
    }

    private func scrollOffset(for documentView: NSView, documentHeight: CGFloat) -> CGFloat {
        let visibleRect = documentView.visibleRect
        if documentView.isFlipped {
            return visibleRect.minY
        }
        return documentHeight - visibleRect.maxY
    }

    private func invalidateDocumentHeightIfNeeded() {
        let viewportWidth = contentView.bounds.width
        let viewportHeight = contentView.bounds.height
        if abs(viewportWidth - lastViewportWidth) > 0.5
            || abs(viewportHeight - lastViewportHeight) > 0.5
        {
            lastViewportWidth = viewportWidth
            lastViewportHeight = viewportHeight
            if liveResizeState.shouldDeferInvalidation(
                hasCachedDocumentHeight: cachedDocumentHeight != nil,
                isInLiveResize: isLiveResizingForLayout
            ) {
                return
            }
            invalidateDocumentHeight()
        }
    }

    @objc private func scrollGeometryDidChange(_ notification: Notification) {
        if let object = notification.object as? NSView, object === documentView {
            if liveResizeState.shouldDeferInvalidation(
                hasCachedDocumentHeight: cachedDocumentHeight != nil,
                isInLiveResize: isLiveResizingForLayout
            ) {
                return
            }
            invalidateDocumentHeight()
        } else {
            invalidateDocumentHeightIfNeeded()
        }
        refreshScrollIndicator()
    }
}

struct MarkdownScrollViewLiveResizeState {
    private var needsPostResizeRefresh = false
    private var isWindowLiveResizing = false

    func isLiveResizing(viewInLiveResize: Bool) -> Bool {
        viewInLiveResize || isWindowLiveResizing
    }

    mutating func windowLiveResizeDidStart() {
        isWindowLiveResizing = true
    }

    mutating func windowLiveResizeDidEnd() -> Bool {
        isWindowLiveResizing = false
        return consumeNeedsPostResizeRefresh()
    }

    mutating func shouldDeferMeasurement(
        hasCachedDocumentHeight: Bool,
        isInLiveResize: Bool
    ) -> Bool {
        shouldDeferLiveResizeLayoutWork(
            hasCachedDocumentHeight: hasCachedDocumentHeight,
            isInLiveResize: isInLiveResize
        )
    }

    mutating func shouldDeferDocumentFrameUpdate(
        hasCachedDocumentHeight: Bool,
        isInLiveResize: Bool
    ) -> Bool {
        shouldDeferLiveResizeLayoutWork(
            hasCachedDocumentHeight: hasCachedDocumentHeight,
            isInLiveResize: isInLiveResize
        )
    }

    private mutating func shouldDeferLiveResizeLayoutWork(
        hasCachedDocumentHeight: Bool,
        isInLiveResize: Bool
    ) -> Bool {
        guard isInLiveResize, hasCachedDocumentHeight else { return false }
        needsPostResizeRefresh = true
        return true
    }

    mutating func shouldDeferInvalidation(
        hasCachedDocumentHeight: Bool,
        isInLiveResize: Bool
    ) -> Bool {
        guard isInLiveResize, hasCachedDocumentHeight else { return false }
        needsPostResizeRefresh = true
        return true
    }

    mutating func consumeNeedsPostResizeRefresh() -> Bool {
        defer { needsPostResizeRefresh = false }
        return needsPostResizeRefresh
    }
}

private final class MarkdownDocumentView: NSView {
    let textView: NSTextView
    private var textFrameHeight: CGFloat = 0

    init(textView: NSTextView) {
        self.textView = textView
        super.init(frame: .zero)
        addSubview(textView)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool {
        true
    }

    override func layout() {
        super.layout()
        updateTextFrame(width: bounds.width, height: textFrameHeight)
    }

    func updateTextFrame(width: CGFloat, height: CGFloat) {
        let targetHeight = max(1, height)
        textFrameHeight = targetHeight
        let targetFrame = NSRect(x: 0, y: 0, width: max(1, width), height: targetHeight)
        guard abs(textView.frame.width - targetFrame.width) > 0.5
            || abs(textView.frame.height - targetFrame.height) > 0.5
        else { return }
        textView.frame = targetFrame
    }
}

private final class MarkdownScrollIndicatorView: NSView {
    private var isPointerInside = false
    private var isRecentlyActive = false
    private var visualProgress: CGFloat = 0
    private var scrollProgress: CGFloat = 0
    private var thumbHeight: CGFloat = 24
    private var trackingAreaToken: NSTrackingArea?
    private var idleGeneration = 0
    private var animationGeneration = 0
    private var idleTask: Task<Void, Never>?
    private var animationTask: Task<Void, Never>?
    private var animationTarget: CGFloat = 0

    deinit {
        idleTask?.cancel()
        animationTask?.cancel()
    }

    override var isFlipped: Bool {
        true
    }

    override func updateTrackingAreas() {
        if let trackingAreaToken {
            removeTrackingArea(trackingAreaToken)
        }

        let area = NSTrackingArea(
            rect: .zero,
            options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited],
            owner: self
        )
        addTrackingArea(area)
        trackingAreaToken = area
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        setPointerInside(true)
        super.mouseEntered(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        setPointerInside(false)
        super.mouseExited(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let progress = min(max(visualProgress, 0), 1)
        let knobWidth = 2 + progress * 1
        let availableTravel = max(0, bounds.height - thumbHeight)
        let y = availableTravel * min(max(scrollProgress, 0), 1)
        let knobRect = NSRect(
            x: (bounds.width - knobWidth) / 2,
            y: y,
            width: knobWidth,
            height: thumbHeight
        ).insetBy(dx: 0, dy: 1.5 - progress * 0.8)

        guard knobRect.height > 8 else { return }
        NSColor.systemGray.withAlphaComponent(0.36 + progress * 0.2).setFill()
        NSBezierPath(roundedRect: knobRect, xRadius: knobRect.width / 2, yRadius: knobRect.width / 2).fill()
    }

    func update(progress: CGFloat, thumbHeight: CGFloat) {
        scrollProgress = min(max(progress, 0), 1)
        self.thumbHeight = min(max(thumbHeight, 24), max(24, bounds.height))
        needsDisplay = true
    }

    func markActive() {
        isRecentlyActive = true
        animateVisibility(to: targetVisualProgress)
        idleGeneration += 1
        let generation = idleGeneration

        idleTask?.cancel()
        idleTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled,
                  let self,
                  self.idleGeneration == generation
            else { return }
            self.isRecentlyActive = false
            self.animateVisibility(to: self.targetVisualProgress)
            self.idleTask = nil
        }
    }

    private func setPointerInside(_ value: Bool) {
        isPointerInside = value
        animateVisibility(to: targetVisualProgress)
    }

    private var targetVisualProgress: CGFloat {
        isPointerInside || isRecentlyActive ? 1 : 0
    }

    private func animateVisibility(to target: CGFloat) {
        if abs(animationTarget - target) <= 0.01, animationTask != nil {
            return
        }
        animationTarget = target
        animationGeneration += 1
        let generation = animationGeneration
        let start = visualProgress
        let distance = target - start

        animationTask?.cancel()
        guard abs(distance) > 0.01 else {
            visualProgress = target
            needsDisplay = true
            animationTask = nil
            return
        }

        animationTask = Task { @MainActor [weak self] in
            let frames = 12
            for frame in 1...frames {
                guard !Task.isCancelled,
                      let self,
                      self.animationGeneration == generation
                else { return }
                let t = CGFloat(frame) / CGFloat(frames)
                let eased = 1 - pow(1 - t, 3)
                self.visualProgress = start + distance * eased
                self.needsDisplay = true
                try? await Task.sleep(for: .seconds(0.015))
            }
            guard !Task.isCancelled,
                  let self,
                  self.animationGeneration == generation
            else { return }
            self.visualProgress = target
            self.needsDisplay = true
            self.animationTask = nil
        }
    }
}
