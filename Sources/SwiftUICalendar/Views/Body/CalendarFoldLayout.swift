import SwiftUI

/// Places complete months in the usable panels around a division, in physical coordinates.
struct CalendarFoldLayout: Equatable {
    enum Mode: String {
        case single
        case book
        case tabletop
    }

    let mode: Mode
    let primary: CGRect
    let secondary: CGRect?

    static func resolve(
        size: CGSize, blocked: [CGRect], minimumPaneSize: CGSize,
        allowsCompanion: Bool, layoutDirection: LayoutDirection
    ) -> CalendarFoldLayout {
        let bounds = CGRect(origin: .zero, size: size)
        let divisions = blocked.compactMap { frame -> (frame: CGRect, vertical: Bool)? in
            guard !frame.isInfinite, !frame.isNull, frame.width > 0, frame.height > 0 else {
                return nil
            }
            let intersection = bounds.intersection(frame)
            guard !intersection.isNull, !intersection.isEmpty else { return nil }
            return (intersection, frame.height >= frame.width)
        }
        var panels = [bounds]
        for division in divisions {
            panels = panels.flatMap { panel -> [CGRect] in
                guard panel.intersects(division.frame) else { return [panel] }
                if division.vertical {
                    return [
                        CGRect(
                            x: panel.minX, y: panel.minY,
                            width: max(0, division.frame.minX - panel.minX), height: panel.height),
                        CGRect(
                            x: max(panel.minX, division.frame.maxX), y: panel.minY,
                            width: max(0, panel.maxX - division.frame.maxX), height: panel.height),
                    ].filter { !$0.isEmpty }
                }
                return [
                    CGRect(
                        x: panel.minX, y: panel.minY, width: panel.width,
                        height: max(0, division.frame.minY - panel.minY)),
                    CGRect(
                        x: panel.minX, y: max(panel.minY, division.frame.maxY), width: panel.width,
                        height: max(0, panel.maxY - division.frame.maxY)),
                ].filter { !$0.isEmpty }
            }
        }
        panels.sort { first, second in
            if first.minY != second.minY { return first.minY < second.minY }
            return layoutDirection == .rightToLeft
                ? first.minX > second.minX : first.minX < second.minX
        }
        if allowsCompanion, divisions.count == 1, panels.count == 2,
            panels.allSatisfy({
                $0.width >= minimumPaneSize.width && $0.height >= minimumPaneSize.height
            })
        {
            return CalendarFoldLayout(
                mode: divisions[0].vertical ? .book : .tabletop,
                primary: panels[0], secondary: panels[1])
        }
        let largest = panels.reduce(nil as CGRect?) { best, panel in
            guard let best else { return panel }
            return panel.width * panel.height > best.width * best.height ? panel : best
        }
        return CalendarFoldLayout(mode: .single, primary: largest ?? bounds, secondary: nil)
    }
}

/// Preserves the primary subtree while the same children move between fold panels.
struct CalendarFoldPlacement: Layout {
    let size: CGSize
    let fold: CalendarFoldLayout

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        size
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        for (index, subview) in subviews.enumerated() {
            let frame = index == 0 ? fold.primary : fold.secondary ?? .zero
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                anchor: .topLeading, proposal: ProposedViewSize(frame.size))
        }
    }
}
