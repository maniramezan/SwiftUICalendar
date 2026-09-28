import SwiftUICalendarAccessibility
import XCTest

extension XCUIApplication {
    // MARK: - Calendar queries

    func dayIdentifier(for date: Date) -> String {
        let components = Calendar(identifier: .gregorian).dateComponents(
            [.year, .month, .day], from: date)
        return CalendarAccessibilityID.day(
            year: components.year!, month: components.month!, day: components.day!)
    }

    func dayButtons(inMonthContaining date: Date) -> XCUIElementQuery {
        let components = Calendar(identifier: .gregorian).dateComponents(
            [.year, .month], from: date)
        return buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@",
                CalendarAccessibilityID.dayMonthPrefix(
                    year: components.year!, month: components.month!)))
    }

    // MARK: - Settings

    /// Selects a scroll mode from the settings sheet and dismisses it.
    ///
    /// The settings form is lazy, and in a landscape-height sheet the layout section starts below the
    /// fold, so its options only enter the hierarchy once the form is scrolled to them.
    func chooseScrollMode(
        _ mode: CalendarScrollMode, architecture: SampleArchitecture? = nil,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let settings = buttons[CalendarSampleAccessibilityID.settings]
        XCTAssertTrue(
            settings.waitForExistence(timeout: 5), "Settings button not found", file: file,
            line: line)
        settings.tap()
        if let architecture {
            let picker = segmentedControls[CalendarSampleAccessibilityID.stateOwnerPicker]
            XCTAssertTrue(picker.waitForExistence(timeout: 5), file: file, line: line)
            picker.buttons[architecture.accessibilityIdentifier].tap()
        }
        let option = segmentedControls[CalendarSampleAccessibilityID.scrollModePicker]
            .buttons[mode.accessibilityIdentifier]
        let form = collectionViews.firstMatch
        for _ in 0..<4 where !option.waitForExistence(timeout: 1) {
            form.swipeUp()
        }
        XCTAssertTrue(
            option.exists, "scroll mode '\(mode)' not found in settings", file: file, line: line)
        option.tap()
        buttons[CalendarSampleAccessibilityID.done].tap()
    }
}
