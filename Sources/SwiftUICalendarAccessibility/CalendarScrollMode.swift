/// Calendar scrolling behavior, shared with UI automation without importing SwiftUI.
public enum CalendarScrollMode: String, CaseIterable, Sendable {
    case none
    case vertical
    case horizontal

    // MARK: - Accessibility

    public var accessibilityIdentifier: String { "scroll-mode-\(rawValue)" }
}
