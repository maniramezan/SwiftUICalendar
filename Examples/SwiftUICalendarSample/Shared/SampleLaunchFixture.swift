import Foundation
import SwiftUICalendarAccessibility

/// Launch arguments that start the sample already configured.
///
/// UI tests that are not about the settings panel pass these instead of driving it: opening the
/// panel, picking three options and dismissing it cost about 18 seconds per launch on a local
/// simulator, more than the checks that followed. Each key is read from the argument domain of
/// `UserDefaults` (`-calendar-architecture tca`); an absent or unknown value keeps the default.
enum SampleLaunchFixture {
    static let architectureKey = "calendar-architecture"
    static let selectionModeKey = "calendar-selection-mode"
    static let scrollModeKey = "calendar-scroll-mode"

    /// The launch arguments that select each given value.
    static func arguments(
        architecture: SampleArchitecture, selectionMode: SampleSelectionMode,
        scrollMode: CalendarScrollMode
    ) -> [String] {
        [
            "-\(architectureKey)", architecture.rawValue,
            "-\(selectionModeKey)", selectionMode.rawValue,
            "-\(scrollModeKey)", scrollMode.rawValue,
        ]
    }

    static func value<Value: RawRepresentable>(
        forKey key: String, in defaults: UserDefaults = .standard
    ) -> Value? where Value.RawValue == String {
        defaults.string(forKey: key).flatMap(Value.init(rawValue:))
    }
}
