/// Day cell renderers demonstrated by the sample application, shared with UI automation.
enum SampleDayViewMode: String, CaseIterable, Identifiable, Sendable {
    case circle
    case square

    var id: String { rawValue }
    var accessibilityIdentifier: String { "day-view-\(rawValue)" }

    var title: String {
        switch self {
        case .circle: "Circle"
        case .square: "Square"
        }
    }
}
