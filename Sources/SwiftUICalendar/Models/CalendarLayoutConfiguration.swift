import SwiftUI

/// Spacing and overflow behavior, independent of visual styling.
public struct CalendarLayoutConfiguration: Equatable, Sendable {
    public enum Overflow: Equatable, Sendable {
        /// Scroll columns only when readable content and minimum spacing cannot fit.
        case automatic
        /// Request the required width. The host owns overflow and date reachability.
        case minimumSize
    }

    /// The gap between day columns when the container has room for it.
    ///
    /// `nil` uses the design theme's item spacing.
    public let preferredColumnSpacing: CGFloat?
    /// The narrowest gap columns may shrink to before the grid overflows its container.
    ///
    /// Never larger than ``preferredColumnSpacing``.
    public let minimumColumnSpacing: CGFloat
    /// What happens when seven readable columns and their minimum spacing do not fit.
    public let overflow: Overflow

    /// The minimum column spacing used when none is given or the given value is not finite.
    @usableFromInline static let defaultMinimumColumnSpacing: CGFloat = 4

    /// A nil preferred spacing uses the design theme. Invalid spacing is normalized to defaults.
    public init(
        preferredColumnSpacing: CGFloat? = nil,
        minimumColumnSpacing: CGFloat = Self.defaultMinimumColumnSpacing,
        overflow: Overflow = .automatic
    ) {
        let preferred = preferredColumnSpacing.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
        self.preferredColumnSpacing = preferred
        let minimum =
            minimumColumnSpacing.isFinite
            ? max(0, minimumColumnSpacing) : Self.defaultMinimumColumnSpacing
        self.minimumColumnSpacing = min(minimum, preferred ?? minimum)
        self.overflow = overflow
    }
}

/// The resolved horizontal sizing contract. Heights depend on the displayed month's rows.
public struct CalendarLayoutInfo: Equatable, Sendable {
    /// The narrowest width that fits seven readable columns at the minimum column spacing.
    public let minimumWidth: CGFloat
    /// The smallest day cell that keeps the day content readable at the current Dynamic Type size.
    public let minimumCellSize: CGSize
    /// The gap between day columns the calendar resolved for the current width.
    public let columnSpacing: CGFloat
    /// Whether the grid is wider than the calendar, so the calendar scrolls its columns.
    ///
    /// Always `false` with ``CalendarLayoutConfiguration/Overflow/minimumSize``: the calendar
    /// requests ``minimumWidth`` instead, and any overflow belongs to the host.
    public let overflowsHorizontally: Bool
}

extension EnvironmentValues {
    var calendarLayoutObserver: (@MainActor (CalendarLayoutInfo) -> Void)? {
        get { self[CalendarLayoutObserverKey.self] }
        set { self[CalendarLayoutObserverKey.self] = newValue }
    }
}

private struct CalendarLayoutObserverKey: EnvironmentKey {
    static let defaultValue: (@MainActor (CalendarLayoutInfo) -> Void)? = nil
}

extension View {
    /// Observes sizing changes, including the minimum width a host-owned layout must provide.
    public func onCalendarLayoutChange(
        _ action: @escaping @MainActor (CalendarLayoutInfo) -> Void
    ) -> some View {
        environment(\.calendarLayoutObserver, action)
    }
}
