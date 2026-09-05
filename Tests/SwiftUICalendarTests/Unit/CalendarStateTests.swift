import Foundation
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Shared calendar state ownership")
struct CalendarStateTests {
  private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
    try #require(
      Calendar(identifier: .gregorian).date(
        from: DateComponents(year: year, month: month, day: day)))
  }

  @Test("Explicit state validates dates and normalizes selection")
  func initialization() throws {
    let day = try date(2025, 6, 1)
    let state = try CalendarState(
      currentDate: day, selection: .single(day.addingTimeInterval(3600)))
    #expect(state.selection == .single(day))
    #expect(throws: (any Error).self) { try CalendarState(currentDate: date(1800, 1, 1)) }
    #expect(throws: (any Error).self) {
      try CalendarState(calendar: Calendar(identifier: .persian), currentDate: date(2200, 1, 1))
    }
    let model = CalendarViewModel(state: state)
    #expect(model.state == state)
  }

  @Test("Convenience initialization clamps unsupported clocks without trapping")
  func clampedInitialization() throws {
    let calendar = Calendar(identifier: .gregorian)
    let state = CalendarState(
      calendar: calendar, clamping: try date(1800, 1, 1), selection: .single(nil))
    #expect(state.currentDate == (try date(1900, 1, 1)))
    let model = CalendarViewModel(state: state)
    #expect(throws: (any Error).self) { try model.updateMonth(byAdding: -1) }
    #expect(model.state == state)
  }

  @Test("Rejected compound actions preserve both selection and navigation")
  func atomicSelection() throws {
    var state = try CalendarState(currentDate: date(2025, 6, 1))
    let original = state
    #expect(throws: (any Error).self) {
      try state.apply(.select(date(1800, 1, 1), navigating: true))
    }
    #expect(state == original)
    let july = try date(2025, 7, 1)
    try state.apply(.select(july, navigating: true))
    #expect(state.currentDate == july)
    #expect(state.selection == .single(july))
  }

  @Test("Controlled projections forward intents without mutating state")
  func projection() throws {
    let state = try CalendarState(currentDate: date(2025, 6, 1))
    var actions: [CalendarAction] = []
    let projection = CalendarViewModel(state: state) { actions.append($0) }
    try projection.updateMonth(byAdding: 1)
    projection.select(try date(2025, 7, 1), navigating: true)
    projection.selection = .multiple([])
    projection.updateCalendar(identifier: .persian)
    projection.goToToday()
    #expect(projection.state == state)
    #expect(
      actions == [
        .offsetMonths(1), .select(try date(2025, 7, 1), navigating: true),
        .setSelection(.multiple([])), .setCalendar(.persian), .today,
      ])
  }

  @Test("Today uses supplied clock and preserves range or multiple selection")
  func today() throws {
    let june = try date(2025, 6, 1)
    let july = try date(2025, 7, 1)
    for selection: CalendarSelection in [.single(nil), .range(june, nil), .multiple([june])] {
      var state = try CalendarState(currentDate: june, selection: selection)
      try state.apply(.today, now: july)
      #expect(state.currentDate == july)
      #expect(state.selection == (selection == .single(nil) ? .single(july) : selection))
    }
  }

  @Test("Switching calendars preserves an explicit time zone and absolute date")
  func calendarSwitch() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(secondsFromGMT: 12600))
    var state = try CalendarState(calendar: calendar, currentDate: date(2025, 6, 1))
    let original = state.currentDate
    try state.apply(.setCalendar(.persian))
    #expect(state.calendar.timeZone == calendar.timeZone)
    #expect(state.currentDate == original)
    #expect(state.visibleMonth.year == 1404)
    let before = state
    #expect(throws: (any Error).self) { try state.apply(.navigateYear(-1)) }
    #expect(state == before)
  }
}
