/// Day cell renderers demonstrated by the sample application, shared with UI automation.
public enum SampleDayViewMode: String, CaseIterable, Identifiable, Sendable {
    case circle
    case square

    public var id: String { rawValue }
    public var accessibilityIdentifier: String { "day-view-\(rawValue)" }

    public var title: String {
        switch self {
        case .circle: "Circle"
        case .square: "Square"
        }
    }
}
