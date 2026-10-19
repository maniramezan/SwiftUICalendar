import Foundation

/// Identifiers for the sample application's configuration controls.
enum CalendarSampleAccessibilityID {
    static let settings = "calendar-sample-settings"
    static let done = "calendar-sample-done"
    static let stateOwnerPicker = "state-owner-picker"
    static let calendarPicker = "calendar-picker"
    static let selectionPicker = "selection-mode-picker"
    static let scrollModePicker = "scroll-mode-picker"
    static let dayViewPicker = "day-view-picker"
    static let horizontalHeightPicker = "horizontal-height-picker"

    static func calendarOption(_ identifier: Calendar.Identifier) -> String {
        "calendar-option-\(identifier)"
    }
}
