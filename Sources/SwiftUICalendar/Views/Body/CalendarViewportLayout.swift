import SwiftUI

// MARK: - Narrow Window Layout

/// How wide the calendar's scroll content is, and whether it overflows the viewport.
///
/// The safe area is excluded from `width`. Margins compress first, then column gaps, and the grid
/// overflows only below the readable grid minimum. Once it overflows, the margins are restored in
/// full so the outer columns keep their inset at both scroll extremes instead of sitting flush
/// against the viewport edge.
struct CalendarViewportLayout: Equatable {
    let contentWidth: CGFloat
    let overflows: Bool
    /// Fraction of the soft margins to keep, from 0 to 1.
    let marginScale: CGFloat
    let columnSpacing: CGFloat
    let minimumWidth: CGFloat

    func horizontalOffsetToReveal(column: Int, viewportWidth: CGFloat) -> CGFloat {
        let cellWidth =
            (minimumWidth - CalendarGrid.columnGapCount * columnSpacing)
            / CalendarGrid.columnWidthDivisor
        let center =
            (contentWidth - minimumWidth) / 2 + cellWidth / 2
            + CGFloat(column) * (cellWidth + columnSpacing)
        return max(0, min(contentWidth - viewportWidth, center - viewportWidth / 2))
    }

    /// Seven readable columns separated by the narrowest gap the configuration allows.
    static func minimumWidth(
        cellWidth: CGFloat, preferredSpacing: CGFloat, minimumSpacing: CGFloat
    ) -> CGFloat {
        CalendarGrid.columnWidthDivisor * cellWidth
            + CalendarGrid.columnGapCount * min(minimumSpacing, preferredSpacing)
    }

    init(
        width: CGFloat, cellWidth: CGFloat, margins: CGFloat, preferredSpacing: CGFloat,
        minimumSpacing: CGFloat
    ) {
        let minimumGap = min(minimumSpacing, preferredSpacing)
        minimumWidth = Self.minimumWidth(
            cellWidth: cellWidth, preferredSpacing: preferredSpacing, minimumSpacing: minimumSpacing
        )
        let preferredWidth =
            CalendarGrid.columnWidthDivisor * cellWidth + CalendarGrid.columnGapCount
            * preferredSpacing
        overflows = width < minimumWidth
        columnSpacing = min(
            preferredSpacing,
            max(
                minimumGap,
                (width - CalendarGrid.columnWidthDivisor * cellWidth) / CalendarGrid.columnGapCount)
        )
        if overflows {
            // The content scrolls, so the margins can no longer push the grid below its floor.
            marginScale = 1
            contentWidth = minimumWidth + max(0, margins)
        } else {
            marginScale = margins > 0 ? min(1, max(0, (width - preferredWidth) / margins)) : 1
            contentWidth = width
        }
    }
}
