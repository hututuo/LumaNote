import XCTest
@testable import QuietNote

final class ClipboardDetectorTests: XCTestCase {
    func testLabeledAddressUsesOnlyValueAfterColon() {
        let text = "联系人：张三 电话：13800138000 地址：北京市海淀区中关村大街27号 备注：前台"

        let detections = ClipboardDetector.detect(in: text)

        XCTAssertTrue(detections.contains { $0.kind == .address && $0.value == "北京市海淀区中关村大街27号" })
        XCTAssertFalse(detections.contains { $0.kind == .address && $0.value == text })
    }

    func testUnknownColonValueBecomesCopyableText() {
        let detections = ClipboardDetector.detect(in: "备注：明天下午送到")

        XCTAssertEqual(detections.first?.kind, .text)
        XCTAssertEqual(detections.first?.value, "明天下午送到")
    }

    func testPlainNumbersAreNotExtracted() {
        let detections = ClipboardDetector.detect(in: "今天 2026 年预算是 300 元")

        XCTAssertTrue(detections.isEmpty)
    }

    func testMacAppPathWithSpacesIsExtractedAsFile() {
        let text = "还有一个旧版进程仍在 /Users/ceshi/Applications/Codex Token Bar.app，系统不让我杀；新版是现在打开的 dist/Codex Token Bar.app。"

        let detections = ClipboardDetector.detect(in: text)

        XCTAssertTrue(detections.contains { $0.kind == .file && $0.value == "/Users/ceshi/Applications/Codex Token Bar.app" })
        XCTAssertFalse(detections.contains { $0.kind == .address && $0.value == text })
    }

    func testLabeledPathIsExtractedAsFile() {
        let detections = ClipboardDetector.detect(in: "目录：/Users/ceshi/Applications/Codex Token Bar.app")

        XCTAssertEqual(detections.first?.kind, .file)
        XCTAssertEqual(detections.first?.value, "/Users/ceshi/Applications/Codex Token Bar.app")
    }

    func testLabeledPathTrimsTrailingChinesePunctuation() {
        let detections = ClipboardDetector.detect(in: "目录：/Users/ceshi/Applications/Codex Token Bar.app。")

        XCTAssertEqual(detections.first?.kind, .file)
        XCTAssertEqual(detections.first?.value, "/Users/ceshi/Applications/Codex Token Bar.app")
    }

    func testConfidentDetectionsFollowOriginalTextOrder() {
        let detections = ClipboardDetector.detect(in: "电话 13800138000，邮箱 person@example.com")

        XCTAssertGreaterThanOrEqual(detections.count, 2)
        XCTAssertEqual(detections[0].kind, .phone)
        XCTAssertEqual(detections[0].value, "13800138000")
        XCTAssertEqual(detections[1].kind, .email)
        XCTAssertEqual(detections[1].value, "person@example.com")
    }

    func testColonFallbackTextMovesAfterConfidentDetections() {
        let detections = ClipboardDetector.detect(in: "备注：明天下午 电话：13800138000 邮箱：person@example.com")

        XCTAssertEqual(detections.map(\.kind), [.phone, .email, .text])
        XCTAssertEqual(detections.map(\.value), ["13800138000", "person@example.com", "明天下午"])
    }

    func testDuplicateDetectedValuesAreReturnedOnlyOnce() {
        let detections = ClipboardDetector.detect(in: "13800138000，13800138000")

        XCTAssertEqual(detections.filter { $0.kind == .phone && $0.value == "13800138000" }.count, 1)
    }
}
