struct ClipboardListPagingBatch: Equatable {
    let generation: Int
    let totalCount: Int
}

struct ClipboardListPagingState: Equatable {
    static let initialVisibleItemLimit = 28
    static let visibleItemBatchSize = 16

    private(set) var visibleItemLimit: Int
    private(set) var isBatchLoadScheduled: Bool
    private var generation: Int

    init(
        visibleItemLimit: Int = Self.initialVisibleItemLimit,
        isBatchLoadScheduled: Bool = false,
        generation: Int = 0
    ) {
        self.visibleItemLimit = max(0, visibleItemLimit)
        self.isBatchLoadScheduled = isBatchLoadScheduled
        self.generation = generation
    }

    mutating func resetForQueryChange() {
        visibleItemLimit = Self.initialVisibleItemLimit
        isBatchLoadScheduled = false
        generation &+= 1
    }

    mutating func resetForItemCountChange() {
        visibleItemLimit = max(visibleItemLimit, Self.initialVisibleItemLimit)
        isBatchLoadScheduled = false
        generation &+= 1
    }

    mutating func scheduleNextBatch(totalCount: Int) -> ClipboardListPagingBatch? {
        guard visibleItemLimit < totalCount, !isBatchLoadScheduled else { return nil }

        isBatchLoadScheduled = true
        generation &+= 1
        return ClipboardListPagingBatch(generation: generation, totalCount: totalCount)
    }

    mutating func finishScheduledBatch(_ batch: ClipboardListPagingBatch) {
        guard isBatchLoadScheduled, batch.generation == generation else { return }

        visibleItemLimit = min(batch.totalCount, visibleItemLimit + Self.visibleItemBatchSize)
        isBatchLoadScheduled = false
    }
}
