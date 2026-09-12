import Foundation

/// Calendar arithmetic uses absolute month intervals so eras and leap months remain distinct.
struct CalendarEngine: Sendable {
  let calendar: Calendar

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
    let start = calendar.dateInterval(of: .month, for: date)?.start ?? date
    let components = calendar.dateComponents([.era, .year, .month], from: start)
    return MonthIdentifier(
      month: components.month ?? 1, year: components.year ?? 1,
      calendarIdentifier: calendar.identifier, era: components.era ?? 1,
      isLeapMonth: components.isLeapMonth ?? false
    )
  }

  func start(of month: MonthIdentifier) -> Date? {
    guard month.calendarIdentifier == calendar.identifier else { return nil }
    var components = DateComponents(
      era: month.era, year: month.year, month: month.month, day: 1)
    components.isLeapMonth = month.isLeapMonth
    guard let date = calendar.date(from: components), self.month(containing: date) == month else {
      return nil
    }
    return calendar.dateInterval(of: .month, for: date)?.start
  }

  func interval(of month: MonthIdentifier) -> DateInterval? {
    guard let start = start(of: month) else { return nil }
    return calendar.dateInterval(of: .month, for: start)
  }

  func intersectsSupportedDates(_ interval: DateInterval) -> Bool {
    interval.start < supportedDates.upperBound && interval.end > supportedDates.lowerBound
  }

  func month(offset: Int, from month: MonthIdentifier) -> MonthIdentifier? {
    guard let start = start(of: month),
      let date = calendar.date(byAdding: .month, value: offset, to: start),
      let interval = calendar.dateInterval(of: .month, for: date),
      intersectsSupportedDates(interval)
    else { return nil }
    return self.month(containing: date)
  }

  func date(day: Int, in month: MonthIdentifier) -> Date? {
    guard let start = start(of: month),
      let days = calendar.range(of: .day, in: .month, for: start), days.contains(day)
    else { return nil }
    return calendar.date(byAdding: .day, value: day - 1, to: start)
  }

  func navigationDate(in month: MonthIdentifier, preferredDay: Int) -> Date? {
    guard let interval = interval(of: month), intersectsSupportedDates(interval),
      let days = calendar.range(of: .day, in: .month, for: interval.start),
      let date = date(day: min(max(preferredDay, days.lowerBound), days.upperBound - 1), in: month)
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
    let era = calendar.component(.era, from: reference)
    guard let seed = calendar.date(from: DateComponents(era: era, year: year, month: 1, day: 1)),
      let yearInterval = calendar.dateInterval(of: .year, for: seed)
    else { return [] }
    let eraInterval = calendar.dateInterval(of: .era, for: reference)
    let start = max(yearInterval.start, eraInterval?.start ?? yearInterval.start)
    let end = min(yearInterval.end, eraInterval?.end ?? yearInterval.end)
    guard start < end, calendar.component(.year, from: start) == year else { return [] }
    var result: [MonthIdentifier] = []
    var cursor = start
    while cursor < end {
      guard let interval = calendar.dateInterval(of: .month, for: cursor), interval.end > cursor
      else {
        break
      }
      if intersectsSupportedDates(interval) {
        result.append(month(containing: cursor))
      }
      cursor = interval.end
    }
    return result
  }
}
