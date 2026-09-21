import SwiftUI

// MARK: - Narrow Window Layout

struct CalendarViewportLayout: Equatable {
    let contentWidth: CGFloat
    let overflows: Bool

    init(width: CGFloat, minimumWidth: CGFloat) {
        contentWidth = max(width, minimumWidth)
        overflows = width < minimumWidth
    }
}

/// Keeps every date reachable without reducing the grid's minimum touch targets.
/// The same scroll container remains mounted across the overflow boundary.
struct CalendarViewport<Content: View>: View {
    @Environment(\.calendarMetrics) private var metrics
    @Environment(\.calendarConfiguration) private var configuration
    // Gesture arbitration only. Layout does not read this, so a viewport that has not been measured
    // yet still lays its content out at the correct width on the very first pass.
    @State private var allowsPaging = true
    @ViewBuilder let content: (Bool) -> Content

    /// Narrowest width the calendar can occupy before the viewport starts scrolling horizontally.
    ///
    /// The vertically scrolling body insets each month, so its grid needs that inset back on top of
    /// the bare seven-column minimum.
    private var minimumWidth: CGFloat {
        metrics.minCalendarWidth
            + (configuration.scrollMode == .vertical ? 2 * metrics.monthInset : 0)
    }

    var body: some View {
        // Bound here rather than read inside the closures below: both run outside the main actor,
        // so they capture this plain `CGFloat` instead of `self`.
        let minimumWidth = minimumWidth
        ScrollView(.horizontal) {
            content(allowsPaging)
                // Resolved against the scroll viewport during layout, so the first pass already has
                // the final width. Reading the width into `@State` instead lays the whole body out
                // once at a placeholder width and again after the geometry callback lands — and the
                // vertical body's `LazyVStack` can settle as empty on that first pass, leaving a
                // blank calendar until something else invalidates it.
                .containerRelativeFrame(.horizontal) { length, _ in
                    CalendarViewportLayout(width: length, minimumWidth: minimumWidth).contentWidth
                }
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .defaultScrollAnchor(.leading)
        // Paging is handed back to the viewport only while the grid genuinely overflows, so a
        // horizontal swipe scrolls to the clipped columns instead of flipping the month.
        .onGeometryChange(for: Bool.self) { geometry in
            !CalendarViewportLayout(width: geometry.size.width, minimumWidth: minimumWidth)
                .overflows
        } action: { fits in
            allowsPaging = fits
        }
    }
}
