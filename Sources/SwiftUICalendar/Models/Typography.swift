import SwiftUI

// MARK: - Day View Typography

/// Typography configuration for a specific day view type.
///
/// Each day view type can have its own font configuration for primary and secondary labels.
/// Register values with `Typography.setDayViewTypography(_:for:)` and retrieve them from custom
/// day views with `Typography.dayViewTypography(for:)`.
///
/// ```swift
/// let typography = Typography.default
/// typography.setDayViewTypography(
///     DayViewTypography(primaryFont: .headline, secondaryFont: .caption),
///     for: "eventDay"
/// )
/// ```
public struct DayViewTypography: Sendable {
  /// Font used for the primary day number.
  public var primaryFont: Font

  /// Font used for secondary labels (e.g., alternate calendar day).
  public var secondaryFont: Font

  /// Creates typography for a day view type.
  ///
  /// - Parameters:
  ///   - primaryFont: Font for the main day label.
  ///   - secondaryFont: Font for the secondary label.
  public init(primaryFont: Font, secondaryFont: Font) {
    self.primaryFont = primaryFont
    self.secondaryFont = secondaryFont
  }
}

/// Known day view type identifiers.
///
/// Use these constants when registering or retrieving typography for built-in day views.
/// Custom day views can use any unique string identifier.
public enum DayViewType {
  /// Identifier for the circular day view.
  public static let circle = "circle"
  /// Identifier for the square dual-calendar day view.
  public static let squareDual = "squareDual"
}

// MARK: - Typography

/// A container for semantic typography used by the calendar UI, with sensible
/// defaults per platform and optional text scaling behavior for tight layouts.
///
/// Use this class to standardize fonts across calendar components such as the
/// month header, weekday headers, and individual day cells.
///
/// ```swift
/// let typography = Typography(
///     headerFont: .title2.weight(.semibold),
///     weekdayHeaderFont: .caption,
///     dayFont: .body,
///     minScaleFactor: 0.8
/// )
/// CalendarView(model: viewModel, typography: typography)
/// ```
@MainActor
@Observable
public final class Typography {

  // MARK: - Semantic fonts

  /// Font used for the primary month or section header in the calendar.
  public var headerFont: Font

  /// Font used for month titles in vertically scrolling calendars.
  public var monthHeaderFont: Font

  /// Font used for year labels in vertically scrolling calendars.
  public var monthYearFont: Font

  /// Font used for the weekday header labels (e.g., "Mon", "Tue").
  public var weekdayHeaderFont: Font

  /// Font used for individual day numbers within the calendar grid.
  /// This serves as the default fallback for day views without specific typography.
  public var dayFont: Font

  // MARK: - Day View Typography Registry

  /// Registry of typography configurations for specific day view types.
  private var dayViewTypographyRegistry: [String: DayViewTypography] = [:]

  // MARK: - Scaling behavior

  /// Whether text is allowed to scale down to fit in tighter layouts.
  ///
  /// When `true`, views may apply a minimum scale factor so text can shrink
  /// slightly to avoid truncation on compact devices or when space is limited.
  public var allowsScaling: Bool

  /// The minimum scale factor to apply when `allowsScaling` is enabled.
  ///
  /// A value like `0.85` allows text to shrink to 85% of its original size.
  /// Set to `nil` to avoid applying a minimum scale factor.
  public var minScaleFactor: CGFloat?

  // MARK: - Initialization

  /// Creates a new typography configuration.
  ///
  /// Pass semantic fonts for each major calendar region. If month-specific fonts are omitted,
  /// the initializer uses `headerFont` for month and year headers.
  ///
  /// - Parameters:
  ///   - headerFont: Font for the primary calendar header (e.g., month title).
  ///   - monthHeaderFont: Font for month titles in vertical scrolling mode.
  ///   - monthYearFont: Font for year labels in vertical scrolling mode.
  ///   - weekdayHeaderFont: Font for weekday header labels.
  ///   - dayFont: Font for day numbers in the calendar grid.
  ///   - allowsScaling: Enables optional text downscaling for tight layouts. Defaults to `true`.
  ///   - minScaleFactor: Minimum scale factor to use when scaling is allowed. Defaults to `nil`.
  public init(
    headerFont: Font,
    monthHeaderFont: Font? = nil,
    monthYearFont: Font? = nil,
    weekdayHeaderFont: Font,
    dayFont: Font,
    allowsScaling: Bool = true,
    minScaleFactor: CGFloat? = nil
  ) {
    self.headerFont = headerFont
    self.monthHeaderFont = monthHeaderFont ?? headerFont
    self.monthYearFont = monthYearFont ?? headerFont
    self.weekdayHeaderFont = weekdayHeaderFont
    self.dayFont = dayFont
    self.allowsScaling = allowsScaling
    self.minScaleFactor = minScaleFactor
  }

  // MARK: - Day View Typography Access

  /// Returns the typography configuration for a specific day view type.
  ///
  /// If no specific typography is registered for the given type, returns a default
  /// configuration using `dayFont` for both primary and secondary fonts.
  ///
  /// - Parameter type: The day view type identifier (e.g., `DayViewType.circle`).
  /// - Returns: The typography configuration for the specified day view type.
  ///
  /// ```swift
  /// let dayTypography = typography.dayViewTypography(for: DayViewType.squareDual)
  /// ```
  public func dayViewTypography(for type: String) -> DayViewTypography {
    dayViewTypographyRegistry[type]
      ?? DayViewTypography(
        primaryFont: dayFont,
        secondaryFont: weekdayHeaderFont
      )
  }

  /// Registers a typography configuration for a specific day view type.
  ///
  /// - Parameters:
  ///   - typography: The typography configuration to register.
  ///   - type: The day view type identifier.
  ///
  /// ```swift
  /// typography.setDayViewTypography(
  ///     DayViewTypography(primaryFont: .headline, secondaryFont: .caption2),
  ///     for: DayViewType.squareDual
  /// )
  /// ```
  public func setDayViewTypography(_ typography: DayViewTypography, for type: String) {
    dayViewTypographyRegistry[type] = typography
  }

  /// A platform-aware default typography configuration.
  ///
  /// - On macOS: uses slightly larger, desktop-friendly fonts with no minimum scale factor.
  /// - On iOS and related platforms: uses tighter fonts and permits slight downscaling.
  public static var `default`: Typography {
    #if os(macOS)
      makeDefaultMacOS()
    #else
      makeDefaultiOS()
    #endif
  }

  // MARK: - Defaults

  /// Default configuration for macOS.
  private static func makeDefaultMacOS() -> Typography {
    let typography = Typography(
      headerFont: .title2.bold(),
      monthHeaderFont: .title.bold(),
      monthYearFont: .title2.bold(),
      weekdayHeaderFont: .title2.bold(),
      dayFont: .system(.title2, weight: .semibold),
      allowsScaling: true,
      minScaleFactor: nil
    )
    typography.registerDefaultDayViewTypography()
    return typography
  }

  /// Default configuration for iOS and related platforms.
  private static func makeDefaultiOS() -> Typography {
    let typography = Typography(
      headerFont: .title3,
      monthHeaderFont: .title2.weight(.semibold),
      monthYearFont: .title3.weight(.semibold),
      weekdayHeaderFont: .subheadline,
      dayFont: .body,
      allowsScaling: true,
      minScaleFactor: 0.85
    )
    typography.registerDefaultDayViewTypography()
    return typography
  }

  /// Registers default typography for built-in day view types.
  private func registerDefaultDayViewTypography() {
    // Circle day view - uses the base dayFont
    setDayViewTypography(
      DayViewTypography(
        primaryFont: dayFont,
        secondaryFont: weekdayHeaderFont
      ),
      for: DayViewType.circle
    )

    // Square dual day view - needs smaller fonts for the compact layout
    #if os(macOS)
      setDayViewTypography(
        DayViewTypography(
          primaryFont: .system(.body, weight: .semibold),
          secondaryFont: .caption
        ),
        for: DayViewType.squareDual
      )
    #else
      setDayViewTypography(
        DayViewTypography(
          primaryFont: .footnote,
          secondaryFont: .caption2
        ),
        for: DayViewType.squareDual
      )
    #endif
  }
}
