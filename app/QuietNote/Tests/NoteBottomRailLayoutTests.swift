import XCTest
@testable import QuietNote

final class NoteBottomRailLayoutTests: XCTestCase {
    func testMinimumWidthRailFitsAllButtonsInsideShell() {
        let metrics = NoteBottomRailLayout.metrics(for: NoteWindowLayout.minimumSize.width)

        XCTAssertEqual(metrics.buttonCount, 7)
        XCTAssertEqual(metrics.opacityEndpointLabelWidth, 0, accuracy: 0.001)
        XCTAssertLessThanOrEqual(metrics.estimatedMinimumContentWidth, NoteWindowLayout.minimumSize.width + 0.1)
    }

    func testInitialWidthRailOmitsOpacityEndpointLabels() {
        let metrics = NoteBottomRailLayout.metrics(for: NoteWindowLayout.initialSize.width)

        XCTAssertEqual(metrics.opacityEndpointLabelWidth, 0, accuracy: 0.001)
        XCTAssertTrue(metrics.allowsFlexibleOpacityExpansion)
        XCTAssertEqual(metrics.buttonCount, 7)
        XCTAssertLessThanOrEqual(metrics.estimatedMinimumContentWidth, NoteWindowLayout.initialSize.width + 0.1)
    }

    func testWideRailHasFlexibleSliderSpaceBeyondMinimumBudget() {
        let metrics = NoteBottomRailLayout.metrics(for: NoteWindowLayout.maximumSize.width)

        XCTAssertTrue(metrics.allowsFlexibleOpacityExpansion)
        XCTAssertEqual(metrics.opacityEndpointLabelWidth, 0, accuracy: 0.001)
        XCTAssertGreaterThan(
            NoteWindowLayout.maximumSize.width - metrics.estimatedMinimumContentWidth,
            100
        )
    }
}
