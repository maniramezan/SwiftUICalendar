/// State ownership options demonstrated by the sample application.
public enum SampleArchitecture: String, CaseIterable, Identifiable, Sendable {
    case mvvm
    case tca

    public var id: String { rawValue }
    public var accessibilityIdentifier: String { "state-owner-\(rawValue)" }

    public var title: String {
        switch self {
        case .mvvm: "MVVM"
        case .tca: "TCA"
        }
    }
}
