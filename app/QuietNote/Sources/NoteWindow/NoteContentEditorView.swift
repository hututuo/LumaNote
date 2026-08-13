import AppKit
import SwiftUI

struct NoteDocumentSwipePreview: Identifiable, Equatable {
    let id: String
    let url: URL
    let offset: Int
    let text: String
    let position: MarkdownDocumentPosition?
    let revision: Int
    let preRenderedImage: NSImage?
    let modificationDate: Date?

    init(
        id: String,
        url: URL,
        offset: Int,
        text: String,
        position: MarkdownDocumentPosition?,
        revision: Int,
        preRenderedImage: NSImage? = nil,
        modificationDate: Date? = nil
    ) {
        self.id = id
        self.url = url
        self.offset = offset
        self.text = text
        self.position = position
        self.revision = revision
        self.preRenderedImage = preRenderedImage
        self.modificationDate = modificationDate
    }

    static func == (lhs: NoteDocumentSwipePreview, rhs: NoteDocumentSwipePreview) -> Bool {
        lhs.id == rhs.id
            && lhs.url == rhs.url
            && lhs.offset == rhs.offset
            && lhs.text == rhs.text
            && lhs.position == rhs.position
            && lhs.revision == rhs.revision
            && lhs.preRenderedImage === rhs.preRenderedImage
            && lhs.modificationDate == rhs.modificationDate
    }
}

struct NoteContentEditorLayoutMetrics: Equatable {
    let editorFrame: CGRect
    let fadeMaskFrame: CGRect
    let scrollIndicatorOpaqueStripFrame: CGRect
}

enum NoteContentEditorLayout {
    static let scrollIndicatorOpaqueStripWidth: CGFloat = 12

    static func metrics(
        for size: CGSize,
        leadingInset: CGFloat,
        trailingInset: CGFloat
    ) -> NoteContentEditorLayoutMetrics {
        let width = max(0, size.width)
        let height = max(0, size.height)
        let leadingInset = max(0, leadingInset)
        let trailingInset = max(0, trailingInset)
        let editorWidth = max(0, width - leadingInset - trailingInset)
        let editorFrame = CGRect(x: leadingInset, y: 0, width: editorWidth, height: height)

        let stripWidth = min(scrollIndicatorOpaqueStripWidth, width)
        let stripMaxX = min(width, max(0, width - trailingInset))
        let stripFrame = CGRect(
            x: max(0, stripMaxX - stripWidth),
            y: 0,
            width: stripWidth,
            height: height
        )

        return NoteContentEditorLayoutMetrics(
            editorFrame: editorFrame,
            fadeMaskFrame: CGRect(x: 0, y: 0, width: width, height: height),
            scrollIndicatorOpaqueStripFrame: stripFrame
        )
    }
}

enum NoteContentSwipeLayout {
    static func currentTranslation(progress: CGFloat, width: CGFloat) -> CGFloat {
        -progress * swipeDistance(for: width)
    }

    static func previewTranslation(progress: CGFloat, previewOffset: Int, width: CGFloat) -> CGFloat {
        CGFloat(previewOffset) * swipeDistance(for: width) - progress * swipeDistance(for: width)
    }

    private static func swipeDistance(for width: CGFloat) -> CGFloat {
        max(1, width)
    }
}

enum NoteContentSwipeFadePolicy {
    static func usesGradientMask(hasPreview: Bool, progress: CGFloat) -> Bool {
        true
    }
}

private struct NoteContentFadeMaskModifier: ViewModifier {
    let layout: NoteContentEditorLayoutMetrics
    let topFadeHeight: CGFloat
    let bottomFadeHeight: CGFloat
    let usesGradientMask: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if usesGradientMask {
            content.mask { fadeMask }
        } else {
            content.clipped()
        }
    }

    private var fadeMask: some View {
        let size = layout.fadeMaskFrame.size
        let maxFadeHeight = max(0, size.height / 2)
        let topFadeHeight = min(topFadeHeight, maxFadeHeight)
        let bottomFadeHeight = min(bottomFadeHeight, maxFadeHeight)

        return ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [.white.opacity(0), .white],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: topFadeHeight)

                Rectangle()
                    .fill(.white)

                LinearGradient(
                    colors: [.white, .white.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: bottomFadeHeight)
            }
            .frame(width: size.width, height: size.height)

            Rectangle()
                .fill(.white)
                .frame(
                    width: layout.scrollIndicatorOpaqueStripFrame.width,
                    height: layout.scrollIndicatorOpaqueStripFrame.height
                )
                .offset(
                    x: layout.scrollIndicatorOpaqueStripFrame.minX,
                    y: layout.scrollIndicatorOpaqueStripFrame.minY
                )
        }
    }
}

private struct NoteContentEditorViewportSizePreferenceKey: PreferenceKey {
    static let defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct NoteContentEditorView: View {
    @Binding var text: String

    let documentID: String
    let contentRevision: Int
    let documentPosition: MarkdownDocumentPosition?
    let preview: NoteDocumentSwipePreview?
    let swipeProgress: CGFloat
    let fontSize: Double
    let accentColor: NSColor
    let appearanceIdentity: String
    let emphasisCommand: MarkdownEmphasisCommand?
    let topFadeHeight: CGFloat
    let bottomFadeHeight: CGFloat
    let contentLeadingInset: CGFloat
    let contentTrailingInset: CGFloat
    var onEditorViewportChange: (CGSize) -> Void = { _ in }
    let onDocumentPositionChange: (MarkdownDocumentPosition) -> Void

    var body: some View {
        GeometryReader { proxy in
            let layout = NoteContentEditorLayout.metrics(
                for: proxy.size,
                leadingInset: contentLeadingInset,
                trailingInset: contentTrailingInset
            )
            let usesGradientMask = NoteContentSwipeFadePolicy.usesGradientMask(
                hasPreview: preview != nil,
                progress: swipeProgress
            )
            ZStack {
                MarkdownRenderingEditor(
                    text: $text,
                    documentID: documentID,
                    contentRevision: contentRevision,
                    fontSize: fontSize,
                    accentColor: accentColor,
                    documentPosition: documentPosition,
                    emphasisCommand: emphasisCommand,
                    onDocumentPositionChange: onDocumentPositionChange
                )
                .frame(width: layout.editorFrame.width, height: layout.editorFrame.height)
                .padding(.leading, layout.editorFrame.minX)
                .padding(.trailing, contentTrailingInset)
                .frame(width: layout.fadeMaskFrame.width, height: layout.fadeMaskFrame.height, alignment: .leading)
                .offset(
                    x: NoteContentSwipeLayout.currentTranslation(
                        progress: swipeProgress,
                        width: proxy.size.width
                    )
                )

                if let preview {
                    MarkdownStaticPreviewView(
                        text: preview.text,
                        documentID: preview.url.standardizedFileURL.path,
                        contentRevision: preview.revision,
                        fontSize: fontSize,
                        accentColor: accentColor,
                        documentPosition: preview.position,
                        initialSize: layout.editorFrame.size,
                        preRenderedImage: preview.preRenderedImage,
                        appearanceIdentity: appearanceIdentity
                    )
                    .id(preview.id)
                    .frame(width: layout.editorFrame.width, height: layout.editorFrame.height)
                    .padding(.leading, layout.editorFrame.minX)
                    .padding(.trailing, contentTrailingInset)
                    .frame(width: layout.fadeMaskFrame.width, height: layout.fadeMaskFrame.height, alignment: .leading)
                    .offset(
                        x: NoteContentSwipeLayout.previewTranslation(
                            progress: swipeProgress,
                            previewOffset: preview.offset,
                            width: proxy.size.width
                        )
                    )
                    .allowsHitTesting(false)
                }
            }
            .modifier(NoteContentFadeMaskModifier(
                layout: layout,
                topFadeHeight: topFadeHeight,
                bottomFadeHeight: bottomFadeHeight,
                usesGradientMask: usesGradientMask
            ))
            .background {
                Color.clear.preference(
                    key: NoteContentEditorViewportSizePreferenceKey.self,
                    value: layout.editorFrame.size
                )
            }
        }
        .onPreferenceChange(NoteContentEditorViewportSizePreferenceKey.self) { size in
            onEditorViewportChange(size)
        }
        .clipped()
    }

}
