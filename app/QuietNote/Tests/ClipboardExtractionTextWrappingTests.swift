import XCTest
@testable import QuietNote

final class ClipboardExtractionTextWrappingTests: XCTestCase {
    func testAddsZeroWidthBreaksAfterUrlSeparators() {
        let wrapped = ClipboardExtractionTextWrapping.wrappingValue("https://example.com/a?b=1&c=2")

        XCTAssertTrue(wrapped.contains("/\u{200B}/\u{200B}"))
        XCTAssertTrue(wrapped.contains("?\u{200B}"))
        XCTAssertTrue(wrapped.contains("=\u{200B}"))
        XCTAssertTrue(wrapped.contains("&\u{200B}"))
    }

    func testAddsZeroWidthBreaksAfterChineseSeparators() {
        let wrapped = ClipboardExtractionTextWrapping.wrappingValue("地址：北京市朝阳区，电话；13800138000")

        XCTAssertTrue(wrapped.contains("：\u{200B}"))
        XCTAssertTrue(wrapped.contains("，\u{200B}"))
        XCTAssertTrue(wrapped.contains("；\u{200B}"))
    }

    func testLeavesPlainTextWithoutSeparatorsUnchanged() {
        XCTAssertEqual(
            ClipboardExtractionTextWrapping.wrappingValue("纯文本ABC123"),
            "纯文本ABC123"
        )
    }
}
