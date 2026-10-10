import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Layout contract")
struct CalendarLayoutContractTests {
    @Test(arguments: [320.0, 331.5, 332, 343, 355, 356, 359, 375, 404, 900])
    func compressionBeforeOverflow(width: CGFloat) {
        let layout = CalendarViewportLayout(
            width: width, cellWidth: 44, margins: 48, preferredSpacing: 8, minimumSpacing: 4)
        #expect(layout.minimumWidth == 332)
        #expect(layout.overflows == (width < 332))
        #expect(layout.columnSpacing >= 4 && layout.columnSpacing <= 8)
        // Below the floor the content scrolls and carries its margins in full; above it the
        // content is exactly the viewport.
        #expect(layout.contentWidth == (width < 332 ? 332 + 48 : width))
        if width < 332 { #expect(layout.marginScale == 1) }
        // The grid plus the margins that survive always fill the content, up to the preferred width.
        #expect(
            abs(
                7 * 44 + 6 * layout.columnSpacing + 48 * layout.marginScale
                    - min(layout.contentWidth, 404)) < 0.001)
    }

    @Test func readableContentRaisesMinimum() {
        let metrics = CalendarMetrics.default.resolvingContent(
            cell: CGSize(width: 80, height: 120), weekday: CGSize(width: 90, height: 55))
        let layout = CalendarViewportLayout(
            width: 430, cellWidth: metrics.minCellSize, margins: 16, preferredSpacing: 8,
            minimumSpacing: 4)
        #expect(layout.minimumWidth == 654)
        #expect(layout.overflows)
        let grid = CalendarGridLayout(
            containerWidth: layout.contentWidth,
            metrics: metrics.resolvingSpacing(layout.columnSpacing))
        #expect(grid.cellSize == 90)
        #expect(grid.rowHeight == 120)
        #expect(metrics.weekdayHeaderHeight(cellSize: grid.cellSize) >= 55)
    }

    @Test func invalidSpacingIsNormalized() {
        #expect(CalendarLayoutConfiguration(minimumColumnSpacing: .nan).minimumColumnSpacing == 4)
        #expect(
            CalendarLayoutConfiguration(preferredColumnSpacing: 2, minimumColumnSpacing: 4)
                .minimumColumnSpacing == 2)
        #expect(CalendarLayoutConfiguration(minimumColumnSpacing: -1).minimumColumnSpacing == 0)
    }

    @Test func disablingTextShrinkIsRespected() {
        let typography = Typography.default
        typography.minScaleFactor = 0.5
        typography.allowsScaling = false
        #expect(typography.resolvedMinScaleFactor == 1)
        typography.allowsScaling = true
        #expect(typography.resolvedMinScaleFactor == 0.5)
    }
}
