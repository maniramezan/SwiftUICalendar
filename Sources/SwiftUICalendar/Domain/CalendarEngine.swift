import Foundation
import SwiftCommons

/// Calendar arithmetic uses absolute month intervals so eras and leap months remain distinct.
struct CalendarEngine: Sendable {
  let calendar: Calendar

  private var arithmetic: CalendarArithmetic { CalendarArithmetic(calendar: calendar) }

  /// The navigable interval, January 1 1900 through December 31 2100 in the Gregorian calendar.
  ///
  /// Resolved once per time zone rather than per access. Every offset, containment, and navigation
  /// check reads this, so the vertical scroll hits it several times per realized month — building a
  /// Gregorian `Calendar` and two dates each time showed up as scroll jank.
  var supportedDates: Range<Date> {
    Self.supportedDates(in: calendar.timeZone)
  }

  private static let supportedDatesLock = NSLock()
  nonisolated(unsafe) private static var supportedDatesByTimeZone: [TimeZone: Range<Date>] = [:]

  private static func supportedDates(in timeZone: TimeZone) -> Range<Date> {
    supportedDatesLock.lock()
    defer { supportedDatesLock.unlock() }
    if let cached = supportedDatesByTimeZone[timeZone] { return cached }

    var gregorian = Calendar(identifier: .gregorian)
    gregorian.timeZone = timeZone
    let start = gregorian.date(from: DateComponents(year: 1900, month: 1, day: 1))
    let end = gregorian.date(from: DateComponents(year: 2101, month: 1, day: 1))
    // These components are always resolvable in the Gregorian calendar; the fallbacks exist only so
    // the range stays well formed without a force unwrap.
    let range = (start ?? .distantPast)..<(end ?? .distantFuture)
    supportedDatesByTimeZone[timeZone] = range
    return range
  }

  func contains(_ date: Date) -> Bool {
    supportedDates.contains(date)
  }

  func month(containing date: Date) -> MonthIdentifier {
    arithmetic.month(containing: date)
  }

  func start(of month: MonthIdentifier) -> Date? {
    arithmetic.start(of: month)
  }

  func interval(of month: MonthIdentifier) -> DateInterval? {
    arithmetic.interval(of: month)
  }

  func intersectsSupportedDates(_ interval: DateInterval) -> Bool {
    interval.start < supportedDates.upperBound && interval.end > supportedDates.lowerBound
  }

  func month(offset: Int, from month: MonthIdentifier) -> MonthIdentifier? {
    guard let resolved = arithmetic.month(offset: offset, from: month),
      let interval = arithmetic.interval(of: resolved), intersectsSupportedDates(interval)
    else { return nil }
    return resolved
  }

  func date(day: Int, in month: MonthIdentifier) -> Date? {
    arithmetic.date(day: day, in: month)
  }

  /// Clamps `preferredDay` to the day-of-month numbers actually present in `month`, then resolves
  /// the corresponding date.
  ///
  /// A month whose era began mid-month (see `CalendarArithmetic`) covers only part of its
  /// underlying Gregorian month — e.g. Heisei's January 1989 runs the 8th through the 31st, not
  /// the 1st. `calendar.range(of: .day, in: .month, for:)` reports the full Gregorian month's day
  /// range regardless, so clamping against it can still pass an out-of-range day (day 1, in that
  /// example) through to `date(day:in:)`, which then legitimately returns nil. Reading the day
  /// number at the interval's own start and last moment gives the range this specific month
  /// identity actually spans.
  func navigationDate(in month: MonthIdentifier, preferredDay: Int) -> Date? {
    guard let interval = interval(of: month), intersectsSupportedDates(interval),
      let lastMoment = calendar.date(byAdding: .second, value: -1, to: interval.end)
    else { return nil }
    let lowerDay = calendar.component(.day, from: interval.start)
    let upperDay = calendar.component(.day, from: lastMoment)
    guard let date = date(day: min(max(preferredDay, lowerDay), upperDay), in: month)
    else { return nil }
    return min(
      max(date, supportedDates.lowerBound), supportedDates.upperBound.addingTimeInterval(-1))
  }

  /// Numeric year pickers address the visible era; relative navigation can cross eras.
  func yearBounds(containing date: Date) -> ClosedRange<Int> {
    let era = calendar.dateInterval(of: .era, for: date)
    let start = max(era?.start ?? supportedDates.lowerBound, supportedDates.lowerBound)
    let end = min(era?.end ?? supportedDates.upperBound, supportedDates.upperBound)
    let lower = calendar.component(.year, from: start)
    let upper = calendar.component(.year, from: end.addingTimeInterval(-1))
    return min(lower, upper)...max(lower, upper)
  }

  func months(in year: Int, relativeTo reference: Date) -> [MonthIdentifier] {
    guard yearBounds(containing: reference).contains(year) else { return [] }
    return arithmetic.months(in: year, relativeTo: reference).filter { month in
      guard let interval = arithmetic.interval(of: month) else { return false }
      return intersectsSupportedDates(interval)
    }
  }
}
