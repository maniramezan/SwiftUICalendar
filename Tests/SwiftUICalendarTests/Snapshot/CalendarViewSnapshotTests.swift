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
    typography: Typography = .default,
    configuration: CalendarConfiguration = CalendarConfiguration()
  ) -> some View {
    CalendarView(
      model: vm,
      theme: theme,
      typography: typography,
      configuration: configuration
    )
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
    assertCalendarSnapshot(
      of: makeCalendarView(
        vm: vm,
        configuration: CalendarConfiguration(showsHeader: false)
      ),
      width: snapshotWidth,
      height: 500,
      named: "fixed-calendar-without-header"
    )
  }

  @Test("CalendarView renders vertical scroll mode")
  func verticalCalendar() {
    let vm = CalendarViewModel.snapshot(selection: .single(nil))
    assertCalendarSnapshot(
      of: makeCalendarView(
        vm: vm,
        configuration: CalendarConfiguration(scrollMode: .vertical)
      ),
      width: snapshotWidth,
      height: 620,
      named: "vertical-calendar"
    )
  }

  @Test("CalendarView renders horizontal scroll mode")
  func horizontalCalendar() {
    let vm = CalendarViewModel.snapshot(selection: .single(nil))
    assertCalendarSnapshot(
      of: makeCalendarView(
        vm: vm,
        configuration: CalendarConfiguration(scrollMode: .horizontal)
      ),
      width: snapshotWidth,
      height: 560,
      named: "horizontal-calendar"
    )
  }

  @Test("Horizontal calendar scrolls in a short landscape viewport")
  func horizontalCalendarInShortLandscapeViewport() {
    let vm = CalendarViewModel.snapshot(selection: .single(nil))
    assertCalendarSnapshot(
      of: makeCalendarView(
        vm: vm,
        configuration: CalendarConfiguration(scrollMode: .horizontal)
      ),
      width: 844,
      height: 320,
      named: "horizontal-calendar-short-landscape"
    )
  }

  @Test("Flexible grid fills a landscape horizontal calendar")
  func flexibleHorizontalCalendarInLandscapeViewport() {
    let vm = CalendarViewModel.snapshot(selection: .single(nil))
    assertCalendarSnapshot(
      of: makeCalendarView(
        vm: vm,
        configuration: CalendarConfiguration(scrollMode: .horizontal, gridSizing: .flexible)
      ),
      width: 844,
      height: 320,
      named: "horizontal-calendar-flexible-landscape"
    )
  }

  @Test("Adaptive horizontal calendar fits a portrait viewport after rotation")
  func adaptiveHorizontalCalendarInPortraitViewport() {
    let vm = CalendarViewModel.snapshot(selection: .single(nil))
    assertCalendarSnapshot(
      of: makeCalendarView(
        vm: vm,
        configuration: CalendarConfiguration(scrollMode: .horizontal)
      ),
      width: 390,
      height: 844,
      named: "horizontal-calendar-adaptive-portrait"
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

  @Test("CalendarWeekHeaderView renders localized weekdays")
  func calendarWeekHeader() {
    let vm = CalendarViewModel.snapshot(identifier: .persian, selection: .single(nil))
    assertCalendarSnapshot(
      of: CalendarWeekHeaderView(weekDays: vm.headerTitles),
      width: snapshotWidth,
      height: 48,
      named: "calendar-week-header-persian"
    )
  }
}
