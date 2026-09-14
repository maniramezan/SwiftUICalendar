import Foundation

/// Builders for ``CalendarState/dateRange``.
///
/// Any `ClosedRange<Date>` works as a date range; these cover the common shapes. Open ends are
/// bounded by the calendar's supported interval (January 1 1900 through December 31 2100 in the
/// Gregorian calendar), and availability is judged per day.
extension ClosedRange where Bound == Date {
    /// Allows every date on or after `date` — for example, only future dates.
    ///
    /// The whole day containing `date` stays available, so `.onOrAfter(.now)` still allows today.
    ///
    /// ```swift
    /// let state = try CalendarState(calendarIdentifier: .gregorian, dateRange: .onOrAfter(.now))
    /// ```
    public static func onOrAfter(_ date: Date) -> ClosedRange<Date> {
        date...Date.distantFuture
    }

    /// Allows every date on or before `date` — for example, only past dates.
    ///
    /// The whole day containing `date` stays available, so `.onOrBefore(.now)` still allows today.
    ///
    /// ```swift
    /// let model = CalendarViewModel(calendarIdentifier: .gregorian, dateRange: .onOrBefore(.now))
    /// ```
    public static func onOrBefore(_ date: Date) -> ClosedRange<Date> {
        Date.distantPast...date
    }

    /// Allows whole years as numbered in `calendar`, from the first instant of
    /// `years.lowerBound` through the last instant of `years.upperBound`.
    ///
    /// Pass a calendar with the same identifier and time zone as the state, so year boundaries
    /// match the days the calendar displays. Years resolve the way `Calendar.date(from:)` resolves
    /// components without an era; for era-based calendars such as `.japanese`, build the range from
    /// explicit dates instead.
    ///
    /// ```swift
    /// let persian = Calendar(identifier: .persian)
    /// let state = try CalendarState(
    ///     calendar: persian, currentDate: .now, dateRange: .years(1400...1410, in: persian))
    /// ```
    ///
    /// - Throws: `Calendar.CalendarError.cannotCalculateDate` when either year can't be resolved in
    ///   `calendar`.
    public static func years(_ years: ClosedRange<Int>, in calendar: Calendar) throws
        -> ClosedRange<Date>
    {
        guard
            let firstDay = calendar.date(
                from: DateComponents(year: years.lowerBound, month: 1, day: 1)),
            let lastDay = calendar.date(
                from: DateComponents(year: years.upperBound, month: 1, day: 1)),
            let first = calendar.dateInterval(of: .year, for: firstDay),
            let last = calendar.dateInterval(of: .year, for: lastDay),
            first.start < last.end
        else {
            throw Calendar.CalendarError.cannotCalculateDate
        }
        return first.start...last.end.previousInstant
    }
}
