import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("CalendarView Snapshot Tests")
struct CalendarViewSnapshotTests {

  private let snapshotWidth: CGFloat = 390

  private func makeCalendarView(
    vm: CalendarViewModel,
    theme: Theme = Theme(),
    typography: Typography = .default
  ) -> some View {
    CalendarView(model: vm, theme: theme, typography: typography)
  }

  @Test("CalendarView renders fixed calendar with header")
  func fixedCalendarWithHeader() {
    let vm = CalendarViewModel.snapshot(selection: .single(nil))
    assertCalendarSnapshot(
      of: makeCalendarView(vm: vm),
      width: snapshotWidth,
      height: 560,
      named: "fixed-calendar-with-header"
    )
  }

  @Test("CalendarView renders without header")
  func fixedCalendarWithoutHeader() {
    let vm = CalendarViewModel.snapshot(selection: .single(nil))
    vm.showHeader = false
    assertCalendarSnapshot(
      of: makeCalendarView(vm: vm),
      width: snapshotWidth,
      height: 500,
      named: "fixed-calendar-without-header"
    )
  }

  @Test("CalendarView renders vertical scroll mode")
  func verticalCalendar() {
    let vm = CalendarViewModel.snapshot(selection: .single(nil))
    let theme = Theme()
    theme.scrollMode = .vertical
    assertCalendarSnapshot(
      of: makeCalendarView(vm: vm, theme: theme),
      width: snapshotWidth,
      height: 620,
      named: "vertical-calendar"
    )
  }

  @Test("CalendarView renders horizontal scroll mode")
  func horizontalCalendar() {
    let vm = CalendarViewModel.snapshot(selection: .single(nil))
    let theme = Theme()
    theme.scrollMode = .horizontal
    assertCalendarSnapshot(
      of: makeCalendarView(vm: vm, theme: theme),
      width: snapshotWidth,
      height: 560,
      named: "horizontal-calendar"
    )
  }

  @Test("CalendarHeaderView renders localized controls")
  func calendarHeader() {
    let vm = CalendarViewModel.snapshot(identifier: .persian, selection: .single(nil))
    assertCalendarSnapshot(
      of: CalendarHeaderView()
        .environment(vm)
        .environment(Typography.default)
        .environment(Theme.default)
        .environment(\.locale, vm.locale)
        .environment(\.layoutDirection, vm.layoutDirection),
      width: snapshotWidth,
      height: 80,
      named: "calendar-header-persian"
    )
  }
}
