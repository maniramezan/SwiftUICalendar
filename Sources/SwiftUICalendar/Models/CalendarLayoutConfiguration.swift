import SwiftUI

/// Spacing and overflow behavior, independent of visual styling.
public struct CalendarLayoutConfiguration: Equatable, Sendable {
    public enum Overflow: Equatable, Sendable {
        /// Scroll columns only when readable content and minimum spacing cannot fit.
        case automatic
        /// Request the required width. The host owns overflow and date reachability.
        case minimumSize
    }

    public let preferredColumnSpacing: CGFloat?
    public let minimumColumnSpacing: CGFloat
    public let overflow: Overflow

    /// A nil preferred spacing uses the design theme. Invalid spacing is normalized to defaults.
    public init(
        preferredColumnSpacing: CGFloat? = nil,
        minimumColumnSpacing: CGFloat = 4,
        overflow: Overflow = .automatic
    ) {
        let preferred = preferredColumnSpacing.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
        self.preferredColumnSpacing = preferred
        let minimum = minimumColumnSpacing.isFinite ? max(0, minimumColumnSpacing) : 4
        self.minimumColumnSpacing = min(minimum, preferred ?? minimum)
        self.overflow = overflow
    }
}

/// The resolved horizontal sizing contract. Heights depend on the displayed month's rows.
public struct CalendarLayoutInfo: Equatable, Sendable {
    public let minimumWidth: CGFloat
    public let minimumCellSize: CGSize
    public let columnSpacing: CGFloat
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
