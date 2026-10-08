import Foundation

/// A day's role in a selected range, independent of its selected accessibility trait.
public enum CalendarRangePosition: String, Sendable, Equatable {
    case start
    case end
    case interior
    case startAndEnd
}

extension CalendarSelection {
    /// Normalizes range boundaries once for all cells in a rendered month.
    func rangePositionMatcher(in calendar: Calendar) -> (Date) -> CalendarRangePosition? {
        guard case .range(let start?, let end) = normalized(in: calendar) else {
            return { _ in nil }
        }
        return { dayStart in
            if dayStart == start {
                return end == start ? .startAndEnd : .start
            }
            guard let end else { return nil }
            if dayStart == end { return .end }
            return start < dayStart && dayStart < end ? .interior : nil
        }
    }
}
