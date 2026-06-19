import Foundation

/// Pure integer arithmetic for laying a month onto a 7-column grid.
///
/// Computes how many leading days belong to the previous month, how many trailing days belong to
/// the next month, and the resulting row count. Kept free of SwiftUI and `Calendar` so the layout
/// math can be unit tested directly.
struct MonthGridLayout {
  static let columnCount = 7

  /// Number of empty cells before the first of the month (`startOfMonthDay - 1`, floored at 0).
  let leadingEmptyDays: Int
  /// Number of days in the month being rendered.
  let currentMonthDays: Int
  /// Number of days in the previous month, used to back-fill leading cells.
  let previousMonthDays: Int

  /// - Parameters:
  ///   - startOfMonthDay: Weekday index (1-based) of the first day of the month.
  ///   - currentMonthDays: Day count of the rendered month.
  ///   - previousMonthDays: Day count of the previous month.
  init(startOfMonthDay: Int, currentMonthDays: Int, previousMonthDays: Int) {
    self.leadingEmptyDays = max(startOfMonthDay - 1, 0)
    self.currentMonthDays = currentMonthDays
    self.previousMonthDays = previousMonthDays
  }

  /// First previous-month day shown in the leading cells.
  var previousMonthStartingDay: Int {
    max(1, previousMonthDays - leadingEmptyDays + 1)
  }

  /// Count of leading (previous-month) plus current-month cells, before trailing fill.
  var leadingAndCurrentCount: Int {
    leadingEmptyDays + currentMonthDays
  }

  /// Number of next-month cells needed to complete the final row.
  var trailingEmptyDays: Int {
    let remainder = leadingAndCurrentCount % Self.columnCount
    return remainder == 0 ? 0 : Self.columnCount - remainder
  }

  /// Total rendered rows (at least one).
  var rowCount: Int {
    max(1, (leadingAndCurrentCount + trailingEmptyDays) / Self.columnCount)
  }

  /// Wraps a 1-based `baseMonth` by `offset` within a `monthCount`-month year, reporting how many
  /// whole years the wrap crossed.
  ///
  /// Used to synthesize adjacent-month metadata when a real date cannot be resolved (e.g. at the
  /// supported-year edges) without depending on `Calendar`.
  static func wrappedMonth(base baseMonth: Int, offset: Int, monthCount: Int)
    -> (month: Int, yearDelta: Int)
  {
    let count = max(1, monthCount)
    var monthIndex = (baseMonth - 1) + offset
    var yearDelta = 0
    while monthIndex < 0 {
      monthIndex += count
      yearDelta -= 1
    }
    while monthIndex >= count {
      monthIndex -= count
      yearDelta += 1
    }
    return (monthIndex + 1, yearDelta)
  }

  /// Reverses each row of `items` in place for right-to-left layout, preserving row order.
  ///
  /// SwiftUI's `LazyVGrid` fills left-to-right; mirroring whole rows produces correct RTL day
  /// placement without flipping the grid's coordinate space.
  static func rowReversed<T>(_ items: [T], rowWidth: Int = columnCount) -> [T] {
    guard rowWidth > 0 else { return items }
    var reordered: [T] = []
    reordered.reserveCapacity(items.count)
    var index = 0
    while index < items.count {
      let endIndex = min(index + rowWidth, items.count)
      reordered.append(contentsOf: items[index..<endIndex].reversed())
      index += rowWidth
    }
    return reordered
  }
}
