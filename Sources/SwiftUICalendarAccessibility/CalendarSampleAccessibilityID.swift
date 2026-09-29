import Foundation

/// Identifiers for the sample application's configuration controls.
public enum CalendarSampleAccessibilityID {
    public static let settings = "calendar-sample-settings"
    public static let done = "calendar-sample-done"
    public static let stateOwnerPicker = "state-owner-picker"
    public static let calendarPicker = "calendar-picker"
    public static let selectionPicker = "selection-mode-picker"
    public static let scrollModePicker = "scroll-mode-picker"
    public static let dayViewPicker = "day-view-picker"
    public static let horizontalHeightPicker = "horizontal-height-picker"

    public static func calendarOption(_ identifier: Calendar.Identifier) -> String {
        "calendar-option-\(identifier)"
    }
}
