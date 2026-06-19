import SwiftUI

/// Visual configuration for the calendar, including day rendering and layout behavior.
///
/// Create a theme when you want to change scrolling, selection colors, or the view used for
/// each day cell. `Theme` is observable so SwiftUI refreshes the calendar when you mutate it.
///
/// ```swift
/// let theme = Theme()
/// theme.scrollMode = .horizontal
/// theme.horizontalHeightMode = .hugContent
/// theme.day.selectedBackgroundColor = .indigo
/// theme.day.useSquareDualCalendarDayView(secondaryLabel: .persian)
///
/// CalendarView(model: viewModel, theme: theme)
/// ```
@MainActor
@Observable final public class Theme {
  /// Configuration for day view rendering.
  public var day = Day()
  /// Controls whether the calendar scrolls vertically, horizontally, or stays fixed.
  public var scrollMode: ScrollMode = .none
  /// Controls how horizontal (paging) calendars determine their height.
  ///
  /// Use ``HorizontalHeightMode/sixRows`` (the default) for a fixed height that never shifts as
  /// the user pages between months, or ``HorizontalHeightMode/hugContent`` to size to the tallest
  /// of the visible months. This only affects `ScrollMode.horizontal`.
  public var horizontalHeightMode: HorizontalHeightMode = .sixRows
  /// A fresh default theme configuration.
  ///
  /// This property returns a new theme each time so local mutations do not leak into other
  /// calendars that also request default styling.
  ///
  /// ```swift
  /// let first = Theme.default
  /// first.scrollMode = .horizontal
  ///
  /// let second = Theme.default
  /// // second.scrollMode is still .none
  /// ```
  public static var `default`: Theme { Theme() }

  /// Creates a theme with default values.
  ///
  /// The default configuration renders a single, fixed month using circular day cells.
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
  ///
  /// Use this nested theme to customize day colors, alternate labels, or swap the built-in
  /// circular renderer for a custom `CalendarDayView`.
  ///
  /// ```swift
  /// let theme = Theme()
  /// theme.day.todayBorderColor = .orange
  /// theme.day.dayContent = { context in
  ///     MyDayCell(context: context)
  /// }
  /// ```
  @MainActor
  @Observable
  final public class Day {
    /// Provides the view used to render a day cell.
    ///
    /// The closure receives a `CalendarDayContext` for each visible date. Return a view that
    /// calls `context.onSelect(context.date)` when the user selects that date.
    ///
    /// ```swift
    /// theme.day.dayContent = { context in
    ///     SquareDualCalendarDayView(context: context)
    /// }
    /// ```
    public var dayContent:
      (
        CalendarDayContext
      ) -> any CalendarDayView = { context in
        CircleDayView(context: context)
      }

    /// Mode for displaying secondary labels on day views that support them.
    public var secondaryLabelMode: SecondaryLabelMode = .none

    /// Background color for selected days.
    public var selectedBackgroundColor: Color = .blue
    /// Border color for the current day.
    public var todayBorderColor: Color = .pink
    /// Border width for the current day.
    public var todayBorderColorWidth: CGFloat = 1
    /// Background color for the current day.
    public var todayBackgroundColor: Color = .clear
    /// Border color for days outside the currently displayed month.
    public var emptyDayBorderColor: Color = .clear
    /// Border width for days outside the currently displayed month.
    public var emptyDayBorderColorWidth: CGFloat = 0
    /// Background color for days outside the currently displayed month.
    public var emptyDayBackgroundColor: Color = .clear

    /// Creates a day theme with default values.
    ///
    /// The default day theme uses circular cells, blue selection fill, and a pink outline for today.
    public init() {}
  }
}

extension Theme.Day {
  /// Mode for configuring secondary labels in day views that support them.
  ///
  /// Use a built-in calendar case for common alternate labels, `.calendar(_:)` for any
  /// `Calendar.Identifier`, or `.custom(_:)` when your app owns the formatting.
  ///
  /// ```swift
  /// theme.day.useSquareDualCalendarDayView(secondaryLabel: .persian)
  /// theme.day.secondaryLabelMode = .calendar(.hebrew)
  /// theme.day.secondaryLabelMode = .custom { date in
  ///     alternateFormatter.string(from: date)
  /// }
  /// ```
  public enum SecondaryLabelMode {
    /// No secondary label is displayed.
    case none

    /// Displays the day number from another calendar system.
    case calendar(Calendar.Identifier)

    /// Displays a custom secondary label generated by the supplied closure.
    case custom((Date) -> String?)

    /// Displays the Persian calendar day number.
    case persian

    /// Displays the Hebrew calendar day number.
    case hebrew

    /// Displays the Islamic calendar day number.
    case islamic

    /// Displays the Japanese calendar day number.
    case japanese
  }

  /// Switches the day view to the square dual calendar style.
  /// - Parameter secondaryLabel: Optional secondary label configuration to apply.
  ///
  /// ```swift
  /// let theme = Theme()
  /// theme.day.useSquareDualCalendarDayView(secondaryLabel: .persian)
  /// CalendarView(model: viewModel, theme: theme)
  /// ```
  public func useSquareDualCalendarDayView(secondaryLabel: SecondaryLabelMode? = nil) {
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
