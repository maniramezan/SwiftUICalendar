import SwiftUI

/// Gives an unbounded vertical host a useful ideal height, while honoring bounded hosts exactly.
/// A GeometryReader inside a host ScrollView otherwise accepts its 10pt ideal height.
struct CalendarViewportSize: Layout {
    /// Width used when the host proposes none: the narrowest readable grid.
    let idealWidth: CGFloat
    /// Height used when the host proposes none, resolved for the width the calendar is given.
    let idealHeight: CalendarIdealHeight

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? idealWidth
        return CGSize(width: width, height: proposal.height ?? idealHeight(width))
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        for subview in subviews {
            subview.place(
                at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(bounds.size))
        }
    }
}

/// The height a host that proposes none gives the calendar, resolved for the width it is given.
///
/// A regular-width iPad's fixed month grows with the width, so its height follows the grown cells
/// instead of the phone-sized grid. A value rather than a closure, because `Layout` is `Sendable`.
struct CalendarIdealHeight: Sendable {
    let metrics: CalendarMetrics
    let showsHeader: Bool
    let growsCells: Bool
    /// Visible height of the scroll view hosting the calendar, `nil` outside one.
    let hostHeight: CGFloat?

    func callAsFunction(_ width: CGFloat) -> CGFloat {
        if growsCells {
            return metrics.idealGrownHeight(
                width: width, hostHeight: hostHeight.map { $0 - 2 * metrics.calendarMargin },
                controls: metrics.controlsHeight(showsHeader: showsHeader))
        }
        return metrics.resolvedHeight(
            rowCount: CalendarGrid.maximumRowCount, layoutWidth: metrics.minCalendarWidth)
            + metrics.weekdayHeaderMinHeight + 3 * metrics.headerRowHeight
    }
}
