import Foundation
import Testing

@testable import SwiftUICalendar

/// Month titles are memoized in ``CalendarRenderCache`` (keyed by calendar signature), not on
/// `CalendarViewModel` itself — see `CalendarRenderCache.monthTitle(for:calendar:)`. Each test
/// injects a private cache so entry-count assertions aren't order-dependent against the shared
/// instance other tests also touch.
@MainActor
@Suite("CalendarViewModel Month-Title Cache Tests")
struct CalendarViewModelMonthTitleCacheTests {

    private func makeModel(
        identifier: Calendar.Identifier = .gregorian
    ) -> (CalendarViewModel, CalendarRenderCache) {
        let cache = CalendarRenderCache()
        let model = CalendarViewModel.test(identifier: identifier, selection: .single(nil))
        model.renderCache = cache
        return (model, cache)
    }

    @Test("repeated calls for one month keep a single cache entry")
    func repeatedCallsKeepSingleEntry() throws {
        let (vm, cache) = makeModel()
        let month = vm.visibleMonth

        for _ in 0..<1000 {
            _ = vm.monthSymbol(for: month)
        }

        #expect(cache.monthTitleCount == 1)
    }

    @Test("cache size tracks distinct months, not the number of calls")
    func cacheSizeTracksDistinctMonths() throws {
        let (vm, cache) = makeModel()
        let base = try #require(vm.monthIdentifier(offset: 0))

        for call in 0..<600 {
            let month = try #require(vm.monthIdentifier(offset: call % 6, from: base))
            _ = vm.monthSymbol(for: month)
        }

        #expect(cache.monthTitleCount == 6)
    }

    @Test("cached title matches the calendar's own month symbols")
    func cachedTitleMatchesMonthSymbols() throws {
        let (vm, _) = makeModel()
        let month = vm.visibleMonth

        #expect(vm.monthSymbol(for: month) == vm.monthSymbols[month.month - 1])
    }

    @Test("distinct calendars keep separate title entries")
    func distinctCalendarsKeepSeparateEntries() throws {
        let (vm, cache) = makeModel()
        _ = vm.monthSymbol(for: vm.visibleMonth)
        #expect(cache.monthTitleCount == 1)

        vm.updateCalendar(identifier: .persian)
        let persianMonth = vm.visibleMonth
        let title = vm.monthSymbol(for: persianMonth)

        #expect(title == vm.monthSymbols[persianMonth.month - 1])
        #expect(cache.monthTitleCount == 2)
    }
}
