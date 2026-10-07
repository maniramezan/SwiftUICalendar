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
                        .environment(
                            \.calendarContentWidth, layout.contentWidth - 2 * metrics.calendarMargin
                        )
                        .padding(.horizontal, metrics.calendarMargin)
                        .frame(width: layout.contentWidth)
                }
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .defaultScrollAnchor(.leading)
            // Constrain the scroll view itself so overflow is clipped to the free band.
            // Padding its content would scroll the reserved space along with the day cells.
            .padding(.leading, fold.leading)
            .padding(.trailing, fold.trailing)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newWidth in
                width = newWidth
            }
            // Measured on the same view as `width`, so the bands share its coordinate space.
            .modifier(SystemFoldReader(ranges: $systemFoldRanges))
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

extension EnvironmentValues {
    /// The width the viewport gives the calendar's content, inside its soft margins; `nil` outside a
    /// viewport. A body that measured this itself could not settle: a grid wider than the space it
    /// was offered inflated the scroll view around it, which reported that width back and held the
    /// grid at its landscape size after rotating to portrait.
    @Entry var calendarContentWidth: CGFloat? = nil
}
