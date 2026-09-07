import Foundation
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("CalendarViewModel Month-Title Cache Tests")
struct CalendarViewModelMonthTitleCacheTests {

  @Test("repeated calls for one month keep a single cache entry")
  func repeatedCallsKeepSingleEntry() throws {
    let vm = CalendarViewModel.test(identifier: .gregorian, selection: .single(nil))
    let month = vm.visibleMonth

    for _ in 0..<1000 {
      _ = vm.monthSymbol(for: month)
    }

    #expect(vm.monthTitleCache.count == 1)
  }

  @Test("cache size tracks distinct months, not the number of calls")
  func cacheSizeTracksDistinctMonths() throws {
    let vm = CalendarViewModel.test(identifier: .gregorian, selection: .single(nil))
    let base = try #require(vm.monthIdentifier(offset: 0))

    for call in 0..<600 {
      let month = try #require(vm.monthIdentifier(offset: call % 6, from: base))
      _ = vm.monthSymbol(for: month)
    }

    #expect(vm.monthTitleCache.count == 6)
  }

  @Test("cached title matches the calendar's own month symbols")
  func cachedTitleMatchesMonthSymbols() throws {
    let vm = CalendarViewModel.test(identifier: .gregorian, selection: .single(nil))
    let month = vm.visibleMonth

    #expect(vm.monthSymbol(for: month) == vm.monthSymbols[month.month - 1])
  }

  @Test("switching calendar invalidates the cache")
  func switchingCalendarInvalidatesCache() throws {
    let vm = CalendarViewModel.test(identifier: .gregorian, selection: .single(nil))
    _ = vm.monthSymbol(for: vm.visibleMonth)
    #expect(vm.monthTitleCache.count == 1)

    vm.updateCalendar(identifier: .persian)
    let persianMonth = vm.visibleMonth
    let title = vm.monthSymbol(for: persianMonth)

    #expect(title == vm.monthSymbols[persianMonth.month - 1])
    #expect(vm.monthTitleCache.count == 1)
  }
}
