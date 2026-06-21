import CoreGraphics
import XCTest
@testable import QuietNote

final class DocumentSwipeGestureAxisStateTests: XCTestCase {
    func testHorizontalLockIgnoresLaterVerticalDriftWhenCommitting() {
        var state = DocumentSwipeGestureAxisState()

        state.add(deltaX: 14, deltaY: 8)
        XCTAssertEqual(state.mode, .horizontal)

        state.add(deltaX: 46, deltaY: 70)

        XCTAssertTrue(state.shouldCommitHorizontal())
        XCTAssertEqual(state.progress, 60.0 / 220.0, accuracy: 0.001)
    }

    func testShortIntentionalHorizontalSwipeCommitsInsteadOfRebounding() {
        var state = DocumentSwipeGestureAxisState()

        state.add(deltaX: 14, deltaY: 6)
        XCTAssertEqual(state.mode, .horizontal)

        state.add(deltaX: 30, deltaY: 4)

        XCTAssertTrue(state.shouldCommitHorizontal())
    }

    func testVerticalDominantStartDoesNotBecomeHorizontalCommit() {
        var state = DocumentSwipeGestureAxisState()

        state.add(deltaX: 6, deltaY: 12)
        XCTAssertEqual(state.mode, .vertical)

        state.add(deltaX: 70, deltaY: 0)

        XCTAssertFalse(state.shouldCommitHorizontal())
    }

    func testProgressPublishingSkipsTinyRepeatedChanges() {
        var publisher = DocumentSwipeProgressPublisher()
        var published: [CGFloat] = []

        XCTAssertTrue(publisher.shouldPublish(progress: 0.04, force: true, now: 0))
        published.append(0.04)

        for index in 1...5 {
            let progress = 0.04 + CGFloat(index) * 0.002
            if publisher.shouldPublish(progress: progress, now: TimeInterval(index) * 0.004) {
                published.append(progress)
            }
        }

        XCTAssertEqual(published, [0.04])
        XCTAssertTrue(publisher.shouldPublish(progress: 0.09, now: 0.02))
    }

    func testDisablingAfterQuickSwipeTriggerDoesNotCancelCommittedSwipe() {
        XCTAssertFalse(DocumentSwipeDisablePolicy.shouldCancelWhenDisabling(
            mode: .horizontal,
            didTriggerQuickSwipe: true
        ))
        XCTAssertTrue(DocumentSwipeDisablePolicy.shouldCancelWhenDisabling(
            mode: .horizontal,
            didTriggerQuickSwipe: false
        ))
        XCTAssertFalse(DocumentSwipeDisablePolicy.shouldCancelWhenDisabling(
            mode: .vertical,
            didTriggerQuickSwipe: false
        ))
    }

    func testTriggerCooldownDoesNotOutlastSwipeAnimationUnlock() {
        XCTAssertLessThanOrEqual(
            DocumentSwipeMonitorTiming.triggerCooldown,
            NoteWindowTiming.documentSwipeCommitAnimation + NoteWindowTiming.documentSwipeUnlockDelay
        )
    }

    func testQuickSwipePublishesPartialProgressSoCommitCanAnimate() {
        let nextProgress = DocumentSwipeTriggerProgressPolicy.quickCommitStartProgress(for: 1)
        let previousProgress = DocumentSwipeTriggerProgressPolicy.quickCommitStartProgress(for: -1)

        XCTAssertGreaterThan(nextProgress, 0)
        XCTAssertLessThan(nextProgress, 1)
        XCTAssertEqual(previousProgress, -nextProgress, accuracy: 0.001)
    }
}
