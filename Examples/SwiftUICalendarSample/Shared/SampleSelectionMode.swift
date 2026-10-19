/// Selection behaviors demonstrated by the sample application, shared with UI automation.
enum SampleSelectionMode: String, CaseIterable, Identifiable, Sendable {
    case single
    case range
    case multiple

    var id: String { rawValue }
    var accessibilityIdentifier: String { "selection-mode-\(rawValue)" }

    var title: String {
        switch self {
        case .single: "Single"
        case .range: "Range"
        case .multiple: "Multiple"
        }
    }
}
