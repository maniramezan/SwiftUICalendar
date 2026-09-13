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
}
