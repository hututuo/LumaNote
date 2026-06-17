import XCTest
@testable import QuietNote

final class NoteGlassMetricsTests: XCTestCase {
    func testBottomRailOpacityKeepsExpectedRangeForValidInputs() {
        let minimumMetrics = NoteGlassMetrics(
            noteOpacity: AppSettings.minimumNoteOpacity,
            glassStrength: AppSettings.defaultGlassStrength,
            minimumNoteOpacity: AppSettings.minimumNoteOpacity
        )
        let maximumMetrics = NoteGlassMetrics(
            noteOpacity: AppSettings.maximumNoteOpacity,
            glassStrength: AppSettings.defaultGlassStrength,
            minimumNoteOpacity: AppSettings.minimumNoteOpacity
        )

        XCTAssertEqual(minimumMetrics.bottomRailOpacity, 0.075, accuracy: 0.0001)
        XCTAssertEqual(maximumMetrics.bottomRailOpacity, 0.5, accuracy: 0.0001)
    }

    func testInvalidInputsFallBackBeforeGlassCalculations() {
        let metrics = NoteGlassMetrics(
            noteOpacity: .nan,
            glassStrength: .infinity,
            minimumNoteOpacity: .nan
        )

        XCTAssertEqual(metrics.noteOpacity, AppSettings.defaultNoteOpacity)
        XCTAssertEqual(metrics.glassStrength, AppSettings.defaultGlassStrength)
        XCTAssertEqual(metrics.minimumNoteOpacity, AppSettings.minimumNoteOpacity)
        assertFinite(metrics)
    }

    func testOutOfRangeInputsAreClampedBeforeGlassCalculations() {
        let lowMetrics = NoteGlassMetrics(
            noteOpacity: -100,
            glassStrength: -100,
            minimumNoteOpacity: AppSettings.minimumNoteOpacity
        )
        let highMetrics = NoteGlassMetrics(
            noteOpacity: 100,
            glassStrength: 100,
            minimumNoteOpacity: 100
        )

        XCTAssertEqual(lowMetrics.noteOpacity, AppSettings.minimumNoteOpacity)
        XCTAssertEqual(lowMetrics.glassStrength, AppSettings.minimumGlassStrength)
        XCTAssertEqual(highMetrics.minimumNoteOpacity, 0.99)
        XCTAssertEqual(highMetrics.noteOpacity, AppSettings.maximumNoteOpacity)
        XCTAssertEqual(highMetrics.glassStrength, AppSettings.maximumGlassStrength)
        assertFinite(lowMetrics)
        assertFinite(highMetrics)
    }

    func testFallbackValuesAreClampedToNormalizedMinimumOpacity() {
        let metrics = NoteGlassMetrics(
            noteOpacity: .nan,
            glassStrength: .nan,
            minimumNoteOpacity: 100
        )

        XCTAssertEqual(metrics.minimumNoteOpacity, 0.99)
        XCTAssertEqual(metrics.noteOpacity, 0.99)
        XCTAssertEqual(metrics.glassStrength, AppSettings.defaultGlassStrength)
        assertFinite(metrics)
    }

    private func assertFinite(_ metrics: NoteGlassMetrics, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(metrics.shellMaterialOpacity.isFinite, file: file, line: line)
        XCTAssertTrue(metrics.shellHazeOpacity.isFinite, file: file, line: line)
        XCTAssertTrue(metrics.shellTintOpacity.isFinite, file: file, line: line)
        XCTAssertTrue(metrics.shellBorderOpacity.isFinite, file: file, line: line)
        XCTAssertTrue(metrics.shellVisibilityCurve.isFinite, file: file, line: line)
        XCTAssertTrue(metrics.glassTextureCurve.isFinite, file: file, line: line)
        XCTAssertTrue(metrics.islandOpacity.isFinite, file: file, line: line)
        XCTAssertTrue(metrics.bottomRailOpacity.isFinite, file: file, line: line)
        XCTAssertTrue(metrics.collapsedChromeOpacity.isFinite, file: file, line: line)
    }
}
