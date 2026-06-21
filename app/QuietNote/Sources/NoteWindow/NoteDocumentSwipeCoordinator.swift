import AppKit
import SwiftUI

@MainActor
@Observable
final class NoteDocumentSwipeCoordinator {
    typealias PreviewLoader = @MainActor (Int, NoteStore) async -> (url: URL, text: String)?

    private struct PreviewColorSignature: Equatable {
        let red: Int
        let green: Int
        let blue: Int
        let alpha: Int

        init(_ color: NSColor) {
            let rgb = color.usingColorSpace(.deviceRGB) ?? .systemCyan
            red = Int((rgb.redComponent * 1000).rounded())
            green = Int((rgb.greenComponent * 1000).rounded())
            blue = Int((rgb.blueComponent * 1000).rounded())
            alpha = Int((rgb.alphaComponent * 1000).rounded())
        }
    }

    private struct PreviewPrewarmConfiguration: Equatable {
        let viewportSize: CGSize
        let backingScale: CGFloat
        let fontSize: CGFloat
        let accentColor: PreviewColorSignature

        init(viewportSize: CGSize, backingScale: CGFloat, fontSize: CGFloat, accentColor: NSColor) {
            self.viewportSize = CGSize(
                width: max(1, viewportSize.width),
                height: max(1, viewportSize.height)
            )
            self.backingScale = max(1, backingScale)
            self.fontSize = MarkdownTaskLayout.normalizedFontSize(fontSize)
            self.accentColor = PreviewColorSignature(accentColor)
        }

        var pixelWidth: Int {
            Int((viewportSize.width * backingScale).rounded(.up))
        }

        var pixelHeight: Int {
            Int((viewportSize.height * backingScale).rounded(.up))
        }
    }

    private struct PrewarmedPreview {
        let id: String
        let url: URL
        let text: String
        let position: MarkdownDocumentPosition?
        let revision: Int
        let preRenderedImage: NSImage
        let modificationDate: Date?
        let configuration: PreviewPrewarmConfiguration
        let requiresCurrentModificationDate: Bool

        func preview(offset: Int) -> NoteDocumentSwipePreview {
            NoteDocumentSwipePreview(
                id: id,
                url: url,
                offset: offset,
                text: text,
                position: position,
                revision: revision,
                preRenderedImage: preRenderedImage
            )
        }

        func matchesModificationDate(_ currentModificationDate: Date?) -> Bool {
            !requiresCurrentModificationDate || modificationDate == currentModificationDate
        }
    }

    private struct CurrentDocumentSnapshot {
        let url: URL
        let text: String
        let position: MarkdownDocumentPosition?
    }

    private static let prewarmOffsets = [-1, 1]
    private static let maximumPrewarmPixelDimension = 4096

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
    @ObservationIgnored private var pendingProgress: CGFloat?
    @ObservationIgnored private var prewarmConfiguration: PreviewPrewarmConfiguration?
    @ObservationIgnored private var prewarmAccentColor: NSColor?
    @ObservationIgnored private var prewarmedPreviews: [Int: PrewarmedPreview] = [:]

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
        guard preview?.offset == direction else {
            if previewLoadingOffset == direction {
                pendingProgress = newProgress
                setProgressWithoutAnimation(0)
                return
            }
            cancel()
            return
        }

        pendingProgress = nil
        setProgressWithoutAnimation(newProgress)
    }

    func prewarmAdjacentPreviews(
        noteStore: NoteStore,
        viewportSize: CGSize,
        backingScale: CGFloat,
        fontSize: Double,
        accentColor: NSColor
    ) async {
        guard noteStore.canSwitchWorkspaceDocument,
              !isAnimating,
              abs(progress) <= 0.001
        else { return }

        let configuration = PreviewPrewarmConfiguration(
            viewportSize: viewportSize,
            backingScale: backingScale,
            fontSize: CGFloat(fontSize),
            accentColor: accentColor
        )
        guard configuration.pixelWidth > 1,
              configuration.pixelHeight > 1,
              configuration.pixelWidth <= Self.maximumPrewarmPixelDimension,
              configuration.pixelHeight <= Self.maximumPrewarmPixelDimension
        else {
            prewarmConfiguration = nil
            prewarmAccentColor = nil
            prewarmedPreviews.removeAll()
            return
        }

        if prewarmConfiguration != configuration {
            prewarmConfiguration = configuration
            prewarmedPreviews.removeAll()
        }
        prewarmAccentColor = accentColor

        for offset in Self.prewarmOffsets {
            guard !Task.isCancelled,
                  !isAnimating,
                  abs(progress) <= 0.001
            else { return }
            await prewarmPreview(
                offset: offset,
                noteStore: noteStore,
                configuration: configuration,
                accentColor: accentColor
            )
        }
    }

    func cancel() {
        cancelCommitAnimationTasks()
        isAnimating = false
        previewTask?.cancel()
        previewTask = nil
        previewLoadingOffset = nil
        pendingProgress = nil
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

        commitAnimationTask?.cancel()
        unlockAnimationTask?.cancel()
        previewClearTask?.cancel()
        commitAnimationTask = Task { @MainActor [weak self] in
            guard let self else { return }

            if self.preview?.offset != direction,
               self.previewLoadingOffset == direction {
                await self.previewTask?.value
            }
            guard !Task.isCancelled else { return }
            guard self.preview?.offset == direction else {
                self.cancelPreviewTask()
                self.setProgressWithoutAnimation(0)
                self.preview = nil
                self.scheduleAnimationUnlock()
                return
            }

            withAnimation(.snappy(duration: NoteWindowTiming.documentSwipeCommitAnimation)) {
                self.progress = signedDirection
            }

            try? await Task.sleep(for: .seconds(NoteWindowTiming.documentSwipeCommitAnimation))
            guard !Task.isCancelled else { return }

            let currentSnapshot = CurrentDocumentSnapshot(
                url: noteStore.currentFileURL,
                text: noteStore.markdown,
                position: noteStore.currentDocumentPosition
            )
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
                self.cacheReversePreview(snapshot: currentSnapshot, noteStore: noteStore)
                self.scheduleAnimationUnlock(
                    continuationPrewarmOffset: direction,
                    noteStore: noteStore
                )
            } else {
                self.cancelPreviewTask()
                withAnimation(.snappy(duration: NoteWindowTiming.documentSwipeCancelAnimation)) {
                    self.progress = 0
                }
                self.clearPreviewAfterDelay(NoteWindowTiming.documentSwipePreviewClearDelay)
                self.scheduleAnimationUnlock()
            }
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
        pendingProgress = nil
        prewarmConfiguration = nil
        prewarmAccentColor = nil
        prewarmedPreviews.removeAll()
    }

    private func preparePreview(offset: Int, noteStore: NoteStore) {
        guard offset != 0 else { return }
        previewClearTask?.cancel()
        previewClearTask = nil
        if let prewarmedPreview = validPrewarmedPreview(offset: offset, noteStore: noteStore) {
            cancelPreviewTask()
            preview = prewarmedPreview.preview(offset: offset)
            return
        }
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
                pendingProgress = nil
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
            applyPendingProgressIfNeeded(for: offset)
        }
    }

    private func prewarmPreview(
        offset: Int,
        noteStore: NoteStore,
        configuration: PreviewPrewarmConfiguration,
        accentColor: NSColor
    ) async {
        guard offset != 0 else { return }
        if let existingPreview = validPrewarmedPreview(offset: offset, noteStore: noteStore),
           existingPreview.requiresCurrentModificationDate {
            return
        }
        guard let targetURL = noteStore.workspaceDocumentURL(offset: offset) else {
            prewarmedPreviews[offset] = nil
            return
        }
        let targetPosition = noteStore.documentPosition(for: targetURL)
        if let reusablePreview = reusablePrewarmedPreview(
            for: targetURL,
            configuration: configuration,
            position: targetPosition
        ) {
            prewarmedPreviews[offset] = reusablePreview
            return
        }

        let targetPath = targetURL.standardizedFileURL.path
        guard let loadedPreview = await previewLoader(offset, noteStore),
              !Task.isCancelled,
              loadedPreview.url.standardizedFileURL.path == targetPath
        else { return }

        guard let image = MarkdownStaticPreviewRenderer.render(
            text: loadedPreview.text,
            fontSize: configuration.fontSize,
            accentColor: accentColor,
            documentPosition: targetPosition,
            size: configuration.viewportSize,
            backingScale: configuration.backingScale
        ) else { return }

        previewRevision &+= 1
        prewarmedPreviews[offset] = PrewarmedPreview(
            id: "\(loadedPreview.url.standardizedFileURL.path)#prewarm-\(previewRevision)",
            url: loadedPreview.url,
            text: loadedPreview.text,
            position: targetPosition,
            revision: previewRevision,
            preRenderedImage: image,
            modificationDate: fileModificationDate(for: loadedPreview.url),
            configuration: configuration,
            requiresCurrentModificationDate: true
        )
    }

    private func validPrewarmedPreview(offset: Int, noteStore: NoteStore) -> PrewarmedPreview? {
        guard let prewarmedPreview = prewarmedPreviews[offset],
              let prewarmConfiguration,
              prewarmedPreview.configuration == prewarmConfiguration,
              let targetURL = noteStore.workspaceDocumentURL(offset: offset),
              prewarmedPreview.url.standardizedFileURL.path == targetURL.standardizedFileURL.path,
              prewarmedPreview.matchesModificationDate(fileModificationDate(for: targetURL)),
              prewarmedPreview.position == noteStore.documentPosition(for: targetURL)
        else { return nil }
        return prewarmedPreview
    }

    private func reusablePrewarmedPreview(
        for targetURL: URL,
        configuration: PreviewPrewarmConfiguration,
        position: MarkdownDocumentPosition?
    ) -> PrewarmedPreview? {
        let targetPath = targetURL.standardizedFileURL.path
        let modificationDate = fileModificationDate(for: targetURL)
        return prewarmedPreviews.values.first { preview in
            preview.requiresCurrentModificationDate
                && preview.configuration == configuration
                && preview.url.standardizedFileURL.path == targetPath
                && preview.modificationDate == modificationDate
                && preview.position == position
        }
    }

    private func cacheReversePreview(snapshot: CurrentDocumentSnapshot, noteStore: NoteStore) {
        guard let configuration = prewarmConfiguration,
              let accentColor = prewarmAccentColor
        else { return }

        let snapshotPath = snapshot.url.standardizedFileURL.path
        let matchingOffsets = Self.prewarmOffsets.filter { offset in
            noteStore.workspaceDocumentURL(offset: offset)?.standardizedFileURL.path == snapshotPath
        }
        guard !matchingOffsets.isEmpty,
              let image = MarkdownStaticPreviewRenderer.render(
                text: snapshot.text,
                fontSize: configuration.fontSize,
                accentColor: accentColor,
                documentPosition: snapshot.position,
                size: configuration.viewportSize,
                backingScale: configuration.backingScale
              )
        else { return }

        previewRevision &+= 1
        let preview = PrewarmedPreview(
            id: "\(snapshotPath)#reverse-\(previewRevision)",
            url: snapshot.url,
            text: snapshot.text,
            position: snapshot.position,
            revision: previewRevision,
            preRenderedImage: image,
            modificationDate: fileModificationDate(for: snapshot.url),
            configuration: configuration,
            requiresCurrentModificationDate: false
        )

        for offset in matchingOffsets {
            prewarmedPreviews[offset] = preview
        }
    }

    private func fileModificationDate(for url: URL) -> Date? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.standardizedFileURL.path)
        return attributes?[.modificationDate] as? Date
    }

    private func cancelPreviewTask() {
        previewTask?.cancel()
        previewTask = nil
        previewLoadingOffset = nil
        pendingProgress = nil
    }

    private func applyPendingProgressIfNeeded(for offset: Int) {
        guard !isAnimating,
              let pendingProgress,
              (pendingProgress > 0 ? 1 : -1) == offset,
              preview?.offset == offset
        else { return }

        self.pendingProgress = nil
        setProgressWithoutAnimation(pendingProgress)
    }

    private func setProgressWithoutAnimation(_ newProgress: CGFloat) {
        guard progress != newProgress else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            progress = newProgress
        }
    }

    private func cancelCommitAnimationTasks() {
        commitAnimationTask?.cancel()
        commitAnimationTask = nil
        unlockAnimationTask?.cancel()
        unlockAnimationTask = nil
    }

    private func scheduleAnimationUnlock(
        continuationPrewarmOffset: Int? = nil,
        noteStore: NoteStore? = nil
    ) {
        unlockAnimationTask?.cancel()
        unlockAnimationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(NoteWindowTiming.documentSwipeUnlockDelay))
            guard !Task.isCancelled, let self else { return }
            isAnimating = false
            unlockAnimationTask = nil
            commitAnimationTask = nil
            if let continuationPrewarmOffset, let noteStore {
                await prewarmContinuationPreview(
                    offset: continuationPrewarmOffset,
                    noteStore: noteStore
                )
            }
        }
    }

    private func prewarmContinuationPreview(offset: Int, noteStore: NoteStore) async {
        guard let configuration = prewarmConfiguration,
              let accentColor = prewarmAccentColor,
              noteStore.canSwitchWorkspaceDocument,
              abs(progress) <= 0.001,
              !isAnimating
        else { return }

        await prewarmPreview(
            offset: offset,
            noteStore: noteStore,
            configuration: configuration,
            accentColor: accentColor
        )
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
