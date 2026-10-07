import SwiftUI

// MARK: - Narrow Window Layout

/// How wide the calendar's scroll content is, and whether it overflows the viewport.
///
/// The safe area is excluded from `width`. Soft margins shrink while the grid fits, then return in
/// full once the grid overflows so the outer columns remain reachable.
struct CalendarViewportLayout: Equatable {
    let contentWidth: CGFloat
    let overflows: Bool
    /// Fraction of the soft margins to keep, from 0 to 1. Below 1 only while the grid fits with less
    /// than its full margins to spare: the margins give way so the grid keeps its minimum width.
    let marginScale: CGFloat

    /// - Parameters:
    ///   - width: Horizontal space inside the safe area.
    ///   - minimumWidth: Narrowest the day grid can be: seven minimum-size cells and their spacing.
    ///   - margins: Total soft margin around the grid, restored in full once the grid overflows.
    init(width: CGFloat, minimumWidth: CGFloat, margins: CGFloat = 0) {
        overflows = width < minimumWidth
        contentWidth = overflows ? minimumWidth + margins : width
        if overflows || margins <= 0 {
            marginScale = 1
        } else {
            marginScale = min(1, max(0, (width - minimumWidth) / margins))
        }
    }
}
