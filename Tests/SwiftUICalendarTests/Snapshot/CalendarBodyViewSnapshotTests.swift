import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("CalendarBodyView Snapshot Tests (.none scroll mode)")
struct CalendarBodyViewSnapshotTests {

  private func calendarBodyView(vm: CalendarViewModel, theme: Theme = Theme()) -> some View {
    CalendarBodyView()
      .environment(vm)
      .environment(theme)
      .environment(Typography.default)
      .environment(\.locale, vm.locale)
      .environment(\.layoutDirection, vm.layoutDirection)
  }

  private func makeSelectedDate(day: Int) -> Date {
    Calendar(identifier: .gregorian)
      .date(from: DateComponents(year: 2025, month: 6, day: day))!
  }

  private func makeGregorianDate(year: Int, month: Int, day: Int) -> Date {
    Calendar(identifier: .gregorian)
      .date(from: DateComponents(year: year, month: month, day: day))!
  }

  // MARK: - Gregorian, various selection modes

  @Test("No selection")
  func noSelection() {
    let vm = CalendarViewModel.snapshot(selection: .single(nil))
    assertCalendarSnapshot(of: calendarBodyView(vm: vm), named: "no-selection")
  }

  @Test("Single date selected")
  func singleDateSelected() {
    let selected = makeSelectedDate(day: 15)
    let vm = CalendarViewModel.snapshot(selection: .single(selected))
    assertCalendarSnapshot(of: calendarBodyView(vm: vm), named: "single-selected")
  }

  @Test("Date range selected")
  func dateRangeSelected() {
    let start = makeSelectedDate(day: 10)
    let end = makeSelectedDate(day: 20)
    let vm = CalendarViewModel.snapshot(selection: .range(start, end))
    assertCalendarSnapshot(of: calendarBodyView(vm: vm), named: "range-selected")
  }

  @Test("Multiple dates selected")
  func multipleDatesSelected() {
    let d1 = makeSelectedDate(day: 5)
    let d2 = makeSelectedDate(day: 15)
    let d3 = makeSelectedDate(day: 25)
    let vm = CalendarViewModel.snapshot(selection: .multiple([d1, d2, d3]))
    assertCalendarSnapshot(of: calendarBodyView(vm: vm), named: "multiple-selected")
  }

  @Test("Square dual day view with Persian secondary labels")
  func squareDualWithPersianLabels() {
    let vm = CalendarViewModel.snapshot(selection: .single(nil))
    let theme = Theme()
    theme.day.useSquareDualCalendarDayView(secondaryLabel: .persian)
    assertCalendarSnapshot(
      of: calendarBodyView(vm: vm, theme: theme), named: "square-dual-persian-labels")
  }

  @Test("Square day borders fill full cell bounds")
  func squareDayBordersFillFullCellBounds() {
    let vm = CalendarViewModel.snapshot(selection: .single(nil))
    vm.currentDate = makeGregorianDate(year: 2026, month: 2, day: 1)

    let theme = Theme()
    theme.day.useSquareDualCalendarDayView()
    theme.day.emptyDayBorderColor = .pink
    theme.day.emptyDayBorderColorWidth = 1

    assertCalendarSnapshot(
      of: calendarBodyView(vm: vm, theme: theme),
      named: "square-full-cell-borders"
    )
  }

  // MARK: - Persian calendar

  @Test("Persian calendar, no selection")
  func persianNoSelection() {
    let vm = CalendarViewModel.snapshot(identifier: .persian, selection: .single(nil))
    assertCalendarSnapshot(
      of: calendarBodyView(vm: vm)
        .environment(\.layoutDirection, .rightToLeft),
      named: "persian-no-selection"
    )
  }

  @Test("Persian calendar, single selection")
  func persianSingleSelection() {
    let persianDate = Calendar(identifier: .persian)
      .date(from: DateComponents(year: 1404, month: 3, day: 15))
    let vm = CalendarViewModel.snapshot(identifier: .persian, selection: .single(persianDate))
    assertCalendarSnapshot(
      of: calendarBodyView(vm: vm)
        .environment(\.layoutDirection, .rightToLeft),
      named: "persian-single-selection"
    )
  }

  // MARK: - Hebrew

  @Test("Hebrew calendar, no selection")
  func hebrewNoSelection() {
    let vm = CalendarViewModel.snapshot(identifier: .hebrew, selection: .single(nil))
    assertCalendarSnapshot(
      of: calendarBodyView(vm: vm)
        .environment(\.layoutDirection, vm.layoutDirection),
      named: "hebrew-no-selection"
    )
  }

  // MARK: - Islamic (Umm al-Qura)

  @Test("Islamic (UmmAlQura), no selection")
  func islamicNoSelection() {
    let vm = CalendarViewModel.snapshot(identifier: .islamicUmmAlQura, selection: .single(nil))
    assertCalendarSnapshot(
      of: calendarBodyView(vm: vm)
        .environment(\.layoutDirection, vm.layoutDirection),
      named: "islamic-no-selection"
    )
  }

  // MARK: - Chinese

  @Test("Chinese calendar, no selection")
  func chineseNoSelection() {
    let vm = CalendarViewModel.snapshot(identifier: .chinese, selection: .single(nil))
    assertCalendarSnapshot(of: calendarBodyView(vm: vm), named: "chinese-no-selection")
  }

  // MARK: - Width variants

  @Test("Narrow width (320pt — iPhone SE)")
  func narrowWidth() {
    let vm = CalendarViewModel.snapshot(selection: .single(nil))
    assertCalendarSnapshot(of: calendarBodyView(vm: vm), width: 320, named: "narrow-320")
  }

  @Test("Wide width (428pt — iPhone Pro Max)")
  func wideWidth() {
    let vm = CalendarViewModel.snapshot(selection: .single(nil))
    assertCalendarSnapshot(of: calendarBodyView(vm: vm), width: 428, named: "wide-428")
  }
}
