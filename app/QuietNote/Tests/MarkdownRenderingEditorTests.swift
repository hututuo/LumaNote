import AppKit
import SwiftUI
@testable import QuietNote
import XCTest

@MainActor
final class MarkdownRenderingEditorTests: XCTestCase {
    func testReadOnlyEditorModeDisablesEditingAndPositionObservationForSwipePreview() {
        let mode = MarkdownRenderingEditorInteractionMode.readOnlyPreview

        XCTAssertFalse(mode.isEditable)
        XCTAssertFalse(mode.isSelectable)
        XCTAssertFalse(mode.allowsUndo)
        XCTAssertFalse(mode.observesDocumentPosition)
    }

    func testStaticPreviewRendererProducesImageAtRequestedSize() {
        let size = CGSize(width: 240, height: 160)
        let image = MarkdownStaticPreviewRenderer.render(
            text: "# Preview\n\n- [ ] Task\n\n**Bold** body",
            fontSize: 15.5,
            accentColor: .systemCyan,
            documentPosition: .top,
            size: size,
            backingScale: 1
        )

        XCTAssertEqual(image?.size, size)
        XCTAssertEqual(image?.representations.first?.pixelsWide, Int(size.width))
        XCTAssertEqual(image?.representations.first?.pixelsHigh, Int(size.height))
    }

    func testStaticPreviewNSViewRendersBeforeFirstLayoutUsingInitialSize() {
        let size = CGSize(width: 240, height: 160)
        let view = MarkdownStaticPreviewNSView()

        view.configure(
            text: "# Preview\n\nReady before layout",
            documentID: "preview.md",
            contentRevision: 1,
            fontSize: 15.5,
            accentColor: .systemCyan,
            documentPosition: .top,
            initialSize: size
        )

        let image = view.subviews.compactMap { ($0 as? NSImageView)?.image }.first
        XCTAssertEqual(image?.size, size)
    }

    func testStaticPreviewNSViewUsesPreRenderedImage() {
        let size = CGSize(width: 240, height: 160)
        let view = MarkdownStaticPreviewNSView()
        let preRenderedImage = NSImage(size: size)

        view.configure(
            text: "# Preview\n\nReady before gesture",
            documentID: "preview.md",
            contentRevision: 1,
            fontSize: 15.5,
            accentColor: .systemCyan,
            documentPosition: .top,
            initialSize: size,
            preRenderedImage: preRenderedImage
        )

        let image = view.subviews.compactMap { ($0 as? NSImageView)?.image }.first
        XCTAssertTrue(image === preRenderedImage)
    }

    func testStaticPreviewNSViewReusesPreRenderedImageAcrossTinySizeDrift() {
        let preRenderedSize = CGSize(width: 240, height: 160)
        let initialSize = CGSize(width: 240.25, height: 160.25)
        let view = MarkdownStaticPreviewNSView()
        let preRenderedImage = NSImage(size: preRenderedSize)

        view.configure(
            text: "# Preview\n\nReady before gesture",
            documentID: "preview.md",
            contentRevision: 1,
            fontSize: 15.5,
            accentColor: .systemCyan,
            documentPosition: .top,
            initialSize: initialSize,
            preRenderedImage: preRenderedImage
        )

        let image = view.subviews.compactMap { ($0 as? NSImageView)?.image }.first
        XCTAssertTrue(image === preRenderedImage)
    }

    func testStaticPreviewStylingMatchesLiveEditorAtRestoredHeadingPosition() {
        let markdown = "# Preview title\n\nBody"
        let position = MarkdownDocumentPosition(selectedLocation: 3, selectedLength: 0, scrollY: 0)
        let storage = MarkdownStaticPreviewRenderer.styledStorageForTesting(
            text: markdown,
            fontSize: 15.5,
            accentColor: .systemCyan,
            documentPosition: position,
            size: CGSize(width: 240, height: 160)
        )
        let liveStorage = styledStorage(markdown, selectedRange: NSRange(location: 3, length: 0))

        XCTAssertEqual(isHiddenSyntax(at: 0, in: storage), isHiddenSyntax(at: 0, in: liveStorage))
        XCTAssertEqual(foregroundAlpha(at: 0, in: storage), foregroundAlpha(at: 0, in: liveStorage), accuracy: 0.01)
        XCTAssertFalse(isHiddenSyntax(at: 2, in: storage))
    }

    func testStaticPreviewSnapshotCollapsesHiddenHeadingMarkerBeforeDrawing() {
        let image = MarkdownStaticPreviewRenderer.render(
            text: "# Preview title\n\nBody",
            fontSize: 15.5,
            accentColor: .systemCyan,
            documentPosition: .top,
            size: CGSize(width: 320, height: 160),
            backingScale: 1
        )

        let firstVisiblePointX = firstVisiblePointX(in: image)

        XCTAssertNotNil(firstVisiblePointX)
        XCTAssertLessThanOrEqual(firstVisiblePointX ?? .greatestFiniteMagnitude, 8)
    }

    func testStaticPreviewHeadingOriginMatchesReadOnlyEditorSnapshot() {
        let size = CGSize(width: 320, height: 160)
        var text = "# Preview title\n\nBody"
        let staticImage = MarkdownStaticPreviewRenderer.render(
            text: text,
            fontSize: 15.5,
            accentColor: .systemCyan,
            documentPosition: .top,
            size: size,
            backingScale: 1
        )
        let liveImage = renderedImage(
            of: MarkdownRenderingEditor(
                text: Binding(
                    get: { text },
                    set: { text = $0 }
                ),
                documentID: "preview.md",
                contentRevision: 1,
                fontSize: 15.5,
                accentColor: .systemCyan,
                documentPosition: .top,
                interactionMode: .readOnlyPreview
            )
            .frame(width: size.width, height: size.height),
            size: size
        )

        let staticX = firstVisiblePointX(in: staticImage)
        let liveX = firstVisiblePointX(in: liveImage)

        XCTAssertNotNil(staticX)
        XCTAssertNotNil(liveX)
        XCTAssertEqual(staticX ?? -1, liveX ?? -2, accuracy: 1)
    }

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

    func testTaskTextViewCachesHiddenSyntaxRangesAfterStyling() {
        var text = "**bold** and [link](https://example.com)"
        let binding = Binding<String>(
            get: { text },
            set: { text = $0 }
        )
        let coordinator = MarkdownRenderingEditor.Coordinator(
            text: binding,
            contentRevision: 0,
            fontSize: 15.5
        )
        let textView = MarkdownTaskTextView()
        textView.string = text
        coordinator.textView = textView

        coordinator.applyMarkdownStyle()

        XCTAssertFalse(textView.hiddenSyntaxRanges.isEmpty)
        XCTAssertTrue(textView.isHiddenSyntaxCharacter(at: 0))
        XCTAssertTrue(textView.isHiddenSyntaxCharacter(at: 1))
        XCTAssertFalse(textView.isHiddenSyntaxCharacter(at: 2))
    }

    func testTaskTextViewDetectsHiddenSyntaxBeforeGlyphMutation() {
        let storage = NSTextStorage(string: "**bold** text")
        storage.addAttribute(
            .markdownHiddenSyntax,
            value: true,
            range: NSRange(location: 0, length: 2)
        )
        storage.addAttribute(
            .markdownHiddenSyntax,
            value: true,
            range: NSRange(location: 6, length: 2)
        )
        let textView = MarkdownTaskTextView()
        textView.updateHiddenSyntaxRanges(from: storage)

        XCTAssertFalse(textView.containsHiddenSyntaxCharacters([2, 3, 4, 5, 8, 9]))
        XCTAssertTrue(textView.containsHiddenSyntaxCharacters([2, 3, 6]))
    }

    func testTaskTextViewBuildsDirectHiddenSyntaxLookup() {
        let storage = NSTextStorage(string: "**bold** text")
        storage.addAttribute(
            .markdownHiddenSyntax,
            value: true,
            range: NSRange(location: 0, length: 2)
        )
        storage.addAttribute(
            .markdownHiddenSyntax,
            value: true,
            range: NSRange(location: 6, length: 2)
        )
        let textView = MarkdownTaskTextView()

        textView.updateHiddenSyntaxRanges(from: storage)

        XCTAssertEqual(textView.hiddenSyntaxCharacterMap.count, storage.length)
        XCTAssertEqual(textView.hiddenSyntaxCharacterMap[0], 1)
        XCTAssertEqual(textView.hiddenSyntaxCharacterMap[2], 0)
        XCTAssertEqual(textView.hiddenSyntaxCharacterMap[6], 1)
    }

    func testUnderscoreBoldMarkersStayVisibleWhileTextStaysBold() {
        let markdown = "__bold__"
        let storage = styledStorage(markdown)

        XCTAssertFalse(isHiddenSyntax(at: 0, in: storage))
        XCTAssertFalse(isHiddenSyntax(at: 1, in: storage))
        XCTAssertGreaterThan(foregroundAlpha(at: 0, in: storage), 0.1)
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

    func testMarkedTextDefersMarkdownStylingUntilIMECommit() {
        var text = "**bold**"
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
        textView.string = text
        textView.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
        textView.setMarkedText(
            "abc",
            selectedRange: NSRange(location: 3, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: 0)
        )
        coordinator.textView = textView

        XCTAssertTrue(textView.hasMarkedText())
        coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))

        XCTAssertEqual(text, "**bold**")
        XCTAssertFalse(isHiddenSyntax(at: 0, in: textView.textStorage ?? NSTextStorage()))

        textView.unmarkText()
        XCTAssertFalse(textView.hasMarkedText())
        coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))

        XCTAssertEqual(text, textView.string)
        XCTAssertTrue(isHiddenSyntax(at: 0, in: textView.textStorage ?? NSTextStorage()))
    }

    func testCoordinatorAppliesEmphasisCommandToBoundMarkdown() {
        var text = "hello world"
        let binding = Binding<String>(
            get: { text },
            set: { text = $0 }
        )
        let coordinator = MarkdownRenderingEditor.Coordinator(
            text: binding,
            contentRevision: 0,
            fontSize: 15.5
        )
        let textView = MarkdownTaskTextView()
        textView.string = text
        textView.setSelectedRange(NSRange(location: 6, length: 5))
        coordinator.textView = textView

        coordinator.applyEmphasis(styles: [.bold, .highlight])

        XCTAssertEqual(text, "hello ==**world**==")
        XCTAssertEqual(textView.string, "hello ==**world**==")
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 10, length: 5))
        XCTAssertTrue((textView.textStorage?.attribute(.font, at: 10, effectiveRange: nil) as? NSFont)?.fontDescriptor.symbolicTraits.contains(.bold) == true)
        XCTAssertNotNil(textView.textStorage?.attribute(.backgroundColor, at: 10, effectiveRange: nil))
    }

    func testHighlightUsesBrighterBackground() {
        let markdown = "==important=="
        let storage = styledStorage(markdown)
        let color = storage.attribute(.backgroundColor, at: 2, effectiveRange: nil) as? NSColor

        XCTAssertGreaterThanOrEqual(color?.alphaComponent ?? 0, 0.34)
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

        XCTAssertEqual(paragraphSpacing(at: closingFenceLocation, in: storage), 11, accuracy: 0.01)
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

    func testTaskPrefixKeepsCheckboxSlotAlignment() {
        let markdown = "  - [ ] task"
        let storage = styledStorage(markdown)
        let markerLocation = range(of: "- [ ]", in: markdown).location
        let bodyLocation = range(of: "task", in: markdown).location
        let expectedIndentation = MarkdownTaskLayout.textWidth("  ", fontSize: 15.5)
        let expectedContentIndent = expectedIndentation + MarkdownTaskLayout.slotWidth(for: 15.5)
        let paragraph = paragraphStyle(at: bodyLocation, in: storage)

        XCTAssertEqual(foregroundAlpha(at: markerLocation, in: storage), 0, accuracy: 0.01)
        XCTAssertNotNil(storage.attribute(.kern, at: markerLocation, effectiveRange: nil))
        XCTAssertEqual(paragraph?.headIndent ?? 0, expectedContentIndent, accuracy: 0.5)
        XCTAssertEqual(paragraph?.firstLineHeadIndent ?? -1, 0, accuracy: 0.01)
    }

    func testScrollViewAddsBottomBreathingSpace() {
        let viewportHeight: CGFloat = 300
        let scrollView = MarkdownScrollView(frame: NSRect(x: 0, y: 0, width: 320, height: viewportHeight))
        let textView = MarkdownTaskTextView(frame: NSRect(x: 0, y: 0, width: 320, height: viewportHeight))
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 10)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.string = (1...24).map { "line \($0)" }.joined(separator: "\n")

        scrollView.setMarkdownTextView(textView)
        scrollView.layoutSubtreeIfNeeded()
        scrollView.refreshScrollIndicator()

        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer
        else {
            return XCTFail("Expected text layout to be available")
        }

        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        let expectedMinimumHeight = ceil(usedRect.maxY + textView.textContainerInset.height * 2 + viewportHeight * 2 / 3) - 1
        let documentHeight = scrollView.documentView?.frame.height ?? 0
        XCTAssertGreaterThanOrEqual(documentHeight, expectedMinimumHeight)
        XCTAssertLessThan(textView.frame.height, documentHeight)
    }

    func testTypingAtBottomBreathingSpaceDoesNotSnapToDocumentBottom() {
        let viewportHeight: CGFloat = 300
        let scrollView = MarkdownScrollView(frame: NSRect(x: 0, y: 0, width: 320, height: viewportHeight))
        let textView = MarkdownTaskTextView(frame: NSRect(x: 0, y: 0, width: 320, height: viewportHeight))
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 10)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.string = (1...30).map { "line \($0)" }.joined(separator: "\n")

        scrollView.setMarkdownTextView(textView)
        scrollView.layoutSubtreeIfNeeded()
        scrollView.refreshScrollIndicator()

        textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
        let documentHeight = scrollView.documentView?.frame.height ?? textView.frame.height
        let bottomOffset = max(0, documentHeight - scrollView.contentView.bounds.height)
        let breathingOffset = max(0, bottomOffset - 90)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: breathingOffset))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        let before = scrollView.contentView.bounds.origin.y

        textView.insertText("x", replacementRange: textView.selectedRange())

        XCTAssertEqual(scrollView.contentView.bounds.origin.y, before, accuracy: 0.5)
    }

    func testRestoringSelectionAfterMarkdownStylingDoesNotSnapToDocumentBottom() {
        let viewportHeight: CGFloat = 300
        let scrollView = MarkdownScrollView(frame: NSRect(x: 0, y: 0, width: 320, height: viewportHeight))
        let textView = MarkdownTaskTextView(frame: NSRect(x: 0, y: 0, width: 320, height: viewportHeight))
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 10)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.string = (1...30).map { "line \($0)" }.joined(separator: "\n")

        scrollView.setMarkdownTextView(textView)
        scrollView.layoutSubtreeIfNeeded()
        scrollView.refreshScrollIndicator()

        let selectedRanges = [NSValue(range: NSRange(location: (textView.string as NSString).length, length: 0))]
        textView.selectedRanges = selectedRanges
        let documentHeight = scrollView.documentView?.frame.height ?? textView.frame.height
        let bottomOffset = max(0, documentHeight - scrollView.contentView.bounds.height)
        let breathingOffset = max(0, bottomOffset - 90)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: breathingOffset))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        let before = scrollView.contentView.bounds.origin.y

        textView.restoreSelectedRangesWithoutScroll(selectedRanges)

        XCTAssertEqual(scrollView.contentView.bounds.origin.y, before, accuracy: 0.5)
    }

    func testDocumentReplacementAppliesTargetDocumentPosition() {
        let viewportHeight: CGFloat = 160
        let markdown = Array(repeating: "Line with enough content", count: 80).joined(separator: "\n")
        let scrollView = configuredScrollView(markdown: markdown, viewportHeight: viewportHeight)
        guard let textView = scrollView.markdownTextView else {
            return XCTFail("Expected markdown text view")
        }

        textView.selectedRanges = [NSValue(range: NSRange(location: 120, length: 0))]
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: 220))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        let targetPosition = MarkdownDocumentPosition(
            selectedLocation: 120,
            selectedLength: 0,
            scrollY: 64
        )

        MarkdownDocumentPositionApplicator.apply(
            targetPosition,
            textView: textView,
            scrollView: scrollView
        )

        XCTAssertEqual(textView.selectedRange(), NSRange(location: 120, length: 0))
        XCTAssertEqual(scrollView.contentView.bounds.origin.y, 64, accuracy: 0.5)
    }

    func testDocumentPositionRestorePrefersSavedScrollOverStaleSelection() {
        let viewportHeight: CGFloat = 160
        let markdown = Array(repeating: "Line with enough content", count: 140).joined(separator: "\n")
        let scrollView = configuredScrollView(markdown: markdown, viewportHeight: viewportHeight)
        guard let textView = scrollView.markdownTextView else {
            return XCTFail("Expected markdown text view")
        }
        let staleSelectionLocation = min(2600, (markdown as NSString).length - 1)
        let targetPosition = MarkdownDocumentPosition(
            selectedLocation: staleSelectionLocation,
            selectedLength: 0,
            scrollY: 72
        )

        MarkdownDocumentPositionApplicator.apply(
            targetPosition,
            textView: textView,
            scrollView: scrollView
        )

        let visibleCharacterRange = visibleCharacterRange(in: scrollView, textView: textView)
        XCTAssertEqual(scrollView.contentView.bounds.origin.y, targetPosition.scrollY, accuracy: 0.5)
        XCTAssertTrue(
            NSLocationInRange(textView.selectedRange().location, visibleCharacterRange),
            "Restored selection should stay in the saved visible scroll range instead of jumping to stale location \(staleSelectionLocation); visible range: \(visibleCharacterRange), selected: \(textView.selectedRange())"
        )
    }

    func testApplyingDocumentPositionDoesNotEmitIntermediatePosition() {
        var text = Array(repeating: "Line with enough content", count: 120).joined(separator: "\n")
        var emittedPositions: [MarkdownDocumentPosition] = []
        let binding = Binding<String>(
            get: { text },
            set: { text = $0 }
        )
        let coordinator = MarkdownRenderingEditor.Coordinator(
            text: binding,
            documentID: "target.md",
            contentRevision: 0,
            fontSize: 15.5,
            onDocumentPositionChange: { emittedPositions.append($0) }
        )
        let scrollView = configuredScrollView(markdown: text, viewportHeight: 160)
        guard let textView = scrollView.markdownTextView else {
            return XCTFail("Expected markdown text view")
        }
        textView.delegate = coordinator
        coordinator.textView = textView
        coordinator.observeScrollView(scrollView)

        let targetPosition = MarkdownDocumentPosition(
            selectedLocation: min(900, (text as NSString).length),
            selectedLength: 0,
            scrollY: 72
        )

        coordinator.applyDocumentPosition(
            targetPosition,
            scrollView: scrollView
        )

        XCTAssertTrue(emittedPositions.isEmpty)
        XCTAssertTrue(NSLocationInRange(textView.selectedRange().location, visibleCharacterRange(in: scrollView, textView: textView)))
        XCTAssertEqual(scrollView.contentView.bounds.origin.y, targetPosition.scrollY, accuracy: 0.5)
    }

    func testLiveResizeReusesCachedDocumentHeightUntilResizeEnds() {
        var state = MarkdownScrollViewLiveResizeState()

        XCTAssertFalse(state.shouldDeferMeasurement(hasCachedDocumentHeight: true, isInLiveResize: false))
        XCTAssertTrue(state.shouldDeferMeasurement(hasCachedDocumentHeight: true, isInLiveResize: true))
        XCTAssertTrue(state.consumeNeedsPostResizeRefresh())
        XCTAssertFalse(state.consumeNeedsPostResizeRefresh())
        XCTAssertFalse(state.shouldDeferMeasurement(hasCachedDocumentHeight: true, isInLiveResize: false))
    }

    func testLiveResizeStillMeasuresWhenThereIsNoCachedDocumentHeight() {
        var state = MarkdownScrollViewLiveResizeState()

        XCTAssertFalse(state.shouldDeferMeasurement(hasCachedDocumentHeight: false, isInLiveResize: true))
        XCTAssertFalse(state.consumeNeedsPostResizeRefresh())
    }

    func testWindowLiveResizeStateDefersMeasurementEvenWhenViewFlagIsFalse() {
        var state = MarkdownScrollViewLiveResizeState()

        state.windowLiveResizeDidStart()

        XCTAssertTrue(state.isLiveResizing(viewInLiveResize: false))
        XCTAssertTrue(state.shouldDeferMeasurement(
            hasCachedDocumentHeight: true,
            isInLiveResize: state.isLiveResizing(viewInLiveResize: false)
        ))
        XCTAssertTrue(state.windowLiveResizeDidEnd())
        XCTAssertFalse(state.isLiveResizing(viewInLiveResize: false))
    }

    func testLiveResizeKeepsDocumentFrameUpdatesForRealtimeReflow() {
        var state = MarkdownScrollViewLiveResizeState()

        state.windowLiveResizeDidStart()

        XCTAssertFalse(state.shouldDeferDocumentFrameUpdate(
            hasCachedDocumentHeight: true,
            isInLiveResize: state.isLiveResizing(viewInLiveResize: false)
        ))
    }

    func testScrollViewLayoutRefreshSkipsUnchangedCachedGeometry() {
        var state = MarkdownScrollViewLayoutRefreshState()
        let size = CGSize(width: 320, height: 180)

        XCTAssertTrue(state.shouldRefreshLayout(boundsSize: size, viewportSize: size, hasCachedDocumentHeight: true))
        XCTAssertFalse(state.shouldRefreshLayout(boundsSize: size, viewportSize: size, hasCachedDocumentHeight: true))
        XCTAssertTrue(state.shouldRefreshLayout(
            boundsSize: CGSize(width: 360, height: 180),
            viewportSize: CGSize(width: 360, height: 180),
            hasCachedDocumentHeight: true
        ))
        XCTAssertTrue(state.shouldRefreshLayout(boundsSize: size, viewportSize: size, hasCachedDocumentHeight: false))
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

    private func paragraphStyle(at location: Int, in storage: NSTextStorage) -> NSParagraphStyle? {
        storage.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle
    }

    private func firstVisiblePixelX(in image: NSImage?) -> Int? {
        guard let representation = image?.representations.first as? NSBitmapImageRep else { return nil }

        var x = 0
        while x < representation.pixelsWide {
            var y = 0
            while y < representation.pixelsHigh {
                guard let color = representation.colorAt(x: x, y: y) else {
                    y += 1
                    continue
                }
                if color.alphaComponent > 0.04 {
                    return x
                }
                y += 1
            }
            x += 1
        }
        return nil
    }

    private func firstVisiblePointX(in image: NSImage?) -> CGFloat? {
        guard let image,
              let representation = image.representations.first as? NSBitmapImageRep,
              representation.pixelsWide > 0,
              let pixelX = firstVisiblePixelX(in: image)
        else { return nil }

        return CGFloat(pixelX) * image.size.width / CGFloat(representation.pixelsWide)
    }

    private func renderedImage<V: View>(of view: V, size: CGSize) -> NSImage? {
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.layoutSubtreeIfNeeded()
        hostingView.displayIfNeeded()

        guard let representation = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            return nil
        }
        representation.size = size
        hostingView.cacheDisplay(in: hostingView.bounds, to: representation)

        let image = NSImage(size: size)
        image.addRepresentation(representation)
        return image
    }

    private func configuredScrollView(markdown: String, viewportHeight: CGFloat) -> MarkdownScrollView {
        let scrollView = MarkdownScrollView(frame: NSRect(x: 0, y: 0, width: 320, height: viewportHeight))
        let textView = MarkdownTaskTextView(frame: NSRect(x: 0, y: 0, width: 320, height: viewportHeight))
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 10)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.string = markdown
        scrollView.setMarkdownTextView(textView)
        scrollView.layoutSubtreeIfNeeded()
        scrollView.refreshScrollIndicator()
        return scrollView
    }

    private func visibleCharacterRange(in scrollView: MarkdownScrollView, textView: NSTextView) -> NSRange {
        guard let documentView = scrollView.documentView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer
        else { return NSRange(location: 0, length: 0) }

        layoutManager.ensureLayout(for: textContainer)
        let visibleRect = textView.convert(documentView.visibleRect, from: documentView)
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        return layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
    }
}
