import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("CalendarBodyHorizontalView Snapshot Tests")
struct CalendarBodyHorizontalViewSnapshotTests {

  private let snapshotWidth: CGFloat = 390

  private func horizontalView(vm: CalendarViewModel, theme: Theme = Theme()) -> some View {
    CalendarBodyHorizontalView(viewModel: vm)
      .environment(theme)
      .environment(Typography.default)
      .environment(\.locale, vm.locale)
      .environment(\.layoutDirection, vm.layoutDirection)
  }

  private func makeDate(year: Int, month: Int, day: Int) -> Date {
    Calendar(identifier: .gregorian)
      .date(from: DateComponents(year: year, month: month, day: day))!
  }

  @Test("Gregorian, sixRows height mode, no selection")
  func gregorianSixRowsNoSelection() {
    let vm = CalendarViewModel.snapshot(selection: .single(nil))
    let theme = Theme()
    theme.horizontalHeightMode = .sixRows
    assertCalendarSnapshot(
      of: horizontalView(vm: vm, theme: theme),
      width: snapshotWidth,
      named: "gregorian-six-rows"
    )
  }

  @Test("Gregorian, hugContent height mode")
  func gregorianHugContent() {
    let vm = CalendarViewModel.snapshot(selection: .single(nil))
    let theme = Theme()
    theme.horizontalHeightMode = .hugContent
    assertCalendarSnapshot(
      of: horizontalView(vm: vm, theme: theme),
      width: snapshotWidth,
      named: "gregorian-hug-content"
    )
  }

  @Test("Persian calendar, RTL layout")
  func persianRTL() {
    let vm = CalendarViewModel.snapshot(identifier: .persian, selection: .single(nil))
    let theme = Theme()
    theme.horizontalHeightMode = .sixRows
    assertCalendarSnapshot(
      of: horizontalView(vm: vm, theme: theme)
        .environment(\.layoutDirection, .rightToLeft),
      width: snapshotWidth,
      named: "persian-rtl"
    )
  }

  @Test("Range selection crossing a month boundary")
  func rangeSelectionCrossingMonthBoundary() {
    // Start in May 2025, end in June 2025 — crosses the month boundary
    let start = makeDate(year: 2025, month: 5, day: 28)
    let end = makeDate(year: 2025, month: 6, day: 5)
    let vm = CalendarViewModel.snapshot(selection: .range(start, end))
    let theme = Theme()
    theme.horizontalHeightMode = .sixRows
    assertCalendarSnapshot(
      of: horizontalView(vm: vm, theme: theme),
      width: snapshotWidth,
      named: "range-crossing-month-boundary"
    )
  }

  @Test("Square day borders fill full cells in horizontal mode")
  func squareDayBordersFillFullCellsInHorizontalMode() {
    let vm = CalendarViewModel.snapshot(selection: .single(nil))
    vm.currentDate = makeDate(year: 2026, month: 2, day: 1)

    let theme = Theme()
    theme.horizontalHeightMode = .hugContent
    theme.day.useSquareDualCalendarDayView()
    theme.day.emptyDayBorderColor = .pink
    theme.day.emptyDayBorderColorWidth = 1

    assertCalendarSnapshot(
      of: horizontalView(vm: vm, theme: theme),
      width: snapshotWidth,
      named: "square-full-cell-borders-horizontal"
    )
  }
}
