import SwiftUI

// MARK: - Viewport

/// Keeps every date reachable without reducing the grid's minimum touch targets.
/// The same scroll container remains mounted across the overflow boundary.
struct CalendarViewport<Content: View>: View {
    @Environment(\.calendarMetrics) private var metrics
    @Environment(\.calendarConfiguration) private var configuration
    @Environment(\.calendarLayoutObserver) private var layoutObserver
    // The viewport's measured width. Content is not laid out until it is known, so the content's
    // first layout pass already has the final width — never a placeholder width that a vertical
    // `LazyVStack` could settle empty on.
    @State private var width: CGFloat = 0
    @State private var height: CGFloat = 0
    @State private var dateRevealer = CalendarDateRevealer()
    var keyboard: CalendarKeyboardCursor? = nil
    @Environment(\.calendarFoldRanges) private var injectedFoldRanges
    // The hinge the system reports; empty unless built with the iOS 27.1 SDK on a folding device.
    @State private var systemFoldRanges: [ClosedRange<CGFloat>] = []
    @Environment(\.layoutDirection) private var layoutDirection

    private var foldRanges: [ClosedRange<CGFloat>] {
        injectedFoldRanges + systemFoldRanges
    }
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

    /// Width surrendered to an iPhone Duo fold, measured in this viewport's own coordinate space —
    /// already inside the safe area, so a fold is weighed against the space actually available.
    private var fold: CalendarFoldSpan {
        // The fold is physical; the insets below are applied as leading and trailing padding.
        CalendarFoldSpan.resolve(
            containerWidth: width,
            blocked: CalendarFoldSpan.leadingOrigin(
                foldRanges, containerWidth: width, layoutDirection: layoutDirection))
    }

    private var layout: CalendarViewportLayout {
        CalendarViewportLayout(
            width: width - fold.total, cellWidth: metrics.minCellSize, margins: softMargins,
            preferredSpacing: configuration.layout.preferredColumnSpacing ?? metrics.itemSpacing,
            minimumSpacing: configuration.layout.minimumColumnSpacing)
    }

    private var resolvedMetrics: CalendarMetrics {
        metrics.scalingSoftMargins(by: layout.marginScale).resolvingSpacing(layout.columnSpacing)
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
        CalendarViewportSize(
            idealHeight:
                metrics.resolvedHeight(rowCount: 6, layoutWidth: metrics.minCalendarWidth)
                + metrics.weekdayHeaderMinHeight + 3 * metrics.headerRowHeight
        ) {
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
                                max(0, width - fold.total - 2 * horizontalMargin)
                            )
                            .padding(.horizontal, horizontalMargin)
                            .frame(width: layout.contentWidth)
                    }
                }
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
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
                // Constrain the scroll view itself so overflow is clipped to the free band.
                // Padding its content would scroll the reserved space along with the day cells.
                .padding(.leading, fold.leading)
                .padding(.trailing, fold.trailing)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onGeometryChange(for: CGSize.self) { proxy in
                    proxy.size
                } action: { size in
                    width = size.width
                    height = size.height
                }
                // Measured on the same view as `width`, so the bands share its coordinate space.
                .modifier(SystemFoldReader(ranges: $systemFoldRanges))
                // Only keyboard-initiated movement asks to scroll; see `CalendarKeyboardCursor`.
                .onChange(of: keyboard?.scrollRequest) { _, request in
                    guard layout.overflows, let request, keyboard?.isActive == true else { return }
                    proxy.scrollTo(request.identity, anchor: .center)
                }
            }
        }
        // Vertical margins stay safe-area padding, exactly as before this viewport existed, so the
        // vertically scrolling body can still scroll content beneath them.
        .safeAreaPadding(.vertical, metrics.calendarMargin)
        .frame(minWidth: configuration.layout.overflow == .minimumSize ? layout.minimumWidth : nil)
        .onChange(of: layoutInfo, initial: true) { _, info in
            guard width > 0 else { return }
            layoutObserver?(info)
        }
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
