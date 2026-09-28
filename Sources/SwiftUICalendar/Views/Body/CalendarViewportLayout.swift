import SwiftUI

// MARK: - Narrow Window Layout

/// How wide the calendar's scroll content is, and whether it overflows the viewport.
///
/// The safe area is excluded from `width`. Soft margins shrink while the grid fits, then return in
/// full once the grid overflows so the outer columns remain reachable.
struct CalendarViewportLayout: Equatable {
    let contentWidth: CGFloat
    let overflows: Bool

    /// - Parameters:
    ///   - width: Horizontal space inside the safe area.
    ///   - minimumWidth: Narrowest the day grid can be: seven minimum-size cells and their spacing.
    ///   - margins: Total soft margin around the grid, restored in full once the grid overflows.
    init(width: CGFloat, minimumWidth: CGFloat, margins: CGFloat = 0) {
        overflows = width < minimumWidth
        contentWidth = overflows ? minimumWidth + margins : width
    }
}
