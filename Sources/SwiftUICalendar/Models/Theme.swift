import SwiftUI

/// Visual configuration for the calendar, including day rendering and layout behavior.
@MainActor
@Observable final public class Theme {
    /// Configuration for day view rendering.
    public var day = Day()
    /// Controls whether the calendar scrolls vertically, horizontally, or stays fixed.
    public var scrollMode: ScrollMode = .none
    /// Controls how horizontal calendars determine their height.
    public var horizontalHeightMode: HorizontalHeightMode = .sixRows
    /// The default theme configuration.
    public static let `default` = Theme()

    /// Creates a theme with default values.
    public init() {}
}

extension Theme {
    /// Scrolling behavior for the calendar body.
    public enum ScrollMode {
        /// No scrolling; renders a single month.
        case none
        /// Vertical scrolling through months.
        case vertical
        /// Horizontal paging through months.
        case horizontal
    }

    /// Height strategy for horizontally scrolling calendars.
    public enum HorizontalHeightMode {
        /// Size to the content height.
        case hugContent
        /// Use a fixed six-row month grid height.
        case sixRows
    }

    /// Day-level styling and behavior configuration.
    @MainActor
    @Observable
    final public class Day {
        /// Provides the view used to render a day cell.
        public var dayContent: (
            CalendarDayContext
        ) -> any CalendarDayView = { context in
            CircleDayView(context: context)
        }

        /// Deprecated: Use `secondaryLabelMode` for type-safe configuration.
        @available(*, deprecated, message: "Use secondaryLabelMode for type-safe configuration")
        public var secondaryLabelProvider: ((Date) -> String?)? = nil {
            didSet {
                guard let provider = secondaryLabelProvider else {
                    if case .custom = secondaryLabelMode {
                        secondaryLabelMode = .none
                    }
                    return
                }
                secondaryLabelMode = .custom(provider)
            }
        }

        /// Mode for displaying secondary labels on day views that support them
        public var secondaryLabelMode: SecondaryLabelMode = .none

        /// Background color for selected days.
        public var selectedBackgroundColor: Color = .blue
        /// Border color for the current day.
        public var todayBorderColor: Color = .pink
        /// Border width for the current day.
        public var todayBorderColorWidth: CGFloat = 1
        /// Background color for the current day.
        public var todayBackgroundColor: Color = .clear
        /// Border color for days outside the current month.
        public var emptyDayBorderColor: Color = .clear
        /// Border width for days outside the current month.
        public var emptyDayBorderColorWidth: CGFloat = 0
        /// Background color for days outside the current month.
        public var emptyDayBackgroundColor: Color = .clear

        /// Creates a day theme with default values.
        public init() {}
    }
}

public extension Theme.Day {
    /// Mode for configuring secondary labels in day views that support them
    enum SecondaryLabelMode {
        /// No secondary label displayed
        case none

        /// Display day number from a different calendar system
        case calendar(Calendar.Identifier)

        /// Custom secondary label using a closure
        case custom((Date) -> String?)

        /// Convenience: Display Persian calendar day
        case persian

        /// Convenience: Display Hebrew calendar day
        case hebrew

        /// Convenience: Display Islamic calendar day
        case islamic

        /// Convenience: Display Japanese calendar day
        case japanese
    }

    /// Switches the day view to the square dual calendar style.
    /// - Parameter secondaryLabel: Optional secondary label configuration to apply.
    func useSquareDualCalendarDayView(secondaryLabel: SecondaryLabelMode? = nil) {
        dayContent = { context in
            SquareDualCalendarDayView(context: context)
        }
        if let mode = secondaryLabel {
            secondaryLabelMode = mode
        }
    }
}

extension Theme.Day.SecondaryLabelMode {
    /// Resolves this mode into a secondary label string for the given date
    func label(for date: Date) -> String? {
        switch self {
        case .none:
            return nil

        case .calendar(let identifier):
            return Self.formatDay(date, calendar: Calendar(identifier: identifier))

        case .custom(let provider):
            return provider(date)

        case .persian:
            return Self.formatDay(date, calendar: Calendar(identifier: .persian))

        case .hebrew:
            return Self.formatDay(date, calendar: Calendar(identifier: .hebrew))

        case .islamic:
            return Self.formatDay(date, calendar: Calendar(identifier: .islamic))

        case .japanese:
            return Self.formatDay(date, calendar: Calendar(identifier: .japanese))
        }
    }

    /// Formats the day number from a date using the specified calendar
    private static func formatDay(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        let locale = Locale(calendarIdentifier: calendar.identifier)
        switch calendar.identifier {
        case .persian:
            formatter.locale = locale.withNumberingSystemIdentifier(.arabExtended)
        case .islamic, .islamicCivil, .islamicUmmAlQura, .islamicTabular:
            formatter.locale = locale.withNumberingSystemIdentifier(.arab)
        default:
            formatter.locale = locale
        }
        formatter.setLocalizedDateFormatFromTemplate("dd")
        return formatter.string(from: date)
    }
}
