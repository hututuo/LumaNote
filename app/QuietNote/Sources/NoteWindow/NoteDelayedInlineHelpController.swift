import SwiftUI

@MainActor
@Observable
final class NoteDelayedInlineHelpController {
    var isVisible = false

    @ObservationIgnored private var showTask: Task<Void, Never>?

    func setHovering(_ isHovering: Bool, delay: TimeInterval) {
        cancelShowTask()

        if isHovering {
            showTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled, let self else { return }

                withAnimation(.snappy(duration: 0.14)) {
                    self.isVisible = true
                }
                self.showTask = nil
            }
        } else {
            withAnimation(.snappy(duration: 0.10)) {
                isVisible = false
            }
        }
    }

    func cancel() {
        cancelShowTask()
        isVisible = false
    }

    private func cancelShowTask() {
        showTask?.cancel()
        showTask = nil
    }
}
