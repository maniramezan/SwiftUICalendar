import OSLog
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

extension CalendarFoldSpan {
    /// `ranges`, measured from the container's physical left edge, re-expressed from its leading edge.
    ///
    /// A fold is physical — the hinge is where it is whatever the language — but the viewport applies
    /// its insets as leading and trailing padding, which SwiftUI flips in a right-to-left layout.
    /// Resolved in physical space, a Persian, Hebrew, or Islamic calendar chose the right band and was
    /// then padded onto the wrong side of it, straight across the fold. Resolving in leading-origin
    /// space keeps the selection, including its tie-break toward the leading band, right both ways.
    static func leadingOrigin(
        _ ranges: [ClosedRange<CGFloat>], containerWidth: CGFloat, layoutDirection: LayoutDirection
    ) -> [ClosedRange<CGFloat>] {
        guard layoutDirection == .rightToLeft else { return ranges }
        return ranges.map { (containerWidth - $0.upperBound)...(containerWidth - $0.lowerBound) }
    }
}

// MARK: - Fold Source

extension EnvironmentValues {
    /// Horizontal bands of the calendar's viewport that the grid must not occupy, measured from the
    /// viewport's physical left edge regardless of layout direction — where the hinge actually is.
    ///
    /// Tests inject folds here; on a device the system's hinge arrives through `SystemFoldReader`
    /// and is added to whatever this holds. Keeping band selection over plain ranges is what makes
    /// the displacement testable at all: `ReservedRegion` has no public initializer.
    @Entry var calendarFoldRanges: [ClosedRange<CGFloat>] = []
}

/// Reports the system's fold bands for the view it modifies, in that view's own physical
/// coordinates — the same space `calendarFoldRanges` uses.
///
/// `GeometryProxy.reservedRegions` exists only in the iOS 27.1 SDK. Swift has no SDK-version
/// conditional and 27.0 and 27.1 ship the same compiler, but they ship different SwiftUICore module
/// versions (8.0.84 and 8.0.85), and `canImport(_:_version:)` compares exactly that. So a build with
/// the 27.1 SDK or newer reads the hinge, while a 27.0 build — the CI runner's — compiles this to a
/// no-op instead of failing. The runtime `#available` check still guards older devices.
struct SystemFoldReader: ViewModifier {
    @Binding var ranges: [ClosedRange<CGFloat>]

    func body(content: Content) -> some View {
        #if os(iOS) && canImport(SwiftUICore, _version: 8.0.85)
            content.onGeometryChange(for: [ClosedRange<CGFloat>].self) { proxy in
                guard #available(iOS 27.1, *) else { return [] }
                // `.fixed`: the calendar handles right-to-left itself and expects physical coordinates.
                return proxy.reservedRegions(kind: .division, layoutDirectionBehavior: .fixed)
                    .filter(\.isActive)
                    .map { $0.frame.minX...$0.frame.maxX }
            } action: { newRanges in
                Logger.calendarUI.info(
                    "System fold bands changed: \(newRanges.count) active, \(String(describing: newRanges))"
                )
                ranges = newRanges
            }
        #else
            content
        #endif
    }
}
