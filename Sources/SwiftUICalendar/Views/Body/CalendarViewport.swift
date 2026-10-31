import OSLog
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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var panelHeaders = CalendarPanelHeaders()
    /// Visible height of the scroll view hosting the calendar, `nil` outside one. It does not depend
    /// on the calendar's own size, so measuring it cannot feed back into the layout it informs.
    @State private var hostHeight: CGFloat?
    private let logger = Logger.swiftUICalendar(for: Self.self)
    var keyboard: CalendarKeyboardCursor? = nil
    @ViewBuilder let content: (Bool) -> Content

    var body: some View {
        CalendarViewportSize(
            idealWidth: metrics.minCalendarWidth,
            idealHeight: idealHeight
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
                .onChange(of: fold.mode, initial: true) { _, mode in
                    logger.info("Fold layout changed to \(mode.rawValue, privacy: .public)")
                }
                .onChange(of: fold.secondary == nil ? nil : nextMonth, initial: true) { _, month in
                    logger.debug(
                        "Companion month \(month == nil ? "hidden" : "shown", privacy: .public)")
                    keyboard?.companionMonth = month
                }
            }
        }
        .onGeometryChange(for: CGFloat?.self) { proxy in
            proxy.bounds(of: .scrollView).map {
                $0.height - proxy.safeAreaInsets.top - proxy.safeAreaInsets.bottom
            }
        } action: { height in
            logger.debug("Host viewport height changed")
            hostHeight = height
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

    private var idealHeight: CalendarIdealHeight {
        #if os(iOS)
        let grows = horizontalSizeClass == .regular && configuration.scrollMode != .vertical
        #else
        let grows = false
        #endif
        return CalendarIdealHeight(
            metrics: metrics, showsHeader: configuration.showsHeader, growsCells: grows,
            hostHeight: hostHeight)
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
