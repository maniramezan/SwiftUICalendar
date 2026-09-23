import SwiftUI

// MARK: - Viewport

/// Keeps every date reachable without reducing the grid's minimum touch targets.
/// The same scroll container remains mounted across the overflow boundary.
struct CalendarViewport<Content: View>: View {
    @Environment(\.calendarMetrics) private var metrics
    @Environment(\.calendarConfiguration) private var configuration
    // The viewport's measured width. Content is not laid out until it is known, so the content's
    // first layout pass already has the final width — never a placeholder width that a vertical
    // `LazyVStack` could settle empty on.
    @State private var width: CGFloat = 0
    var keyboard: CalendarKeyboardCursor? = nil
    @Environment(\.calendarFoldRanges) private var foldRanges
    @ViewBuilder let content: (Bool) -> Content

    /// Total soft margin around the grid. The vertically scrolling body insets each month as well.
    private var softMargins: CGFloat {
        2 * metrics.calendarMargin
            + (configuration.scrollMode == .vertical ? 2 * metrics.monthInset : 0)
    }

    /// Width surrendered to an iPhone Duo fold, measured in this viewport's own coordinate space —
    /// already inside the safe area, so a fold is weighed against the space actually available.
    private var fold: CalendarFoldSpan {
        CalendarFoldSpan.resolve(containerWidth: width, blocked: foldRanges)
    }

    private var layout: CalendarViewportLayout {
        CalendarViewportLayout(
            width: width - fold.total, minimumWidth: metrics.minCalendarWidth, margins: softMargins)
    }

    var body: some View {
        // The safe area is left to SwiftUI: the scroll view sits inside it — a notch or a host's
        // `.safeAreaPadding` alike — so its measured width is already the usable width. Two shapes
        // that handled it explicitly failed on device. Ignoring the horizontal safe area and padding
        // by the reported insets double-counted `.safeAreaPadding`, which that modifier does not let
        // a view ignore, pushing the grid off screen during a resize. And sizing the content with
        // `containerRelativeFrame` in that shape never finished laying out a right-to-left calendar:
        // Persian or Hebrew in landscape on a notched iPhone hung the app.
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                if width > 0 {
                    // Paging is handed back to the viewport only while the grid genuinely overflows, so
                    // a horizontal swipe scrolls to the clipped columns instead of flipping the month.
                    content(!layout.overflows)
                        .padding(.horizontal, metrics.calendarMargin)
                        .frame(width: layout.contentWidth)
                        // Displaces the calendar into the band beside the fold. The insets plus the
                        // band add back up to the viewport, so nothing overflows that would not anyway.
                        .padding(.leading, fold.leading)
                        .padding(.trailing, fold.trailing)
                }
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .defaultScrollAnchor(.leading)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newWidth in
                width = newWidth
            }
            // Only keyboard-initiated movement asks to scroll; see `CalendarKeyboardCursor`.
            .onChange(of: keyboard?.scrollRequest) { _, request in
                guard layout.overflows, let request, keyboard?.isActive == true else { return }
                proxy.scrollTo(request.identity, anchor: .center)
            }
        }
        // Vertical margins stay safe-area padding, exactly as before this viewport existed, so the
        // vertically scrolling body can still scroll content beneath them.
        .safeAreaPadding(.vertical, metrics.calendarMargin)
    }
}
