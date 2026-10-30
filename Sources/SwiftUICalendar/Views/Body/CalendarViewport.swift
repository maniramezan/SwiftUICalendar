import SwiftUI

// MARK: - Viewport

/// Keeps every date reachable without reducing the grid's minimum touch targets.
/// The same scroll container remains mounted across the overflow boundary.
struct CalendarViewport<Content: View>: View {
    var model: CalendarViewModel? = nil
    @Environment(\.calendarMetrics) private var metrics
    @Environment(\.calendarConfiguration) private var configuration
    @Environment(\.calendarFoldRegions) private var foldRegions
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var panelHeaders = CalendarPanelHeaders()
    var keyboard: CalendarKeyboardCursor? = nil
    @ViewBuilder let content: (Bool) -> Content

    var body: some View {
        CalendarViewportSize(
            idealWidth: metrics.minCalendarWidth,
            idealHeight:
                metrics.resolvedHeight(
                    rowCount: CalendarGrid.maximumRowCount, layoutWidth: metrics.minCalendarWidth)
                + metrics.weekdayHeaderMinHeight + 3 * metrics.headerRowHeight
        ) {
            GeometryReader { geometry in
                let nextMonth = model?.monthIdentifier(offset: 1)
                let fold = CalendarFoldLayout.resolve(
                    size: geometry.size,
                    blocked: foldRegions + CalendarFoldRegions.read(in: geometry),
                    minimumPaneSize: CGSize(
                        width: CalendarViewportLayout.minimumWidth(
                            cellWidth: metrics.minCellSize,
                            preferredSpacing: configuration.layout.preferredColumnSpacing
                                ?? metrics.itemSpacing,
                            minimumSpacing: configuration.layout.minimumColumnSpacing),
                        height: metrics.minRowHeight + metrics.weekdayHeaderMinHeight
                            + 2 * metrics.headerRowHeight),
                    allowsCompanion: nextMonth != nil, layoutDirection: layoutDirection)
                CalendarFoldPlacement(size: geometry.size, fold: fold) {
                    CalendarViewportContent(
                        size: fold.primary.size, model: model, keyboard: keyboard, content: content
                    )
                    .environment(\.layoutDirection, layoutDirection)
                    .environment(\.calendarHasCompanionMonth, fold.secondary != nil)

                    if let secondary = fold.secondary, let nextMonth {
                        CalendarViewportContent(size: secondary.size) { _ in
                            CalendarCompanionMonthView(month: nextMonth, keyboard: keyboard)
                        }
                        .environment(\.layoutDirection, layoutDirection)
                        .environment(\.calendarIsCompanionPanel, true)
                        .environment(\.calendarConfiguration, companionConfiguration)
                        .environment(\.calendarLayoutObserver, nil)
                    }
                }
                .environment(\.layoutDirection, .leftToRight)
                .environment(\.calendarPanelHeaders, panelHeaders)
                .onChange(of: fold.secondary == nil ? nil : nextMonth, initial: true) { _, month in
                    keyboard?.companionMonth = month
                }
            }
        }
        .safeAreaPadding(.vertical, metrics.calendarMargin)
        .frame(
            minWidth: configuration.layout.overflow == .minimumSize
                ? CalendarViewportLayout.minimumWidth(
                    cellWidth: metrics.minCellSize,
                    preferredSpacing: configuration.layout.preferredColumnSpacing
                        ?? metrics.itemSpacing,
                    minimumSpacing: configuration.layout.minimumColumnSpacing)
                : nil)
    }

    private var companionConfiguration: CalendarConfiguration {
        var companion = configuration
        companion.scrollMode = .none
        return companion
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
