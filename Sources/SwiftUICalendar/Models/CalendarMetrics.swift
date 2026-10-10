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
    private(set) var itemSpacing: CGFloat
    /// Vertical gap between day rows (and between the weekday header and the grid).
    let rowSpacing: CGFloat
    /// Lower bound for a day cell's side length.
    private(set) var minCellSize: CGFloat
    /// Upper bound for a day cell's row height; stops cells ballooning on wide (macOS) windows.
    private(set) var maxCellSize: CGFloat
    /// Lower bound for a day row's height; grows with Dynamic Type but never drops below the touch floor.
    private(set) var minRowHeight: CGFloat
    /// The platform touch floor, from `motion.minimumHitTarget`. Controls that must stay tappable
    /// at every text size and width take this rather than a literal.
    let minimumHitTarget: CGFloat
    /// Vertical gap between months in the vertically scrolling calendar.
    let monthSpacing: CGFloat
    /// Horizontal inset applied to each month in the vertically scrolling calendar.
    private(set) var monthInset: CGFloat
    /// Margin between the calendar and the edges of its container.
    private(set) var calendarMargin: CGFloat
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
    /// Corner radius for the calendar's rounded surfaces: square day cells, the weekday header, and
    /// a selected year option's fill.
    let cornerRadius: CGFloat
    /// Gap between a header chevron and the picker it steps.
    let chevronSpacing: CGFloat
    /// Opacity of a disabled header control.
    let disabledOpacity: Double
    /// Floor for the weekday header row's height.
    private(set) var weekdayHeaderMinHeight: CGFloat
    /// Bounds on how much of the adjacent months the horizontal pager reveals at each edge.
    let minimumPeekWidth: CGFloat
    let maximumPeekWidth: CGFloat
    /// How far a compact control's hit area extends past its visible bounds on each side, so the
    /// tappable region reaches the platform touch floor without enlarging the control itself.
    ///
    /// Only for controls with at least this much clear space around them. The header's adjacent
    /// month and year chevrons do not have it — enlarged there, a tap on one fired the other.
    let hitTargetOutset: CGFloat
    /// Minimum height of a year option in the decade grid.
    let yearOptionMinHeight: CGFloat
    /// Width of the decade-grid year picker's popover.
    let yearPickerPopoverWidth: CGFloat
    /// Vertical gap between the two labels in a dual-calendar day cell.
    let dayLabelSpacing: CGFloat
    /// Gap between the month and year controls in a header row.
    let headerControlSpacing: CGFloat
    /// Hairline border width, for outlines that should read as a single pixel.
    let hairlineStroke: CGFloat
    /// Standard border width, for outlines that should read as a deliberate edge.
    let thinStroke: CGFloat
    /// Opacity of the highlight edge drawn over a glass (or material-fallback) fill.
    let glassBorderOpacity: Double
    /// Opacity of the same edge when it is drawn hairline-thin over a rounded rectangle.
    let glassHairlineBorderOpacity: Double
    /// Geometry, thresholds, and motion for the horizontal month pager.
    let pager: Pager

    /// Narrowest the seven-column grid can be.
    var minCalendarWidth: CGFloat {
        (CalendarGrid.columnWidthDivisor * minCellSize)
            + (CalendarGrid.columnGapCount * itemSpacing)
    }

    /// Resolves metrics from a design theme's spacing and motion tokens.
    init(theme: any DesignSystem.Theme) {
        let spacing = theme.spacing
        let motion = theme.motion
        itemSpacing = spacing.oneUnit
        rowSpacing = spacing.oneUnit
        minimumHitTarget = motion.minimumHitTarget
        minCellSize = motion.minimumHitTarget
        minRowHeight = motion.minimumHitTarget
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
        hitTargetOutset = (motion.minimumHitTarget - compactControlSize) / 2
        controlPadding = spacing.oneUnit
        tightPadding = spacing.halfUnit
        controlSpacing = spacing.oneAndHalfUnits
        dayContentPadding = spacing.oneUnit
        cornerRadius = theme.radius.oneUnit
        // Previously a raw 3pt with no matching step; `halfUnit` is the nearest token.
        chevronSpacing = spacing.halfUnit
        // Previously a raw 0.4.
        disabledOpacity = motion.disabledOpacity
        weekdayHeaderMinHeight = spacing.threeUnits
        minimumPeekWidth = spacing.oneAndHalfUnits
        maximumPeekWidth = spacing.sixUnits
        // Derived: one spacing step of breathing room above the compact control size.
        yearOptionMinHeight = spacing.fourUnits + spacing.halfUnit
        // A component-level popover width with no matching global token, centralized here so the
        // picker view holds no raw number. Wide enough for a four-column decade grid of year labels.
        yearPickerPopoverWidth = 220
        // Half the tightest spacing step: enough to separate a day number from the alternate
        // calendar's number beneath it without competing with the cell's own padding.
        dayLabelSpacing = spacing.halfUnit / 2
        // Previously a raw 3pt. Nearest step, same as `chevronSpacing` below.
        headerControlSpacing = spacing.halfUnit
        // The glass fallback draws a specular highlight edge over a translucent fill, and its
        // width comes from the design system's stroke scale rather than literals. The highlight is
        // always white — it is a reflection, not a themed color — and there is no token for one:
        // `ColorTheme`'s overlays are all shadow-derived and @MainActor, so they cannot be
        // resolved into a plain `Double` here. Curved shapes carry a thin edge, the rounded
        // rectangle a fainter hairline, so the corner radius does not read as an outline.
        hairlineStroke = theme.stroke.hairline
        thinStroke = theme.stroke.thin
        glassBorderOpacity = 0.2
        glassHairlineBorderOpacity = 0.15
        pager = Pager(theme: theme)
    }

    /// Metrics resolved from the default design theme.
    static let `default` = CalendarMetrics(theme: DesignSystem.DefaultTheme())
}

// MARK: - Pager

extension CalendarMetrics {
    func resolvingContent(cell: CGSize, weekday: CGSize) -> CalendarMetrics {
        var result = self
        result.minCellSize = max(minCellSize, cell.width, weekday.width)
        result.maxCellSize = max(maxCellSize, result.minCellSize)
        result.minRowHeight = max(minCellSize, cell.height)
        result.weekdayHeaderMinHeight = max(weekdayHeaderMinHeight, weekday.height)
        return result
    }

    func resolvingSpacing(_ spacing: CGFloat) -> CalendarMetrics {
        var result = self
        result.itemSpacing = spacing
        return result
    }

    /// Tokens for the horizontal month pager.
    ///
    /// Grouped rather than flattened onto ``CalendarMetrics`` because they only mean something to
    /// the one scroll mode: a vertical calendar resolves none of them. Keeping them together also
    /// gives the pager's feel (how far a swipe must travel, how it settles) a single theming seam
    /// instead of a dozen independent properties.
    struct Pager: Equatable, Sendable {
        /// Weekday header height as a fraction of the day cell's side length.
        let headerHeightRatio: CGFloat
        /// Slack added after ceiling the carousel's height, so rounding cannot clip a row edge.
        let heightCeilingPadding: CGFloat
        /// How much of a day cell the peek must reach to expose real content rather than margin.
        let peekContentFraction: CGFloat
        /// Fraction of the page width a swipe must cross to commit to the next month.
        let swipeThresholdRatio: CGFloat
        /// Floor for ``swipeThresholdRatio``, so a narrow page still needs a deliberate swipe.
        let minimumSwipeThreshold: CGFloat
        /// Accumulated trackpad scroll that pages one month, on macOS.
        let scrollPageThreshold: CGFloat
        /// How much of a drag's *predicted* end translation counts toward committing the swipe.
        let momentumWeight: CGFloat
        /// Spring that completes a committed page transition.
        let pagingSpring: DesignSystem.MotionSpring
        /// Spring that returns the carousel to rest after a swipe that did not commit.
        let snapBackSpring: DesignSystem.MotionSpring

        init(theme: any DesignSystem.Theme) {
            let spacing = theme.spacing
            let motion = theme.motion
            headerHeightRatio = 0.45
            // Half the tightest spacing step. Pure rounding slack: enough to keep a ceiled height
            // from landing a hair under the row it was measured from, small enough to read as
            // nothing.
            heightCeilingPadding = spacing.halfUnit / 2
            peekContentFraction = 0.35
            swipeThresholdRatio = 0.25
            // A quarter of a phone-width page is about 90pt, so on the widths that matter this
            // ratio governs and the floor only matters on a very narrow page. There the floor
            // stands in for "a whole touch target's worth of travel", which is the distance a
            // finger can make without its motion reading as a tap.
            minimumSwipeThreshold = motion.minimumHitTarget + spacing.oneAndHalfUnits
            // Three quarters of a `threeUnits` step. Scroll-wheel deltas are raw trackpad points,
            // not layout points, so this is a feel value rather than a size — it is a swipe
            // accumulator threshold, the same role as `minimumSwipeThreshold` on touch.
            scrollPageThreshold = spacing.threeUnits + (spacing.oneAndHalfUnits / 2)
            // Favouring the predicted end translation lets a fast flick commit a month it has not
            // yet scrolled past, which is what makes a flick feel responsive instead of sticky.
            momentumWeight = 0.65
            pagingSpring = motion.pagingSpring
            snapBackSpring = motion.snapBackSpring
        }

        /// Distance a horizontal swipe must travel before the pager commits to a month.
        func swipeThreshold(layoutWidth: CGFloat) -> CGFloat {
            max(layoutWidth * swipeThresholdRatio, minimumSwipeThreshold)
        }
    }
}

// MARK: - Geometry

extension CalendarMetrics {
    /// Metrics with the soft horizontal margins (`calendarMargin` and `monthInset`) scaled by `factor`.
    ///
    /// The viewport hands its content these when the grid fits with less than its full margins to
    /// spare, so the margins give way instead of squeezing the grid below ``minCalendarWidth``.
    func scalingSoftMargins(by factor: CGFloat) -> CalendarMetrics {
        var scaled = self
        scaled.calendarMargin *= factor
        scaled.monthInset *= factor
        return scaled
    }

    /// The width the grid is actually laid out at, never narrower than ``minCalendarWidth``.
    func layoutWidth(containerWidth: CGFloat) -> CGFloat {
        max(containerWidth, minCalendarWidth)
    }

    /// Height of the weekday header row for a given day cell size.
    func weekdayHeaderHeight(cellSize: CGFloat) -> CGFloat {
        max(pager.headerHeightRatio * cellSize, weekdayHeaderMinHeight)
    }

    /// How much of the adjacent months the pager reveals at each edge.
    ///
    /// Reserves space for a swipe affordance that reliably reveals real day content, not just empty
    /// margin. Day cells render as a `cellSize`-capped square *centered* within each grid column (see
    /// `CalendarBodyView`'s square-cell centering), so on wide layouts the column can be much wider
    /// than the visible cell — a peek narrower than that centering margin would only expose blank
    /// space. This reaches past the margin and into a meaningful fraction of the actual cell before
    /// falling back to whatever space remains above the minimum grid width.
    func peekWidth(containerWidth: CGFloat) -> CGFloat {
        let width = layoutWidth(containerWidth: containerWidth)
        let approxCellSize = CalendarGridLayout.cellSize(
            containerWidth: containerWidth, metrics: self)
        let approxColumnWidth = width / CalendarGrid.columnWidthDivisor
        let marginToContent = max(0, (approxColumnWidth - approxCellSize) / 2)
        let desired = min(
            maximumPeekWidth,
            max(minimumPeekWidth, marginToContent + (approxCellSize * pager.peekContentFraction))
        )
        return min(desired, max(0, (width - minCalendarWidth) / 2))
    }

    /// The width a single month page occupies: the viewport less the two edge peeks.
    func pageWidth(containerWidth: CGFloat) -> CGFloat {
        layoutWidth(containerWidth: containerWidth)
            - (2 * peekWidth(containerWidth: containerWidth))
    }

    /// Height of a parked month of `rowCount` rows, ceiled so a fractional cell size cannot clip.
    func resolvedHeight(rowCount: Int, layoutWidth: CGFloat) -> CGFloat {
        let cellSize = CalendarGridLayout.cellSize(containerWidth: layoutWidth, metrics: self)
        let totalRowSpacing = rowSpacing * CGFloat(rowCount - 1)
        let height = (CGFloat(rowCount) * max(minRowHeight, cellSize)) + totalRowSpacing
        return ceil(height) + pager.heightCeilingPadding
    }
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
