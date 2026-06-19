import SwiftUI

@MainActor
@Observable
final class NoteDocumentSwipeCoordinator {
    typealias PreviewLoader = @MainActor (Int, NoteStore) async -> (url: URL, text: String)?

    var progress: CGFloat = 0
    var isAnimating = false
    var preview: NoteDocumentSwipePreview?

    @ObservationIgnored private let previewLoader: PreviewLoader
    @ObservationIgnored private var previewLoadingOffset: Int?
    @ObservationIgnored private var previewTask: Task<Void, Never>?
    @ObservationIgnored private var commitAnimationTask: Task<Void, Never>?
    @ObservationIgnored private var unlockAnimationTask: Task<Void, Never>?
    @ObservationIgnored private var previewClearTask: Task<Void, Never>?
    @ObservationIgnored private var previewRevision = 0

    init(previewLoader: @escaping PreviewLoader = { offset, noteStore in
        await noteStore.loadWorkspaceDocumentPreview(offset: offset)
    }) {
        self.previewLoader = previewLoader
    }

    func updateProgress(_ newProgress: CGFloat, noteStore: NoteStore) {
        guard !isAnimating else { return }
        guard abs(newProgress) > 0.001 else {
            cancel()
            return
        }

        let direction = newProgress > 0 ? 1 : -1
        preparePreview(offset: direction, noteStore: noteStore)
        guard preview?.offset == direction || previewLoadingOffset == direction else {
            cancel()
            return
        }

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            progress = newProgress
        }
    }

    func cancel() {
        cancelCommitAnimationTasks()
        isAnimating = false
        previewTask?.cancel()
        previewTask = nil
        previewLoadingOffset = nil
        previewClearTask?.cancel()
        previewClearTask = nil
        guard abs(progress) > 0.001 else {
            preview = nil
            return
        }
        withAnimation(.snappy(duration: NoteWindowTiming.documentSwipeCancelAnimation)) {
            progress = 0
        }
        clearPreviewAfterDelay(NoteWindowTiming.documentSwipePreviewClearDelay)
    }

    func commit(
        offset: Int,
        noteStore: NoteStore,
        didSwitch: @escaping @MainActor () -> Void
    ) {
        guard !isAnimating else { return }

        let direction = offset > 0 ? 1 : -1
        let signedDirection = CGFloat(direction)
        preparePreview(offset: direction, noteStore: noteStore)
        guard preview?.offset == direction || previewLoadingOffset == direction else {
            cancel()
            return
        }

        isAnimating = true

        withAnimation(.snappy(duration: NoteWindowTiming.documentSwipeCommitAnimation)) {
            progress = signedDirection
        }

        commitAnimationTask?.cancel()
        unlockAnimationTask?.cancel()
        previewClearTask?.cancel()
        commitAnimationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(NoteWindowTiming.documentSwipeCommitAnimation))
            guard !Task.isCancelled, let self else { return }

            if self.preview?.offset != direction,
               self.previewLoadingOffset == direction {
                await self.previewTask?.value
            }
            guard !Task.isCancelled else { return }

            let matchingPreview = self.preview?.offset == direction ? self.preview : nil
            let didSwitchDocument = noteStore.switchWorkspaceDocument(
                offset: direction,
                preloadedPreview: matchingPreview.map { ($0.url, $0.text) }
            )

            if didSwitchDocument {
                didSwitch()
                self.cancelPreviewTask()
                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    self.progress = 0
                    self.preview = nil
                }
            } else {
                self.cancelPreviewTask()
                withAnimation(.snappy(duration: NoteWindowTiming.documentSwipeCancelAnimation)) {
                    self.progress = 0
                }
                self.clearPreviewAfterDelay(NoteWindowTiming.documentSwipePreviewClearDelay)
            }

            self.scheduleAnimationUnlock()
        }
    }

    func cancelTasks() {
        cancelCommitAnimationTasks()
        cancelPreviewTask()
        previewClearTask?.cancel()
        previewClearTask = nil
        progress = 0
        preview = nil
        isAnimating = false
    }

    private func preparePreview(offset: Int, noteStore: NoteStore) {
        guard offset != 0 else { return }
        previewClearTask?.cancel()
        previewClearTask = nil
        if preview?.offset == offset || previewLoadingOffset == offset {
            return
        }

        cancelPreviewTask()
        preview = nil

        guard noteStore.workspaceDocumentURL(offset: offset) != nil else {
            preview = nil
            return
        }

        previewLoadingOffset = offset
        previewTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let loadedPreview = await self.previewLoader(offset, noteStore)
            guard !Task.isCancelled else { return }

            previewLoadingOffset = nil
            previewTask = nil

            guard let loadedPreview else {
                if preview?.offset == offset {
                    preview = nil
                }
                return
            }

            previewRevision &+= 1
            preview = NoteDocumentSwipePreview(
                id: "\(loadedPreview.url.standardizedFileURL.path)#\(previewRevision)",
                url: loadedPreview.url,
                offset: offset,
                text: loadedPreview.text,
                position: noteStore.documentPosition(for: loadedPreview.url),
                revision: previewRevision
            )
        }
    }

    private func cancelPreviewTask() {
        previewTask?.cancel()
        previewTask = nil
        previewLoadingOffset = nil
    }

    private func cancelCommitAnimationTasks() {
        commitAnimationTask?.cancel()
        commitAnimationTask = nil
        unlockAnimationTask?.cancel()
        unlockAnimationTask = nil
    }

    private func scheduleAnimationUnlock() {
        unlockAnimationTask?.cancel()
        unlockAnimationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(NoteWindowTiming.documentSwipeUnlockDelay))
            guard !Task.isCancelled, let self else { return }
            isAnimating = false
            unlockAnimationTask = nil
            commitAnimationTask = nil
        }
    }

    private func clearPreviewAfterDelay(_ delay: TimeInterval) {
        let previewID = preview?.id
        previewClearTask?.cancel()
        previewClearTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled,
                  let self,
                  self.preview?.id == previewID,
                  abs(self.progress) <= 0.001,
                  !self.isAnimating
            else { return }
            self.preview = nil
            self.previewClearTask = nil
        }
    }
}
