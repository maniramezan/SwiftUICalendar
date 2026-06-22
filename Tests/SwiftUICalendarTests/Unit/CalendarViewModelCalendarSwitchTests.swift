import Foundation
import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("CalendarViewModel Calendar Switch Tests")
struct CalendarViewModelCalendarSwitchTests {

  // MARK: - updateCalendar(identifier:)

  @Test(
    "init: requested calendar owns initial current date",
    arguments: [
      Calendar.Identifier.gregorian,
      .buddhist,
      .hebrew,
      .islamicUmmAlQura,
      .japanese,
      .persian,
    ]
  )
  func initUsesRequestedCalendarForCurrentDate(identifier: Calendar.Identifier) {
    let calendar = Calendar(identifier: identifier)
    let vm = CalendarViewModel.test(identifier: identifier)

    #expect(vm.calendarIdentifier == identifier)
    #expect(vm.currentYear == calendar.component(.year, from: Date()))
    #expect(vm.currentMonth == calendar.component(.month, from: Date()))
    #expect((vm.minYear...vm.maxYear).contains(vm.currentYear))
    #expect(vm.months(in: vm.currentYear).contains { $0.month == vm.currentMonth })
  }

  @Test("Japanese: current era year is included in vertical scroll range")
  func japaneseCurrentEraYearIsIncludedInSupportedRange() {
    let calendar = Calendar(identifier: .japanese)
    let vm = CalendarViewModel.test(identifier: .japanese)

    let currentYear = calendar.component(.year, from: Date())
    #expect(vm.currentYear == currentYear)
    #expect(vm.minYear <= currentYear)
    #expect(vm.maxYear >= currentYear)
    #expect(vm.months(in: currentYear).contains { $0.month == vm.currentMonth })
  }

  @Test("updateCalendar: Gregorian and Persian produce different month names")
  func updateCalendarChangesMonthName() {
    let vm = CalendarViewModel.test(identifier: .gregorian)
    let gregorianName = vm.currentMonthName
    vm.updateCalendar(identifier: .persian)
    let persianName = vm.currentMonthName
    #expect(gregorianName != persianName)
  }

  @Test("updateCalendar: selection is preserved across calendar switch")
  func updateCalendarPreservesSelection() {
    let date = Calendar(identifier: .gregorian).date(
      from: DateComponents(year: 2025, month: 6, day: 15)
    )!
    let vm = CalendarViewModel.test(identifier: .gregorian, selection: .single(date))
    vm.updateCalendar(identifier: .persian)
    guard case .single(let selected) = vm.selection else {
      Issue.record("Expected single selection after calendar switch")
      return
    }
    #expect(selected != nil)
  }

  @Test("updateCalendar: calendar signature changes with identifier")
  func updateCalendarChangesSignature() {
    let vm = CalendarViewModel.test(identifier: .gregorian)
    let oldSignature = vm.calendarSignature

    vm.updateCalendar(identifier: .persian)

    #expect(vm.calendarIdentifier == .persian)
    #expect(vm.calendarSignature != oldSignature)
  }

  @Test("updateCalendar: current month remains valid in target calendar")
  func updateCalendarKeepsCurrentMonthValid() {
    let vm = CalendarViewModel.test(identifier: .gregorian)
    vm.currentDate = Calendar(identifier: .gregorian).date(
      from: DateComponents(year: 2025, month: 6, day: 15)
    )!

    vm.updateCalendar(identifier: .hebrew)

    let validMonths = vm.months(in: vm.currentYear).map(\.month)
    #expect(validMonths.contains(vm.currentMonth))
    #expect(!vm.currentMonthName.isEmpty)
  }

  // MARK: - Persian calendar year boundaries

  @Test("Persian: minYear is within expected Persian era range")
  func persianMinYearInPersianEra() {
    let vm = CalendarViewModel.test(identifier: .persian)
    // Gregorian 1900 ≈ Persian 1278
    #expect(vm.minYear > 1200)
    #expect(vm.minYear < 1500)
  }

  @Test("Persian: maxYear is within expected Persian era range")
  func persianMaxYearInPersianEra() {
    let vm = CalendarViewModel.test(identifier: .persian)
    // Gregorian 2100 ≈ Persian 1478
    #expect(vm.maxYear > 1200)
    #expect(vm.maxYear < 1600)
  }

  // MARK: - layoutDirection

  @Test("Persian calendar uses right-to-left layout direction")
  func persianLayoutDirectionIsRTL() {
    let vm = CalendarViewModel.test(identifier: .persian)
    #expect(vm.layoutDirection == .rightToLeft)
  }

  @Test("Gregorian calendar uses left-to-right layout direction")
  func gregorianLayoutDirectionIsLTR() {
    let vm = CalendarViewModel.test(identifier: .gregorian)
    #expect(vm.layoutDirection == .leftToRight)
  }

  // MARK: - Hebrew calendar

  @Test("Hebrew: headerTitles has 7 entries")
  func hebrewHeaderTitlesHasSevenEntries() {
    let vm = CalendarViewModel.test(identifier: .hebrew)
    #expect(vm.headerTitles.count == 7)
  }

  @Test("Hebrew: monthSymbols is non-empty")
  func hebrewMonthSymbolsNonEmpty() {
    let vm = CalendarViewModel.test(identifier: .hebrew)
    #expect(!vm.monthSymbols.isEmpty)
  }
}
