import SwiftUI

// MARK: - Viewport

/// Keeps every date reachable without reducing the grid's minimum touch targets.
/// The same scroll container remains mounted across the overflow boundary.
struct CalendarViewport<Content: View>: View {
    @Environment(\.calendarMetrics) private var metrics
    @Environment(\.calendarConfiguration) private var configuration
    var keyboard: CalendarKeyboardCursor? = nil
    @ViewBuilder let content: (Bool) -> Content

    var body: some View {
        CalendarViewportSize(
            idealWidth: metrics.minCalendarWidth,
            idealHeight:
                metrics.resolvedHeight(rowCount: 6, layoutWidth: metrics.minCalendarWidth)
                + metrics.weekdayHeaderMinHeight + 3 * metrics.headerRowHeight
        ) {
            GeometryReader { geometry in
                CalendarViewportContent(size: geometry.size, keyboard: keyboard, content: content)
            }
        }
        .safeAreaPadding(.vertical, metrics.calendarMargin)
        .frame(
            minWidth: configuration.layout.overflow == .minimumSize
                ? 7 * metrics.minCellSize
                    + 6
                    * min(
                        configuration.layout.minimumColumnSpacing,
                        configuration.layout.preferredColumnSpacing ?? metrics.itemSpacing)
                : nil)
    }
}

extension EnvironmentValues {
    @Entry var calendarViewportWidth: CGFloat? = nil
    /// The width the viewport gives the calendar's content, inside its soft margins; `nil` outside a
    /// viewport. A body that measured this itself could not settle: a grid wider than the space it
    /// was offered inflated the scroll view around it, which reported that width back and held the
    /// grid at its landscape size after rotating to portrait.
    @Entry var calendarContentWidth: CGFloat? = nil
}
