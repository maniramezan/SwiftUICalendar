import SwiftUI

// MARK: - Fold Avoidance

/// How much of a container's width the calendar gives up to stay clear of a fold.
///
/// On iPhone Duo a partially folded inner display reports a *division* reserved region where the
/// hinge crosses it. Content spanning that band is hard to read and controls landing in it are hard
/// to tap, so the calendar displaces itself into the widest band beside the fold instead of straddling
/// it — the pattern Apple's Human Interface Guidelines call *displacement*. A week therefore still
/// reads as one row, and if the chosen band is narrower than the grid's minimum width, the enclosing
/// ``CalendarViewport`` scrolls horizontally exactly as it does in any other narrow window.
///
/// Resolving the band is pure geometry over plain ranges: `ReservedRegion` has no public
/// initializer, so the algorithm cannot be exercised with real regions in a test.
struct CalendarFoldSpan: Equatable, Sendable {
    /// Width given up at the container's leading edge.
    var leading: CGFloat = 0
    /// Width given up at the container's trailing edge.
    var trailing: CGFloat = 0

    /// No fold to avoid: the calendar uses the whole container.
    static let none = CalendarFoldSpan()

    /// Total width given up.
    var total: CGFloat { leading + trailing }

    /// Resolves the widest band of `0...containerWidth` that avoids every blocked range.
    ///
    /// `blocked` ranges are in the container's own coordinate space and may overlap or extend past
    /// its edges. When no band is left — a fold covering everything — the container is returned
    /// whole, because displacing to a zero-width band would render nothing at all.
    static func resolve(containerWidth: CGFloat, blocked: [ClosedRange<CGFloat>])
        -> CalendarFoldSpan
    {
        guard containerWidth > 0 else { return .none }

        // Clamp to the container and drop anything that misses it, then merge overlaps so the gaps
        // between consecutive bands are the genuinely free spans.
        let clamped =
            blocked
            .compactMap { range -> ClosedRange<CGFloat>? in
                let lower = max(range.lowerBound, 0)
                let upper = min(range.upperBound, containerWidth)
                guard upper > lower else { return nil }
                return lower...upper
            }
            .sorted { $0.lowerBound < $1.lowerBound }

        guard !clamped.isEmpty else { return .none }

        var merged: [ClosedRange<CGFloat>] = []
        for range in clamped {
            if let last = merged.last, range.lowerBound <= last.upperBound {
                merged[merged.count - 1] = last.lowerBound...max(last.upperBound, range.upperBound)
            } else {
                merged.append(range)
            }
        }

        var best = (origin: CGFloat(0), width: CGFloat(0))
        var cursor: CGFloat = 0
        for range in merged {
            let width = range.lowerBound - cursor
            if width > best.width { best = (cursor, width) }
            cursor = max(cursor, range.upperBound)
        }
        let trailingWidth = containerWidth - cursor
        if trailingWidth > best.width { best = (cursor, trailingWidth) }

        guard best.width > 0 else { return .none }
        return CalendarFoldSpan(
            leading: best.origin, trailing: containerWidth - best.origin - best.width)
    }
}

// MARK: - Fold Source

extension EnvironmentValues {
    /// Horizontal bands of the calendar's container that the grid must not occupy, in the container's
    /// own coordinate space.
    ///
    /// This is the seam where an iPhone Duo fold enters the layout. Reading the hinge from the system
    /// needs `GeometryProxy.reservedRegions(kind: .division)`, which exists only in the iOS 27.1 SDK
    /// and therefore cannot be referenced while the project still builds against 27.0. Keeping the
    /// source injected rather than called inline means the displacement behavior is complete, live and
    /// testable on every platform today, and switching it on later adds one availability-gated line
    /// that populates this value.
    @Entry var calendarFoldRanges: [ClosedRange<CGFloat>] = []
}
