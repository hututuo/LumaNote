import Foundation
import SwiftUI

@MainActor
@Observable
final class NoteChromeAutoHideController {
    var controlsCollapsed = false
    var hintPulse = false

    @ObservationIgnored private var collapseTask: Task<Void, Never>?
    @ObservationIgnored private var hintPulseTask: Task<Void, Never>?
    @ObservationIgnored private var lastActivityAt = Date.distantPast

    func markActivity(
        autoHideEnabled: Bool,
        shouldStayExpanded: Bool,
        revealIfCollapsed: Bool = true,
        forceReschedule: Bool = false
    ) {
        guard autoHideEnabled else {
            cancelCollapseTask()
            if controlsCollapsed {
                controlsCollapsed = false
            }
            return
        }

        let now = Date()
        let wasCollapsed = controlsCollapsed
        let shouldReschedule = forceReschedule
            || now.timeIntervalSince(lastActivityAt) > NoteWindowTiming.autoHideActivityThrottle
            || wasCollapsed
        lastActivityAt = now

        if wasCollapsed {
            guard revealIfCollapsed else { return }
            withAnimation(.snappy(duration: NoteWindowTiming.chromeRevealAnimation)) {
                controlsCollapsed = false
            }
        }

        if shouldStayExpanded {
            cancelCollapseTask()
            return
        }

        if shouldReschedule {
            scheduleAutoCollapse(autoHideEnabled: autoHideEnabled, shouldStayExpanded: shouldStayExpanded)
        }
    }

    func revealControls(autoHideEnabled: Bool, shouldStayExpanded: Bool) {
        markActivity(
            autoHideEnabled: autoHideEnabled,
            shouldStayExpanded: shouldStayExpanded,
            revealIfCollapsed: true,
            forceReschedule: true
        )
    }

    func handlePinnedStateChange(shouldStayExpanded: Bool, autoHideEnabled: Bool) {
        if shouldStayExpanded {
            cancelCollapseTask()
            withAnimation(.snappy(duration: NoteWindowTiming.chromeExpandAnimation)) {
                controlsCollapsed = false
            }
        } else {
            markActivity(autoHideEnabled: autoHideEnabled, shouldStayExpanded: false, forceReschedule: true)
        }
    }

    func handleAutoHideSettingChange(isEnabled: Bool, shouldStayExpanded: Bool) {
        if isEnabled {
            markActivity(autoHideEnabled: true, shouldStayExpanded: shouldStayExpanded, forceReschedule: true)
        } else {
            cancelCollapseTask()
            withAnimation(.snappy(duration: NoteWindowTiming.chromeExpandAnimation)) {
                controlsCollapsed = false
            }
        }
    }

    func expandImmediately() {
        controlsCollapsed = false
    }

    func cancelTasks() {
        cancelCollapseTask()
        hintPulseTask?.cancel()
        hintPulseTask = nil
        hintPulse = false
    }

    private func cancelCollapseTask() {
        collapseTask?.cancel()
        collapseTask = nil
    }

    private func scheduleAutoCollapse(autoHideEnabled: Bool, shouldStayExpanded: Bool) {
        cancelCollapseTask()
        guard autoHideEnabled, !shouldStayExpanded else { return }

        let delay = NoteWindowTiming.autoHideDelay
        collapseTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }

            let idleTime = Date().timeIntervalSince(self.lastActivityAt)
            guard idleTime >= delay - NoteWindowTiming.autoHideIdleTolerance else {
                self.collapseTask = nil
                self.scheduleAutoCollapse(autoHideEnabled: autoHideEnabled, shouldStayExpanded: shouldStayExpanded)
                return
            }

            withAnimation(.snappy(duration: NoteWindowTiming.autoHideCollapseAnimation)) {
                self.controlsCollapsed = true
            }
            self.collapseTask = nil
            self.triggerHintPulse()
        }
    }

    private func triggerHintPulse() {
        hintPulseTask?.cancel()
        hintPulse = false
        hintPulseTask = Task { @MainActor [weak self] in
            guard let self else { return }
            withAnimation(.easeInOut(duration: NoteWindowTiming.collapsedHandlePulseInAnimation)) {
                self.hintPulse = true
            }
            try? await Task.sleep(for: .milliseconds(NoteWindowTiming.collapsedHandlePulseHoldMilliseconds))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: NoteWindowTiming.collapsedHandlePulseOutAnimation)) {
                self.hintPulse = false
            }
            self.hintPulseTask = nil
        }
    }
}
