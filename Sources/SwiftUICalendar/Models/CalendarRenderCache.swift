import Foundation
import OSLog
import SwiftCommons

/// Memoizes the `Calendar` and `DateFormatter` work that the scrolling calendar repeats every frame.
///
/// Resolving one month grid costs roughly six `Calendar` calls per day plus a `NumberFormatter`
/// lookup — around 300 operations for a six-row month. A vertically scrolling calendar keeps six to
/// eight months realized, and every model mutation re-evaluates all of their bodies, so an uncached
/// grid lands ~2,500 calendar operations inside a single frame and the scroll visibly stalls.
///
/// The cache is deliberately **not** owned by ``CalendarViewModel``. In the externally owned
/// (TCA) integration `CalendarView` builds a fresh rendering projection on every store mutation, so
/// an instance-scoped cache starts cold on every frame — precisely when the calendar is busiest.
/// Keying on the calendar/locale/time-zone signature instead makes the memoized work survive those
/// rebuilds while still isolating distinct calendar systems from one another.
///
/// Entries hold only calendar *geometry* — the dates, labels, and in-month flags of a month. `today`
/// and the current selection are applied on read (see ``CalendarViewModel/monthSnapshot(for:)``), so
/// tapping a day never invalidates a grid.
@MainActor
final class CalendarRenderCache {

  /// The process-wide cache. Shared so rendering projections rebuilt per frame stay warm.
  static let shared = CalendarRenderCache()

  /// Upper bound on retained month grids. Twelve years of scrollback at ~36KB per entry.
  private static let monthGeometryLimit = 144
  /// Upper bound on retained month-offset resolutions.
  private static let monthOffsetLimit = 4_096

  private let logger = Logger.swiftUICalendar(for: CalendarRenderCache.self)

  // MARK: - Stored entries

  /// A month grid stripped of everything that changes without the calendar changing.
  struct MonthGeometry: Equatable, Sendable {
    struct Day: Equatable, Sendable {
      let id: String
      let date: Date
      /// `date` snapped to the start of its day, precomputed so `isToday` and selection checks are
      /// plain `Date` comparisons rather than per-day `Calendar` work.
      let dayStart: Date
      let day: Int
      let dayLabel: String
      let month: Int
      let year: Int
      let isInDisplayedMonth: Bool
    }

    let days: [Day]
  }

  private struct MonthKey: Hashable {
    let signature: String
    let month: MonthIdentifier
  }

  private struct OffsetKey: Hashable {
    let signature: String
    let month: MonthIdentifier
    let offset: Int
  }

  private var monthGeometry: [MonthKey: MonthGeometry] = [:]
  private var monthGeometryOrder: [MonthKey] = []
  private var monthOffsets: [OffsetKey: MonthIdentifier?] = [:]
  private var monthOffsetOrder: [OffsetKey] = []
  private var formatters: [String: DateFormatter] = [:]

  // MARK: - Signature

  /// Identifies every input that changes a month's geometry.
  ///
  /// The time zone is part of the key because it moves the wall-clock instants the grid stores, and
  /// the locale is because it selects the numbering system used for day labels.
  static func signature(for calendar: Calendar) -> String {
    let locale = calendar.locale ?? Locale(calendarIdentifier: calendar.identifier)
    return "\(calendar.identifier)|\(locale.identifier)|\(calendar.timeZone.identifier)"
  }

  // MARK: - Month geometry

  /// Returns the cached geometry for `month`, resolving and storing it on a miss.
  ///
  /// - Returns: The month's geometry, or `nil` when the identifier does not resolve in `calendar`.
  func monthGeometry(
    for month: MonthIdentifier, calendar: Calendar, engine: CalendarEngine
  ) -> MonthGeometry? {
    let key = MonthKey(signature: Self.signature(for: calendar), month: month)
    if let cached = monthGeometry[key] {
      return cached
    }

    return CalendarSignpost.rendering.measure("resolveMonthGeometry") {
      guard let start = engine.start(of: month),
        let count = calendar.range(of: .day, in: .month, for: start)?.count
      else {
        logger.debug(
          "Month geometry unresolved: \(month.year, privacy: .public)-\(month.month, privacy: .public)"
        )
        return nil
      }

      let locale = calendar.locale ?? Locale(calendarIdentifier: calendar.identifier)
      let leading = calendar.component(.weekday, from: start) - 1
      let total = ((leading + count + 6) / 7) * 7
      let days = (0..<total).compactMap { index -> MonthGeometry.Day? in
        guard let date = calendar.date(byAdding: .day, value: index - leading, to: start) else {
          return nil
        }
        let day = calendar.component(.day, from: date)
        return MonthGeometry.Day(
          id: "day-\(date.timeIntervalSinceReferenceDate)",
          date: date,
          dayStart: calendar.startOfDay(for: date),
          day: day,
          dayLabel: NumberFormatter.formatDay(day, locale: locale),
          month: calendar.component(.month, from: date),
          year: calendar.component(.year, from: date),
          isInDisplayedMonth: index >= leading && index < leading + count)
      }

      let geometry = MonthGeometry(days: days)
      store(geometry, for: key)
      return geometry
    }
  }

  // MARK: - Month offsets

  /// Returns the month `offset` months from `month`, memoizing both hits and misses.
  ///
  /// The vertical calendar resolves one offset per realized row on every body pass, and each
  /// resolution costs six `Calendar` round trips. Memoizing turns that into a dictionary lookup.
  func month(
    offset: Int, from month: MonthIdentifier, calendar: Calendar, engine: CalendarEngine
  ) -> MonthIdentifier? {
    let key = OffsetKey(signature: Self.signature(for: calendar), month: month, offset: offset)
    // A cached miss is stored as `.some(nil)`; only an absent key is a cache miss.
    if let cached = monthOffsets[key] {
      return cached
    }

    let resolved = CalendarSignpost.rendering.measure("resolveMonthOffset") {
      engine.month(offset: offset, from: month)
    }
    store(resolved, for: key)
    return resolved
  }

  // MARK: - Formatters

  /// Returns a `DateFormatter` configured for `calendar` and `format`, reusing it across calls.
  ///
  /// `DateFormatter` construction dominates month-title resolution. Sharing instances by signature
  /// keeps title lookups cheap even when the owning view model is rebuilt every frame.
  func formatter(format: String, calendar: Calendar) -> DateFormatter {
    let key = "\(Self.signature(for: calendar))|\(format)"
    if let cached = formatters[key] {
      return cached
    }

    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = calendar.locale ?? Locale(calendarIdentifier: calendar.identifier)
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = format
    formatters[key] = formatter
    logger.debug("Created date formatter for \(key, privacy: .public)")
    return formatter
  }

  // MARK: - Diagnostics

  /// Number of retained month grids. Exposed for tests and log instrumentation.
  var monthGeometryCount: Int { monthGeometry.count }
  /// Number of retained month-offset resolutions. Exposed for tests and log instrumentation.
  var monthOffsetCount: Int { monthOffsets.count }

  /// Drops every entry. Used by tests; also safe to call to reclaim memory under pressure.
  func removeAll() {
    monthGeometry.removeAll(keepingCapacity: true)
    monthGeometryOrder.removeAll(keepingCapacity: true)
    monthOffsets.removeAll(keepingCapacity: true)
    monthOffsetOrder.removeAll(keepingCapacity: true)
    formatters.removeAll(keepingCapacity: true)
    logger.debug("Render cache cleared")
  }

  // MARK: - Eviction

  private func store(_ geometry: MonthGeometry, for key: MonthKey) {
    monthGeometry[key] = geometry
    monthGeometryOrder.append(key)
    evictOldest(
      from: &monthGeometry, order: &monthGeometryOrder, limit: Self.monthGeometryLimit,
      label: "month geometry")
  }

  private func store(_ identifier: MonthIdentifier?, for key: OffsetKey) {
    monthOffsets[key] = .some(identifier)
    monthOffsetOrder.append(key)
    evictOldest(
      from: &monthOffsets, order: &monthOffsetOrder, limit: Self.monthOffsetLimit,
      label: "month offsets")
  }

  /// Trims the oldest entries once `storage` exceeds `limit`, in insertion order.
  private func evictOldest<Key: Hashable, Value>(
    from storage: inout [Key: Value], order: inout [Key], limit: Int, label: StaticString
  ) {
    guard storage.count > limit else { return }
    var index = 0
    while storage.count > limit, index < order.count {
      storage.removeValue(forKey: order[index])
      index += 1
    }
    order.removeFirst(index)
    logger.debug("Evicted \(index, privacy: .public) \(label, privacy: .public) cache entries")
  }
}
