import Foundation
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("CalendarBodyVerticalView structural snapshots", .enabled(if: snapshotsEnabled))
struct CalendarBodyVerticalViewSnapshotTests {

  private let config = CalendarConfiguration(scrollMode: .vertical)

  private func makeDate(year: Int, month: Int, day: Int) -> Date {
    Calendar(identifier: .gregorian)
      .date(from: DateComponents(year: year, month: month, day: day))!
  }

  @Test("Gregorian, no selection")
  func gregorianNoSelection() {
    let vm = CalendarViewModel.snapshot(selection: .single(nil))
    assertCalendarStructure(
      model: vm, configuration: config, monthSpan: 1, named: "gregorian-no-selection")
  }

  @Test("Gregorian, range selection within current month")
  func gregorianRangeSelection() {
    let vm = CalendarViewModel.snapshot(
      selection: .range(
        makeDate(year: 2025, month: 6, day: 10), makeDate(year: 2025, month: 6, day: 20)))
    assertCalendarStructure(
      model: vm, configuration: config, monthSpan: 1, named: "gregorian-range-selection")
  }

  @Test("Persian calendar, no selection")
  func persianNoSelection() {
    let vm = CalendarViewModel.snapshot(identifier: .persian, selection: .single(nil))
    assertCalendarStructure(
      model: vm, configuration: config, monthSpan: 1, named: "persian-no-selection")
  }

  @Test("Hebrew calendar, no selection")
  func hebrewNoSelection() {
    let vm = CalendarViewModel.snapshot(identifier: .hebrew, selection: .single(nil))
    assertCalendarStructure(
      model: vm, configuration: config, monthSpan: 1, named: "hebrew-no-selection")
  }

  @Test("Square dual day view variant")
  func squareDualDayView() {
    let vm = CalendarViewModel.snapshot(selection: .single(nil))
    let theme = Theme()
    theme.day.useSquareDualCalendarDayView(secondaryLabel: .persian)
    assertCalendarStructure(
      model: vm, configuration: config, theme: theme, monthSpan: 1, named: "square-dual-variant")
  }

  @Test("Gregorian scroll window spans several months")
  func gregorianScrollWindow() {
    let vm = CalendarViewModel.snapshot(selection: .single(nil))
    assertCalendarStructure(
      model: vm, configuration: config, monthSpan: 3, named: "gregorian-scroll-window")
  }
}
