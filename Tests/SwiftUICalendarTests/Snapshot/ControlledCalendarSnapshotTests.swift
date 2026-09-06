import ComposableArchitecture
import Foundation
import SwiftUICalendarTCA
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Externally owned calendar structural snapshots", .enabled(if: snapshotsEnabled))
struct ControlledCalendarSnapshotTests {
  @Test(
    "Controlled rendering supports every mode and both writing directions",
    arguments: [CalendarConfiguration.ScrollMode.none, .horizontal, .vertical],
    [Calendar.Identifier.gregorian, .persian])
  func controlled(mode: CalendarConfiguration.ScrollMode, identifier: Calendar.Identifier) {
    let model = CalendarViewModel.snapshot(identifier: identifier)
    assertCalendarStructure(
      model: model,
      configuration: CalendarConfiguration(scrollMode: mode),
      width: 390,
      monthSpan: mode == .none ? 0 : 1,
      named: "controlled-\(identifier)-\(mode)")
  }

  @Test("TCA reducer state renders and observes parent-driven changes")
  func tcaRendering() {
    let initial = CalendarViewModel.snapshot(identifier: .persian).state
    let store = Store(initialState: CalendarFeature.State(calendar: initial)) {
      CalendarFeature()
    }
    assertCalendarStructure(model: CalendarViewModel(state: store.calendar), named: "tca-persian")

    store.send(.view(.setCalendar(.gregorian)))
    store.send(.view(.offsetMonths(1)))
    #expect(CalendarViewModel(state: store.calendar).visibleMonth.month == 7)
    assertCalendarStructure(model: CalendarViewModel(state: store.calendar), named: "tca-july")
  }
}
