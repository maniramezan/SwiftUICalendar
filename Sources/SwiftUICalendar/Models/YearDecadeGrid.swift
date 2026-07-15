import Foundation

/// Pure layout math for the custom 3x3 year-selection grid.
///
/// Each page shows nine consecutive years (a 3x3 grid). Pages are not aligned to calendar
/// decades (e.g. 2020-2029) because nine cells cannot hold a ten-year decade; instead each page
/// is labeled with the literal range of years it displays (e.g. "2025-2033").
enum YearDecadeGrid {
  /// The number of years displayed per page (a 3x3 grid).
  static let pageSize = 9

  /// Returns the first year of the page that contains `year`.
  static func pageStart(for year: Int) -> Int {
    let flooredIndex = Int(floor(Double(year) / Double(pageSize)))
    return flooredIndex * pageSize
  }

  /// Returns the nine consecutive years belonging to the page that starts at `pageStart`.
  static func years(pageStart: Int) -> [Int] {
    Array(pageStart..<(pageStart + pageSize))
  }

  /// Clamps `pageStart` so it never precedes the page containing `minYear` or follows the page
  /// containing `maxYear`.
  static func clampedPageStart(_ pageStart: Int, minYear: Int, maxYear: Int) -> Int {
    let minPageStart = Self.pageStart(for: minYear)
    let maxPageStart = Self.pageStart(for: maxYear)
    return min(max(pageStart, minPageStart), maxPageStart)
  }

  /// Returns the page start after paging forward or backward by one page, clamped to bounds.
  static func adjacentPageStart(
    from pageStart: Int,
    by direction: Int,
    minYear: Int,
    maxYear: Int
  ) -> Int {
    clampedPageStart(pageStart + (direction * pageSize), minYear: minYear, maxYear: maxYear)
  }

  /// Whether paging backward from `pageStart` would move within the supported range.
  static func canPageBackward(from pageStart: Int, minYear: Int) -> Bool {
    pageStart > Self.pageStart(for: minYear)
  }

  /// Whether paging forward from `pageStart` would move within the supported range.
  static func canPageForward(from pageStart: Int, maxYear: Int) -> Bool {
    pageStart < Self.pageStart(for: maxYear)
  }

  /// A human-readable label describing the range of years on a page, e.g. "2025-2033".
  static func rangeLabel(pageStart: Int) -> String {
    "\(pageStart)-\(pageStart + pageSize - 1)"
  }
}
