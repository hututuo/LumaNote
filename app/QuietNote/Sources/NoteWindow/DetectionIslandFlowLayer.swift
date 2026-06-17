import AppKit
import SwiftUI

struct DetectionIslandFlowLayer: View {
    let shape: AnyInsettableShape
    let accentColor: Color
    let opacity: Double

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                shape
                    .fill(accentColor.opacity(0.025 + opacity * 0.035))

                DetectionIslandFlowAnimationView(accentColor: accentColor, opacity: opacity)
                    .frame(width: width, height: height)
                    .mask(shape)
            }
            .frame(width: width, height: height)
            .mask(shape)
            .opacity(0.62 + opacity * 0.18)
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
        }
    }
}

private struct DetectionIslandFlowAnimationView: NSViewRepresentable {
    let accentColor: Color
    let opacity: Double

    func makeNSView(context: Context) -> DetectionIslandFlowNSView {
        DetectionIslandFlowNSView()
    }

    func updateNSView(_ nsView: DetectionIslandFlowNSView, context: Context) {
        nsView.configure(accentColor: NSColor(accentColor), opacity: opacity)
    }
}

private final class DetectionIslandFlowNSView: NSView {
    private let baseLayer = CALayer()
    private let flowLayer = CALayer()
    private var currentAccentColor: NSColor = .systemCyan
    private var currentOpacity: Double = 0
    private var lastAnimationSize: CGSize = .zero
    private var lastRenderedKey: RenderKey?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        let rootLayer = CALayer()
        rootLayer.masksToBounds = true
        rootLayer.isGeometryFlipped = true
        layer = rootLayer

        baseLayer.backgroundColor = currentAccentColor.withAlphaComponent(0.06).cgColor
        rootLayer.addSublayer(baseLayer)

        flowLayer.contentsGravity = .resizeAspectFill
        flowLayer.masksToBounds = false
        flowLayer.cornerRadius = 999
        flowLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        flowLayer.transform = CATransform3DMakeRotation(10 * .pi / 180, 0, 0, 1)
        rootLayer.addSublayer(flowLayer)
        updateLayerColors()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        updateLayerGeometry(restartAnimationIfNeeded: false)
    }

    func configure(accentColor: NSColor, opacity: Double) {
        let rgbAccent = accentColor.usingColorSpace(.deviceRGB) ?? .systemCyan
        if !currentAccentColor.isEqual(rgbAccent) || abs(currentOpacity - opacity) > 0.001 {
            currentAccentColor = rgbAccent
            currentOpacity = opacity
            updateLayerColors()
            lastRenderedKey = nil
        }
        updateLayerGeometry(restartAnimationIfNeeded: false)
    }

    private func updateLayerColors() {
        baseLayer.backgroundColor = currentAccentColor.withAlphaComponent(0.025 + currentOpacity * 0.045).cgColor
    }

    private func updateLayerGeometry(restartAnimationIfNeeded: Bool) {
        guard bounds.width > 1, bounds.height > 1 else { return }

        let cornerRadius = bounds.height / 2
        layer?.cornerRadius = cornerRadius
        baseLayer.frame = bounds
        baseLayer.cornerRadius = cornerRadius

        let sweepWidth = max(84, bounds.width * 0.92)
        let sweepHeight = max(44, bounds.height * 2.7)
        flowLayer.bounds = CGRect(x: 0, y: 0, width: sweepWidth, height: sweepHeight)
        flowLayer.position.y = bounds.midY
        flowLayer.cornerRadius = sweepHeight / 2

        updatePreRenderedSweepImage(size: CGSize(width: sweepWidth, height: sweepHeight))

        let didSizeChange = lastAnimationSize != bounds.size
        if restartAnimationIfNeeded || didSizeChange || flowLayer.animation(forKey: "flowPosition") == nil {
            lastAnimationSize = bounds.size
            startFlowAnimation(sweepWidth: sweepWidth)
        }
    }

    private func updatePreRenderedSweepImage(size: CGSize) {
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let pixelWidth = Int((size.width * scale).rounded())
        let pixelHeight = Int((size.height * scale).rounded())
        let accent = currentAccentColor.usingColorSpace(.deviceRGB)
            ?? NSColor(calibratedRed: 0.10, green: 0.72, blue: 0.86, alpha: 1)
        let key = RenderKey(
            width: pixelWidth,
            height: pixelHeight,
            accentRed: roundedColorComponent(accent.redComponent),
            accentGreen: roundedColorComponent(accent.greenComponent),
            accentBlue: roundedColorComponent(accent.blueComponent),
            opacity: Int((currentOpacity * 1_000).rounded())
        )

        guard key != lastRenderedKey else { return }
        flowLayer.contents = makeSweepImage(pixelWidth: pixelWidth, pixelHeight: pixelHeight)
        lastRenderedKey = key
    }

    private func makeSweepImage(pixelWidth: Int, pixelHeight: Int) -> CGImage? {
        guard pixelWidth > 0, pixelHeight > 0,
              let context = CGContext(
                data: nil,
                width: pixelWidth,
                height: pixelHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }

        context.clear(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

        let accent = currentAccentColor.usingColorSpace(.deviceRGB) ?? .systemCyan
        let alphaBoost = CGFloat(currentOpacity)
        let colors = [
            accent.withAlphaComponent(0).cgColor,
            accent.withAlphaComponent(0.10 + alphaBoost * 0.10).cgColor,
            NSColor.white.withAlphaComponent(0.18 + alphaBoost * 0.10).cgColor,
            accent.withAlphaComponent(0.11 + alphaBoost * 0.09).cgColor,
            accent.withAlphaComponent(0).cgColor
        ] as CFArray
        let locations: [CGFloat] = [0.00, 0.28, 0.50, 0.72, 1.00]

        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: locations
        ) else { return nil }

        let rect = CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight)
        let insetY = rect.height * 0.17
        let roundedRect = rect.insetBy(dx: 0, dy: insetY)
        let path = CGPath(
            roundedRect: roundedRect,
            cornerWidth: roundedRect.height / 2,
            cornerHeight: roundedRect.height / 2,
            transform: nil
        )
        context.addPath(path)
        context.clip()
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: rect.midY),
            end: CGPoint(x: rect.maxX, y: rect.midY),
            options: []
        )

        return context.makeImage()
    }

    private func roundedColorComponent(_ value: CGFloat) -> Int {
        Int((value * 1_000).rounded())
    }

    private func startFlowAnimation(sweepWidth: CGFloat) {
        let fromX = -sweepWidth * 0.72
        let toX = bounds.width + sweepWidth * 0.72

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        flowLayer.position.x = fromX
        CATransaction.commit()

        let animation = CABasicAnimation(keyPath: "position.x")
        animation.fromValue = fromX
        animation.toValue = toX
        animation.duration = 3.2
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.isRemovedOnCompletion = false
        flowLayer.add(animation, forKey: "flowPosition")
    }

    private struct RenderKey: Equatable {
        let width: Int
        let height: Int
        let accentRed: Int
        let accentGreen: Int
        let accentBlue: Int
        let opacity: Int
    }
}

struct AnyInsettableShape: InsettableShape {
    private let pathBuilder: @Sendable (CGRect) -> Path
    private let insetBuilder: @Sendable (CGFloat) -> AnyInsettableShape

    init<S: InsettableShape>(_ shape: S) {
        pathBuilder = { rect in
            shape.path(in: rect)
        }
        insetBuilder = { amount in
            AnyInsettableShape(shape.inset(by: amount))
        }
    }

    func path(in rect: CGRect) -> Path {
        pathBuilder(rect)
    }

    func inset(by amount: CGFloat) -> AnyInsettableShape {
        insetBuilder(amount)
    }
}
