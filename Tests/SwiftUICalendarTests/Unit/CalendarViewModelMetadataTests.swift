import Foundation
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("CalendarViewModel Metadata Tests")
struct CalendarViewModelMetadataTests {

  private func makeDate(year: Int, month: Int, day: Int) -> Date {
    Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day))!
  }

  // MARK: - monthMetadata(month:year:) — day counts

  @Test("Leap year February has 29 days")
  func leapYearFebruaryHas29Days() {
    let vm = CalendarViewModel.test()
    let metadata = vm.monthMetadata(month: 2, year: 2024)
    #expect(metadata != nil)
    #expect(metadata?.numberOfDays == 29)
    #expect(metadata?.month == 2)
    #expect(metadata?.year == 2024)
  }

  @Test("Non-leap year February has 28 days")
  func nonLeapYearFebruaryHas28Days() {
    let vm = CalendarViewModel.test()
    let metadata = vm.monthMetadata(month: 2, year: 2023)
    #expect(metadata != nil)
    #expect(metadata?.numberOfDays == 28)
  }

  @Test("January has 31 days")
  func januaryHas31Days() {
    let vm = CalendarViewModel.test()
    let metadata = vm.monthMetadata(month: 1, year: 2025)
    #expect(metadata?.numberOfDays == 31)
  }

  @Test("April has 30 days")
  func aprilHas30Days() {
    let vm = CalendarViewModel.test()
    let metadata = vm.monthMetadata(month: 4, year: 2025)
    #expect(metadata?.numberOfDays == 30)
  }

  // MARK: - monthMetadata(offset:)

  @Test("Offset 0 returns current month metadata")
  func offsetZeroReturnsCurrentMonth() {
    let vm = CalendarViewModel.test()
    vm.currentDate = makeDate(year: 2025, month: 6, day: 1)
    let metadata = vm.monthMetadata(offset: 0)
    #expect(metadata?.month == 6)
    #expect(metadata?.year == 2025)
  }

  @Test("Offset +1 returns next month metadata")
  func offsetPlusOneReturnsNextMonth() {
    let vm = CalendarViewModel.test()
    vm.currentDate = makeDate(year: 2025, month: 6, day: 1)
    let metadata = vm.monthMetadata(offset: 1)
    #expect(metadata?.month == 7)
    #expect(metadata?.year == 2025)
  }

  @Test("Offset -1 returns previous month metadata")
  func offsetMinusOneReturnsPrevMonth() {
    let vm = CalendarViewModel.test()
    vm.currentDate = makeDate(year: 2025, month: 6, day: 1)
    let metadata = vm.monthMetadata(offset: -1)
    #expect(metadata?.month == 5)
    #expect(metadata?.year == 2025)
  }

  @Test("Offset wraps year: December +1 = January next year")
  func offsetWrapsDecemberToJanuary() {
    let vm = CalendarViewModel.test()
    vm.currentDate = makeDate(year: 2025, month: 12, day: 1)
    let metadata = vm.monthMetadata(offset: 1)
    #expect(metadata?.month == 1)
    #expect(metadata?.year == 2026)
  }

  @Test("Offset wraps year: January -1 = December previous year")
  func offsetWrapsJanuaryToDecember() {
    let vm = CalendarViewModel.test()
    vm.currentDate = makeDate(year: 2025, month: 1, day: 1)
    let metadata = vm.monthMetadata(offset: -1)
    #expect(metadata?.month == 12)
    #expect(metadata?.year == 2024)
  }

  // MARK: - rowCount(month:year:)

  @Test("Row count is at minimum 1")
  func rowCountMinimumOne() {
    let vm = CalendarViewModel.test()
    #expect(vm.rowCount(month: 2, year: 2025) >= 1)
  }

  @Test("Row count for a 4-row month: February 2015 (starts Sunday, 28 days)")
  func rowCountFourRows() {
    // Feb 2015: Sunday start, 28 days → 0 leading + 28 days → 28/7 = 4 rows exactly
    let vm = CalendarViewModel.test()
    #expect(vm.rowCount(month: 2, year: 2015) == 4)
  }

  @Test("Row count for a 5-row month: June 2025 (starts Sunday, 30 days)")
  func rowCountFiveRows() {
    // Jun 2025: Sunday start, 30 days → 30 + 5 trailing = 35 → 5 rows
    let vm = CalendarViewModel.test()
    #expect(vm.rowCount(month: 6, year: 2025) == 5)
  }

  @Test("Row count for a 6-row month: July 2023 (starts Saturday, 31 days)")
  func rowCountSixRows() {
    // Jul 2023: Saturday start (6 leading empty), 31 days → 37 + 5 trailing = 42 → 6 rows
    let vm = CalendarViewModel.test()
    #expect(vm.rowCount(month: 7, year: 2023) == 6)
  }

  // MARK: - date(for:) and date(for:month:year:)

  @Test("date(for:) constructs correct date for current month")
  func dateForDayInCurrentMonth() throws {
    let vm = CalendarViewModel.test()
    vm.currentDate = makeDate(year: 2025, month: 6, day: 1)
    let date = try #require(vm.date(for: 15))
    let cal = Calendar(identifier: .gregorian)
    #expect(cal.component(.day, from: date) == 15)
    #expect(cal.component(.month, from: date) == 6)
    #expect(cal.component(.year, from: date) == 2025)
  }

  @Test("date(for:month:year:) constructs correct date for arbitrary month/year")
  func dateForDayMonthYear() throws {
    let vm = CalendarViewModel.test()
    let date = try #require(vm.date(for: 20, month: 3, year: 2024))
    let cal = Calendar(identifier: .gregorian)
    #expect(cal.component(.day, from: date) == 20)
    #expect(cal.component(.month, from: date) == 3)
    #expect(cal.component(.year, from: date) == 2024)
  }

  // MARK: - isToday

  @Test("isToday: true for today's day number in current month")
  func isTodayTrueForTodayInCurrentMonth() {
    let vm = CalendarViewModel.test()
    let today = Date()
    vm.currentDate = today
    let todayDay = Calendar(identifier: .gregorian).component(.day, from: today)
    #expect(vm.isToday(todayDay))
  }

  @Test("isToday: false for a different day in a past month")
  func isTodayFalseForDayInPastMonth() {
    let vm = CalendarViewModel.test()
    // Pin to June 2025 — a month in the past (test runs Feb 2026)
    vm.currentDate = makeDate(year: 2025, month: 6, day: 1)
    // Day 1 of June 2025 is not today
    #expect(!vm.isToday(1))
  }

  // MARK: - headerTitles and monthSymbols

  @Test("headerTitles has 7 entries for Gregorian calendar")
  func headerTitlesHasSevenEntries() {
    let vm = CalendarViewModel.test()
    #expect(vm.headerTitles.count == 7)
  }

  @Test("monthSymbols has 12 entries for Gregorian calendar")
  func monthSymbolsHasTwelveEntries() {
    let vm = CalendarViewModel.test()
    #expect(vm.monthSymbols.count == 12)
  }

  @Test("startOfMonthDay exposes current month weekday offset")
  func startOfMonthDayExposesCurrentMonthWeekdayOffset() {
    let vm = CalendarViewModel.test()
    vm.currentDate = makeDate(year: 2025, month: 6, day: 15)

    #expect(vm.startOfMonthDay == 1)
  }

  @Test("Hebrew months(in:) includes month 13 in a common year")
  func hebrewMonthsIncludeMonthThirteen() {
    let vm = CalendarViewModel.test(identifier: .hebrew)

    let months = vm.months(in: 5785).map(\.month)

    #expect(months == [1, 2, 3, 4, 5, 7, 8, 9, 10, 11, 12, 13])
  }

  @Test("Hebrew months(in:) includes leap month 6")
  func hebrewLeapYearMonthsIncludeMonthSix() {
    let vm = CalendarViewModel.test(identifier: .hebrew)

    let months = vm.months(in: 5784).map(\.month)

    #expect(months == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13])
  }

  @Test("Hebrew monthSymbol resolves month 13 correctly")
  func hebrewMonthSymbolForMonthThirteen() {
    let vm = CalendarViewModel.test(identifier: .hebrew)

    #expect(vm.monthSymbol(for: 13, year: 5785) == "Elul")
  }

  @Test("monthSymbol resolves current year overload")
  func monthSymbolCurrentYearOverload() {
    let vm = CalendarViewModel.test()
    vm.currentDate = makeDate(year: 2025, month: 6, day: 1)

    #expect(vm.monthSymbol(for: 6) == "June")
  }

  @Test("Overflow month metadata normalizes into next year")
  func overflowMonthMetadataNormalizesIntoNextYear() {
    let vm = CalendarViewModel.test()

    #expect(vm.monthMetadata(month: 13, year: 2025) == nil)
    #expect(vm.monthMetadata(month: 13, year: 2025, offset: 1)?.month == 2)
    #expect(vm.monthMetadata(month: 13, year: 2025, offset: 1)?.year == 2026)
  }

  @Test("Displayed month metadata offset keeps previous and next in chronological order")
  func displayedMonthMetadataOffsetKeepsChronologicalOrder() {
    let vm = CalendarViewModel.test()

    let previous = vm.monthMetadata(month: 6, year: 2026, offset: -1)
    let next = vm.monthMetadata(month: 6, year: 2026, offset: 1)

    #expect(previous?.month == 5)
    #expect(previous?.year == 2026)
    #expect(next?.month == 7)
    #expect(next?.year == 2026)
  }
}
