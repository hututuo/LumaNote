import XCTest
@testable import QuietNote

final class AppSettingsTests: XCTestCase {
    func testNoteOpacityNormalizationMatchesSliderRange() {
        XCTAssertEqual(AppSettings.normalizedNoteOpacity(-1), AppSettings.minimumNoteOpacity)
        XCTAssertEqual(AppSettings.normalizedNoteOpacity(0), AppSettings.minimumNoteOpacity)
        XCTAssertEqual(AppSettings.normalizedNoteOpacity(0.6), 0.6)
        XCTAssertEqual(AppSettings.normalizedNoteOpacity(2), AppSettings.maximumNoteOpacity)
        XCTAssertEqual(AppSettings.normalizedNoteOpacity(.nan), AppSettings.defaultNoteOpacity)
    }

    func testGlassStrengthNormalizationMatchesSliderRange() {
        XCTAssertEqual(AppSettings.normalizedGlassStrength(-1), AppSettings.minimumGlassStrength)
        XCTAssertEqual(AppSettings.normalizedGlassStrength(0.2), 0.2)
        XCTAssertEqual(AppSettings.normalizedGlassStrength(2), AppSettings.maximumGlassStrength)
        XCTAssertEqual(AppSettings.normalizedGlassStrength(.nan), AppSettings.defaultGlassStrength)
    }

    func testEditorFontSizeNormalizationMatchesSliderRange() {
        XCTAssertEqual(AppSettings.normalizedEditorFontSize(-1), AppSettings.minimumEditorFontSize)
        XCTAssertEqual(AppSettings.normalizedEditorFontSize(15.5), 15.5)
        XCTAssertEqual(AppSettings.normalizedEditorFontSize(200), AppSettings.maximumEditorFontSize)
        XCTAssertEqual(AppSettings.normalizedEditorFontSize(.nan), AppSettings.defaultEditorFontSize)
    }

    func testClipboardLimitNormalizationMatchesStepperRange() {
        XCTAssertEqual(AppSettings.normalizedClipboardLimit(-1), AppSettings.minimumClipboardLimit)
        XCTAssertEqual(AppSettings.normalizedClipboardLimit(0), AppSettings.minimumClipboardLimit)
        XCTAssertEqual(AppSettings.normalizedClipboardLimit(200), 200)
        XCTAssertEqual(AppSettings.normalizedClipboardLimit(10_000), AppSettings.maximumClipboardLimit)
    }
}
