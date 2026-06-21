import SwiftUI
import XCTest
@testable import QuietNote

final class NoteContentEditorLayoutTests: XCTestCase {
    func testFadeMaskCoversFullShellWidthWhileEditorKeepsHorizontalInsets() {
        let shellSize = CGSize(width: NoteWindowLayout.minimumSize.width, height: 320)

        let layout = NoteContentEditorLayout.metrics(
            for: shellSize,
            leadingInset: NoteWindowChromeLayout.contentLeadingPadding,
            trailingInset: NoteWindowChromeLayout.contentTrailingPadding
        )

        XCTAssertEqual(layout.editorFrame.minX, NoteWindowChromeLayout.contentLeadingPadding, accuracy: 0.001)
        XCTAssertEqual(layout.editorFrame.width, shellSize.width - 15, accuracy: 0.001)
        XCTAssertEqual(
            layout.fadeMaskFrame,
            CGRect(origin: .zero, size: shellSize),
            "The vertical fade should span the full note width, not just the padded editor width."
        )
        XCTAssertEqual(
            layout.scrollIndicatorOpaqueStripFrame.maxX,
            shellSize.width - NoteWindowChromeLayout.contentTrailingPadding,
            accuracy: 0.001
        )
    }

    func testSwipeTranslationsKeepCurrentAndPreviewPagesOneViewportApart() {
        let width: CGFloat = 360

        XCTAssertEqual(NoteContentSwipeLayout.currentTranslation(progress: 0.25, width: width), -90, accuracy: 0.001)
        XCTAssertEqual(NoteContentSwipeLayout.previewTranslation(progress: 0.25, previewOffset: 1, width: width), 270, accuracy: 0.001)
        XCTAssertEqual(NoteContentSwipeLayout.previewTranslation(progress: -0.5, previewOffset: -1, width: width), -180, accuracy: 0.001)
    }

    func testFadeMaskStaysActiveWhileDocumentSwipePreviewIsActive() {
        XCTAssertTrue(NoteContentSwipeFadePolicy.usesGradientMask(hasPreview: false, progress: 0))
        XCTAssertTrue(NoteContentSwipeFadePolicy.usesGradientMask(hasPreview: true, progress: 0))
        XCTAssertTrue(NoteContentSwipeFadePolicy.usesGradientMask(hasPreview: true, progress: 0.2))
    }
}
