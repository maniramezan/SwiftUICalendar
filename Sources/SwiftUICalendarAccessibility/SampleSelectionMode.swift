/// Selection behaviors demonstrated by the sample application, shared with UI automation.
public enum SampleSelectionMode: String, CaseIterable, Identifiable, Sendable {
    case single
    case range
    case multiple

    public var id: String { rawValue }
    public var accessibilityIdentifier: String { "selection-mode-\(rawValue)" }

    public var title: String {
        switch self {
        case .single: "Single"
        case .range: "Range"
        case .multiple: "Multiple"
        }
    }
}
