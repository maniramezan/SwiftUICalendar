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
}
