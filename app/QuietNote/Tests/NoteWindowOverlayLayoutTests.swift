import XCTest
@testable import QuietNote

final class NoteWindowOverlayLayoutTests: XCTestCase {
    func testMoreMenuMetricsCentersOversizedPanelInsideTinyContainer() {
        let metrics = NoteWindowOverlayLayout.moreMenuMetrics(
            in: CGSize(width: 160, height: 150),
            anchorFrame: .zero,
            topDragPassthroughHeight: 24
        )

        XCTAssertEqual(metrics.width, 210)
        XCTAssertEqual(metrics.height, 210)
        XCTAssertEqual(metrics.centerX, 80)
        XCTAssertEqual(metrics.centerY, 86)
        XCTAssertTrue(metrics.centerX.isFinite)
        XCTAssertTrue(metrics.centerY.isFinite)
    }

    func testFileSwitcherMetricsCentersOversizedPanelInsideTinyContainer() {
        let metrics = NoteWindowOverlayLayout.fileSwitcherMetrics(
            in: CGSize(width: 170, height: 140),
            anchorFrame: .zero,
            documentCount: 0,
            topDragPassthroughHeight: 22
        )

        XCTAssertEqual(metrics.width, 218)
        XCTAssertEqual(metrics.height, 150)
        XCTAssertEqual(metrics.centerX, 85)
        XCTAssertEqual(metrics.centerY, 80)
        XCTAssertTrue(metrics.centerX.isFinite)
        XCTAssertTrue(metrics.centerY.isFinite)
    }

    func testFileSwitcherDocumentCountIsClampedForPanelHeight() {
        let smallList = NoteWindowOverlayLayout.fileSwitcherMetrics(
            in: CGSize(width: 420, height: 800),
            anchorFrame: CGRect(x: 40, y: 700, width: 28, height: 28),
            documentCount: -10,
            topDragPassthroughHeight: 20
        )
        let largeList = NoteWindowOverlayLayout.fileSwitcherMetrics(
            in: CGSize(width: 420, height: 800),
            anchorFrame: CGRect(x: 40, y: 700, width: 28, height: 28),
            documentCount: 99,
            topDragPassthroughHeight: 20
        )

        XCTAssertEqual(smallList.height, 210)
        XCTAssertEqual(largeList.height, 468)
    }
}
