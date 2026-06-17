import Foundation
import SwiftUI

@MainActor
@Observable
final class NoteClipboardSuggestionController {
    var hiddenItemID: ClipboardItem.ID?

    @ObservationIgnored private var resetTask: Task<Void, Never>?

    func activeItem(from latestItem: ClipboardItem?, isSuppressedByOverlay: Bool) -> ClipboardItem? {
        guard let latestItem,
              latestItem.id != hiddenItemID,
              !isSuppressedByOverlay
        else { return nil }

        return latestItem
    }

    func scheduleReset(
        for itemID: ClipboardItem.ID?,
        delay: Duration = .seconds(NoteWindowTiming.suggestionVisibleSeconds),
        onExpire: @escaping @MainActor () -> Void
    ) {
        resetTask?.cancel()
        resetTask = nil
        hiddenItemID = nil

        guard let itemID else { return }

        resetTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }

            self.hiddenItemID = itemID
            self.resetTask = nil
            onExpire()
        }
    }

    func cancelTasks() {
        resetTask?.cancel()
        resetTask = nil
    }
}
