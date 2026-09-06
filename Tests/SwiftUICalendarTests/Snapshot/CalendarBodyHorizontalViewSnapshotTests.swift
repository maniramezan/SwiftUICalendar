import Foundation
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("CalendarBodyHorizontalView structural snapshots", .enabled(if: snapshotsEnabled))
struct CalendarBodyHorizontalViewSnapshotTests {

  private let sixRows = CalendarConfiguration(
    scrollMode: .horizontal, horizontalHeightMode: .sixRows)
  private let hugContent = CalendarConfiguration(
    scrollMode: .horizontal, horizontalHeightMode: .hugContent)

  private func makeDate(year: Int, month: Int, day: Int) -> Date {
    Calendar(identifier: .gregorian)
      .date(from: DateComponents(year: year, month: month, day: day))!
  }

  @Test("Gregorian, sixRows height mode, no selection")
  func gregorianSixRowsNoSelection() {
    let vm = CalendarViewModel.snapshot(selection: .single(nil))
    assertCalendarStructure(
      model: vm, configuration: sixRows, monthSpan: 1, named: "gregorian-six-rows")
  }

  @Test("Gregorian, hugContent height mode")
  func gregorianHugContent() {
    let vm = CalendarViewModel.snapshot(selection: .single(nil))
    assertCalendarStructure(
      model: vm, configuration: hugContent, monthSpan: 1, named: "gregorian-hug-content")
  }

  @Test("Persian calendar, RTL layout")
  func persianRTL() {
    let vm = CalendarViewModel.snapshot(identifier: .persian, selection: .single(nil))
    assertCalendarStructure(model: vm, configuration: sixRows, monthSpan: 1, named: "persian-rtl")
  }

  @Test("Range selection crossing a month boundary")
  func rangeSelectionCrossingMonthBoundary() {
    // Start in May 2025, end in June 2025 — crosses the month boundary
    let vm = CalendarViewModel.snapshot(
      selection: .range(
        makeDate(year: 2025, month: 5, day: 28), makeDate(year: 2025, month: 6, day: 5)))
    assertCalendarStructure(
      model: vm, configuration: sixRows, monthSpan: 1, named: "range-crossing-month-boundary")
  }

  @Test("Square day borders fill full cells in horizontal mode")
  func squareDayBordersFillFullCellsInHorizontalMode() {
    let vm = CalendarViewModel.snapshot(selection: .single(nil))
    vm.currentDate = makeDate(year: 2026, month: 2, day: 1)

    let theme = Theme()
    theme.day.useSquareDualCalendarDayView()
    theme.day.emptyDayBorderColor = .pink
    theme.day.emptyDayBorderColorWidth = 1

    assertCalendarStructure(
      model: vm, configuration: hugContent, theme: theme, monthSpan: 1,
      named: "square-full-cell-borders-horizontal")
  }
}
