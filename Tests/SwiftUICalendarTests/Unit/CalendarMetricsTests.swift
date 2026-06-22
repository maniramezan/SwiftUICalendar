import DesignSystem
import Testing

@testable import SwiftUICalendar

@Suite("CalendarMetrics Tests")
struct CalendarMetricsTests {

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
