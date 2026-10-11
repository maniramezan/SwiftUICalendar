import SwiftUI

/// Gives an unbounded vertical host a useful ideal height, while honoring bounded hosts exactly.
/// A GeometryReader inside a host ScrollView otherwise accepts its 10pt ideal height.
struct CalendarViewportSize: Layout {
    /// Width used when the host proposes none: the narrowest readable grid.
    let idealWidth: CGFloat
    let idealHeight: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: proposal.width ?? idealWidth, height: proposal.height ?? idealHeight)
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
