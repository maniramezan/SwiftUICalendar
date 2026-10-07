import DesignSystem
import Foundation
import Testing

@testable import SwiftUICalendar

@Suite("CalendarMetrics Tests")
struct CalendarMetricsTests {
    @Test("grid layout centralizes width, cell size, and seven fixed columns")
    func gridLayoutResolvesCalendarGeometry() {
        let metrics = CalendarMetrics.default
        let layout = CalendarGridLayout(containerWidth: 390, metrics: metrics)

        #expect(layout.width == 390)
        #expect(abs(layout.cellSize - (390 - metrics.itemSpacing * 6) / 7) < 0.0001)
        #expect(layout.gridWidth == 390)
        #expect(layout.columns.count == 7)
    }

    @Test("scaling the soft margins leaves every other metric alone")
    func scalingSoftMarginsOnlyChangesMargins() {
        let metrics = CalendarMetrics.default
        let scaled = metrics.scalingSoftMargins(by: 0.25)

        #expect(scaled.calendarMargin == metrics.calendarMargin * 0.25)
        #expect(scaled.monthInset == metrics.monthInset * 0.25)
        #expect(scaled.minCellSize == metrics.minCellSize)
        #expect(scaled.itemSpacing == metrics.itemSpacing)
        #expect(scaled.minCalendarWidth == metrics.minCalendarWidth)
        #expect(metrics.scalingSoftMargins(by: 1) == metrics)
        #expect(metrics.scalingSoftMargins(by: 0).calendarMargin == 0)
    }

    @Test("wide grids retain compact cell spacing")
    func wideGridRetainsCompactCellSpacing() {
        let metrics = CalendarMetrics.default
        let layout = CalendarGridLayout(containerWidth: 844, metrics: metrics)

        #expect(layout.cellSize == metrics.maxCellSize)
        #expect(
            abs(layout.gridWidth - ((metrics.maxCellSize * 7) + (metrics.itemSpacing * 6))) < 0.0001
        )
    }

    @Test("grid sizing selects compact or flexible width as configured")
    func gridSizingResolvesWidthPolicy() {
        let metrics = CalendarMetrics.default

        #expect(
            abs(
                CalendarGridLayout(containerWidth: 844, metrics: metrics, sizing: .compact)
                    .gridWidth
                    - ((metrics.maxCellSize * 7) + (metrics.itemSpacing * 6))
            ) < 0.0001
        )
        #expect(
            CalendarGridLayout(containerWidth: 844, metrics: metrics, sizing: .flexible).gridWidth
                == 844
        )
        #expect(
            CalendarGridLayout(containerWidth: 390, metrics: metrics, sizing: .adaptive).gridWidth
                == 390
        )
    }

    @Test("grid layout falls back to the minimum calendar width and clamps cell size")
    func gridLayoutClampsCellSize() {
        let metrics = CalendarMetrics.default

        let unmeasured = CalendarGridLayout(containerWidth: 0, metrics: metrics)
        #expect(unmeasured.width == metrics.minCalendarWidth)
        #expect(unmeasured.cellSize == metrics.minCellSize)

        let wide = CalendarGridLayout(containerWidth: 2000, metrics: metrics)
        #expect(wide.cellSize == metrics.maxCellSize)
    }

    @Test("grid layouts compare by width and cell size")
    func gridLayoutEquality() {
        let metrics = CalendarMetrics.default
        #expect(
            CalendarGridLayout(containerWidth: 390, metrics: metrics)
                == CalendarGridLayout(containerWidth: 390, metrics: metrics))
        #expect(
            CalendarGridLayout(containerWidth: 390, metrics: metrics)
                != CalendarGridLayout(containerWidth: 500, metrics: metrics))
    }

    // MARK: - Default mapping

    @Test("Default metrics map design-system tokens (8pt grid, 44 min, 64 max)")
    func defaultMetricsMapTokens() {
        let metrics = CalendarMetrics.default
        #expect(metrics.itemSpacing == 8)
        #expect(metrics.rowSpacing == 8)
        #expect(metrics.minCellSize == 44)
        // Derived ceiling: minimumHitTarget (44) + twoAndHalfUnits (20).
        #expect(metrics.maxCellSize == 64)
        #expect(metrics.monthSpacing == 24)
        #expect(metrics.monthInset == 16)
        #expect(metrics.focusRingRadius == 8)
        #expect(metrics.headerRowHeight == 44)
        // threeUnits (24) + halfUnit (4)
        #expect(metrics.compactControlSize == 28)
        #expect(metrics.todayRowHeight == 28)
        #expect(metrics.controlPadding == 8)
        #expect(metrics.tightPadding == 4)
        #expect(metrics.controlSpacing == 12)
        #expect(metrics.dayContentPadding == 8)
        #expect(metrics.dayLabelSpacing == 2)
        // Was a raw 3pt, which is off the 4pt spacing scale. Snapped up to the nearest step.
        #expect(metrics.headerControlSpacing == 4)
        #expect(metrics.cornerRadius == 8)
        #expect(metrics.chevronSpacing == 4)
        #expect(metrics.disabledOpacity == 0.45)
        #expect(metrics.weekdayHeaderMinHeight == 24)
        #expect(metrics.minimumPeekWidth == 12)
        #expect(metrics.maximumPeekWidth == 48)
        #expect(metrics.hitTargetOutset == 8)
        #expect(metrics.hairlineStroke == 0.5)
        #expect(metrics.thinStroke == 1)
        #expect(metrics.glassBorderOpacity == 0.2)
        #expect(metrics.glassHairlineBorderOpacity == 0.15)
        // fourUnits (32) + halfUnit (4)
        #expect(metrics.yearOptionMinHeight == 36)
        #expect(metrics.yearPickerPopoverWidth == 220)
        // 7 * 44 + 6 * 8
        #expect(metrics.minCalendarWidth == 356)
    }

    // MARK: - Pager

    @Test("Pager tokens resolve from the design system and derive their thresholds")
    func pagerTokensResolveFromTheme() {
        let pager = CalendarMetrics.default.pager

        #expect(pager.headerHeightRatio == 0.45)
        // Half a `halfUnit` (4) step of pure rounding slack.
        #expect(pager.heightCeilingPadding == 2)
        #expect(pager.peekContentFraction == 0.35)
        #expect(pager.swipeThresholdRatio == 0.25)
        // minimumHitTarget (44) + oneAndHalfUnits (12)
        #expect(pager.minimumSwipeThreshold == 56)
        // threeUnits (24) + half of oneAndHalfUnits (12)
        #expect(pager.scrollPageThreshold == 30)
        #expect(pager.momentumWeight == 0.65)
        #expect(pager.pagingSpring == DesignSystem.MotionSpring.paging)
        #expect(pager.snapBackSpring == DesignSystem.MotionSpring.snapBack)
    }

    @Test("A narrow page falls back to the swipe floor, a wide one uses the ratio")
    func swipeThresholdFallsBackToFloorOnNarrowPages() {
        let pager = CalendarMetrics.default.pager

        #expect(pager.swipeThreshold(layoutWidth: 120) == pager.minimumSwipeThreshold)
        #expect(pager.swipeThreshold(layoutWidth: 400) == 100)
        #expect(pager.swipeThreshold(layoutWidth: 0) == pager.minimumSwipeThreshold)
    }

    @Test("Pager springs match the ones the design system exposes on motion")
    func pagerSpringsFollowMotionTokens() {
        let theme = DesignSystem.DefaultTheme()
        let pager = CalendarMetrics(theme: theme).pager

        #expect(pager.pagingSpring == theme.motion.pagingSpring)
        #expect(pager.snapBackSpring == theme.motion.snapBackSpring)
    }

    // MARK: - Week header

    @Test("The weekday header row scales to a tenth of its day cell, never less")
    func weekdayHeaderHeightUsesRatioWithFloor() {
        let metrics = CalendarMetrics.default

        #expect(metrics.weekdayHeaderHeight(cellSize: 44) == 24)
        #expect(metrics.weekdayHeaderHeight(cellSize: 64) == 28.8)
        // Below the floor the minimum wins, so a tiny cell keeps a legible header.
        #expect(metrics.weekdayHeaderHeight(cellSize: 8) == metrics.weekdayHeaderMinHeight)
    }

    // MARK: - Year grid

    @Test("The year page is a square of three columns, so nine years fill it")
    func yearPageIsSquareOfThreeColumns() {
        #expect(YearDecadeGrid.columnCount == 3)
        #expect(YearDecadeGrid.pageSize == 9)
        #expect(YearDecadeGrid.years(pageStart: 2025).count == YearDecadeGrid.pageSize)
    }

    // MARK: - Custom theme flows through

    @Test("Custom design-theme tokens flow into the resolved metrics")
    func customThemeTokens() {
        let theme = DesignSystem.DefaultTheme(
            spacing: DesignSystem.DefaultSpacing(
                oneUnit: 10, twoUnits: 22, twoAndHalfUnits: 30, threeUnits: 36),
            motion: DesignSystem.DefaultMotion(minimumHitTarget: 50)
        )
        let metrics = CalendarMetrics(theme: theme)
        #expect(metrics.itemSpacing == 10)
        #expect(metrics.rowSpacing == 10)
        #expect(metrics.minCellSize == 50)
        #expect(metrics.maxCellSize == 80)
        #expect(metrics.monthSpacing == 36)
        #expect(metrics.monthInset == 22)
        // The control metrics track the same custom spacing scale.
        #expect(metrics.headerRowHeight == 50)
        // threeUnits (36, overridden) + halfUnit (4, still the default)
        #expect(metrics.compactControlSize == 40)
        #expect(metrics.todayRowHeight == metrics.compactControlSize)
        #expect(metrics.controlPadding == 10)
    }

    // MARK: - Hit target

    /// The compact control size is deliberately below the platform touch floor. Pin that so raising
    /// it becomes a conscious change rather than an accident.
    /// The controls stay visually compact, but what a finger can hit must still reach the platform
    /// touch floor.
    @Test("Compact controls' tappable area reaches the minimum hit target")
    func compactControlsHitAreaReachesTouchFloor() {
        // Computed into typed locals: `#expect` evaluates each operand of a compound expression on
        // its own, which let two equal 44.0 values compare unequal here.
        let metrics = CalendarMetrics.default
        let hitArea: CGFloat = metrics.compactControlSize + 2 * metrics.hitTargetOutset
        #expect(hitArea == metrics.minCellSize)
        let custom = CalendarMetrics(
            theme: DesignSystem.DefaultTheme(
                motion: DesignSystem.DefaultMotion(minimumHitTarget: 50)))
        let customHitArea: CGFloat = custom.compactControlSize + 2 * custom.hitTargetOutset
        #expect(customHitArea == 50)
    }

    @Test("Compact controls are smaller than the minimum hit target")
    func compactControlsAreBelowHitTarget() {
        let metrics = CalendarMetrics.default
        #expect(metrics.compactControlSize < metrics.minCellSize)
        #expect(metrics.headerRowHeight == metrics.minCellSize)
    }

    // MARK: - Cap relationship

    @Test("Maximum cell size never falls below the minimum hit target")
    func maximumExceedsMinimum() {
        #expect(CalendarMetrics.default.maxCellSize >= CalendarMetrics.default.minCellSize)
    }
}
