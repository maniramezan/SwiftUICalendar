import Foundation
import Testing

@testable import SwiftUICalendar

@Suite("Year Decade Grid Tests")
struct YearDecadeGridTests {

  @Test("pageStart floors to the nearest multiple of pageSize")
  func pageStartFloorsToNearestPageSize() {
    #expect(YearDecadeGrid.pageStart(for: 2026) == 2025)
    #expect(YearDecadeGrid.pageStart(for: 2025) == 2025)
    #expect(YearDecadeGrid.pageStart(for: 2033) == 2025)
    #expect(YearDecadeGrid.pageStart(for: 2034) == 2034)
  }

  @Test("pageStart floors correctly for negative years")
  func pageStartFloorsForNegativeYears() {
    #expect(YearDecadeGrid.pageStart(for: -1) == -9)
    #expect(YearDecadeGrid.pageStart(for: 0) == 0)
  }

  @Test("years(pageStart:) returns nine consecutive years starting at pageStart")
  func yearsReturnsNineConsecutiveYears() {
    let years = YearDecadeGrid.years(pageStart: 2025)

    #expect(years == Array(2025...2033))
    #expect(years.count == YearDecadeGrid.pageSize)
  }

  @Test("clampedPageStart keeps an in-range page unchanged")
  func clampedPageStartKeepsInRangePageUnchanged() {
    let clamped = YearDecadeGrid.clampedPageStart(2025, minYear: 1900, maxYear: 2100)

    #expect(clamped == 2025)
  }

  @Test("clampedPageStart clamps below the minimum year's page")
  func clampedPageStartClampsBelowMinimum() {
    let clamped = YearDecadeGrid.clampedPageStart(1000, minYear: 1900, maxYear: 2100)

    #expect(clamped == YearDecadeGrid.pageStart(for: 1900))
  }

  @Test("clampedPageStart clamps above the maximum year's page")
  func clampedPageStartClampsAboveMaximum() {
    let clamped = YearDecadeGrid.clampedPageStart(3000, minYear: 1900, maxYear: 2100)

    #expect(clamped == YearDecadeGrid.pageStart(for: 2100))
  }

  @Test("adjacentPageStart pages forward by pageSize years")
  func adjacentPageStartPagesForward() {
    let next = YearDecadeGrid.adjacentPageStart(
      from: 2025, by: 1, minYear: 1900, maxYear: 2100)

    #expect(next == 2025 + YearDecadeGrid.pageSize)
  }

  @Test("adjacentPageStart pages backward by pageSize years")
  func adjacentPageStartPagesBackward() {
    let previous = YearDecadeGrid.adjacentPageStart(
      from: 2025, by: -1, minYear: 1900, maxYear: 2100)

    #expect(previous == 2025 - YearDecadeGrid.pageSize)
  }

  @Test("adjacentPageStart clamps forward paging at the maximum year")
  func adjacentPageStartClampsForwardAtMaximum() {
    let maxPageStart = YearDecadeGrid.pageStart(for: 2100)
    let next = YearDecadeGrid.adjacentPageStart(
      from: maxPageStart, by: 1, minYear: 1900, maxYear: 2100)

    #expect(next == maxPageStart)
  }

  @Test("adjacentPageStart clamps backward paging at the minimum year")
  func adjacentPageStartClampsBackwardAtMinimum() {
    let minPageStart = YearDecadeGrid.pageStart(for: 1900)
    let previous = YearDecadeGrid.adjacentPageStart(
      from: minPageStart, by: -1, minYear: 1900, maxYear: 2100)

    #expect(previous == minPageStart)
  }

  @Test("canPageBackward is false at the minimum year's page")
  func canPageBackwardIsFalseAtMinimum() {
    let minPageStart = YearDecadeGrid.pageStart(for: 1900)

    #expect(!YearDecadeGrid.canPageBackward(from: minPageStart, minYear: 1900))
  }

  @Test("canPageBackward is true above the minimum year's page")
  func canPageBackwardIsTrueAboveMinimum() {
    #expect(YearDecadeGrid.canPageBackward(from: 2025, minYear: 1900))
  }

  @Test("canPageForward is false at the maximum year's page")
  func canPageForwardIsFalseAtMaximum() {
    let maxPageStart = YearDecadeGrid.pageStart(for: 2100)

    #expect(!YearDecadeGrid.canPageForward(from: maxPageStart, maxYear: 2100))
  }

  @Test("canPageForward is true below the maximum year's page")
  func canPageForwardIsTrueBelowMaximum() {
    #expect(YearDecadeGrid.canPageForward(from: 2025, maxYear: 2100))
  }

  @Test("rangeLabel describes the literal span of years on the page")
  func rangeLabelDescribesLiteralSpan() {
    #expect(YearDecadeGrid.rangeLabel(pageStart: 2025) == "2025-2033")
  }
}
