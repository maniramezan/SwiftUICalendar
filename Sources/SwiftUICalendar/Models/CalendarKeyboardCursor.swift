import SwiftUI

// MARK: - Keyboard Navigation

/// Presentation state owned by one calendar view, independent of date selection and state ownership.
@MainActor
@Observable
final class CalendarKeyboardCursor {
    /// A request for the scroll containers to bring a date into view.
    ///
    /// Carries a generation so two successive requests for the same date still compare unequal and
    /// still fire `onChange`.
    struct ScrollRequest: Equatable {
        let dayStart: Date
        let generation: Int

        /// Scroll identity of the cell this request targets.
        var identity: String {
            MonthSnapshot.Day.identity(for: dayStart)
        }
    }

    /// The focused day, always snapped to the start of the day so per-cell checks are plain `==`.
    var date: Date?
    var isActive = false
    /// Observed by the owning view to request native focus after a day activation.
    private(set) var focusRequest = 0

    /// Set only by keyboard-initiated movement.
    ///
    /// The scroll containers observe this rather than ``date``. In the vertically scrolling body a
    /// settled scroll navigates the model, which moves the cursor to follow — so a container that
    /// scrolled to ``date`` would scroll itself in response to the user's own gesture, fighting the
    /// fling that caused it.
    private(set) var scrollRequest: ScrollRequest?
    private var generation = 0

    func isFocused(_ dayStart: Date) -> Bool {
        isActive && date == dayStart
    }

    /// Moves the cursor to track a navigation the calendar performed for some other reason, without
    /// asking any scroll container to move.
    func follow(_ date: Date, calendar: Calendar) {
        self.date = calendar.startOfDay(for: date)
    }

    /// Establishes the cursor for a day activation before the view requests keyboard focus.
    /// Does not navigate or request scrolling: the day activation already handles selection.
    @discardableResult
    func focus(
        on date: Date, model: CalendarViewModel,
        shortcuts: CalendarConfiguration.KeyboardNavigation
    ) -> Bool {
        guard !shortcuts.isEmpty, model.engine.containsDay(date) else { return false }
        follow(date, calendar: model.engine.calendar)
        isActive = true
        focusRequest += 1
        return true
    }

    /// Moves the cursor by `days`, navigating the calendar to keep it visible.
    ///
    /// Returns `false` when the destination falls outside the calendar's date range, leaving the
    /// cursor where it was.
    @discardableResult
    func move(days: Int, model: CalendarViewModel) throws -> Bool {
        let engine = model.engine
        guard
            let destination = engine.calendar.date(
                byAdding: .day, value: days, to: date ?? model.currentDate),
            engine.containsDay(destination)
        else { return false }
        try navigate(to: destination, model: model)
        return true
    }

    /// Moves the cursor by `months`, keeping the same day of the month where that day exists.
    ///
    /// Returns `false` when there is no such month inside the calendar's date range.
    @discardableResult
    func moveMonths(_ months: Int, model: CalendarViewModel) throws -> Bool {
        guard let month = model.monthIdentifier(offset: months) else { return false }
        let destination = try Self.projectedDate(after: .navigateMonth(month), in: model)
        try model.navigate(toMonth: month)
        requestScroll(to: destination, calendar: model.engine.calendar)
        return true
    }

    /// Moves the cursor to today.
    ///
    /// Returns `false` when today lies outside the calendar's date range.
    @discardableResult
    func goToToday(model: CalendarViewModel) -> Bool {
        guard model.canGoToToday else { return false }
        let destination = (try? Self.projectedDate(after: .today, in: model)) ?? model.currentDate
        model.goToToday()
        requestScroll(to: destination, calendar: model.engine.calendar)
        return true
    }

    /// Selects the focused day using the calendar's current selection mode.
    ///
    /// Returns `false` when there is no cursor, or it sits outside the date range.
    @discardableResult
    func select(model: CalendarViewModel) -> Bool {
        guard let date, model.engine.containsDay(date) else { return false }
        model.select(date)
        return true
    }

    /// Where `action` leaves the calendar, computed on a copy of its state.
    ///
    /// When a store owns the state, navigating only sends an action: `model.currentDate` does not
    /// change until the store's update renders back in. Reading it straight after navigating gave the
    /// month being *left*, so the cursor stayed put and the scroll request targeted the wrong month.
    /// Applying the action to a copy yields the destination the owner's reducer will reach.
    private static func projectedDate(after action: CalendarAction, in model: CalendarViewModel)
        throws
        -> Date
    {
        var projected = model.state
        try projected.apply(action)
        return projected.currentDate
    }

    private func navigate(to destination: Date, model: CalendarViewModel) throws {
        let calendar = model.engine.calendar
        let target = model.engine.clamped(destination)
        try model.navigate(to: target)
        requestScroll(to: target, calendar: calendar)
    }

    private func requestScroll(to date: Date, calendar: Calendar) {
        let dayStart = calendar.startOfDay(for: date)
        self.date = dayStart
        generation += 1
        scrollRequest = ScrollRequest(dayStart: dayStart, generation: generation)
    }

    /// The modifiers that change what a key press means.
    ///
    /// Caps Lock, and the numeric-pad and function flags AppKit attaches to every arrow key, would
    /// otherwise fail an exact match — so arrow keys and ⌘-shortcuts silently did nothing with Caps
    /// Lock on, and likely at all on macOS.
    static func meaningfulModifiers(_ modifiers: EventModifiers) -> EventModifiers {
        modifiers.intersection([.command, .option, .control, .shift])
    }

    static func dayOffset(for key: KeyEquivalent, direction: LayoutDirection) -> Int? {
        switch key {
        case .leftArrow: direction == .rightToLeft ? 1 : -1
        case .rightArrow: direction == .rightToLeft ? -1 : 1
        case .upArrow: -7
        case .downArrow: 7
        default: nil
        }
    }

    /// Month step for a horizontal arrow key, following `direction`.
    ///
    /// In a right-to-left calendar the next month lies to the left, so `⌘←` advances.
    static func monthOffset(for key: KeyEquivalent, direction: LayoutDirection) -> Int? {
        switch key {
        case .leftArrow: direction == .rightToLeft ? 1 : -1
        case .rightArrow: direction == .rightToLeft ? -1 : 1
        default: nil
        }
    }
}
