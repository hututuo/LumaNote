import AppKit
import SwiftUI

struct MarkdownStaticPreviewView: NSViewRepresentable {
    let text: String
    let documentID: String
    let contentRevision: Int
    let fontSize: Double
    let accentColor: NSColor
    let documentPosition: MarkdownDocumentPosition?
    let initialSize: CGSize
    let preRenderedImage: NSImage?
    var appearanceIdentity: String = ""

    func makeNSView(context: Context) -> MarkdownStaticPreviewNSView {
        let view = MarkdownStaticPreviewNSView()
        view.frame = NSRect(origin: .zero, size: initialSize)
        view.configure(
            text: text,
            documentID: documentID,
            contentRevision: contentRevision,
            fontSize: CGFloat(fontSize),
            accentColor: accentColor,
            documentPosition: documentPosition,
            initialSize: initialSize,
            preRenderedImage: preRenderedImage,
            appearanceIdentity: appearanceIdentity
        )
        return view
    }

    func updateNSView(_ nsView: MarkdownStaticPreviewNSView, context: Context) {
        nsView.configure(
            text: text,
            documentID: documentID,
            contentRevision: contentRevision,
            fontSize: CGFloat(fontSize),
            accentColor: accentColor,
            documentPosition: documentPosition,
            initialSize: initialSize,
            preRenderedImage: preRenderedImage,
            appearanceIdentity: appearanceIdentity
        )
    }
}

enum MarkdownStaticPreviewLimits {
    static let maximumPixelDimension = 4096
    static let maximumPixelCount = 8_000_000
    static let maximumBitmapBytes = 32 * 1024 * 1024

    static func pixelDimensions(size: CGSize, backingScale: CGFloat) -> (width: Int, height: Int) {
        let scale = max(1, backingScale)
        let width = max(1, Int((max(1, size.width) * scale).rounded(.up)))
        let height = max(1, Int((max(1, size.height) * scale).rounded(.up)))
        return (width, height)
    }

    static func isWithinBudget(pixelWidth: Int, pixelHeight: Int) -> Bool {
        guard pixelWidth > 0, pixelHeight > 0,
              pixelWidth <= maximumPixelDimension,
              pixelHeight <= maximumPixelDimension,
              pixelWidth <= maximumPixelCount / max(1, pixelHeight)
        else { return false }
        let pixels = pixelWidth * pixelHeight
        return pixels <= maximumPixelCount
            && pixels <= maximumBitmapBytes / 4
    }

    static func scaleIdentity(_ backingScale: CGFloat) -> Int {
        Int((max(1, backingScale) * 1000).rounded())
    }
}

final class MarkdownStaticPreviewNSView: NSView {
    private struct Configuration {
        let text: String
        let documentID: String
        let contentRevision: Int
        let fontSize: CGFloat
        let accentColor: NSColor
        let documentPosition: MarkdownDocumentPosition?
        let initialSize: CGSize
        let preRenderedImage: NSImage?
        let appearanceIdentity: String
    }

    private struct RenderKey: Equatable {
        let documentID: String
        let contentRevision: Int
        let textHash: Int
        let fontSize: Int
        let accentColor: ColorSignature
        let documentPosition: MarkdownDocumentPosition?
        let pixelWidth: Int
        let pixelHeight: Int
        let backingScale: Int
        let appearanceIdentity: String
    }

    private struct ColorSignature: Equatable {
        let red: Int
        let green: Int
        let blue: Int
        let alpha: Int

        init(_ color: NSColor) {
            let rgb = color.usingColorSpace(.deviceRGB) ?? .systemCyan
            red = Int((rgb.redComponent * 1000).rounded())
            green = Int((rgb.greenComponent * 1000).rounded())
            blue = Int((rgb.blueComponent * 1000).rounded())
            alpha = Int((rgb.alphaComponent * 1000).rounded())
        }
    }

    private let imageView = NSImageView()
    private var configuration: Configuration?
    private var renderedKey: RenderKey?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        installImageView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        installImageView()
    }

    override func layout() {
        super.layout()
        imageView.frame = bounds
        renderIfNeeded()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        renderedKey = nil
        renderIfNeeded()
    }

    func configure(
        text: String,
        documentID: String,
        contentRevision: Int,
        fontSize: CGFloat,
        accentColor: NSColor,
        documentPosition: MarkdownDocumentPosition?,
        initialSize: CGSize,
        preRenderedImage: NSImage? = nil,
        appearanceIdentity: String = ""
    ) {
        configuration = Configuration(
            text: text,
            documentID: documentID,
            contentRevision: contentRevision,
            fontSize: MarkdownTaskLayout.normalizedFontSize(fontSize),
            accentColor: accentColor,
            documentPosition: documentPosition,
            initialSize: initialSize,
            preRenderedImage: preRenderedImage,
            appearanceIdentity: appearanceIdentity
        )
        renderIfNeeded()
    }

    private func installImageView() {
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        imageView.imageAlignment = .alignTopLeft
        imageView.imageScaling = .scaleAxesIndependently
        imageView.wantsLayer = true
        imageView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        imageView.frame = bounds
        imageView.autoresizingMask = [.width, .height]
        addSubview(imageView)
    }

    private func renderIfNeeded() {
        guard let configuration else { return }
        let scale = max(1, window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2)
        let appearanceIdentity = configuration.appearanceIdentity.isEmpty
            ? (window?.effectiveAppearance.name.rawValue ?? "")
            : configuration.appearanceIdentity
        let renderSize = resolvedRenderSize(configuration: configuration)
        let dimensions = MarkdownStaticPreviewLimits.pixelDimensions(size: renderSize, backingScale: scale)
        guard dimensions.width > 1,
              dimensions.height > 1,
              MarkdownStaticPreviewLimits.isWithinBudget(pixelWidth: dimensions.width, pixelHeight: dimensions.height)
        else {
            imageView.image = nil
            renderedKey = nil
            return
        }

        let key = RenderKey(
            documentID: configuration.documentID,
            contentRevision: configuration.contentRevision,
            textHash: configuration.text.hashValue,
            fontSize: Int((configuration.fontSize * 100).rounded()),
            accentColor: ColorSignature(configuration.accentColor),
            documentPosition: configuration.documentPosition,
            pixelWidth: dimensions.width,
            pixelHeight: dimensions.height,
            backingScale: MarkdownStaticPreviewLimits.scaleIdentity(scale),
            appearanceIdentity: appearanceIdentity
        )
        guard key != renderedKey else { return }

        if let preRenderedImage = configuration.preRenderedImage,
           Self.canReusePreRenderedImage(preRenderedImage, for: renderSize) {
            renderedKey = key
            imageView.image = preRenderedImage
            return
        }

        guard let image = MarkdownStaticPreviewRenderer.render(
            text: configuration.text,
            fontSize: configuration.fontSize,
            accentColor: configuration.accentColor,
            documentPosition: configuration.documentPosition,
            size: renderSize,
            backingScale: scale,
            appearance: NSAppearance(named: NSAppearance.Name(rawValue: appearanceIdentity))
        ) else { return }

        renderedKey = key
        imageView.image = image
    }

    private func resolvedRenderSize(configuration: Configuration) -> CGSize {
        if bounds.width > 1, bounds.height > 1 {
            return bounds.size
        }
        return CGSize(
            width: max(1, configuration.initialSize.width),
            height: max(1, configuration.initialSize.height)
        )
    }

    private static func canReusePreRenderedImage(_ image: NSImage, for renderSize: CGSize) -> Bool {
        guard abs(image.size.width - renderSize.width) <= 0.5,
              abs(image.size.height - renderSize.height) <= 0.5
        else { return false }
        guard let representation = image.representations.first else {
            // An NSImage created with only a logical size is a valid placeholder
            // used by callers/tests; with no bitmap representation there is no
            // pixel allocation to reject against the preview budget.
            return true
        }
        return MarkdownStaticPreviewLimits.isWithinBudget(
            pixelWidth: representation.pixelsWide,
            pixelHeight: representation.pixelsHigh
        )
    }
}

enum MarkdownStaticPreviewRenderer {
    @MainActor
    static func render(
        text: String,
        fontSize: CGFloat,
        accentColor: NSColor,
        documentPosition: MarkdownDocumentPosition?,
        size: CGSize,
        backingScale: CGFloat,
        appearance: NSAppearance? = nil
    ) -> NSImage? {
        let renderSize = CGSize(width: max(1, size.width), height: max(1, size.height))
        let dimensions = MarkdownStaticPreviewLimits.pixelDimensions(size: renderSize, backingScale: backingScale)
        guard MarkdownStaticPreviewLimits.isWithinBudget(
            pixelWidth: dimensions.width,
            pixelHeight: dimensions.height
        ) else { return nil }

        let renderBody: () -> NSImage? = {
        let bounds = NSRect(origin: .zero, size: renderSize)
        let scrollView = preparedScrollView(
            text: text,
            fontSize: fontSize,
            accentColor: accentColor,
            documentPosition: documentPosition,
            size: renderSize
        )

        guard let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: dimensions.width,
            pixelsHigh: dimensions.height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }

        representation.size = renderSize
        scrollView.cacheDisplay(in: bounds, to: representation)

        let image = NSImage(size: renderSize)
        image.addRepresentation(representation)
        return image
        }

        if let appearance {
            var renderedImage: NSImage?
            appearance.performAsCurrentDrawingAppearance {
                renderedImage = renderBody()
            }
            return renderedImage
        }
        return renderBody()
    }

    @MainActor
    static func styledStorageForTesting(
        text: String,
        fontSize: CGFloat,
        accentColor: NSColor,
        documentPosition: MarkdownDocumentPosition?,
        size: CGSize
    ) -> NSTextStorage {
        let scrollView = preparedScrollView(
            text: text,
            fontSize: fontSize,
            accentColor: accentColor,
            documentPosition: documentPosition,
            size: size
        )
        let storage = scrollView.markdownTextView?.textStorage ?? NSTextStorage()
        return NSTextStorage(attributedString: storage)
    }

    @MainActor
    static func glyphOriginXForTesting(
        text: String,
        fontSize: CGFloat,
        accentColor: NSColor,
        documentPosition: MarkdownDocumentPosition?,
        size: CGSize,
        characterLocation: Int
    ) -> CGFloat? {
        let scrollView = preparedScrollView(
            text: text,
            fontSize: fontSize,
            accentColor: accentColor,
            documentPosition: documentPosition,
            size: size
        )
        guard let textView = scrollView.markdownTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              characterLocation >= 0,
              characterLocation < (textView.string as NSString).length
        else { return nil }

        layoutManager.ensureLayout(for: textContainer)
        let glyphIndex = layoutManager.glyphIndexForCharacter(at: characterLocation)
        guard glyphIndex < layoutManager.numberOfGlyphs else { return nil }

        let rect = layoutManager.boundingRect(
            forGlyphRange: NSRange(location: glyphIndex, length: 1),
            in: textContainer
        )
        return textView.textContainerOrigin.x + rect.minX
    }

    @MainActor
    private static func preparedScrollView(
        text: String,
        fontSize: CGFloat,
        accentColor: NSColor,
        documentPosition: MarkdownDocumentPosition?,
        size: CGSize
    ) -> MarkdownScrollView {
        let renderSize = CGSize(width: max(1, size.width), height: max(1, size.height))
        let bounds = NSRect(origin: .zero, size: renderSize)
        let scrollView = makeScrollView(size: renderSize)
        let textView = makeTextView(text: text, fontSize: fontSize, accentColor: accentColor, width: renderSize.width)

        scrollView.setMarkdownTextView(textView)
        scrollView.frame = bounds
        scrollView.contentView.frame = bounds
        scrollView.layoutSubtreeIfNeeded()
        applyScrollPosition(documentPosition ?? .top, scrollView: scrollView)
        // Match the live editor's restored document position before styling.
        // This keeps active Markdown syntax, paragraph metrics, and glyph
        // origins identical while the static page is being swiped into place.
        let activeSelectionRanges = MarkdownRangeHelpers.nsRanges(from: textView.selectedRanges)
        applyMarkdownStyle(
            to: textView,
            fontSize: fontSize,
            activeSelectionRanges: activeSelectionRanges
        )
        scrollView.invalidateDocumentHeight()
        scrollView.refreshScrollIndicator()
        applyScrollPosition(documentPosition ?? .top, scrollView: scrollView)
        ensureLayout(for: textView)
        scrollView.layoutSubtreeIfNeeded()
        scrollView.displayIfNeeded()
        return scrollView
    }

    @MainActor
    private static func makeScrollView(size: CGSize) -> MarkdownScrollView {
        let scrollView = MarkdownScrollView(frame: NSRect(origin: .zero, size: size))
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        return scrollView
    }

    @MainActor
    private static func makeTextView(
        text: String,
        fontSize: CGFloat,
        accentColor: NSColor,
        width: CGFloat
    ) -> MarkdownTaskTextView {
        let textView = MarkdownTaskTextView(frame: NSRect(x: 0, y: 0, width: max(1, width), height: 1))
        textView.drawsBackground = false
        textView.isRichText = false
        textView.isEditable = false
        textView.isSelectable = false
        textView.allowsUndo = false
        textView.importsGraphics = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.enabledTextCheckingTypes = 0
        textView.smartInsertDeleteEnabled = false
        textView.textContainerInset = NSSize(width: 0, height: 10)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: max(1, width), height: CGFloat.greatestFiniteMagnitude)
        textView.layoutManager?.delegate = textView
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.insertionPointColor = accentColor
        textView.bodyFontSize = MarkdownTaskLayout.normalizedFontSize(fontSize)
        textView.taskAccentColor = accentColor
        textView.typingAttributes = MarkdownStyleAttributes(fontSize: fontSize).baseAttributes()
        textView.string = text
        return textView
    }

    @MainActor
    private static func applyMarkdownStyle(
        to textView: MarkdownTaskTextView,
        fontSize: CGFloat,
        activeSelectionRanges: [NSRange]
    ) {
        MarkdownEditorStyling.apply(
            to: textView,
            fontSize: fontSize,
            activeSelectionRanges: activeSelectionRanges
        )
    }

    @MainActor
    private static func applyScrollPosition(_ position: MarkdownDocumentPosition, scrollView: MarkdownScrollView) {
        guard let textView = scrollView.markdownTextView else { return }
        MarkdownDocumentPositionApplicator.apply(
            position,
            textView: textView,
            scrollView: scrollView
        )
    }

    @MainActor
    private static func ensureLayout(for textView: MarkdownTaskTextView) {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer
        else { return }

        layoutManager.ensureLayout(for: textContainer)
        textView.needsDisplay = true
    }
}
