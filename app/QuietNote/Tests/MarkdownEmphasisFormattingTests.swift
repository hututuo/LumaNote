import AppKit
@testable import QuietNote
import XCTest

final class MarkdownEmphasisFormattingTests: XCTestCase {
    func testWrapsSelectedTextInBoldMarkers() {
        let result = MarkdownEmphasisFormatting.apply(
            styles: [.bold],
            to: "hello world",
            selectedRange: NSRange(location: 6, length: 5)
        )

        XCTAssertEqual(result.text, "hello **world**")
        XCTAssertEqual(result.selectedRange, NSRange(location: 8, length: 5))
    }

    func testDefaultEmphasisCombinesBoldInsideHighlight() {
        let result = MarkdownEmphasisFormatting.apply(
            styles: [.bold, .highlight],
            to: "important",
            selectedRange: NSRange(location: 0, length: 9)
        )

        XCTAssertEqual(result.text, "==**important**==")
        XCTAssertEqual(result.selectedRange, NSRange(location: 4, length: 9))
    }

    func testApplyingSameInlineStyleRemovesExistingMarkers() {
        let result = MarkdownEmphasisFormatting.apply(
            styles: [.bold, .highlight],
            to: "==**important**==",
            selectedRange: NSRange(location: 4, length: 9)
        )

        XCTAssertEqual(result.text, "important")
        XCTAssertEqual(result.selectedRange, NSRange(location: 0, length: 9))
    }

    func testUsesCurrentLineWhenSelectionIsEmpty() {
        let result = MarkdownEmphasisFormatting.apply(
            styles: [.strikethrough],
            to: "first\nsecond line\nthird",
            selectedRange: NSRange(location: 8, length: 0)
        )

        XCTAssertEqual(result.text, "first\n~~second line~~\nthird")
        XCTAssertEqual(result.selectedRange, NSRange(location: 8, length: 11))
    }

    func testConvertsCurrentLineToSmallHeading() {
        let result = MarkdownEmphasisFormatting.apply(
            styles: [.smallHeading],
            to: "first\nsecond line\nthird",
            selectedRange: NSRange(location: 8, length: 0)
        )

        XCTAssertEqual(result.text, "first\n## second line\nthird")
        XCTAssertEqual(result.selectedRange, NSRange(location: 9, length: 11))
    }
}
