import XCTest
@testable import QuietNote

final class ClipboardListPagingStateTests: XCTestCase {
    func testSchedulesAndFinishesNextBatchWithinTotalCount() {
        var state = ClipboardListPagingState()

        let batch = state.scheduleNextBatch(totalCount: 60)
        XCTAssertNotNil(batch)
        XCTAssertTrue(state.isBatchLoadScheduled)

        state.finishScheduledBatch(batch!)

        XCTAssertEqual(
            state.visibleItemLimit,
            ClipboardListPagingState.initialVisibleItemLimit + ClipboardListPagingState.visibleItemBatchSize
        )
        XCTAssertFalse(state.isBatchLoadScheduled)
    }

    func testDoesNotScheduleWhenAllItemsAreVisible() {
        var state = ClipboardListPagingState(visibleItemLimit: 28)

        let batch = state.scheduleNextBatch(totalCount: 28)

        XCTAssertNil(batch)
        XCTAssertFalse(state.isBatchLoadScheduled)
    }

    func testQueryResetInvalidatesPendingBatch() {
        var state = ClipboardListPagingState()
        let batch = state.scheduleNextBatch(totalCount: 80)!

        state.resetForQueryChange()
        state.finishScheduledBatch(batch)

        XCTAssertEqual(state.visibleItemLimit, ClipboardListPagingState.initialVisibleItemLimit)
        XCTAssertFalse(state.isBatchLoadScheduled)
    }

    func testItemCountResetInvalidatesPendingBatchAndPreservesMinimumLimit() {
        var state = ClipboardListPagingState(visibleItemLimit: 6)
        let batch = state.scheduleNextBatch(totalCount: 80)!

        state.resetForItemCountChange()
        state.finishScheduledBatch(batch)

        XCTAssertEqual(state.visibleItemLimit, ClipboardListPagingState.initialVisibleItemLimit)
        XCTAssertFalse(state.isBatchLoadScheduled)
    }
}
