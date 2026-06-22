import DesignSystem
import SwiftUI

/// Layout metrics for the calendar grid, resolved from the shared `DesignSystem` tokens.
///
/// Centralizing these values keeps magic numbers out of the body views and ties calendar spacing
/// and cell sizing to the design system. The maximum cell size is intentionally *derived* here
/// rather than added as a global design token: a cell's ceiling is a component-level layout
/// decision, and `motion.minimumHitTarget` (44) is an iOS touch floor — not a macOS sizing rule.
///
/// This is the only file in the package that imports `DesignSystem`. The module's `Theme` and
/// `Typography` types collide by name with the calendar's own, so the design-system `Theme` is
/// referenced as `DesignSystem.Theme` and the resolved metrics are handed to the rest of the
/// package as plain values via `\.calendarMetrics`.
struct CalendarMetrics: Equatable, Sendable {
  /// Horizontal gap between day columns.
  let itemSpacing: CGFloat
  /// Vertical gap between day rows (and between the weekday header and the grid).
  let rowSpacing: CGFloat
  /// Lower bound for a day cell's side length.
  let minCellSize: CGFloat
  /// Upper bound for a day cell's side length; stops cells ballooning on wide (macOS) windows.
  let maxCellSize: CGFloat
  /// Vertical gap between months in the vertically scrolling calendar.
  let monthSpacing: CGFloat

  /// Narrowest the seven-column grid can be.
  var minCalendarWidth: CGFloat { (7 * minCellSize) + (6 * itemSpacing) }

  /// Widest the seven-column grid renders before it is centered within its container.
  var maxCalendarWidth: CGFloat { (7 * maxCellSize) + (6 * itemSpacing) }

  /// Resolves metrics from a design theme's spacing and motion tokens.
  init(theme: any DesignSystem.Theme) {
    let spacing = theme.spacing
    let motion = theme.motion
    itemSpacing = spacing.oneUnit
    rowSpacing = spacing.oneUnit
    minCellSize = motion.minimumHitTarget
    // Derived ceiling: the minimum hit target plus a roomy spacing step. See the type doc for why
    // this is computed here instead of being a global design token.
    maxCellSize = motion.minimumHitTarget + spacing.twoAndHalfUnits
    monthSpacing = spacing.threeUnits
  }

  /// Metrics resolved from the default design theme.
  static let `default` = CalendarMetrics(theme: DesignSystem.DefaultTheme())
}

// MARK: - Environment

private struct CalendarMetricsKey: EnvironmentKey {
  static let defaultValue = CalendarMetrics.default
}

extension EnvironmentValues {
  /// Calendar layout metrics resolved from the active design theme.
  var calendarMetrics: CalendarMetrics {
    get { self[CalendarMetricsKey.self] }
    set { self[CalendarMetricsKey.self] = newValue }
  }
}

extension View {
  /// Resolves `\.calendarMetrics` from the current `\.designTheme` and injects it for descendants.
  func resolveCalendarMetrics() -> some View {
    modifier(CalendarMetricsResolver())
  }
}

private struct CalendarMetricsResolver: ViewModifier {
  @Environment(\.designTheme) private var designTheme

  func body(content: Content) -> some View {
    content.environment(\.calendarMetrics, CalendarMetrics(theme: designTheme))
  }
}
