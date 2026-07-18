import Foundation
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("CalendarBodyVerticalView Layout Tests")
struct CalendarBodyVerticalViewLayoutTests {
  private let anchor = MonthIdentifier(month: 6, year: 2025)

  private func resolve(offset: Int) -> MonthIdentifier? {
    let zeroBased = 5 + offset
    let yearOffset = Int(floor(Double(zeroBased) / 12.0))
    let normalizedMonth = ((zeroBased % 12) + 12) % 12 + 1
    let year = 2025 + yearOffset
    guard (1900...2100).contains(year) else { return nil }
    return MonthIdentifier(month: normalizedMonth, year: year)
  }

  @Test("month window includes backward and forward months around its anchor")
  func monthWindowIsBidirectional() {
    let items = CalendarBodyVerticalView.generateMonthItems(
      anchor: anchor,
      lowerOffset: -2,
      upperOffset: 2,
      resolve: resolve,
      title: { "\($0.month)" }
    )

    #expect(
      items.map(\.id) == [
        MonthIdentifier(month: 4, year: 2025),
        MonthIdentifier(month: 5, year: 2025),
        MonthIdentifier(month: 6, year: 2025),
        MonthIdentifier(month: 7, year: 2025),
        MonthIdentifier(month: 8, year: 2025),
      ])
  }

  @Test("month window omits identifiers outside supported bounds")
  func monthWindowClampsToBounds() {
    let items = CalendarBodyVerticalView.generateMonthItems(
      anchor: anchor,
      lowerOffset: -2,
      upperOffset: 2,
      resolve: { $0 == 0 ? anchor : nil },
      title: { "\($0.month)" }
    )

    #expect(items.map(\.id) == [anchor])
  }

  @Test("month window rejects inverted offset ranges")
  func monthWindowRejectsInvertedRange() {
    let items = CalendarBodyVerticalView.generateMonthItems(
      anchor: anchor,
      lowerOffset: 2,
      upperOffset: -2,
      resolve: resolve,
      title: { "\($0.month)" }
    )

    #expect(items.isEmpty)
  }

  @Test("window expands backward near its leading edge")
  func expandsBackwardNearLeadingEdge() {
    let offsets = CalendarBodyVerticalView.expandedOffsets(
      lowerOffset: -18,
      upperOffset: 18,
      visibleIndex: 2,
      itemCount: 37,
      threshold: 5,
      expansionCount: 18
    )

    #expect(offsets.lower == -36)
    #expect(offsets.upper == 18)
  }

  @Test("window expands forward near its trailing edge")
  func expandsForwardNearTrailingEdge() {
    let offsets = CalendarBodyVerticalView.expandedOffsets(
      lowerOffset: -18,
      upperOffset: 18,
      visibleIndex: 34,
      itemCount: 37,
      threshold: 5,
      expansionCount: 18
    )

    #expect(offsets.lower == -18)
    #expect(offsets.upper == 36)
  }

  @Test("window remains stable away from either edge")
  func remainsStableAwayFromEdges() {
    let offsets = CalendarBodyVerticalView.expandedOffsets(
      lowerOffset: -18,
      upperOffset: 18,
      visibleIndex: 18,
      itemCount: 37,
      threshold: 5,
      expansionCount: 18
    )

    #expect(offsets.lower == -18)
    #expect(offsets.upper == 18)
  }
}
