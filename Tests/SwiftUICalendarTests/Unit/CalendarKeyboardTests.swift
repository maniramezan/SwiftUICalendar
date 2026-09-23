import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Calendar keyboard navigation")
struct CalendarKeyboardTests {
    @Test("Arrows follow layout direction")
    func direction() {
        #expect(CalendarKeyboardCursor.dayOffset(for: .leftArrow, direction: .leftToRight) == -1)
        #expect(CalendarKeyboardCursor.dayOffset(for: .leftArrow, direction: .rightToLeft) == 1)
        #expect(CalendarKeyboardCursor.dayOffset(for: .rightArrow, direction: .rightToLeft) == -1)
        #expect(CalendarKeyboardCursor.dayOffset(for: .rightArrow, direction: .leftToRight) == 1)
        #expect(CalendarKeyboardCursor.dayOffset(for: .upArrow, direction: .rightToLeft) == -7)
        #expect(CalendarKeyboardCursor.dayOffset(for: .downArrow, direction: .leftToRight) == 7)
        #expect(CalendarKeyboardCursor.dayOffset(for: .space, direction: .leftToRight) == nil)
    }

    @Test(
        "Movement preserves selection until activation",
        arguments: [
            Calendar.Identifier.gregorian, .persian,
        ], [CalendarSelection.single(nil), .range(nil, nil), .multiple([])])
    func movement(identifier: Calendar.Identifier, selection: CalendarSelection) throws {
        let model = CalendarViewModel.test(identifier: identifier, selection: selection)
        let start = model.engine.calendar.startOfDay(for: model.currentDate)
        let cursor = CalendarKeyboardCursor()
        cursor.isActive = true
        #expect(try cursor.move(days: 7, model: model))
        let destination = try #require(cursor.date)
        #expect(model.engine.calendar.dateComponents([.day], from: start, to: destination).day == 7)
        #expect(model.selection == selection)
        #expect(cursor.isFocused(destination))
        cursor.select(model: model)
        #expect(model.isSelected(date: destination))
        cursor.isActive = false
        #expect(!cursor.isFocused(destination))
    }

    @Test(
        "Movement crosses month boundaries", arguments: [Calendar.Identifier.gregorian, .persian])
    func monthBoundary(identifier: Calendar.Identifier) throws {
        let model = CalendarViewModel.test(identifier: identifier)
        let interval = try #require(
            model.engine.calendar.dateInterval(of: .month, for: model.currentDate))
        let last = try #require(
            model.engine.calendar.date(byAdding: .day, value: -1, to: interval.end))
        try model.navigate(to: last)
        let original = model.visibleMonth
        let cursor = CalendarKeyboardCursor()
        #expect(try cursor.move(days: 1, model: model))
        #expect(model.visibleMonth != original)
        #expect(model.engine.calendar.component(.day, from: try #require(cursor.date)) == 1)
    }

    @Test("Range limits stop movement without changing focus")
    func rangeBoundary() throws {
        let model = CalendarViewModel.test()
        let cursor = CalendarKeyboardCursor()
        try model.navigate(to: model.dateRange.lowerBound)
        cursor.date = model.currentDate
        #expect(try !cursor.move(days: -1, model: model))
        #expect(cursor.date == model.dateRange.lowerBound)
        try model.navigate(to: model.dateRange.upperBound)
        cursor.date = model.currentDate
        #expect(try !cursor.move(days: 1, model: model))
        #expect(cursor.date == model.dateRange.upperBound)
    }

    @Test("External state receives navigation and selection actions")
    func externalState() throws {
        let seed = CalendarViewModel.test()
        var actions: [CalendarAction] = []
        let model = CalendarViewModel(state: seed.state) { actions.append($0) }
        let cursor = CalendarKeyboardCursor()
        try cursor.move(days: 1, model: model)
        let date = try #require(cursor.date)
        cursor.select(model: model)
        #expect(actions.count == 2)
        guard case .navigate(let destination) = actions.first else {
            Issue.record("Expected a navigation action")
            return
        }
        #expect(model.engine.calendar.isDate(destination, inSameDayAs: date))
        #expect(actions.last == .select(date, navigating: false))
        #expect(model.state == seed.state)
    }

    @Test("An absent or invalid cursor cannot select a day")
    func invalidSelection() {
        let model = CalendarViewModel.test()
        let cursor = CalendarKeyboardCursor()
        cursor.select(model: model)
        #expect(model.selection == .single(nil))
        cursor.date = .distantPast
        cursor.select(model: model)
        #expect(model.selection == .single(nil))
    }

    // MARK: - Scroll requests

    /// The vertically scrolling body navigates the model when a scroll settles, and the cursor
    /// follows that navigation. If following also asked the scroll containers to move, the list would
    /// scroll itself in response to the user's own fling.
    @Test("Following a navigation moves the cursor without requesting a scroll")
    func followDoesNotRequestScroll() throws {
        let model = CalendarViewModel.test()
        let calendar = model.engine.calendar
        let cursor = CalendarKeyboardCursor()
        cursor.isActive = true
        #expect(try cursor.move(days: 1, model: model))
        let keyboardRequest = try #require(cursor.scrollRequest)

        // Exactly what a settled scroll does: navigate, then let the cursor catch up.
        let elsewhere = try #require(
            calendar.date(byAdding: .day, value: 9, to: model.currentDate))
        try model.navigate(to: elsewhere)
        cursor.follow(model.currentDate, calendar: calendar)

        #expect(cursor.date == calendar.startOfDay(for: model.currentDate))
        #expect(
            cursor.scrollRequest == keyboardRequest,
            "following a navigation must not ask the scroll containers to move")
    }

    @Test("Keyboard movement always produces a distinct scroll request")
    func scrollRequestsAreDistinct() throws {
        let model = CalendarViewModel.test()
        let cursor = CalendarKeyboardCursor()
        cursor.isActive = true
        #expect(try cursor.move(days: 1, model: model))
        let first = try #require(cursor.scrollRequest)
        #expect(try cursor.move(days: -1, model: model))
        #expect(try cursor.move(days: 1, model: model))
        let third = try #require(cursor.scrollRequest)
        // Same destination as `first`, so only the generation distinguishes them - without it
        // `onChange` would not fire and the cell would never scroll back into view.
        #expect(third.dayStart == first.dayStart)
        #expect(third != first)
    }

    /// `ScrollViewProxy.scrollTo(_:)` only reaches a cell through the exact id the grid tagged it
    /// with, so a cursor holding a start-of-day date has to resolve that same id.
    @Test(
        "A day cell's scroll identity matches its normalized date",
        arguments: [Calendar.Identifier.gregorian, .persian])
    func scrollIdentityMatchesCell(identifier: Calendar.Identifier) throws {
        let model = CalendarViewModel.test(identifier: identifier)
        let month = try #require(model.monthIdentifier())
        let snapshot = try #require(model.monthSnapshot(for: month))
        let days = snapshot.days.filter(\.isInDisplayedMonth)
        #expect(!days.isEmpty)
        for day in days {
            let dayStart = try #require(day.dayStart)
            #expect(MonthSnapshot.Day.identity(for: dayStart) == day.id)
        }
    }

    // MARK: - Focus matching

    /// The grid compares the cursor against each day's `dayStart`. Comparing against `date` - which
    /// keeps whatever time-of-day the month arithmetic produced - can silently never match.
    @Test(
        "The focus ring matches the grid's normalized day",
        arguments: [Calendar.Identifier.gregorian, .persian])
    func focusMatchesSnapshotDay(identifier: Calendar.Identifier) throws {
        let model = CalendarViewModel.test(identifier: identifier)
        let cursor = CalendarKeyboardCursor()
        cursor.isActive = true
        #expect(try cursor.move(days: 1, model: model))
        let focused = try #require(cursor.date)

        let month = try #require(model.monthIdentifier())
        let snapshot = try #require(model.monthSnapshot(for: month))
        let matches = snapshot.days.filter { day in
            guard let dayStart = day.dayStart else { return false }
            return cursor.isFocused(dayStart)
        }
        #expect(matches.count == 1, "exactly one cell should carry the focus ring")
        #expect(try #require(matches.first?.dayStart) == focused)
    }

    // MARK: - Refused shortcuts

    /// A refused shortcut has to report failure so the view can return `.ignored` and let the host
    /// app see a key the calendar did nothing with.
    @Test("Movement past the date range reports failure")
    func refusedMovementReportsFailure() throws {
        let model = CalendarViewModel.test()
        let cursor = CalendarKeyboardCursor()
        try model.navigate(to: model.dateRange.upperBound)
        cursor.follow(model.currentDate, calendar: model.engine.calendar)
        #expect(try !cursor.move(days: 1, model: model))
        #expect(cursor.scrollRequest == nil, "a refused move must not request a scroll")
    }

    @Test("Selecting without a cursor reports failure")
    func refusedSelectionReportsFailure() {
        let model = CalendarViewModel.test()
        let cursor = CalendarKeyboardCursor()
        #expect(!cursor.select(model: model))
        cursor.date = .distantPast
        #expect(!cursor.select(model: model))
        #expect(model.selection == .single(nil))
    }

    @Test("Month movement and Today report success inside the range")
    func monthAndTodaySucceed() throws {
        let model = CalendarViewModel.test()
        let cursor = CalendarKeyboardCursor()
        cursor.isActive = true
        #expect(try cursor.moveMonths(1, model: model))
        #expect(cursor.scrollRequest != nil)
        #expect(cursor.goToToday(model: model))
        #expect(
            cursor.date == model.engine.calendar.startOfDay(for: model.currentDate))
    }

    @Test("Command arrows follow layout direction by month")
    func monthOffsetDirection() {
        #expect(CalendarKeyboardCursor.monthOffset(for: .leftArrow, direction: .leftToRight) == -1)
        #expect(CalendarKeyboardCursor.monthOffset(for: .rightArrow, direction: .leftToRight) == 1)
        // In a right-to-left calendar the next month lies to the left.
        #expect(CalendarKeyboardCursor.monthOffset(for: .leftArrow, direction: .rightToLeft) == 1)
        #expect(CalendarKeyboardCursor.monthOffset(for: .rightArrow, direction: .rightToLeft) == -1)
        #expect(CalendarKeyboardCursor.monthOffset(for: .upArrow, direction: .leftToRight) == nil)
        #expect(CalendarKeyboardCursor.monthOffset(for: .space, direction: .leftToRight) == nil)
    }

    // MARK: - Modifier filtering

    /// Caps Lock, and the numeric-pad and function flags AppKit attaches to arrow keys, must not
    /// turn a plain arrow or a ⌘-shortcut into an unrecognized chord.
    @Test("Only meaningful modifiers are compared")
    func meaningfulModifiers() {
        #expect(CalendarKeyboardCursor.meaningfulModifiers(.capsLock).isEmpty)
        #expect(CalendarKeyboardCursor.meaningfulModifiers([.numericPad, .function]).isEmpty)
        #expect(CalendarKeyboardCursor.meaningfulModifiers([.command, .capsLock]) == .command)
        #expect(CalendarKeyboardCursor.meaningfulModifiers([.command, .numericPad]) == .command)
        #expect(CalendarKeyboardCursor.meaningfulModifiers(.shift) == .shift)
        #expect(
            CalendarKeyboardCursor.meaningfulModifiers([.command, .option]) == [.command, .option])
    }

    // MARK: - Store-owned state

    /// When a store owns the state, navigation only sends an action and `currentDate` lags until the
    /// store renders back in. The cursor must still land on the month it moved to.
    @Test("Month movement lands on the new month when a store owns the state")
    func externalMonthMovement() throws {
        let seed = CalendarViewModel.test()
        var actions: [CalendarAction] = []
        let model = CalendarViewModel(state: seed.state) { actions.append($0) }
        let cursor = CalendarKeyboardCursor()
        cursor.isActive = true
        let month = try #require(model.monthIdentifier(offset: 1))

        #expect(try cursor.moveMonths(1, model: model))

        var expected = seed.state
        try expected.apply(.navigateMonth(month))
        let calendar = model.engine.calendar
        #expect(model.state == seed.state, "the store owns state; the model must not mutate it")
        #expect(cursor.date == calendar.startOfDay(for: expected.currentDate))
        #expect(cursor.scrollRequest?.dayStart == calendar.startOfDay(for: expected.currentDate))
        #expect(
            engineMonth(of: try #require(cursor.date), in: model) != model.visibleMonth,
            "the cursor stayed on the month being left")
        #expect(actions == [.navigateMonth(month)])
    }

    @Test("Today lands on today when a store owns the state")
    func externalToday() throws {
        var away = CalendarViewModel.test().state
        try away.apply(.offsetMonths(3))
        var actions: [CalendarAction] = []
        let model = CalendarViewModel(state: away) { actions.append($0) }
        let cursor = CalendarKeyboardCursor()
        cursor.isActive = true

        #expect(cursor.goToToday(model: model))

        let calendar = model.engine.calendar
        #expect(cursor.date == calendar.startOfDay(for: Date()))
        #expect(model.state == away)
        #expect(actions == [.today])
    }

    private func engineMonth(of date: Date, in model: CalendarViewModel) -> MonthIdentifier? {
        model.engine.month(containing: date)
    }
}
