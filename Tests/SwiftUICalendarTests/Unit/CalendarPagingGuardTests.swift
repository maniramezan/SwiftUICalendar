import Foundation
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Paging guard")
struct CalendarPagingGuardTests {
    private let start = ContinuousClock.now

    @Test("Without a swipe, selections are never suppressed")
    func idle() {
        #expect(!CalendarPagingGuard().shouldSuppressSelection(at: start))
    }

    @Test("A selection during a swipe is suppressed")
    func duringSwipe() {
        let guardian = CalendarPagingGuard()
        guardian.recordSwipe(at: start)
        #expect(guardian.shouldSuppressSelection(at: start + .milliseconds(500)))
    }

    @Test("A selection arriving with the swipe's end is suppressed, a later tap is not")
    func afterSwipe() {
        let guardian = CalendarPagingGuard()
        guardian.recordSwipe(at: start)
        guardian.endSwipe(at: start + .milliseconds(100))
        #expect(guardian.shouldSuppressSelection(at: start + .milliseconds(120)))
        #expect(
            !guardian.shouldSuppressSelection(
                at: start + .milliseconds(100) + CalendarPagingGuard.afterSwipeGrace
                    + .milliseconds(1)))
    }

    @Test("A swipe that never reports its end stops blocking selection")
    func cancelledSwipe() {
        let guardian = CalendarPagingGuard()
        guardian.recordSwipe(at: start)
        #expect(
            !guardian.shouldSuppressSelection(
                at: start + CalendarPagingGuard.staleSwipeTimeout + .milliseconds(1)))
    }
}
