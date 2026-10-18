import Foundation

/// Geometry for the calendar-owned range background, including the space between day columns.
/// Day renderers still receive exactly their normal cell proposal.
struct CalendarRangeBandGeometry: Equatable {
    let rect: CGRect
    let roundsLeft: Bool
    let roundsRight: Bool

    init(
        position: CalendarRangePosition, columnWidth: CGFloat, gap: CGFloat, height: CGFloat,
        joinsLeading: Bool, joinsTrailing: Bool, rightToLeft: Bool
    ) {
        let leading = joinsLeading ? -gap / 2 : 0
        let trailing = columnWidth + (joinsTrailing ? gap / 2 : 0)
        let start = position == .start ? columnWidth / 2 : leading
        let end = position == .end ? columnWidth / 2 : trailing
        let hasBand =
            position != .startAndEnd
            && (position == .interior || joinsLeading || joinsTrailing)
        let width = hasBand ? max(0, end - start) : 0
        rect = CGRect(
            x: rightToLeft ? columnWidth - start - width : start,
            y: 0, width: width, height: height)
        roundsLeft = rightToLeft ? !joinsTrailing : !joinsLeading
        roundsRight = rightToLeft ? !joinsLeading : !joinsTrailing
    }
}
