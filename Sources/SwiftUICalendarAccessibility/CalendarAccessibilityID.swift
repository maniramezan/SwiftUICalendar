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

    // MARK: - Header controls

    public static let monthButton = "calendar-month-button"
    public static let previousMonthButton = "calendar-previous-month-button"
    public static let nextMonthButton = "calendar-next-month-button"
    public static let yearButton = "calendar-year-button"
    public static let previousYearButton = "calendar-previous-year-button"
    public static let nextYearButton = "calendar-next-year-button"
    public static let todayButton = "calendar-today-button"

    // MARK: - Year picker

    public static let yearOptionPrefix = "calendar-year-option-"

    public static func yearOption(year: Int) -> String {
        "\(yearOptionPrefix)\(year)"
    }

    public static let yearPagePreviousButton = "calendar-year-page-previous-button"
    public static let yearPageNextButton = "calendar-year-page-next-button"
    public static let yearPickerDoneButton = "calendar-year-picker-done-button"

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
