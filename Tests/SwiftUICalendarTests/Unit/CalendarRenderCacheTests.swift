import Foundation
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("CalendarRenderCache Tests")
struct CalendarRenderCacheTests {

    /// A model wired to a cache no other test can touch.
    private func makeModel(
        identifier: Calendar.Identifier = .gregorian,
        selection: CalendarSelection = .single(nil)
    ) -> (CalendarViewModel, CalendarRenderCache) {
        let cache = CalendarRenderCache()
        let model = CalendarViewModel.test(identifier: identifier, selection: selection)
        model.renderCache = cache
        return (model, cache)
    }

    @Test("repeated grid lookups for one month keep a single cache entry")
    func repeatedGridLookupsKeepSingleEntry() throws {
        let (model, cache) = makeModel()
        let month = model.visibleMonth

        for _ in 0..<500 {
            _ = model.monthSnapshot(for: month)
        }

        #expect(cache.monthGeometryCount == 1)
    }

    @Test("grid cache size tracks distinct months, not the number of calls")
    func gridCacheTracksDistinctMonths() throws {
        let (model, cache) = makeModel()
        let base = model.visibleMonth

        for call in 0..<300 {
            let month = try #require(model.monthIdentifier(offset: call % 6, from: base))
            _ = model.monthSnapshot(for: month)
        }

        #expect(cache.monthGeometryCount == 6)
    }

    @Test("month offsets are memoized, including unresolvable ones")
    func monthOffsetsAreMemoized() throws {
        let (model, cache) = makeModel()
        let base = model.visibleMonth

        // Far outside the supported 1900–2100 interval, so the engine resolves nothing.
        #expect(model.monthIdentifier(offset: 100_000, from: base) == nil)
        #expect(model.monthIdentifier(offset: 100_000, from: base) == nil)
        _ = model.monthIdentifier(offset: 1, from: base)
        _ = model.monthIdentifier(offset: 1, from: base)

        #expect(cache.monthOffsetCount == 2)
    }

    @Test("a cached miss still reports nil rather than a stale identifier")
    func cachedMissStaysNil() throws {
        let (model, _) = makeModel()
        let base = model.visibleMonth

        let first = model.monthIdentifier(offset: -100_000, from: base)
        let second = model.monthIdentifier(offset: -100_000, from: base)

        #expect(first == nil)
        #expect(second == nil)
    }

    @Test("distinct calendars never share a cached grid")
    func distinctCalendarsDoNotShareGrids() throws {
        let (model, cache) = makeModel()
        let gregorianMonth = model.visibleMonth
        let gregorianDays = try #require(model.monthSnapshot(for: gregorianMonth)).days.count

        model.updateCalendar(identifier: .persian)
        let persianMonth = model.visibleMonth
        let persianDays = try #require(model.monthSnapshot(for: persianMonth)).days.count

        #expect(cache.monthGeometryCount == 2)
        #expect(gregorianDays > 0)
        #expect(persianDays > 0)
    }

    @Test("formatters are reused per calendar signature and format")
    func formattersAreReused() throws {
        let (model, cache) = makeModel()
        let calendar = model.engine.calendar

        let first = cache.formatter(format: "LLLL", calendar: calendar)
        let second = cache.formatter(format: "LLLL", calendar: calendar)
        let other = cache.formatter(format: "G", calendar: calendar)

        #expect(first === second)
        #expect(first !== other)
    }

    @Test("removeAll drops every retained entry")
    func removeAllDropsEntries() throws {
        let (model, cache) = makeModel()
        _ = model.monthSnapshot(for: model.visibleMonth)
        _ = model.monthIdentifier(offset: 1)
        #expect(cache.monthGeometryCount == 1)
        #expect(cache.monthOffsetCount >= 1)

        cache.removeAll()

        #expect(cache.monthGeometryCount == 0)
        #expect(cache.monthOffsetCount == 0)
    }

    @Test("the grid cache stays bounded while scrolling across many months")
    func gridCacheStaysBounded() throws {
        let (model, cache) = makeModel()
        let base = model.visibleMonth

        for offset in -400...400 {
            guard let month = model.monthIdentifier(offset: offset, from: base) else { continue }
            _ = model.monthSnapshot(for: month)
        }

        #expect(cache.monthGeometryCount <= 144)
        #expect(cache.monthGeometryCount > 0)
    }

    @Test("a cached grid still reflects a later selection change")
    func cachedGridReflectsSelectionChange() throws {
        let (model, cache) = makeModel()
        let month = model.visibleMonth
        let before = try #require(model.monthSnapshot(for: month))
        #expect(before.days.allSatisfy { !$0.isSelected })

        let target = try #require(before.days.first(where: \.isInDisplayedMonth)?.date)
        model.selection = .single(target)
        let after = try #require(model.monthSnapshot(for: month))

        // Selection is applied on read, so the grid is reused rather than rebuilt.
        #expect(cache.monthGeometryCount == 1)
        #expect(after.days.filter(\.isSelected).count == 1)
        #expect(after.days.first(where: \.isSelected)?.date == target)
    }

    @Test("a cached grid marks today in the displayed month")
    func cachedGridMarksToday() throws {
        let (model, _) = makeModel()
        let month = model.visibleMonth
        _ = model.monthSnapshot(for: month)

        let snapshot = try #require(model.monthSnapshot(for: month))
        let calendar = model.engine.calendar
        let todayCells = snapshot.days.filter(\.isToday)

        #expect(todayCells.count == 1)
        let date = try #require(todayCells.first?.date)
        #expect(calendar.isDateInToday(date))
    }

    @Test("a range selection marks every day between its bounds")
    func rangeSelectionMarksInteriorDays() throws {
        let (model, _) = makeModel()
        let month = model.visibleMonth
        let calendar = model.engine.calendar
        let start = try #require(model.engine.date(day: 10, in: month))
        let end = try #require(model.engine.date(day: 14, in: month))

        model.selection = .range(start, end)
        let snapshot = try #require(model.monthSnapshot(for: month))
        let selected = snapshot.days.filter(\.isSelected).compactMap(\.date)

        #expect(selected.count == 5)
        #expect(selected.allSatisfy { calendar.startOfDay(for: $0) >= start })
        #expect(selected.allSatisfy { calendar.startOfDay(for: $0) <= end })
    }

    @Test("a cached grid matches an uncached one day for day")
    func cachedGridMatchesFreshGrid() throws {
        let (model, cache) = makeModel(identifier: .persian, selection: .single(nil))
        let month = model.visibleMonth
        let target = try #require(model.engine.date(day: 5, in: month))
        model.selection = .single(target)

        let cached = try #require(model.monthSnapshot(for: month))
        cache.removeAll()
        let fresh = try #require(model.monthSnapshot(for: month))

        #expect(cached == fresh)
    }

    // MARK: - Background prefetch

    @Test("prefetching a month warms its offset, geometry, and title entries")
    func prefetchWarmsAllThreeCaches() async throws {
        let (model, cache) = makeModel()
        let anchor = model.visibleMonth
        let engine = model.engine
        let calendar = engine.calendar

        await cache.prefetchMonth(offset: 3, from: anchor, calendar: calendar, engine: engine)

        #expect(cache.monthOffsetCount == 1)
        #expect(cache.monthGeometryCount == 1)
        #expect(cache.monthTitleCount == 1)

        // The hot path should now hit every one of those entries rather than computing anything.
        let resolved = try #require(model.monthIdentifier(offset: 3, from: anchor))
        _ = model.monthSnapshot(for: resolved)
        _ = model.monthSymbol(for: resolved)

        #expect(cache.monthOffsetCount == 1)
        #expect(cache.monthGeometryCount == 1)
        #expect(cache.monthTitleCount == 1)
    }

    @Test("a prefetched grid matches synchronous computation exactly")
    func prefetchedGridMatchesSynchronousComputation() async throws {
        let (model, cache) = makeModel(identifier: .persian)
        let anchor = model.visibleMonth
        let engine = model.engine
        let calendar = engine.calendar

        await cache.prefetchMonth(offset: 5, from: anchor, calendar: calendar, engine: engine)
        let resolved = try #require(model.monthIdentifier(offset: 5, from: anchor))
        let prefetched = try #require(
            cache.monthGeometry(for: resolved, calendar: calendar, engine: engine))

        let freshCache = CalendarRenderCache()
        let fresh = try #require(
            freshCache.monthGeometry(for: resolved, calendar: calendar, engine: engine))

        #expect(prefetched == fresh)
    }

    @Test("a prefetched title matches synchronous computation exactly")
    func prefetchedTitleMatchesSynchronousComputation() async throws {
        let (model, cache) = makeModel(identifier: .persian)
        let anchor = model.visibleMonth
        let engine = model.engine
        let calendar = engine.calendar

        await cache.prefetchMonth(offset: 2, from: anchor, calendar: calendar, engine: engine)
        let resolved = try #require(model.monthIdentifier(offset: 2, from: anchor))
        let prefetched = try #require(cache.monthTitle(for: resolved, calendar: calendar))

        let freshCache = CalendarRenderCache()
        let fresh = try #require(freshCache.monthTitle(for: resolved, calendar: calendar))

        #expect(prefetched == fresh)
    }

    @Test("prefetching an unresolvable offset stores the miss without crashing")
    func prefetchingUnresolvableOffsetStoresMiss() async throws {
        let (model, cache) = makeModel()
        let anchor = model.visibleMonth
        let engine = model.engine
        let calendar = engine.calendar

        // Far outside the supported 1900-2100 interval, so the engine resolves nothing.
        await cache.prefetchMonth(offset: 100_000, from: anchor, calendar: calendar, engine: engine)

        #expect(cache.monthOffsetCount == 1)
        #expect(cache.monthGeometryCount == 0)
        #expect(cache.monthTitleCount == 0)
    }

    @Test("cancelling an in-flight prefetch sweep stops it partway")
    func cancellingPrefetchSweepStops() async throws {
        let (model, cache) = makeModel()
        let anchor = model.visibleMonth
        let engine = model.engine
        let calendar = engine.calendar
        let sweepLength = 600

        // Detached so the sweep genuinely runs off the main actor; every store hops back here, so
        // yielding lets it make progress one month at a time.
        let sweep = Task.detached {
            for offset in 1...sweepLength {
                if Task.isCancelled { return }
                await cache.prefetchMonth(
                    offset: offset, from: anchor, calendar: calendar, engine: engine)
            }
        }
        while cache.monthOffsetCount == 0 {
            await Task.yield()
        }
        sweep.cancel()
        await sweep.value

        let stoppedAt = cache.monthOffsetCount
        #expect(stoppedAt > 0)
        #expect(stoppedAt < sweepLength)
    }

    @Test("re-prefetching warmed months adds no eviction bookkeeping")
    func rePrefetchingWarmedMonthsKeepsOrderConsistent() async throws {
        let (model, cache) = makeModel()
        let anchor = model.visibleMonth
        let engine = model.engine
        let calendar = engine.calendar

        // Overlapping sweeps, as a sustained scroll schedules them.
        for start in 0..<10 {
            for offset in start..<(start + 30) {
                await cache.prefetchMonth(
                    offset: offset, from: anchor, calendar: calendar, engine: engine)
            }
        }
        // The render path reading the same months must not add bookkeeping either.
        for offset in 0..<39 {
            let month = try #require(model.monthIdentifier(offset: offset, from: anchor))
            _ = model.monthSnapshot(for: month)
            _ = model.monthSymbol(for: month)
        }

        #expect(cache.monthOffsetCount == 39)
        #expect(cache.monthGeometryCount == 39)
        #expect(cache.monthTitleCount == 39)
        #expect(cache.evictionOrderCount == 39 * 3)
    }

    @Test("eviction stays bounded and consistent when prefetch overlaps many months")
    func evictionStaysConsistentAcrossOverlappingPrefetch() async throws {
        let (model, cache) = makeModel()
        let anchor = model.visibleMonth
        let engine = model.engine
        let calendar = engine.calendar

        for start in stride(from: 0, to: 200, by: 5) {
            for offset in start..<(start + 30) {
                await cache.prefetchMonth(
                    offset: offset, from: anchor, calendar: calendar, engine: engine)
            }
        }

        // Offsets 0...224 were warmed: 225 months, of which the newest 144 keep their grids.
        #expect(cache.monthOffsetCount == 225)
        #expect(cache.monthTitleCount == 225)
        #expect(cache.monthGeometryCount == 144)
        #expect(
            cache.evictionOrderCount
                == cache.monthOffsetCount + cache.monthGeometryCount + cache.monthTitleCount)

        // Insertion-order eviction kept the most recently warmed grids, not the oldest ones.
        let newest = try #require(model.monthIdentifier(offset: 224, from: anchor))
        let oldest = try #require(model.monthIdentifier(offset: 0, from: anchor))
        await cache.prefetchMonth(offset: 224, from: anchor, calendar: calendar, engine: engine)
        _ = cache.monthGeometry(for: newest, calendar: calendar, engine: engine)
        #expect(cache.evictionOrderCount == 225 + 144 + 225)

        // Re-warming an evicted grid stores it once and evicts exactly one older grid.
        await cache.prefetchMonth(offset: 0, from: anchor, calendar: calendar, engine: engine)
        _ = cache.monthGeometry(for: oldest, calendar: calendar, engine: engine)
        #expect(cache.monthGeometryCount == 144)
        #expect(cache.evictionOrderCount == 225 + 144 + 225)
    }

    @Test("reversing scroll direction mid-sweep leaves the cache internally consistent")
    func reversingDirectionMidSweepStaysConsistent() async throws {
        let (model, cache) = makeModel()
        let anchor = model.visibleMonth
        let engine = model.engine
        let calendar = engine.calendar

        async let forward: Void = {
            for offset in 1...40 {
                await cache.prefetchMonth(
                    offset: offset, from: anchor, calendar: calendar, engine: engine)
            }
        }()
        async let backward: Void = {
            for offset in 1...40 {
                await cache.prefetchMonth(
                    offset: -offset, from: anchor, calendar: calendar, engine: engine)
            }
        }()
        _ = await (forward, backward)

        // Two sweeps computing in parallel off the main actor, interleaving their (main-actor
        // serialized) stores, must still leave every entry equal to a fresh computation.
        for offset in [10, -10, 25, -25] {
            let resolved = try #require(model.monthIdentifier(offset: offset, from: anchor))
            let cached = try #require(
                cache.monthGeometry(for: resolved, calendar: calendar, engine: engine))
            let fresh = try #require(
                CalendarRenderCache().monthGeometry(
                    for: resolved, calendar: calendar, engine: engine))
            #expect(cached == fresh)

            let cachedTitle = try #require(cache.monthTitle(for: resolved, calendar: calendar))
            let freshTitle = try #require(
                CalendarRenderCache().monthTitle(for: resolved, calendar: calendar))
            #expect(cachedTitle == freshTitle)
        }
        #expect(cache.monthOffsetCount == 80)
        #expect(cache.monthTitleCount == 80)
    }
}
