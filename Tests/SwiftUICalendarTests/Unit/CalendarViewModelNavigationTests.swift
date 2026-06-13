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

  @Test("goToToday: navigation does not mutate the user's selection")
  func goToTodayPreservesSelection() {
    let selected = makeDate(year: 2020, month: 1, day: 15)
    let vm = CalendarViewModel.test(selection: .single(selected))
    vm.currentDate = makeDate(year: 2020, month: 1, day: 1)

    vm.goToToday()

    // "Today" is navigation-only: it must not select today or clear the existing selection.
    #expect(vm.isSelected(date: selected))
    guard case .single(let date) = vm.selection else {
      Issue.record("Expected single selection to be preserved")
      return
    }
    #expect(date == selected)
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

  // MARK: - copy(addMonths:)

  @Test("copy: positive offset advances month without mutating original")
  func copyPositiveOffset() throws {
    let vm = CalendarViewModel.test()
    vm.currentDate = makeDate(year: 2025, month: 6, day: 1)
    let copy = try vm.copy(addMonths: 1)
    #expect(copy.currentMonth == 7)
    #expect(copy.currentYear == 2025)
    #expect(vm.currentMonth == 6)
  }

  @Test("copy: negative offset retreats month without mutating original")
  func copyNegativeOffset() throws {
    let vm = CalendarViewModel.test()
    vm.currentDate = makeDate(year: 2025, month: 6, day: 1)
    let copy = try vm.copy(addMonths: -1)
    #expect(copy.currentMonth == 5)
    #expect(copy.currentYear == 2025)
    #expect(vm.currentMonth == 6)
  }

  @Test("copy: selection is preserved in the copy")
  func copyPreservesSelection() throws {
    let date = makeDate(year: 2025, month: 6, day: 15)
    let vm = CalendarViewModel.test(selection: .single(date))
    vm.currentDate = makeDate(year: 2025, month: 6, day: 1)
    let copy = try vm.copy(addMonths: 1)
    guard case .single(let selected) = copy.selection else {
      Issue.record("Expected single selection in copy")
      return
    }
    #expect(selected != nil)
  }

  @Test("copy: year wraps correctly when spanning December→January")
  func copyYearWrapAcrossDecemberJanuary() throws {
    let vm = CalendarViewModel.test()
    vm.currentDate = makeDate(year: 2025, month: 12, day: 1)
    let copy = try vm.copy(addMonths: 1)
    #expect(copy.currentMonth == 1)
    #expect(copy.currentYear == 2026)
    #expect(vm.currentMonth == 12)
  }
}
