import Foundation
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Calendar weekday preservation")
struct CalendarWeekdayPreservationTests {
    @Test(
        "Calendar switches retain a custom week start",
        arguments: [Calendar.Identifier.gregorian, .persian])
    func customWeekStart(identifier: Calendar.Identifier) throws {
        var calendar = Calendar(identifier: identifier)
        calendar.locale = CalendarState.locale(for: identifier)
        calendar.firstWeekday = 3
        var state = try CalendarState(calendar: calendar, currentDate: Date())
        try state.apply(.setCalendar(identifier == .gregorian ? .persian : .gregorian))
        #expect(state.calendar.firstWeekday == 3)
    }

    @Test("An override survives a destination whose default matches it")
    func matchingDestinationDefault() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        calendar.firstWeekday = 7
        var state = try CalendarState(calendar: calendar, currentDate: Date())
        try state.apply(.setCalendar(.persian))
        #expect(state.calendar.firstWeekday == 7)
        try state.apply(.setCalendar(.gregorian))
        #expect(state.calendar.firstWeekday == 7)
    }

    @Test("Default week starts follow the destination calendar locale")
    func defaultWeekStart() throws {
        var state = try CalendarState(calendarIdentifier: .gregorian)
        try state.apply(.setCalendar(.persian))
        var expected = Calendar(identifier: .persian)
        expected.locale = CalendarState.locale(for: .persian)
        #expect(state.calendar.firstWeekday == expected.firstWeekday)
    }
}
