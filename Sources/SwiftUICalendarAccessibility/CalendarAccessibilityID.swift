/// Stable identifiers shared by calendar views and UI automation.
public enum CalendarAccessibilityID {
    // MARK: - Days

    public static let dayPrefix = "calendar-day-"

    public static func dayYearPrefix(year: Int) -> String {
        "\(dayPrefix)\(year)-"
    }

    public static func dayMonthPrefix(year: Int, month: Int) -> String {
        "\(dayYearPrefix(year: year))\(month)-"
    }

    public static func day(year: Int, month: Int, day: Int) -> String {
        "\(dayMonthPrefix(year: year, month: month))\(day)"
    }

    // MARK: - Month headers

    public static let verticalMonthHeaderPrefix = "vertical-month-header-"

    public static func verticalMonthHeader(year: Int, month: Int) -> String {
        "\(verticalMonthHeaderPrefix)\(year)-\(month)"
    }

    /// Reads a month header identifier without requiring clients to know its string layout.
    public static func parseVerticalMonthHeader(_ identifier: String) -> (year: Int, month: Int)? {
        guard identifier.hasPrefix(verticalMonthHeaderPrefix) else { return nil }
        let parts = identifier.dropFirst(verticalMonthHeaderPrefix.count)
            .split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2, let year = Int(parts[0]), let month = Int(parts[1]),
            year > 0, (1...13).contains(month)
        else { return nil }
        return (year, month)
    }
}
