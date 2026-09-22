import DesignSystem
import SwiftUI

/// Layout metrics for the calendar grid, resolved from the shared `DesignSystem` tokens.
///
/// Centralizing these values keeps magic numbers out of the body views and ties calendar spacing
/// and cell sizing to the design system. Columns fill the available width, while `maxCellSize` caps
/// the row height so cells never balloon on wide (macOS) windows. The cap is intentionally *derived*
/// here rather than added as a global design token: a cell's ceiling is a component-level layout
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
    /// Upper bound for a day cell's row height; stops cells ballooning on wide (macOS) windows.
    let maxCellSize: CGFloat
    /// Vertical gap between months in the vertically scrolling calendar.
    let monthSpacing: CGFloat
    /// Horizontal inset applied to each month in the vertically scrolling calendar.
    let monthInset: CGFloat
    /// Margin between the calendar and the edges of its container.
    let calendarMargin: CGFloat
    /// Corner radius of the keyboard focus ring drawn around a day cell.
    let focusRingRadius: CGFloat
    /// Height of the navigation header row.
    let headerRowHeight: CGFloat
    /// Height of the compact "Today" control row above the header.
    let todayRowHeight: CGFloat
    /// Side length of a compact square control, such as a header chevron or a decade-grid cell.
    let compactControlSize: CGFloat
    /// Horizontal padding inside a header control's label.
    let controlPadding: CGFloat
    /// Vertical padding inside a header control's label, and around the weekday header.
    let tightPadding: CGFloat
    /// Vertical gap between rows of the year picker.
    let controlSpacing: CGFloat
    /// Padding between a dual-calendar day cell's border and its labels.
    let dayContentPadding: CGFloat
    /// Corner radius for a selected year option's fill.
    let optionCornerRadius: CGFloat
    /// Minimum height of a year option in the decade grid.
    let yearOptionMinHeight: CGFloat
    /// Width of the decade-grid year picker's popover.
    let yearPickerPopoverWidth: CGFloat

    /// Narrowest the seven-column grid can be.
    var minCalendarWidth: CGFloat { (7 * minCellSize) + (6 * itemSpacing) }

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
        monthInset = spacing.twoUnits
        // Previously a raw 10pt with no matching token. `oneUnit` is the nearest step, and the one
        // that keeps the bare grid fitting on a 375pt phone: 375 − 2 × 8 = 359 ≥ the 356pt minimum,
        // where 10pt (355) and `oneAndHalfUnits` (351) both come up short.
        calendarMargin = spacing.oneUnit
        focusRingRadius = theme.radius.oneUnit
        // A row of tappable chevrons and pickers, so it takes the touch floor directly.
        headerRowHeight = motion.minimumHitTarget
        // Derived: there is no 28pt spacing step, and this component already used one compact square
        // size in three places (the Today row, header chevrons, decade-grid cells). Naming it once
        // keeps those in agreement. See the type doc for why derivation happens here.
        //
        // NOTE: this is deliberately smaller than `motion.minimumHitTarget`, which is the platform
        // touch floor. Raising these controls to 44pt is a visual change, so it is left as its own
        // decision rather than folded into a value-preserving refactor.
        compactControlSize = spacing.threeUnits + spacing.halfUnit
        todayRowHeight = compactControlSize
        controlPadding = spacing.oneUnit
        tightPadding = spacing.halfUnit
        controlSpacing = spacing.oneAndHalfUnits
        dayContentPadding = spacing.oneUnit
        optionCornerRadius = theme.radius.oneUnit
        // Derived: one spacing step of breathing room above the compact control size.
        yearOptionMinHeight = spacing.fourUnits + spacing.halfUnit
        // A component-level popover width with no matching global token, centralized here so the
        // picker view holds no raw number. Wide enough for a four-column decade grid of year labels.
        yearPickerPopoverWidth = 220
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
