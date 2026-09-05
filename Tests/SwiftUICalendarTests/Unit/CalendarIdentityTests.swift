import Foundation
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Calendar identity and supported intervals")
struct CalendarIdentityTests {
  private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
    try #require(
      Calendar(identifier: .gregorian).date(
        from: DateComponents(year: year, month: month, day: day)))
  }

  @Test("Chinese leap months retain their dates, identity, and picker entries")
  func chineseLeapMonth() throws {
    let vm = CalendarViewModel.test(identifier: .chinese)
    let regularDate = try date(2025, 6, 25)
    let leapDate = try date(2025, 7, 25)
    try vm.navigate(to: regularDate)
    let regular = vm.visibleMonth
    try vm.updateMonth(byAdding: 1)
    let leap = vm.visibleMonth
    #expect(regular.month == leap.month)
    #expect(regular != leap)
    #expect(leap.isLeapMonth)
    #expect(vm.date(for: 1) == leapDate)
    let snapshot = try #require(vm.monthSnapshot(for: leap))
    #expect(snapshot.days.first(where: \.isInDisplayedMonth)?.date == leapDate)
    let items = CalendarHeaderMonthView.monthItems(for: vm)
    #expect(items.count == 13)
    #expect(Set(items.map(\.id)).count == 13)
    try vm.navigate(toMonth: regular)
    #expect(vm.currentDate == regularDate)
    try vm.navigate(toMonth: leap)
    #expect(vm.currentDate == leapDate)
  }

  @Test(
    "Japanese historical dates and era transitions round-trip",
    arguments: [(1900, 1, 1), (1989, 1, 10), (2019, 4, 1), (2019, 5, 1)])
  func japaneseEra(components: (Int, Int, Int)) throws {
    let vm = CalendarViewModel.test(identifier: .japanese)
    let target = try date(components.0, components.1, components.2)
    try vm.navigate(to: target)
    let month = vm.visibleMonth
    #expect(vm.date(for: components.2) == target)
    let snapshot = try #require(vm.monthSnapshot(for: month))
    #expect(snapshot.days.contains { $0.date == target && $0.isInDisplayedMonth })
    try vm.updateMonth(byAdding: 1)
    try vm.updateMonth(byAdding: -1)
    #expect(vm.visibleMonth == month)
    #expect(vm.currentDate == target)
  }

  @Test(
    "Partial boundary months remain visible and selectable",
    arguments: [Calendar.Identifier.gregorian, .persian])
  func partialBoundaries(identifier: Calendar.Identifier) throws {
    let vm = CalendarViewModel.test(identifier: identifier)
    try vm.navigate(to: date(1900, 1, 1))
    #expect(vm.monthIdentifier() == vm.visibleMonth)
    #expect(vm.monthIdentifier(offset: -1) == nil)
    let first = vm.visibleMonth
    try vm.updateMonth(byAdding: 1)
    try vm.navigate(toMonth: first)
    #expect(vm.engine.contains(vm.currentDate))
    try vm.navigate(to: date(2100, 12, 31))
    #expect(vm.currentYear == vm.maxYear)
    #expect(vm.monthIdentifier(offset: 1) == nil)
    let last = vm.visibleMonth
    try vm.updateMonth(byAdding: -1)
    try vm.navigate(toYear: last.year)
    try vm.navigate(toMonth: last)
    #expect(vm.visibleMonth == last)
  }

  @Test("Invalid and foreign month identities fail without changing state")
  func rejectsInvalidIdentity() throws {
    let vm = CalendarViewModel.test()
    let original = vm.currentDate
    for month in [
      MonthIdentifier(month: 13, year: 2025),
      MonthIdentifier(month: 6, year: 2025, isLeapMonth: true),
      MonthIdentifier(month: 6, year: 1404, calendarIdentifier: .persian, era: 0),
    ] {
      #expect(throws: (any Error).self) { try vm.navigate(toMonth: month) }
      #expect(vm.currentDate == original)
    }
    #expect(throws: (any Error).self) { try vm.navigate(toMonth: 1, year: Int.max) }
    #expect(throws: (any Error).self) { try vm.navigate(toYear: Int.min) }
    #expect(vm.currentDate == original)
    #expect(vm.date(for: 32) == nil)
    #expect(vm.date(for: 0) == nil)
  }

  @Test("Calendar switches preserve selection across every selection mode")
  func preservesSelection() throws {
    let target = try date(2025, 7, 25)
    for selection in [
      CalendarViewModel.Selection.single(target), .range(target, target), .multiple([target]),
    ] {
      let vm = CalendarViewModel.test(selection: selection)
      try vm.navigate(to: target)
      vm.updateCalendar(identifier: .chinese)
      #expect(vm.selection == selection)
      #expect(vm.visibleMonth.isLeapMonth)
      vm.updateCalendar(identifier: .persian)
      #expect(vm.currentDate == target)
      #expect(vm.monthIdentifier() == vm.visibleMonth)
    }
  }

  @Test("Year navigation clamps to the first day of a new era")
  func firstYearOfEra() throws {
    let vm = CalendarViewModel.test(identifier: .japanese)
    try vm.navigate(to: date(2025, 1, 1))
    let era = vm.visibleMonth.era
    try vm.navigate(toYear: 1)
    #expect(vm.currentDate == (try date(2019, 5, 1)))
    #expect(vm.visibleMonth.era == era)
    #expect(vm.currentYear == 1)
    #expect(vm.yearTitle(1).isEmpty == false)
    try vm.navigate(to: date(1990, 1, 1))
    try vm.navigate(toYear: 1)
    #expect(vm.currentDate == (try date(1989, 1, 8)))
  }

  @Test("Numeric month navigation stays within the selected era")
  func monthWithinEra() throws {
    let vm = CalendarViewModel.test(identifier: .japanese)
    try vm.navigate(to: date(1989, 2, 1))
    try vm.navigate(toMonth: 1, year: 1)
    #expect(vm.currentDate == (try date(1989, 1, 8)))
    #expect(vm.currentYear == 1)
    let unchanged = vm.currentDate
    #expect(throws: (any Error).self) {
      try vm.navigateInVisibleEra(toMonth: MonthIdentifier(month: 1, year: 1900))
    }
    #expect(vm.currentDate == unchanged)
  }

  @Test("Zero month offset preserves the exact instant")
  func zeroOffset() throws {
    let vm = CalendarViewModel.test()
    let original = vm.currentDate
    try vm.updateMonth(byAdding: 0)
    #expect(vm.currentDate == original)
  }

  @Test("Last partial year clamps an unavailable month to the end of the supported interval")
  func lastPartialYear() throws {
    let vm = CalendarViewModel.test(identifier: .persian)
    try vm.navigate(toMonth: 12, year: 1478)
    try vm.navigate(toYear: 1479)
    #expect(vm.currentYear == 1479)
    #expect(vm.currentMonth == 10)
    #expect(vm.engine.contains(vm.currentDate))
  }

}
