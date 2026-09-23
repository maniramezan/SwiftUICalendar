import SwiftUI

// MARK: - Narrow Window Layout

/// How wide the calendar's scroll content is, and whether it overflows the viewport.
///
/// Two kinds of horizontal space surround the day grid, and they give way in different orders:
///
/// - *Hard* insets — the device safe area — are never occupied. They are subtracted before `width`
///   reaches this type.
/// - *Soft* margins — the calendar's own margin and, in the vertically scrolling body, each month's
///   inset — are decoration. They shrink first: while the bare grid still fits, the grid spreads into
///   them and every cell stays on screen without scrolling.
///
/// Only when the grid itself no longer fits does the viewport scroll, and then the content carries
/// its full soft margins so the outermost columns are reachable rather than cut off.
struct CalendarViewportLayout: Equatable {
    let contentWidth: CGFloat
    let overflows: Bool

    /// - Parameters:
    ///   - width: Horizontal space left after hard insets.
    ///   - minimumWidth: Narrowest the day grid can be: seven minimum-size cells and their spacing.
    ///   - margins: Total soft margin around the grid, restored in full once the grid overflows.
    init(width: CGFloat, minimumWidth: CGFloat, margins: CGFloat = 0) {
        overflows = width < minimumWidth
        contentWidth = overflows ? minimumWidth + margins : width
    }
}

/// What the viewport knows about its own frame, read in a single geometry pass.
///
/// File-scope rather than nested in the generic ``CalendarViewport``: a nested type would make the
/// nonisolated geometry closure capture the view's `Content` metatype.
private struct CalendarViewportGeometry: Equatable {
    var width: CGFloat = 0
    var safeArea = EdgeInsets()
}

/// Keeps every date reachable without reducing the grid's minimum touch targets.
/// The same scroll container remains mounted across the overflow boundary.
struct CalendarViewport<Content: View>: View {
    @Environment(\.calendarMetrics) private var metrics
    @Environment(\.calendarConfiguration) private var configuration
    // The viewport's own width and safe area. Content is not laid out until this is measured, so
    // its first layout pass already has the final width — never a placeholder width that a vertical
    // `LazyVStack` could settle empty on.
    @State private var geometry = CalendarViewportGeometry()
    @ViewBuilder let content: (Bool) -> Content

    /// Total soft margin around the grid. The vertically scrolling body insets each month as well.
    private var softMargins: CGFloat {
        2 * metrics.calendarMargin
            + (configuration.scrollMode == .vertical ? 2 * metrics.monthInset : 0)
    }

    private var hardInsets: EdgeInsets { geometry.safeArea }

    private var layout: CalendarViewportLayout {
        CalendarViewportLayout(
            width: geometry.width - hardInsets.leading - hardInsets.trailing,
            minimumWidth: metrics.minCalendarWidth,
            margins: softMargins
        )
    }

    var body: some View {
        let hard = hardInsets
        ScrollView(.horizontal) {
            if geometry.width > 0 {
                // Paging is handed back to the viewport only while the grid genuinely overflows, so
                // a horizontal swipe scrolls to the clipped columns instead of flipping the month.
                content(!layout.overflows)
                    .padding(.horizontal, metrics.calendarMargin)
                    // Sized from the measured width rather than `containerRelativeFrame`, which never
                    // finished laying out in a right-to-left calendar once this scroll view ignored a
                    // horizontal safe area: Persian or Hebrew on a notched iPhone in landscape hung.
                    .frame(width: layout.contentWidth)
                    .padding(.leading, hard.leading)
                    .padding(.trailing, hard.trailing)
            }
        }
        // The horizontal safe area is applied above, explicitly, so it is subtracted exactly once.
        // Left to the scroll view it becomes content margins on top of the measured width, and the
        // grid ends up sized for space it does not actually have.
        .ignoresSafeArea(.container, edges: .horizontal)
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .defaultScrollAnchor(.leading)
        .onGeometryChange(for: CalendarViewportGeometry.self) { proxy in
            CalendarViewportGeometry(width: proxy.size.width, safeArea: proxy.safeAreaInsets)
        } action: { newGeometry in
            geometry = newGeometry
        }
        // Vertical margins stay safe-area padding, exactly as before this viewport existed, so the
        // vertically scrolling body can still scroll content beneath them.
        .safeAreaPadding(.vertical, metrics.calendarMargin)
    }
}
