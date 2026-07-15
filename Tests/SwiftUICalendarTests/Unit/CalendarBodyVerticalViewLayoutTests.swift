import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("CalendarBodyVerticalView Layout Tests")
struct CalendarBodyVerticalViewLayoutTests {

  /// A simple Gregorian-shaped 12-month-per-year calendar sequence, used to test
  /// `generateMonthItems` without depending on a full `CalendarViewModel`.
  private func metadata(month: Int, year: Int) -> CalendarViewModel.MonthMetadata? {
    guard (1...12).contains(month) else { return nil }
    return CalendarViewModel.MonthMetadata(month: month, year: year, numberOfDays: 30)
  }

  private func nextMetadata(month: Int, year: Int) -> CalendarViewModel.MonthMetadata? {
    if month == 12 {
      return metadata(month: 1, year: year + 1)
    }
    return metadata(month: month + 1, year: year)
  }

  private func monthTitle(month: Int, year: Int) -> String {
    "Month\(month)"
  }

  @Test("generateMonthItems starts with the requested month as the first element")
  func generateMonthItemsStartsAtRequestedMonth() {
    let start = MonthIdentifier(month: 7, year: 2026)
    let items = CalendarBodyVerticalView.generateMonthItems(
      start: start,
      count: 5,
      maxYear: 2100,
      metadata: metadata,
      nextMetadata: nextMetadata,
      monthTitle: monthTitle
    )

    #expect(items.first?.id == MonthIdentifier(month: 7, year: 2026))
  }

  @Test("generateMonthItems produces months in ascending chronological order")
  func generateMonthItemsIsChronological() {
    let start = MonthIdentifier(month: 7, year: 2026)
    let items = CalendarBodyVerticalView.generateMonthItems(
      start: start,
      count: 6,
      maxYear: 2100,
      metadata: metadata,
      nextMetadata: nextMetadata,
      monthTitle: monthTitle
    )

    let ids = items.map(\.id)
    #expect(
      ids == [
        MonthIdentifier(month: 7, year: 2026),
        MonthIdentifier(month: 8, year: 2026),
        MonthIdentifier(month: 9, year: 2026),
        MonthIdentifier(month: 10, year: 2026),
        MonthIdentifier(month: 11, year: 2026),
        MonthIdentifier(month: 12, year: 2026),
      ])
  }

  @Test("generateMonthItems rolls over into the next year")
  func generateMonthItemsRollsOverYear() {
    let start = MonthIdentifier(month: 11, year: 2026)
    let items = CalendarBodyVerticalView.generateMonthItems(
      start: start,
      count: 4,
      maxYear: 2100,
      metadata: metadata,
      nextMetadata: nextMetadata,
      monthTitle: monthTitle
    )

    #expect(
      items.map(\.id) == [
        MonthIdentifier(month: 11, year: 2026),
        MonthIdentifier(month: 12, year: 2026),
        MonthIdentifier(month: 1, year: 2027),
        MonthIdentifier(month: 2, year: 2027),
      ])
  }

  @Test("generateMonthItems stops at the requested count")
  func generateMonthItemsRespectsCount() {
    let start = MonthIdentifier(month: 1, year: 2026)
    let items = CalendarBodyVerticalView.generateMonthItems(
      start: start,
      count: 3,
      maxYear: 2100,
      metadata: metadata,
      nextMetadata: nextMetadata,
      monthTitle: monthTitle
    )

    #expect(items.count == 3)
  }

  @Test("generateMonthItems stops once maxYear is reached")
  func generateMonthItemsStopsAtMaxYear() {
    let start = MonthIdentifier(month: 11, year: 2026)
    let items = CalendarBodyVerticalView.generateMonthItems(
      start: start,
      count: 240,
      maxYear: 2026,
      metadata: metadata,
      nextMetadata: nextMetadata,
      monthTitle: monthTitle
    )

    // Should include November and December 2026, then stop rather than continuing into 2027.
    #expect(
      items.map(\.id) == [
        MonthIdentifier(month: 11, year: 2026),
        MonthIdentifier(month: 12, year: 2026),
      ])
  }

  @Test("generateMonthItems returns an empty array when the start month can't be resolved")
  func generateMonthItemsHandlesUnresolvableStart() {
    let start = MonthIdentifier(month: 13, year: 2026)
    let items = CalendarBodyVerticalView.generateMonthItems(
      start: start,
      count: 5,
      maxYear: 2100,
      metadata: metadata,
      nextMetadata: nextMetadata,
      monthTitle: monthTitle
    )

    #expect(items.isEmpty)
  }

  @Test("generateMonthItems uses the provided monthTitle for each item")
  func generateMonthItemsUsesMonthTitle() {
    let start = MonthIdentifier(month: 3, year: 2026)
    let items = CalendarBodyVerticalView.generateMonthItems(
      start: start,
      count: 2,
      maxYear: 2100,
      metadata: metadata,
      nextMetadata: nextMetadata,
      monthTitle: monthTitle
    )

    #expect(items.map(\.monthTitle) == ["Month3", "Month4"])
  }
}
