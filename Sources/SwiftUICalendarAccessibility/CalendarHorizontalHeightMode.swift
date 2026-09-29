/// How the horizontal pager resolves its height, shared with UI automation without importing SwiftUI.
///
/// `CalendarConfiguration.HorizontalHeightMode` is a type alias of this type, so configuration and
/// automation name the same cases.
public enum CalendarHorizontalHeightMode: String, CaseIterable, Sendable {
    case hugContent
    case sixRows

    public var accessibilityIdentifier: String { "horizontal-height-\(rawValue.lowercased())" }
}
