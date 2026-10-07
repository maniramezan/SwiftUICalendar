import SwiftUI

// MARK: - Narrow Window Layout

/// How wide the calendar's scroll content is, and whether it overflows the viewport.
///
/// The safe area is excluded from `width`. The content-aware initializer compresses margins first,
/// then column gaps, and overflows only below the readable grid minimum.
struct CalendarViewportLayout: Equatable {
    let contentWidth: CGFloat
    let overflows: Bool
    /// Fraction of the soft margins to keep, from 0 to 1.
    let marginScale: CGFloat
    var columnSpacing: CGFloat = 8
    var minimumWidth: CGFloat = 0

    init(
        width: CGFloat, cellWidth: CGFloat, margins: CGFloat, preferredSpacing: CGFloat,
        minimumSpacing: CGFloat
    ) {
        let minimumGap = min(minimumSpacing, preferredSpacing)
        minimumWidth = 7 * cellWidth + 6 * minimumGap
        let preferredWidth = 7 * cellWidth + 6 * preferredSpacing
        overflows = width < minimumWidth
        columnSpacing = min(preferredSpacing, max(minimumGap, (width - 7 * cellWidth) / 6))
        marginScale = margins > 0 ? min(1, max(0, (width - preferredWidth) / margins)) : 1
        contentWidth = max(width, minimumWidth)
    }

    /// Legacy fixed-gap calculation retained for its original regression tests.
    /// - Parameters:
    ///   - width: Horizontal space inside the safe area.
    ///   - minimumWidth: Narrowest the day grid can be: seven minimum-size cells and their spacing.
    ///   - margins: Total soft margin around the grid, restored in full once the grid overflows.
    init(width: CGFloat, minimumWidth: CGFloat, margins: CGFloat = 0) {
        overflows = width < minimumWidth
        contentWidth = overflows ? minimumWidth + margins : width
        self.minimumWidth = minimumWidth
        if overflows || margins <= 0 {
            marginScale = 1
        } else {
            marginScale = min(1, max(0, (width - minimumWidth) / margins))
        }
    }
}
