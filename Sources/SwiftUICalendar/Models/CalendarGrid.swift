import Foundation

/// Structural constants of a month grid.
///
/// The seven-day week is the grid's *shape*, not a layout preference: cell sizing, month geometry,
/// and keyboard navigation all assume seven columns and six inter-column gaps. Naming the pair once
/// keeps them from drifting apart when any one of those call sites is edited — a grid widened to
/// eight columns in the layout math and left at seven in the geometry builder would silently render
/// the wrong week.
///
/// These are counts, so they are not theme tokens: no brand has a "different number of weekdays".
enum CalendarGrid {
    /// Day columns in a month grid, one per weekday.
    static let columnCount = 7

    /// Gaps *between* day columns.
    ///
    /// One fewer than ``columnCount``, because a row of columns carries no trailing gap.
    static let gapCount = columnCount - 1

    /// The most week-rows a single month can span.
    ///
    /// The longest month is 31 days, and the grid may lead with up to ``columnCount`` - 1 overflow
    /// days from the previous month, so 37 cells — exactly six rows. Pinning to this keeps a
    /// fixed-height month from reserving a seventh row that no month can fill.
    static let maximumRowCount = 6
}

extension CalendarGrid {
    /// ``columnCount`` as a `CGFloat`, for the column-width arithmetic in grid layout.
    static let columnWidthDivisor = CGFloat(columnCount)

    /// ``gapCount`` as a `CGFloat`, for the total-inter-column-spacing arithmetic in grid layout.
    static let columnGapCount = CGFloat(gapCount)
}
