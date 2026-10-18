import SwiftUI

/// A noninteractive ribbon behind built-in range cells. Open ends round off at row/month breaks.
struct CalendarRangeBand: View {
    @Environment(\.layoutDirection) private var layoutDirection
    let position: CalendarRangePosition
    let columnWidth: CGFloat
    let gap: CGFloat
    let height: CGFloat
    let joinsLeading: Bool
    let joinsTrailing: Bool
    let color: Color

    var body: some View {
        let geometry = CalendarRangeBandGeometry(
            position: position, columnWidth: columnWidth, gap: gap, height: height,
            joinsLeading: joinsLeading, joinsTrailing: joinsTrailing,
            rightToLeft: layoutDirection == .rightToLeft)
        // Position in physical coordinates because the geometry already mirrors for RTL.
        Path { path in
            let rect = geometry.rect
            guard !rect.isEmpty else { return }
            let left = geometry.roundsLeft ? rect.height / 2 : 0
            let right = geometry.roundsRight ? rect.height / 2 : 0
            path.move(to: CGPoint(x: rect.minX + left, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - right, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.midY),
                control: CGPoint(x: rect.maxX, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - right, y: rect.maxY),
                control: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + left, y: rect.maxY))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.midY),
                control: CGPoint(x: rect.minX, y: rect.maxY))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + left, y: rect.minY),
                control: CGPoint(x: rect.minX, y: rect.minY))
            path.closeSubpath()
        }
        .fill(color.opacity(0.18))
        // The geometry above has already mirrored. Path itself must render in physical coordinates.
        .environment(\.layoutDirection, .leftToRight)
        .frame(width: columnWidth, height: height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
