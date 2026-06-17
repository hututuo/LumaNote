import AppKit
import SwiftUI

struct NoteDocumentSwipePreview: Identifiable, Equatable {
    let id: String
    let offset: Int
    let text: String
    let revision: Int
}

struct NoteContentEditorView: View {
    @Binding var text: String

    let contentRevision: Int
    let preview: NoteDocumentSwipePreview?
    let swipeProgress: CGFloat
    let fontSize: Double
    let accentColor: NSColor
    let topFadeHeight: CGFloat
    let bottomFadeHeight: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                MarkdownRenderingEditor(
                    text: $text,
                    contentRevision: contentRevision,
                    fontSize: fontSize,
                    accentColor: accentColor
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
                .offset(x: currentOffset(for: proxy.size.width))

                if let preview {
                    MarkdownRenderingEditor(
                        text: .constant(preview.text),
                        contentRevision: preview.revision,
                        fontSize: fontSize,
                        accentColor: accentColor
                    )
                    .id(preview.id)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .offset(x: previewOffset(for: proxy.size.width, preview: preview))
                    .allowsHitTesting(false)
                }
            }
            .mask {
                fadeMask(in: proxy.size)
            }
        }
        .clipped()
    }

    private func fadeMask(in size: CGSize) -> some View {
        let maxFadeHeight = max(0, size.height / 2)
        let topFadeHeight = min(topFadeHeight, maxFadeHeight)
        let bottomFadeHeight = min(bottomFadeHeight, maxFadeHeight)

        return ZStack(alignment: .trailing) {
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
                .frame(width: 12)
        }
    }

    private func currentOffset(for width: CGFloat) -> CGFloat {
        -swipeProgress * swipeDistance(for: width)
    }

    private func previewOffset(for width: CGFloat, preview: NoteDocumentSwipePreview) -> CGFloat {
        let distance = swipeDistance(for: width)
        return CGFloat(preview.offset) * distance - swipeProgress * distance
    }

    private func swipeDistance(for width: CGFloat) -> CGFloat {
        max(1, width)
    }
}
