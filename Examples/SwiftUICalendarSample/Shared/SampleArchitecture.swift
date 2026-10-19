/// State ownership options demonstrated by the sample application.
enum SampleArchitecture: String, CaseIterable, Identifiable, Sendable {
    case mvvm
    case tca

    var id: String { rawValue }
    var accessibilityIdentifier: String { "state-owner-\(rawValue)" }

    var title: String {
        switch self {
        case .mvvm: "MVVM"
        case .tca: "TCA"
        }
    }
}
