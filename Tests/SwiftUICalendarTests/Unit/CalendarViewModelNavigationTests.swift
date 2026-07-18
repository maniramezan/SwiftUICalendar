import Foundation
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("CalendarViewModel Navigation Tests")
struct CalendarViewModelNavigationTests {

  private func makeDate(year: Int, month: Int, day: Int) -> Date {
    Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day))!
  }

  // MARK: - goToToday

  @Test("goToToday: navigates to today's month and year")
  func goToTodayNavigatesToCurrentMonthAndYear() {
    let vm = CalendarViewModel.test()
    vm.currentDate = makeDate(year: 2020, month: 1, day: 1)
    vm.goToToday()
    let today = Date()
    let cal = Calendar(identifier: .gregorian)
    #expect(vm.currentYear == cal.component(.year, from: today))
    #expect(vm.currentMonth == cal.component(.month, from: today))
  }

  @Test("goToToday: selects today in single-selection mode")
  func goToTodaySelectsTodayInSingleSelectionMode() {
    let selected = makeDate(year: 2020, month: 1, day: 15)
    let vm = CalendarViewModel.test(selection: .single(selected))
    vm.currentDate = makeDate(year: 2020, month: 1, day: 1)

    vm.goToToday()

    #expect(vm.isSelected(date: Date()))
    #expect(!vm.isSelected(date: selected))
    guard case .single(let date) = vm.selection else {
      Issue.record("Expected single selection to remain active")
      return
    }
    #expect(date != nil)
  }

  @Test("goToToday: selects today using the active calendar")
  func goToTodaySelectsTodayUsingActiveCalendar() {
    let calendar = Calendar(identifier: .persian)
    let selected = makeDate(year: 2020, month: 1, day: 15)
    let vm = CalendarViewModel.test(identifier: .persian, selection: .single(selected))
    vm.currentDate = makeDate(year: 2020, month: 1, day: 1)

    vm.goToToday()

    #expect(vm.calendarIdentifier == .persian)
    #expect(vm.currentYear == calendar.component(.year, from: Date()))
    #expect(vm.currentMonth == calendar.component(.month, from: Date()))
    guard case .single(let date) = vm.selection else {
      Issue.record("Expected single selection to remain active")
      return
    }
    #expect(date == calendar.startOfDay(for: Date()))
    #expect(vm.isSelected(date: Date()))
  }

  @Test("goToToday: preserves range selection")
  func goToTodayPreservesRangeSelection() {
    let start = makeDate(year: 2020, month: 1, day: 15)
    let end = makeDate(year: 2020, month: 1, day: 20)
    let vm = CalendarViewModel.test(selection: .range(start, end))
    vm.currentDate = makeDate(year: 2020, month: 1, day: 1)

    vm.goToToday()

    guard case .range(let selectedStart, let selectedEnd) = vm.selection else {
      Issue.record("Expected range selection to be preserved")
      return
    }
    #expect(selectedStart == start)
    #expect(selectedEnd == end)
  }

  // MARK: - updateMonthToNextMonth

  @Test("Next month: advances month")
  func nextMonthAdvancesMonth() throws {
    let vm = CalendarViewModel.test()
    vm.currentDate = makeDate(year: 2025, month: 6, day: 1)
    try vm.updateMonthToNextMonth()
    #expect(vm.currentMonth == 7)
    #expect(vm.currentYear == 2025)
  }

  @Test("Next month: preserves the day when possible and clamps it when necessary")
  func nextMonthPreservesOrClampsDay() throws {
    let vm = CalendarViewModel.test()
    vm.currentDate = makeDate(year: 2025, month: 1, day: 31)

    try vm.updateMonthToNextMonth()

    let calendar = Calendar(identifier: .gregorian)
    #expect(calendar.component(.day, from: vm.currentDate) == 28)
    try vm.updateMonthToNextMonth()
    #expect(calendar.component(.day, from: vm.currentDate) == 28)
  }

  @Test("Month navigation availability is true away from year boundaries")
  func monthNavigationAvailabilityIsTrueAwayFromBoundaries() {
    let vm = CalendarViewModel.test()
    vm.currentDate = makeDate(year: 2025, month: 6, day: 1)

    #expect(vm.canNavigateToPreviousMonth)
    #expect(vm.canNavigateToNextMonth)
  }

  @Test("Next month: wraps December to January of next year")
  func nextMonthWrapsDecToJan() throws {
    let vm = CalendarViewModel.test()
    vm.currentDate = makeDate(year: 2025, month: 12, day: 1)
    try vm.updateMonthToNextMonth()
    #expect(vm.currentMonth == 1)
    #expect(vm.currentYear == 2026)
  }

  // MARK: - updateMonthToPreviousMonth

  @Test("Previous month: retreats month")
  func previousMonthRetreats() throws {
    let vm = CalendarViewModel.test()
    vm.currentDate = makeDate(year: 2025, month: 6, day: 1)
    try vm.updateMonthToPreviousMonth()
    #expect(vm.currentMonth == 5)
    #expect(vm.currentYear == 2025)
  }

  @Test("Previous month: wraps January to December of previous year")
  func previousMonthWrapsJanToDec() throws {
    let vm = CalendarViewModel.test()
    vm.currentDate = makeDate(year: 2025, month: 1, day: 1)
    try vm.updateMonthToPreviousMonth()
    #expect(vm.currentMonth == 12)
    #expect(vm.currentYear == 2024)
  }

  @Test("Next month: stops at max supported year")
  func nextMonthStopsAtMaxSupportedYear() {
    let vm = CalendarViewModel.test()
    vm.currentDate = makeDate(year: 2100, month: 12, day: 1)

    #expect(!vm.canNavigateToNextMonth)
    #expect(throws: Error.self) {
      try vm.updateMonthToNextMonth()
    }
    #expect(vm.currentYear == 2100)
    #expect(vm.currentMonth == 12)
  }

  @Test("Previous month: stops at min supported year")
  func previousMonthStopsAtMinSupportedYear() {
    let vm = CalendarViewModel.test()
    vm.currentDate = makeDate(year: 1900, month: 1, day: 1)

    #expect(!vm.canNavigateToPreviousMonth)
    #expect(throws: Error.self) {
      try vm.updateMonthToPreviousMonth()
    }
    #expect(vm.currentYear == 1900)
    #expect(vm.currentMonth == 1)
  }

  // MARK: - currentYear / currentMonth setters

  @Test("currentYear setter updates year while preserving month")
  func currentYearSetterUpdatesCurrentDate() {
    let vm = CalendarViewModel.test()
    vm.currentDate = makeDate(year: 2025, month: 6, day: 1)
    vm.currentYear = 2024
    #expect(vm.currentYear == 2024)
    #expect(vm.currentMonth == 6)
  }

  @Test("currentMonth setter updates month while preserving year")
  func currentMonthSetterUpdatesCurrentDate() {
    let vm = CalendarViewModel.test()
    vm.currentDate = makeDate(year: 2025, month: 6, day: 1)
    vm.currentMonth = 3
    #expect(vm.currentMonth == 3)
    #expect(vm.currentYear == 2025)
  }

  @Test("currentMonth setter ignores invalid month")
  func currentMonthSetterIgnoresInvalidMonth() {
    let vm = CalendarViewModel.test()
    vm.currentDate = makeDate(year: 2025, month: 6, day: 1)

    vm.currentMonth = 13

    #expect(vm.currentMonth == 6)
    #expect(vm.currentYear == 2025)
  }

  @Test("currentYear setter ignores values outside supported range")
  func currentYearSetterIgnoresOutOfRangeValue() {
    let vm = CalendarViewModel.test()
    vm.currentDate = makeDate(year: 2025, month: 6, day: 1)

    vm.currentYear = 2101

    #expect(vm.currentYear == 2025)
    #expect(vm.currentMonth == 6)
  }

  @Test("currentDate setter ignores dates outside the supported range")
  func currentDateSetterIgnoresOutOfRangeValue() {
    let vm = CalendarViewModel.test()
    vm.currentDate = makeDate(year: 2025, month: 6, day: 1)

    vm.currentDate = makeDate(year: 2101, month: 1, day: 1)

    #expect(vm.currentYear == 2025)
    #expect(vm.currentMonth == 6)
  }

  @Test("explicit date navigation throws outside the supported range")
  func explicitDateNavigationThrowsOutOfRange() {
    let vm = CalendarViewModel.test()

    #expect(throws: Error.self) {
      try vm.navigate(to: makeDate(year: 2101, month: 1, day: 1))
    }
  }

  @Test("explicit navigation commands update the visible month")
  func explicitNavigationCommandsUpdateVisibleMonth() throws {
    let vm = CalendarViewModel.test()

    try vm.navigate(to: makeDate(year: 2025, month: 6, day: 15))
    #expect(vm.visibleMonth == MonthIdentifier(month: 6, year: 2025))

    try vm.navigate(toMonth: 8, year: 2025)
    #expect(vm.visibleMonth == MonthIdentifier(month: 8, year: 2025))

    try vm.navigate(toYear: 2026)
    #expect(vm.visibleMonth == MonthIdentifier(month: 8, year: 2026))
  }

  @Test("explicit month and year navigation reject invalid targets")
  func explicitComponentNavigationRejectsInvalidTargets() {
    let vm = CalendarViewModel.test()

    #expect(throws: Error.self) {
      try vm.navigate(toMonth: 13, year: 2025)
    }
    #expect(throws: Error.self) {
      try vm.navigate(toYear: 2101)
    }
  }

  @Test("Next year: advances year while preserving month")
  func nextYearAdvancesYear() throws {
    let vm = CalendarViewModel.test()
    vm.currentDate = makeDate(year: 2025, month: 6, day: 1)

    try vm.updateYearToNextYear()

    #expect(vm.currentYear == 2026)
    #expect(vm.currentMonth == 6)
  }

  @Test("Year navigation availability is true away from year boundaries")
  func yearNavigationAvailabilityIsTrueAwayFromBoundaries() {
    let vm = CalendarViewModel.test()
    vm.currentDate = makeDate(year: 2025, month: 6, day: 1)

    #expect(vm.canNavigateToPreviousYear)
    #expect(vm.canNavigateToNextYear)
  }

  @Test("Previous year: retreats year while preserving month")
  func previousYearRetreatsYear() throws {
    let vm = CalendarViewModel.test()
    vm.currentDate = makeDate(year: 2025, month: 6, day: 1)

    try vm.updateYearToPreviousYear()

    #expect(vm.currentYear == 2024)
    #expect(vm.currentMonth == 6)
  }

  @Test("Next year: stops at max supported year")
  func nextYearStopsAtMaxSupportedYear() {
    let vm = CalendarViewModel.test()
    vm.currentDate = makeDate(year: 2100, month: 6, day: 1)

    #expect(!vm.canNavigateToNextYear)
    #expect(throws: Error.self) {
      try vm.updateYearToNextYear()
    }
    #expect(vm.currentYear == 2100)
    #expect(vm.currentMonth == 6)
  }

  @Test("updateMonth(byAdding:) rejects out-of-range offset")
  func updateMonthByAddingRejectsOutOfRangeOffset() {
    let vm = CalendarViewModel.test()
    vm.currentDate = makeDate(year: 2100, month: 12, day: 1)

    #expect(throws: Error.self) {
      try vm.updateMonth(byAdding: 1)
    }
    #expect(vm.currentYear == 2100)
    #expect(vm.currentMonth == 12)
  }

  @Test("Previous year: stops at min supported year")
  func previousYearStopsAtMinSupportedYear() {
    let vm = CalendarViewModel.test()
    vm.currentDate = makeDate(year: 1900, month: 6, day: 1)

    #expect(!vm.canNavigateToPreviousYear)
    #expect(throws: Error.self) {
      try vm.updateYearToPreviousYear()
    }
    #expect(vm.currentYear == 1900)
    #expect(vm.currentMonth == 6)
  }

  // MARK: - Month identifiers

  @Test("monthIdentifier resolves a positive offset without mutating state")
  func monthIdentifierPositiveOffset() {
    let vm = CalendarViewModel.test()
    vm.currentDate = makeDate(year: 2025, month: 6, day: 1)
    let month = vm.monthIdentifier(offset: 1)
    #expect(month == MonthIdentifier(month: 7, year: 2025))
    #expect(vm.currentMonth == 6)
  }

  @Test("monthIdentifier resolves a negative offset without mutating state")
  func monthIdentifierNegativeOffset() {
    let vm = CalendarViewModel.test()
    vm.currentDate = makeDate(year: 2025, month: 6, day: 1)
    let month = vm.monthIdentifier(offset: -1)
    #expect(month == MonthIdentifier(month: 5, year: 2025))
    #expect(vm.currentMonth == 6)
  }

  @Test("month snapshot reflects selection without creating another model")
  func monthSnapshotReflectsSelection() throws {
    let selectedDate = makeDate(year: 2025, month: 6, day: 15)
    let vm = CalendarViewModel.test(selection: .single(selectedDate))
    vm.currentDate = makeDate(year: 2025, month: 6, day: 1)
    let snapshot = try #require(vm.monthSnapshot(for: MonthIdentifier(month: 6, year: 2025)))
    #expect(
      snapshot.days.first(where: { $0.day == 15 && $0.isInDisplayedMonth })?.isSelected == true)
  }

  @Test("monthIdentifier wraps the year without mutating state")
  func monthIdentifierWrapsYear() {
    let vm = CalendarViewModel.test()
    vm.currentDate = makeDate(year: 2025, month: 12, day: 1)
    #expect(vm.monthIdentifier(offset: 1) == MonthIdentifier(month: 1, year: 2026))
    #expect(vm.currentMonth == 12)
  }

  @Test("monthIdentifier resolves offsets from an explicit source month")
  func monthIdentifierResolvesFromExplicitSource() {
    let vm = CalendarViewModel.test()
    vm.currentDate = makeDate(year: 2025, month: 6, day: 15)

    let source = MonthIdentifier(month: 1, year: 2024)
    #expect(vm.monthIdentifier(offset: 2, from: source) == MonthIdentifier(month: 3, year: 2024))
    #expect(vm.monthIdentifier(offset: -1, from: source) == MonthIdentifier(month: 12, year: 2023))
    #expect(vm.currentMonth == 6)
  }

  @Test("month snapshot is nil for an unresolvable month")
  func monthSnapshotNilForUnresolvableMonth() {
    let vm = CalendarViewModel.test()
    #expect(vm.monthSnapshot(for: MonthIdentifier(month: 0, year: 2025)) == nil)
  }

  @Test("month snapshot pads leading and trailing overflow days to full weeks")
  func monthSnapshotPadsToFullWeeks() throws {
    let vm = CalendarViewModel.test()
    vm.currentDate = makeDate(year: 2025, month: 6, day: 1)
    let snapshot = try #require(vm.monthSnapshot(for: MonthIdentifier(month: 6, year: 2025)))

    #expect(snapshot.days.count % 7 == 0)
    #expect(snapshot.rowCount == snapshot.days.count / 7)
    #expect(snapshot.days.contains { !$0.isInDisplayedMonth })
    #expect(snapshot.days.filter(\.isInDisplayedMonth).count == 30)
  }

  @Test("monthIdentifier returns nil beyond the supported range")
  func monthIdentifierReturnsNilBeyondSupportedRange() {
    let vm = CalendarViewModel.test()

    vm.currentDate = makeDate(year: 2100, month: 12, day: 1)
    #expect(vm.monthIdentifier(offset: 1) == nil)
    #expect(vm.monthIdentifier(offset: -1) == MonthIdentifier(month: 11, year: 2100))

    vm.currentDate = makeDate(year: 1900, month: 1, day: 1)
    #expect(vm.monthIdentifier(offset: -1) == nil)
    #expect(vm.monthIdentifier(offset: 1) == MonthIdentifier(month: 2, year: 1900))
  }
}
