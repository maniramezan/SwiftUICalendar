import OSLog
import SwiftCommons
import SwiftUI

// Geometry is an input to layout, never state written by that same layout's callbacks.
struct CalendarViewportContent<Content: View>: View {
    let size: CGSize
    var model: CalendarViewModel? = nil
    @Environment(\.calendarMetrics) private var metrics
    @Environment(\.calendarConfiguration) private var configuration
    @Environment(\.calendarLayoutObserver) private var layoutObserver
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.calendarHasCompanionMonth) private var hasCompanionMonth
    @Environment(\.calendarIsCompanionPanel) private var isCompanionPanel
    private var width: CGFloat { size.width }
    private var height: CGFloat { size.height }
    @State private var dateRevealer = CalendarDateRevealer()
    @State private var horizontalPosition = ScrollPosition(edge: .leading)
    var keyboard: CalendarKeyboardCursor? = nil
    private let logger = Logger.swiftUICalendar(for: Self.self)

    @ViewBuilder let content: (Bool) -> Content

    /// Total soft margin around the grid. The vertically scrolling body insets each month as well.
    private var softMargins: CGFloat {
        2 * metrics.calendarMargin
            + (configuration.scrollMode == .vertical ? 2 * metrics.monthInset : 0)
    }

    /// The side margin actually applied: the full margin, or less while the grid has little room to spare.
    private var horizontalMargin: CGFloat {
        metrics.calendarMargin * layout.marginScale
    }

    private var layout: CalendarViewportLayout {
        CalendarViewportLayout(
            width: width, cellWidth: metrics.minCellSize, margins: softMargins,
            preferredSpacing: configuration.layout.preferredColumnSpacing ?? metrics.itemSpacing,
            minimumSpacing: configuration.layout.minimumColumnSpacing)
    }

    private var resolvedMetrics: CalendarMetrics {
        let resolved = metrics.scalingSoftMargins(by: layout.marginScale)
            .resolvingSpacing(layout.columnSpacing)
        guard growsCells else { return resolved }
        return resolved.growingCells(
            toFitHeight: height,
            controls: resolved.controlsHeight(showsHeader: configuration.showsHeader))
    }

    /// Cells grow only on a regular-width iPad showing a single fixed or paged month. A two-month
    /// fold sizes its panels together, a compact width keeps the phone-sized cells, and the vertical
    /// list keeps them too: larger months moved where it rests on launch, hiding the month title.
    private var growsCells: Bool {
        #if os(iOS)
        horizontalSizeClass == .regular && configuration.scrollMode != .vertical
            && !hasCompanionMonth && !isCompanionPanel
        #else
        false
        #endif
    }

    private var layoutInfo: CalendarLayoutInfo {
        CalendarLayoutInfo(
            minimumWidth: layout.minimumWidth,
            minimumCellSize: CGSize(width: metrics.minCellSize, height: metrics.minRowHeight),
            columnSpacing: layout.columnSpacing, overflowsHorizontally: layout.overflows)
    }

    var body: some View {
        // The safe area is left to SwiftUI: the scroll view sits inside it — a notch or a host's
        // `.safeAreaPadding` alike — so its measured width is already the usable width. Two shapes
        // that handled it explicitly failed on device. Ignoring the horizontal safe area and padding
        // by the reported insets double-counted `.safeAreaPadding`, which that modifier does not let
        // a view ignore, pushing the grid off screen during a resize. And sizing the content with
        // `containerRelativeFrame` in that shape never finished laying out a right-to-left calendar:
        // Persian or Hebrew in landscape on a notched iPhone hung the app.
        Group {
            ScrollViewReader { proxy in
                ScrollView(
                    configuration.layout.overflow == .automatic && layout.overflows
                        ? .horizontal : []
                ) {
                    if width > 0 && height > 0 {
                        // Paging is handed back to the viewport only while the grid genuinely overflows, so
                        // a horizontal swipe scrolls to the clipped columns instead of flipping the month.
                        content(!layout.overflows)
                            .frame(height: height)
                            .environment(\.calendarRevealDate, dateRevealer)
                            .environment(
                                \.calendarMetrics, resolvedMetrics
                            )
                            .environment(
                                \.calendarContentWidth, layout.contentWidth - 2 * horizontalMargin
                            )
                            .environment(
                                \.calendarViewportWidth,
                                max(0, width - 2 * horizontalMargin)
                            )
                            .padding(.horizontal, horizontalMargin)
                            .frame(width: layout.contentWidth)
                    }
                }
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                .scrollPosition($horizontalPosition)
                .defaultScrollAnchor(.leading)
                .onAppear {
                    dateRevealer.action = { proxy.scrollTo($0, anchor: .center) }
                }
                .onChange(
                    of: layout.overflows && configuration.layout.overflow == .automatic,
                    initial: true
                ) { _, enabled in
                    dateRevealer.enabled = enabled
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onChange(of: keyboard?.scrollRequest) { _, request in
                    guard layout.overflows, let request, keyboard?.isActive == true else { return }
                    proxy.scrollTo(request.identity, anchor: .center)
                }
                .onChange(of: model?.todayScrollRequest) { _, _ in
                    guard let model, layout.overflows, configuration.layout.overflow == .automatic
                    else {
                        return
                    }
                    let calendar = model.engine.calendar
                    let weekday = calendar.component(.weekday, from: model.currentDate)
                    let column =
                        (weekday - calendar.firstWeekday + CalendarGrid.columnCount)
                        % CalendarGrid.columnCount
                    logger.debug("Revealing Today in horizontal overflow")
                    horizontalPosition.scrollTo(
                        x: layout.horizontalOffsetToReveal(
                            column: column, viewportWidth: width))
                }
            }
        }
        .onChange(of: layoutInfo, initial: true) { _, info in
            guard width > 0 else { return }
            layoutObserver?(info)
        }
    }
}
