import AppKit
import SwiftUI
@testable import QuietNote
import XCTest

@MainActor
final class MarkdownRenderingEditorTests: XCTestCase {
    func testHeadingMarkerIsHiddenUntilHeadingIsActive() {
        let markdown = "# Title"
        let storage = styledStorage(markdown)

        XCTAssertTrue(isHiddenSyntax(at: 0, in: storage))
        XCTAssertFalse(isHiddenSyntax(at: 2, in: storage))
    }

    func testActiveHeadingRevealsMarkerForEditing() {
        let markdown = "# Title"
        let storage = styledStorage(markdown, selectedRange: NSRange(location: 2, length: 0))

        XCTAssertFalse(isHiddenSyntax(at: 0, in: storage))
        XCTAssertTrue((storage.attribute(.font, at: 2, effectiveRange: nil) as? NSFont)?.fontDescriptor.symbolicTraits.contains(.bold) == true)
    }

    func testMarkdownLinkWithParenthesesIsStyled() {
        let markdown = "[Spec](https://example.com/a_(b))"
        let storage = styledStorage(markdown)

        XCTAssertEqual(underlineStyle(at: 1, in: storage), NSUnderlineStyle.single.rawValue)
        XCTAssertTrue(isHiddenSyntax(at: 0, in: storage))
        XCTAssertTrue(isHiddenSyntax(at: range(of: "https://example.com/a_(b)", in: markdown).location, in: storage))
    }

    func testBoldMarkersAreHiddenWhileTextStaysBold() {
        let markdown = "**bold**"
        let storage = styledStorage(markdown)

        XCTAssertTrue(isHiddenSyntax(at: 0, in: storage))
        XCTAssertTrue(isHiddenSyntax(at: 1, in: storage))
        XCTAssertFalse(isHiddenSyntax(at: 2, in: storage))
        XCTAssertTrue((storage.attribute(.font, at: 2, effectiveRange: nil) as? NSFont)?.fontDescriptor.symbolicTraits.contains(.bold) == true)
    }

    func testActiveBoldRevealsMarkersForEditing() {
        let markdown = "**bold**"
        let storage = styledStorage(markdown, selectedRange: NSRange(location: 3, length: 0))

        XCTAssertFalse(isHiddenSyntax(at: 0, in: storage))
        XCTAssertFalse(isHiddenSyntax(at: 1, in: storage))
        XCTAssertTrue((storage.attribute(.font, at: 2, effectiveRange: nil) as? NSFont)?.fontDescriptor.symbolicTraits.contains(.bold) == true)
    }

    func testActiveLinkRevealsDestinationForEditing() {
        let markdown = "[Spec](https://example.com/a_(b))"
        let storage = styledStorage(markdown, selectedRange: NSRange(location: 2, length: 0))
        let urlRange = range(of: "https://example.com/a_(b)", in: markdown)

        XCTAssertFalse(isHiddenSyntax(at: 0, in: storage))
        XCTAssertFalse(isHiddenSyntax(at: urlRange.location, in: storage))
        XCTAssertEqual(underlineStyle(at: 1, in: storage), NSUnderlineStyle.single.rawValue)
    }

    func testLinkRevealsWhenCaretTouchesLeftBoundary() {
        let markdown = "见 [图片](https://example.com/image.png)"
        let linkRange = range(of: "[图片]", in: markdown)
        let storage = styledStorage(markdown, selectedRange: NSRange(location: linkRange.location, length: 0))
        let urlRange = range(of: "https://example.com/image.png", in: markdown)

        XCTAssertFalse(isHiddenSyntax(at: linkRange.location, in: storage))
        XCTAssertFalse(isHiddenSyntax(at: urlRange.location, in: storage))
    }

    func testCodeBlockDoesNotRunInlineLinkStyling() {
        let markdown = """
        ```swift
        let url = "https://example.com/a_(b)"
        ```
        """
        let storage = styledStorage(markdown)
        let urlRange = range(of: "https://example.com/a_(b)", in: markdown)

        XCTAssertNil(storage.attribute(.underlineStyle, at: urlRange.location, effectiveRange: nil))
        XCTAssertFalse(isHiddenSyntax(at: 0, in: storage))
        XCTAssertEqual(foregroundAlpha(at: 0, in: storage), 0, accuracy: 0.01)
        XCTAssertTrue((storage.attribute(.font, at: urlRange.location, effectiveRange: nil) as? NSFont)?.fontDescriptor.postscriptName?.lowercased().contains("mono") == true)
    }

    func testActiveCodeBlockRevealsFenceForEditing() {
        let markdown = """
        ```swift
        let url = "https://example.com/a_(b)"
        ```
        """
        let bodyRange = range(of: "let url", in: markdown)
        let storage = styledStorage(markdown, selectedRange: NSRange(location: bodyRange.location + 2, length: 0))

        XCTAssertFalse(isHiddenSyntax(at: 0, in: storage))
        XCTAssertGreaterThan(foregroundAlpha(at: 0, in: storage), 0.1)
        XCTAssertTrue((storage.attribute(.font, at: bodyRange.location, effectiveRange: nil) as? NSFont)?.fontDescriptor.postscriptName?.lowercased().contains("mono") == true)
    }

    func testCodeBlockFenceStaysHiddenWhenCaretIsAtBlockEnd() {
        let markdown = """
        ```swift
        let value = 1
        ```
        """
        let storage = styledStorage(markdown, selectedRange: NSRange(location: (markdown as NSString).length, length: 0))
        let openingFenceLocation = range(of: "```swift", in: markdown).location
        let closingFenceLocation = range(of: "\n```", in: markdown).location + 1

        XCTAssertEqual(foregroundAlpha(at: openingFenceLocation, in: storage), 0, accuracy: 0.01)
        XCTAssertEqual(foregroundAlpha(at: closingFenceLocation, in: storage), 0, accuracy: 0.01)
    }

    func testCodeBlockFenceStaysHiddenAfterClosingFenceBeforeNewline() {
        let markdown = "```swift\nlet value = 1\n```\nnext"
        let closingFenceLocation = range(of: "\n```", in: markdown).location + 1
        let afterClosingFence = closingFenceLocation + 3
        let storage = styledStorage(markdown, selectedRange: NSRange(location: afterClosingFence, length: 0))

        XCTAssertEqual(foregroundAlpha(at: 0, in: storage), 0, accuracy: 0.01)
        XCTAssertEqual(foregroundAlpha(at: closingFenceLocation, in: storage), 0, accuracy: 0.01)
    }

    func testNewlineAfterClosingFenceKeepsNormalTextStyle() {
        let markdown = "```swift\nlet value = 1\n```\n\nnext"
        let closingFenceLocation = range(of: "\n```", in: markdown).location + 1
        let firstNewlineAfterFence = closingFenceLocation + 3
        let secondNewlineAfterFence = firstNewlineAfterFence + 1
        let storage = styledStorage(markdown, selectedRange: NSRange(location: firstNewlineAfterFence, length: 0))

        XCTAssertEqual(foregroundAlpha(at: closingFenceLocation, in: storage), 0, accuracy: 0.01)
        XCTAssertGreaterThan(foregroundAlpha(at: secondNewlineAfterFence, in: storage), 0.5)
    }

    func testClosingFenceAddsBreathingRoomBeforeFollowingText() {
        let markdown = "```swift\nlet value = 1\n```\nnext"
        let closingFenceLocation = range(of: "\n```", in: markdown).location + 1
        let storage = styledStorage(markdown)

        XCTAssertEqual(paragraphSpacing(at: closingFenceLocation, in: storage), 10, accuracy: 0.01)
    }

    func testCodeFenceSpacingMatchesInactiveAndActiveStates() {
        let markdown = """
        intro

        ```swift
        let value = 1
        ```
        """
        let bodyRange = range(of: "let value", in: markdown)
        let inactiveStorage = styledStorage(markdown)
        let activeStorage = styledStorage(markdown, selectedRange: NSRange(location: bodyRange.location + 2, length: 0))
        let openingFenceLocation = range(of: "```swift", in: markdown).location

        XCTAssertEqual(
            paragraphSpacingBefore(at: openingFenceLocation, in: inactiveStorage),
            3,
            accuracy: 0.01
        )
        XCTAssertEqual(
            paragraphSpacingBefore(at: openingFenceLocation, in: inactiveStorage),
            paragraphSpacingBefore(at: openingFenceLocation, in: activeStorage),
            accuracy: 0.01
        )
    }

    func testInlineCodeDoesNotRunNestedLinkStyling() {
        let markdown = "`[Spec](https://example.com)`"
        let storage = styledStorage(markdown)
        let urlRange = range(of: "https://example.com", in: markdown)

        XCTAssertNil(storage.attribute(.underlineStyle, at: urlRange.location, effectiveRange: nil))
        XCTAssertNotNil(storage.attribute(.backgroundColor, at: urlRange.location, effectiveRange: nil))
    }

    private func styledStorage(_ markdown: String, selectedRange: NSRange = NSRange(location: 0, length: 0)) -> NSTextStorage {
        var text = markdown
        let binding = Binding<String>(
            get: { text },
            set: { text = $0 }
        )
        let coordinator = MarkdownRenderingEditor.Coordinator(
            text: binding,
            contentRevision: 0,
            fontSize: 15.5
        )
        let textView = NSTextView()
        textView.string = markdown
        textView.setSelectedRange(selectedRange)
        coordinator.textView = textView
        coordinator.applyMarkdownStyle()
        return textView.textStorage ?? NSTextStorage(string: markdown)
    }

    private func range(of substring: String, in text: String) -> NSRange {
        let nsText = text as NSString
        let range = nsText.range(of: substring)
        XCTAssertNotEqual(range.location, NSNotFound)
        return range
    }

    private func underlineStyle(at location: Int, in storage: NSTextStorage) -> Int? {
        storage.attribute(.underlineStyle, at: location, effectiveRange: nil) as? Int
    }

    private func isHiddenSyntax(at location: Int, in storage: NSTextStorage) -> Bool {
        storage.attribute(.markdownHiddenSyntax, at: location, effectiveRange: nil) != nil
    }

    private func foregroundAlpha(at location: Int, in storage: NSTextStorage) -> CGFloat {
        (storage.attribute(.foregroundColor, at: location, effectiveRange: nil) as? NSColor)?.alphaComponent ?? 1
    }

    private func paragraphSpacingBefore(at location: Int, in storage: NSTextStorage) -> CGFloat {
        (storage.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle)?.paragraphSpacingBefore ?? 0
    }

    private func paragraphSpacing(at location: Int, in storage: NSTextStorage) -> CGFloat {
        (storage.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle)?.paragraphSpacing ?? 0
    }
}
