import DesignSystem
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

  @Test("wide grids retain compact cell spacing")
  func wideGridRetainsCompactCellSpacing() {
    let metrics = CalendarMetrics.default
    let layout = CalendarGridLayout(containerWidth: 844, metrics: metrics)

    #expect(layout.cellSize == metrics.maxCellSize)
    #expect(abs(layout.gridWidth - ((metrics.maxCellSize * 7) + (metrics.itemSpacing * 6))) < 0.0001)
  }

  @Test("grid sizing selects compact or flexible width as configured")
  func gridSizingResolvesWidthPolicy() {
    let metrics = CalendarMetrics.default

    #expect(
      abs(
        CalendarGridLayout(containerWidth: 844, metrics: metrics, sizing: .compact).gridWidth
          - ((metrics.maxCellSize * 7) + (metrics.itemSpacing * 6))
      ) < 0.0001
    )
    #expect(
      CalendarGridLayout(containerWidth: 844, metrics: metrics, sizing: .flexible).gridWidth == 844
    )
    #expect(
      CalendarGridLayout(containerWidth: 390, metrics: metrics, sizing: .adaptive).gridWidth == 390
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
    // 7 * 44 + 6 * 8
    #expect(metrics.minCalendarWidth == 356)
  }

  // MARK: - Custom theme flows through

  @Test("Custom design-theme tokens flow into the resolved metrics")
  func customThemeTokens() {
    let theme = DesignSystem.DefaultTheme(
      spacing: DesignSystem.DefaultSpacing(oneUnit: 10, twoAndHalfUnits: 30, threeUnits: 36),
      motion: DesignSystem.DefaultMotion(minimumHitTarget: 50)
    )
    let metrics = CalendarMetrics(theme: theme)
    #expect(metrics.itemSpacing == 10)
    #expect(metrics.rowSpacing == 10)
    #expect(metrics.minCellSize == 50)
    #expect(metrics.maxCellSize == 80)
    #expect(metrics.monthSpacing == 36)
  }

  // MARK: - Cap relationship

  @Test("Maximum cell size never falls below the minimum hit target")
  func maximumExceedsMinimum() {
    #expect(CalendarMetrics.default.maxCellSize >= CalendarMetrics.default.minCellSize)
  }
}
