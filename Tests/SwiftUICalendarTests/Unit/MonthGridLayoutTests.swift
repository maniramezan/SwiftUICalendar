import Foundation
import Testing

@testable import SwiftUICalendar

@Suite("MonthGridLayout Tests")
struct MonthGridLayoutTests {

  // MARK: - Leading / trailing pad counts

  @Test("Month starting on the first weekday has no leading empty days")
  func noLeadingEmptyDays() {
    let layout = MonthGridLayout(
      startOfMonthDay: 1, currentMonthDays: 30, previousMonthDays: 31)
    #expect(layout.leadingEmptyDays == 0)
    #expect(layout.leadingAndCurrentCount == 30)
  }

  @Test("Leading empty days equal weekday offset minus one")
  func leadingEmptyDaysOffset() {
    // Month starts on the 6th weekday slot -> 5 leading cells from the previous month.
    let layout = MonthGridLayout(
      startOfMonthDay: 6, currentMonthDays: 30, previousMonthDays: 31)
    #expect(layout.leadingEmptyDays == 5)
    // Previous month back-fills: 31 - 5 + 1 = 27.
    #expect(layout.previousMonthStartingDay == 27)
  }

  @Test("Trailing empty days complete the final row")
  func trailingEmptyDays() {
    // 5 leading + 30 current = 35 (multiple of 7) -> no trailing fill.
    let exact = MonthGridLayout(
      startOfMonthDay: 6, currentMonthDays: 30, previousMonthDays: 31)
    #expect(exact.trailingEmptyDays == 0)
    #expect(exact.rowCount == 5)

    // 6 leading + 31 current = 37 -> 5 trailing to reach 42 (6 rows).
    let padded = MonthGridLayout(
      startOfMonthDay: 7, currentMonthDays: 31, previousMonthDays: 30)
    #expect(padded.trailingEmptyDays == 5)
    #expect(padded.rowCount == 6)
  }

  @Test("Row count is at least one for an empty month")
  func rowCountFloor() {
    let layout = MonthGridLayout(
      startOfMonthDay: 1, currentMonthDays: 0, previousMonthDays: 0)
    #expect(layout.rowCount == 1)
  }

  @Test("Negative-ish start day floors leading days at zero")
  func leadingFloor() {
    let layout = MonthGridLayout(
      startOfMonthDay: 0, currentMonthDays: 30, previousMonthDays: 31)
    #expect(layout.leadingEmptyDays == 0)
  }

  // MARK: - Month wrap

  @Test("wrappedMonth advances within the same year")
  func wrapForwardSameYear() {
    let result = MonthGridLayout.wrappedMonth(base: 5, offset: 1, monthCount: 12)
    #expect(result.month == 6)
    #expect(result.yearDelta == 0)
  }

  @Test("wrappedMonth rolls forward into the next year")
  func wrapForwardNextYear() {
    let result = MonthGridLayout.wrappedMonth(base: 12, offset: 1, monthCount: 12)
    #expect(result.month == 1)
    #expect(result.yearDelta == 1)
  }

  @Test("wrappedMonth rolls backward into the previous year")
  func wrapBackwardPreviousYear() {
    let result = MonthGridLayout.wrappedMonth(base: 1, offset: -1, monthCount: 12)
    #expect(result.month == 12)
    #expect(result.yearDelta == -1)
  }

  @Test("wrappedMonth handles a 13-month lunisolar year")
  func wrapThirteenMonths() {
    let result = MonthGridLayout.wrappedMonth(base: 13, offset: 1, monthCount: 13)
    #expect(result.month == 1)
    #expect(result.yearDelta == 1)
  }

  @Test("wrappedMonth tolerates a zero month count")
  func wrapZeroCount() {
    let result = MonthGridLayout.wrappedMonth(base: 1, offset: 1, monthCount: 0)
    #expect(result.month == 1)
  }

  // MARK: - RTL row reversal

  @Test("rowReversed mirrors each 7-wide row but keeps row order")
  func rowReversedFullRows() {
    let input = Array(0..<14)
    let reversed = MonthGridLayout.rowReversed(input)
    #expect(reversed == [6, 5, 4, 3, 2, 1, 0, 13, 12, 11, 10, 9, 8, 7])
  }

  @Test("rowReversed mirrors a partial trailing row")
  func rowReversedPartialRow() {
    let input = Array(0..<10)
    let reversed = MonthGridLayout.rowReversed(input)
    #expect(reversed == [6, 5, 4, 3, 2, 1, 0, 9, 8, 7])
  }

  @Test("rowReversed returns input unchanged for non-positive row width")
  func rowReversedZeroWidth() {
    let input = [1, 2, 3]
    #expect(MonthGridLayout.rowReversed(input, rowWidth: 0) == input)
  }
}
