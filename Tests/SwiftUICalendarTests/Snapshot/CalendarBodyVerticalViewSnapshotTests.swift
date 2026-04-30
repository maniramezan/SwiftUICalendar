import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("CalendarBodyVerticalView Snapshot Tests")
struct CalendarBodyVerticalViewSnapshotTests {

  // Frame used for all vertical snapshots (shows roughly 1-2 months)
  private let snapshotWidth: CGFloat = 390
  private let snapshotHeight: CGFloat = 600

  private func verticalView(vm: CalendarViewModel, theme: Theme = Theme()) -> some View {
    CalendarBodyVerticalView()
      .environment(vm)
      .environment(theme)
      .environment(Typography.default)
      .environment(\.locale, vm.locale)
      .environment(\.layoutDirection, vm.layoutDirection)
  }

  private func makeDate(year: Int, month: Int, day: Int) -> Date {
    Calendar(identifier: .gregorian)
      .date(from: DateComponents(year: year, month: month, day: day))!
  }

  @Test("Gregorian, no selection")
  func gregorianNoSelection() {
    let vm = CalendarViewModel.snapshot(selection: .single(nil))
    assertCalendarSnapshot(
      of: verticalView(vm: vm),
      width: snapshotWidth,
      height: snapshotHeight,
      named: "gregorian-no-selection"
    )
  }

  @Test("Gregorian, range selection within current month")
  func gregorianRangeSelection() {
    let start = makeDate(year: 2025, month: 6, day: 10)
    let end = makeDate(year: 2025, month: 6, day: 20)
    let vm = CalendarViewModel.snapshot(selection: .range(start, end))
    assertCalendarSnapshot(
      of: verticalView(vm: vm),
      width: snapshotWidth,
      height: snapshotHeight,
      named: "gregorian-range-selection"
    )
  }

  @Test("Persian calendar, no selection")
  func persianNoSelection() {
    let vm = CalendarViewModel.snapshot(identifier: .persian, selection: .single(nil))
    assertCalendarSnapshot(
      of: verticalView(vm: vm),
      width: snapshotWidth,
      height: snapshotHeight,
      named: "persian-no-selection"
    )
  }

  @Test("Hebrew calendar, no selection")
  func hebrewNoSelection() {
    let vm = CalendarViewModel.snapshot(identifier: .hebrew, selection: .single(nil))
    assertCalendarSnapshot(
      of: verticalView(vm: vm),
      width: snapshotWidth,
      height: snapshotHeight,
      named: "hebrew-no-selection"
    )
  }

  @Test("Square dual day view variant")
  func squareDualDayView() {
    let vm = CalendarViewModel.snapshot(selection: .single(nil))
    let theme = Theme()
    theme.day.useSquareDualCalendarDayView(secondaryLabel: .persian)
    assertCalendarSnapshot(
      of: verticalView(vm: vm, theme: theme),
      width: snapshotWidth,
      height: snapshotHeight,
      named: "square-dual-variant"
    )
  }
}
