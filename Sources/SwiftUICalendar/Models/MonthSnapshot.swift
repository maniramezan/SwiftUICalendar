import Foundation

struct MonthSnapshot: Identifiable, Equatable, Sendable {
    struct Day: Identifiable, Equatable, Sendable {
        let id: String
        let date: Date?
        /// `date` snapped to the start of its day. Every cross-day comparison in the package uses
        /// this, never `date`: `date` carries whatever time-of-day the month arithmetic produced, so
        /// comparing it to a normalized date with `==` can silently never match.
        let dayStart: Date?
        let day: Int
        let dayLabel: String
        let month: Int
        let year: Int
        let isInDisplayedMonth: Bool
        let isToday: Bool
        let isSelected: Bool
        /// Whether the day overlaps ``CalendarState/dateRange``. Out-of-range days render disabled.
        let isEnabled: Bool
    }

    let id: MonthIdentifier
    let title: String
    let days: [Day]

    var rowCount: Int {
        max(1, (days.count + 6) / 7)
    }
}

extension MonthSnapshot.Day {
    /// Scroll identity for the cell showing `dayStart`.
    ///
    /// `ScrollViewProxy.scrollTo(_:)` can only reach a cell through the exact id the grid tagged it
    /// with, so anything that wants to scroll a date into view resolves it here rather than
    /// rebuilding the string. Always pass a start-of-day date.
    static func identity(for dayStart: Date) -> String {
        "day-\(dayStart.timeIntervalSinceReferenceDate)"
    }
}
