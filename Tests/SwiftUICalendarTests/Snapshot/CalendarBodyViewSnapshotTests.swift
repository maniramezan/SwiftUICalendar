import Foundation
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("CalendarBodyView structural snapshots (.none scroll mode)", .enabled(if: snapshotsEnabled))
struct CalendarBodyViewSnapshotTests {

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
    assertCalendarStructure(model: vm, named: "no-selection")
  }

  // MARK: - Wide window (macOS) — compact grid, capped row height

  @Test("Wide window keeps day spacing compact while capping row height")
  func wideWindowKeepsDaySpacingCompact() {
    let vm = CalendarViewModel.snapshot(selection: .single(nil))
    // Capped cells stay in a natural-width compact grid instead of stretching across the window.
    assertCalendarStructure(model: vm, width: 700, named: "wide-700-fill")
  }

  @Test("Wide window keeps square day cells square")
  func wideWindowSquareCellsStaySquare() {
    let vm = CalendarViewModel.snapshot(selection: .single(nil))
    let theme = Theme()
    theme.day.useSquareDualCalendarDayView()
    theme.day.emptyDayBorderColor = .pink
    theme.day.emptyDayBorderColorWidth = 1
    assertCalendarStructure(model: vm, theme: theme, width: 700, named: "wide-700-square")
  }

  @Test("Single date selected")
  func singleDateSelected() {
    let vm = CalendarViewModel.snapshot(selection: .single(makeSelectedDate(day: 15)))
    assertCalendarStructure(model: vm, named: "single-selected")
  }

  @Test("Date range selected")
  func dateRangeSelected() {
    let vm = CalendarViewModel.snapshot(
      selection: .range(makeSelectedDate(day: 10), makeSelectedDate(day: 20)))
    assertCalendarStructure(model: vm, named: "range-selected")
  }

  @Test("Multiple dates selected")
  func multipleDatesSelected() {
    let vm = CalendarViewModel.snapshot(
      selection: .multiple([
        makeSelectedDate(day: 5), makeSelectedDate(day: 15), makeSelectedDate(day: 25),
      ]))
    assertCalendarStructure(model: vm, named: "multiple-selected")
  }

  @Test("Square dual day view with Persian secondary labels")
  func squareDualWithPersianLabels() {
    let vm = CalendarViewModel.snapshot(selection: .single(nil))
    let theme = Theme()
    theme.day.useSquareDualCalendarDayView(secondaryLabel: .persian)
    assertCalendarStructure(model: vm, theme: theme, named: "square-dual-persian-labels")
  }

  @Test("Square day borders fill full cell bounds")
  func squareDayBordersFillFullCellBounds() {
    let vm = CalendarViewModel.snapshot(selection: .single(nil))
    vm.currentDate = makeGregorianDate(year: 2026, month: 2, day: 1)

    let theme = Theme()
    theme.day.useSquareDualCalendarDayView()
    theme.day.emptyDayBorderColor = .pink
    theme.day.emptyDayBorderColorWidth = 1

    assertCalendarStructure(model: vm, theme: theme, named: "square-full-cell-borders")
  }

  // MARK: - Persian calendar

  @Test("Persian calendar, no selection")
  func persianNoSelection() {
    let vm = CalendarViewModel.snapshot(identifier: .persian, selection: .single(nil))
    assertCalendarStructure(model: vm, named: "persian-no-selection")
  }

  @Test("Persian calendar, single selection")
  func persianSingleSelection() {
    let persianDate = Calendar(identifier: .persian)
      .date(from: DateComponents(year: 1404, month: 3, day: 15))
    let vm = CalendarViewModel.snapshot(identifier: .persian, selection: .single(persianDate))
    assertCalendarStructure(model: vm, named: "persian-single-selection")
  }

  // MARK: - Hebrew

  @Test("Hebrew calendar, no selection")
  func hebrewNoSelection() {
    let vm = CalendarViewModel.snapshot(identifier: .hebrew, selection: .single(nil))
    assertCalendarStructure(model: vm, named: "hebrew-no-selection")
  }

  // MARK: - Islamic (Umm al-Qura)

  @Test("Islamic (UmmAlQura), no selection")
  func islamicNoSelection() {
    let vm = CalendarViewModel.snapshot(identifier: .islamicUmmAlQura, selection: .single(nil))
    assertCalendarStructure(model: vm, named: "islamic-no-selection")
  }

  // MARK: - Chinese

  @Test("Chinese calendar, no selection")
  func chineseNoSelection() {
    let vm = CalendarViewModel.snapshot(identifier: .chinese, selection: .single(nil))
    assertCalendarStructure(model: vm, named: "chinese-no-selection")
  }

  // MARK: - Width variants

  @Test("Narrow width (320pt — iPhone SE)")
  func narrowWidth() {
    let vm = CalendarViewModel.snapshot(selection: .single(nil))
    assertCalendarStructure(model: vm, width: 320, named: "narrow-320")
  }

  @Test("Wide width (428pt — iPhone Pro Max)")
  func wideWidth() {
    let vm = CalendarViewModel.snapshot(selection: .single(nil))
    assertCalendarStructure(model: vm, width: 428, named: "wide-428")
  }
}
