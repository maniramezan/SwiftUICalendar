import ComposableArchitecture
import Foundation
import SwiftUICalendar
import SwiftUICalendarTCA
import Testing

@MainActor
@Suite("Calendar reducer")
struct CalendarFeatureTests {
  private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
    try #require(
      Calendar(identifier: .gregorian).date(
        from: DateComponents(year: year, month: month, day: day)))
  }

  @Test("Navigation reduces against the latest store state")
  func navigation() async throws {
    let initial = try CalendarState(currentDate: date(2025, 6, 1))
    let store = TestStore(initialState: CalendarFeature.State(calendar: initial)) {
      CalendarFeature()
    }
    store.exhaustivity = .on
    let july = try CalendarState(currentDate: date(2025, 7, 1))
    await store.send(.view(.offsetMonths(1))) { $0.calendar = july }
    let august = try CalendarState(currentDate: date(2025, 8, 1))
    await store.send(.view(.offsetMonths(1))) { $0.calendar = august }
    await store.send(.view(.offsetMonths(0)))
    let invalid = CalendarAction.navigate(try date(1800, 1, 1))
    await store.send(.view(invalid))
    await store.receive(.delegate(.navigationRejected(invalid)))
  }

  @Test("Selection delegates all selection modes", arguments: [0, 1, 2])
  func selection(mode: Int) async throws {
    let june = try date(2025, 6, 1)
    let july = try date(2025, 7, 1)
    let selection: CalendarSelection = [.single(nil), .range(nil, nil), .multiple([])][mode]
    let initial = try CalendarState(currentDate: june, selection: selection)
    let store = TestStore(initialState: CalendarFeature.State(calendar: initial)) {
      CalendarFeature()
    }
    store.exhaustivity = .on
    let selected: CalendarSelection = [.single(july), .range(july, nil), .multiple([july])][mode]
    let expected = try CalendarState(currentDate: july, selection: selected)
    await store.send(.view(.select(july, navigating: true))) { $0.calendar = expected }
    await store.receive(.delegate(.selectionChanged(expected.selection)))
    let invalid = CalendarAction.select(try date(1800, 1, 1), navigating: true)
    await store.send(.view(invalid))
    await store.receive(.delegate(.navigationRejected(invalid)))
  }

  @Test("Today uses injected time and calendar switching retains ownership")
  func todayAndCalendar() async throws {
    let june = try date(2025, 6, 1)
    let july = try date(2025, 7, 1)
    let initial = try CalendarState(currentDate: june)
    let store = TestStore(initialState: CalendarFeature.State(calendar: initial)) {
      CalendarFeature()
    } withDependencies: {
      $0.date.now = july
    }
    store.exhaustivity = .on
    var expected = initial
    try expected.apply(.today, now: july)
    await store.send(.view(.today)) { $0.calendar = expected }
    await store.receive(.delegate(.selectionChanged(.single(july))))
    try expected.apply(.setCalendar(.persian))
    await store.send(.view(.setCalendar(.persian))) { $0.calendar = expected }
    #expect(store.state.calendar.visibleMonth.year == 1404)
    await store.send(.view(.today))
  }
}
