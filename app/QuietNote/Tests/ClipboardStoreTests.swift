import XCTest
@testable import QuietNote

final class ClipboardStoreTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: "LumaNoteClipboardTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        temporaryDirectory = nil
        try super.tearDownWithError()
    }

    @MainActor
    func testClipboardCaptureDetectsOffMainAndStoresResult() async throws {
        let store = ClipboardStore(supportDirectory: temporaryDirectory)

        store.captureTextForTesting("电话：13800138000 邮箱：person@example.com")
        await store.waitForPendingDetectionForTesting()

        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.detections.map(\.kind), [.phone, .email])
        XCTAssertEqual(store.latestSuggestion?.kind, .phone)
        XCTAssertFalse(store.items.first?.timeLabel.isEmpty ?? true)
    }

    @MainActor
    func testClipboardSaveTaskClearsAfterPersistenceCompletes() async throws {
        let store = ClipboardStore(supportDirectory: temporaryDirectory)

        store.captureTextForTesting("邮箱：person@example.com")
        await store.waitForPendingDetectionForTesting()

        XCTAssertTrue(store.hasPendingSaveForTesting)
        await store.waitForPendingSaveForTesting()

        XCTAssertFalse(store.hasPendingSaveForTesting)
    }

    @MainActor
    func testStartMonitoringWithoutEnabledSettingsDoesNotCreatePollingTimer() async throws {
        let store = ClipboardStore(supportDirectory: temporaryDirectory)

        store.startMonitoring()

        XCTAssertFalse(store.isMonitoringForTesting)
    }

    @MainActor
    func testNegativeTrimLimitClearsClipboardWithoutCrashing() async throws {
        let store = ClipboardStore(supportDirectory: temporaryDirectory)

        store.captureTextForTesting("邮箱：first@example.com")
        await store.waitForPendingDetectionForTesting()
        store.captureTextForTesting("邮箱：second@example.com")
        await store.waitForPendingDetectionForTesting()

        XCTAssertEqual(store.items.count, 2)

        store.trimForTesting(to: -10)
        await store.waitForPendingSaveForTesting()

        XCTAssertTrue(store.items.isEmpty)
    }

    @MainActor
    func testClearingClipboardCancelsPendingCapture() async throws {
        let store = ClipboardStore(supportDirectory: temporaryDirectory)

        store.captureTextForTesting("邮箱：person@example.com")
        store.clear()
        await store.waitForPendingDetectionForTesting()
        try await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertTrue(store.items.isEmpty)
        XCTAssertNil(store.latestSuggestion)
        XCTAssertNil(store.latestDetectedItem)
    }

    @MainActor
    func testClipboardCaptureSkipsReplacementCharacterFlood() async throws {
        let store = ClipboardStore(supportDirectory: temporaryDirectory)
        let corruptedText = String(repeating: "�", count: 16) + "正常文本"

        store.captureTextForTesting(corruptedText)
        await store.waitForPendingDetectionForTesting()

        XCTAssertTrue(store.items.isEmpty)
        XCTAssertNil(store.latestSuggestion)
        XCTAssertNil(store.latestDetectedItem)
    }

    @MainActor
    func testClipboardCaptureAllowsOccasionalReplacementCharacter() async throws {
        let store = ClipboardStore(supportDirectory: temporaryDirectory)

        store.captureTextForTesting("备注：这个字符 � 是用户复制内容的一部分")
        await store.waitForPendingDetectionForTesting()

        XCTAssertEqual(store.items.count, 1)
    }
}
