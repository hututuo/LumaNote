import Foundation
import XCTest
@testable import QuietNote

final class ClipboardPersistenceTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: "LumaNoteClipboardPersistenceTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        temporaryDirectory = nil
        try super.tearDownWithError()
    }

    func testCorruptJSONIsReportedAndAutomaticSaveLeavesOriginalUntouched() async throws {
        let fileURL = temporaryDirectory.appending(path: "clipboard.json")
        let supportDirectory = temporaryDirectory!
        let original = Data("{not-json".utf8)
        try original.write(to: fileURL)

        let store = await MainActor.run {
            ClipboardStore(supportDirectory: supportDirectory)
        }

        let status = await MainActor.run { store.persistenceStatus }
        let warning = await MainActor.run { store.persistenceWarning }
        XCTAssertEqual(status, .corrupted)
        XCTAssertNotNil(warning)

        await MainActor.run {
            store.captureTextForTesting("新内容")
        }
        await store.waitForPendingDetectionForTesting()
        await store.waitForPendingSaveForTesting()

        XCTAssertEqual(try Data(contentsOf: fileURL), original)
    }

    func testLegacyArrayLoadsAndFlushMigratesToVersionedEnvelope() async throws {
        let item = ClipboardItem(
            id: UUID(),
            text: "legacy text",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            detections: []
        )
        let fileURL = temporaryDirectory.appending(path: "clipboard.json")
        let supportDirectory = temporaryDirectory!
        try JSONEncoder().encode([item]).write(to: fileURL)

        let store = await MainActor.run {
            ClipboardStore(supportDirectory: supportDirectory)
        }

        let status = await MainActor.run { store.persistenceStatus }
        let loadedTexts = await MainActor.run { store.items.map(\.text) }
        XCTAssertEqual(status, .migratedLegacy)
        XCTAssertEqual(loadedTexts, [item.text])
        await MainActor.run { store.saveNow() }

        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: fileURL)) as? [String: Any]
        XCTAssertEqual(object?["version"] as? Int, ClipboardPersistence.currentVersion)
        XCTAssertNotNil(object?["items"] as? [Any])
    }

    func testPartiallyDamagedEnvelopeKeepsGoodRecordsAndDoesNotClearThemOnSave() async throws {
        let item = ClipboardItem(
            id: UUID(),
            text: "good record",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            detections: []
        )
        let validObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(item))
        let envelope = try JSONSerialization.data(withJSONObject: [
            "version": ClipboardPersistence.currentVersion,
            "items": [validObject, "damaged-item"]
        ])
        let supportDirectory = temporaryDirectory!
        try envelope.write(to: supportDirectory.appending(path: "clipboard.json"))

        let store = await MainActor.run {
            ClipboardStore(supportDirectory: supportDirectory)
        }

        let status = await MainActor.run { store.persistenceStatus }
        let loadedText = await MainActor.run { store.items.first?.text }
        XCTAssertEqual(status, .partiallyRecovered(skippedItems: 1))
        XCTAssertEqual(loadedText, item.text)
        await MainActor.run { store.saveNow() }

        let result = ClipboardPersistence.loadResult(from: supportDirectory.appending(path: "clipboard.json"))
        XCTAssertEqual(result.items.first?.text, item.text)
        XCTAssertEqual(result.status, .loaded)
    }

    func testUnknownDetectionKindFallsBackToCopyableText() throws {
        let item = ClipboardItem(
            id: UUID(),
            text: "future",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            detections: [ClipboardDetection(id: UUID(), kind: .text, value: "future")]
        )
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(item)) as? [String: Any])
        var detections = try XCTUnwrap(object["detections"] as? [[String: Any]])
        detections[0]["kind"] = "FutureKind"
        object["detections"] = detections
        let data = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(ClipboardItem.self, from: data)

        XCTAssertEqual(decoded.detections.first?.kind, .text)
        XCTAssertEqual(decoded.text, item.text)
    }

    @MainActor
    func testClearSnapshotWinsWhenAnOlderWriteArrivesAfterClear() async throws {
        let fileURL = temporaryDirectory.appending(path: "clipboard.json")
        let writer = ClipboardPersistenceWriter()
        let oldItem = ClipboardItem(id: UUID(), text: "old", createdAt: Date(), detections: [])
        let store = ClipboardStore(
            supportDirectory: temporaryDirectory,
            persistenceWriter: writer
        )

        store.captureTextForTesting(oldItem.text)
        await store.waitForPendingDetectionForTesting()
        store.saveNow()
        store.clear()
        XCTAssertTrue(writer.save([oldItem], to: fileURL, generation: 1))

        let result = ClipboardPersistence.loadResult(from: fileURL)
        XCTAssertEqual(result.items, [])
    }

    func testLargeCaptureIsClippedPerItemAndHistoryRespectsTotalBudget() async throws {
        let supportDirectory = temporaryDirectory!
        let store = await MainActor.run {
            ClipboardStore(supportDirectory: supportDirectory)
        }
        let oversized = String(repeating: "x", count: ClipboardStore.maximumClipboardItemBytes + 4_096)

        await MainActor.run {
            store.captureTextForTesting(oversized)
        }
        await store.waitForPendingDetectionForTesting()

        let itemBytes = await MainActor.run { store.items.first?.text.utf8.count ?? 0 }
        XCTAssertGreaterThan(itemBytes, 0)
        XCTAssertLessThanOrEqual(itemBytes, ClipboardStore.maximumClipboardItemBytes)

        let historyDirectory = temporaryDirectory.appending(path: "history", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: historyDirectory, withIntermediateDirectories: true)
        let records = (0..<40).map { index in
            ClipboardItem(
                id: UUID(),
                text: "\(index)-" + String(repeating: "y", count: ClipboardStore.maximumClipboardItemBytes - 128),
                createdAt: Date(timeIntervalSince1970: Double(index)),
                detections: []
            )
        }
        let historyEnvelope: [String: Any] = [
            "version": ClipboardPersistence.currentVersion,
            "items": try records.map { try JSONSerialization.jsonObject(with: JSONEncoder().encode($0)) }
        ]
        try JSONSerialization.data(withJSONObject: historyEnvelope)
            .write(to: historyDirectory.appending(path: "clipboard.json"))

        let boundedStore = await MainActor.run {
            ClipboardStore(supportDirectory: historyDirectory)
        }
        let totalBytes = await MainActor.run {
            boundedStore.items.reduce(0) { $0 + $1.text.utf8.count }
        }
        XCTAssertLessThanOrEqual(totalBytes, ClipboardStore.maximumClipboardHistoryBytes)
    }
}
