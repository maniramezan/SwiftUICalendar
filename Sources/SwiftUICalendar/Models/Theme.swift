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
  /// Controls how horizontal calendars determine their height.
  public var horizontalHeightMode: HorizontalHeightMode = .sixRows
  /// Configuration for the year-selection control in the header.
  public var yearSelection = YearSelection()
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

  /// Configuration for the year-selection control shown in the header.
  ///
  /// Use ``style`` to choose between the built-in wheel sheet, a dropdown menu, or a custom
  /// decade-grid popover. Use ``minYear``/``maxYear`` to restrict which years the picker offers
  /// as choices; this only affects the picker's own choices, not overall calendar navigation
  /// bounds.
  ///
  /// ```swift
  /// let theme = Theme()
  /// theme.yearSelection.style = .custom
  /// theme.yearSelection.minYear = 2000
  /// theme.yearSelection.maxYear = 2050
  /// ```
  public struct YearSelection {
    /// The presentation style for the year-selection control.
    public enum Style {
      /// A sheet containing a wheel-style picker, regardless of the number of years offered.
      case wheel
      /// A dropdown menu listing every selectable year.
      case menu
      /// A popover showing a 3x3 grid of years, paged nine years at a time.
      case custom
    }

    /// The presentation style to use. Defaults to ``Style/wheel``, matching prior behavior.
    public var style: Style = .wheel
    /// Restricts the earliest year offered by the picker. `nil` uses the calendar's own minimum.
    public var minYear: Int?
    /// Restricts the latest year offered by the picker. `nil` uses the calendar's own maximum.
    public var maxYear: Int?

    /// Creates a year-selection configuration with default values.
    public init() {}
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
    /// Use ``useSquareDualCalendarDayView(secondaryLabel:)`` to select the built-in square style.
    /// Assign a closure when your app provides a custom ``CalendarDayView`` implementation.
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
    switch calendar.identifier {
    case .buddhist:
      formatter.locale = Locale(identifier: "th_TH@calendar=buddhist")
    case .hebrew:
      formatter.locale = Locale(identifier: "he_IL@calendar=hebrew")
    case .islamic:
      formatter.locale = Locale(identifier: "ar_SA@calendar=islamic")
        .withNumberingSystemIdentifier(.arab)
    case .islamicCivil:
      formatter.locale = Locale(identifier: "ar_SA@calendar=islamic-civil")
        .withNumberingSystemIdentifier(.arab)
    case .islamicTabular:
      formatter.locale = Locale(identifier: "ar_SA@calendar=islamic-tbla")
        .withNumberingSystemIdentifier(.arab)
    case .islamicUmmAlQura:
      formatter.locale = Locale(identifier: "ar_SA@calendar=islamic-umalqura")
        .withNumberingSystemIdentifier(.arab)
    case .japanese:
      formatter.locale = Locale(identifier: "ja_JP@calendar=japanese")
    case .persian:
      formatter.locale = Locale(identifier: "fa_IR@calendar=persian")
        .withNumberingSystemIdentifier(.arabExtended)
    default:
      formatter.locale = Locale(calendarIdentifier: calendar.identifier)
    }
    formatter.setLocalizedDateFormatFromTemplate("dd")
    return formatter.string(from: date)
  }
}
