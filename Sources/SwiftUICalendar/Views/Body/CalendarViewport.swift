import SwiftUI

// MARK: - Narrow Window Layout

struct CalendarViewportLayout: Equatable {
    static let monthInset: CGFloat = 16

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
    @State private var width: CGFloat = 0
    @ViewBuilder let content: (Bool) -> Content

    private var layout: CalendarViewportLayout {
        CalendarViewportLayout(
            width: width,
            minimumWidth: metrics.minCalendarWidth
                + (configuration.scrollMode == .vertical
                    ? 2 * CalendarViewportLayout.monthInset : 0))
    }

    var body: some View {
        ScrollView(.horizontal) {
            content(!layout.overflows)
                .frame(width: layout.contentWidth)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .defaultScrollAnchor(.leading)
        .onGeometryChange(for: CGFloat.self) { geometry in
            geometry.size.width
        } action: { newWidth in
            width = newWidth
        }
    }
}
