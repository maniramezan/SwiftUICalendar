import SwiftUI

extension EnvironmentValues {
    @Entry var calendarPagingGuard: CalendarPagingGuard? = nil
}

/// Keeps a horizontal swipe from also selecting the day it started on.
///
/// The pager's drag runs alongside the day buttons so vertical gestures still reach the enclosing
/// scroller. A swipe that begins on a cell therefore presses that cell's button too, and lifting the
/// finger would fire it. Disabling the buttons once the drag is recognized is too late: the press
/// already began, and every cell would re-render in its disabled style. Instead the pager records
/// the swipe here and `CalendarBodyView` refuses the selection.
///
/// A reference type so recording a swipe never invalidates a view body.
@MainActor
final class CalendarPagingGuard {
    /// How long after a swipe's last activity a selection is still treated as part of that swipe.
    /// The button action and the drag's end arrive within the same touch-up.
    static let afterSwipeGrace: Duration = .milliseconds(250)
    /// How long a swipe may go without activity before it is presumed cancelled. A system-cancelled
    /// gesture never reports its end, and it must not leave day selection blocked.
    static let staleSwipeTimeout: Duration = .seconds(2)

    private var isSwiping = false
    private var lastActivity: ContinuousClock.Instant?

    /// Records that the pager recognized a horizontal swipe, or that it is still moving.
    func recordSwipe(at now: ContinuousClock.Instant = .now) {
        isSwiping = true
        lastActivity = now
    }

    /// Records that the swipe ended.
    func endSwipe(at now: ContinuousClock.Instant = .now) {
        isSwiping = false
        lastActivity = now
    }

    /// Whether a day selection arriving at `now` belongs to a swipe and must be ignored.
    func shouldSuppressSelection(at now: ContinuousClock.Instant = .now) -> Bool {
        guard let lastActivity else { return false }
        let idle = now - lastActivity
        if isSwiping { return idle < Self.staleSwipeTimeout }
        return idle < Self.afterSwipeGrace
    }
}
