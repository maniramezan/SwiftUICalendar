import SwiftUICalendarAccessibility
import XCTest

/// Base class for every sample UI test. Each test starts and ends in the same known state, so a
/// failure in one test (which `continueAfterFailure = false` cuts short mid-body) cannot leave the
/// device rotated or the app running for the next one — on any device, in any run order.
class SampleUITestCase: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        Self.resetDeviceAndApp()
    }

    override func tearDownWithError() throws {
        Self.resetDeviceAndApp()
    }

    /// Terminates any running instance of the app and returns the device to portrait.
    private static func resetDeviceAndApp() {
        XCUIApplication().terminate()
        XCUIDevice.shared.orientation = .portrait
    }
}

extension XCUIApplication {
    // MARK: - Calendar queries

    /// `nonisolated` so the identifier can be built off the main actor — every `XCUIApplication`
    /// member is main-actor isolated, and a test method is not.
    nonisolated func dayIdentifier(for date: Date) -> String {
        let components = Calendar(identifier: .gregorian).dateComponents(
            [.year, .month, .day], from: date)
        return CalendarAccessibilityID.day(
            year: components.year!, month: components.month!, day: components.day!)
    }

    nonisolated func dayButtons(inMonthContaining date: Date) -> XCUIElementQuery {
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
        openSettings(file: file, line: line)
        if let architecture {
            option(
                architecture.accessibilityIdentifier,
                in: CalendarSampleAccessibilityID.stateOwnerPicker, file: file, line: line
            ).tap()
        }
        let scroll = option(
            mode.accessibilityIdentifier, in: CalendarSampleAccessibilityID.scrollModePicker,
            file: file, line: line)
        scroll.tap()
        dismissSettings(file: file, line: line)
    }

    /// Resolves a segmented-control option inside the picker `pickerIdentifier`.
    ///
    /// Queries stay scoped to the picker's own identifier because an option's label also reads as
    /// the start of a longer row once that mode is active (the "Horizontal" scroll option next to
    /// the "Horizontal Height" row), so an app-wide query can resolve to the wrong element.
    ///
    /// The form is scrolled first and the picker is never awaited on its own: the picker's
    /// identifier rides a lazily-rendered row that only enters the hierarchy once the section
    /// scrolls into a short landscape sheet, so waiting for it up front deadlocks.
    func option(
        _ optionIdentifier: String, in pickerIdentifier: String,
        file: StaticString = #filePath, line: UInt = #line
    ) -> XCUIElement {
        let option = descendants(matching: .any)[pickerIdentifier].buttons[optionIdentifier]
        let form = scrollViews.firstMatch
        for _ in 0..<4 where !option.waitForExistence(timeout: 1) {
            form.swipeUp()
        }
        XCTAssertTrue(
            option.exists, "'\(optionIdentifier)' not found in '\(pickerIdentifier)'", file: file,
            line: line)
        return option
    }

    /// Opens the settings sheet or inspector, whichever the current width presents.
    func openSettings(file: StaticString = #filePath, line: UInt = #line) {
        let settings = buttons[CalendarSampleAccessibilityID.settings]
        XCTAssertTrue(
            settings.waitForExistence(timeout: 5), "Settings button not found", file: file,
            line: line)
        settings.tap()
    }

    /// Closes the compact sheet or regular-width inspector.
    func dismissSettings(file: StaticString = #filePath, line: UInt = #line) {
        let done = buttons[CalendarSampleAccessibilityID.done]
        if done.waitForExistence(timeout: 1) {
            done.tap()
            return
        }

        // The regular-width inspector has no Done — the Settings toolbar button toggles it closed.
        let settings = buttons[CalendarSampleAccessibilityID.settings]
        XCTAssertTrue(
            settings.waitForExistence(timeout: 5), "Settings button not found", file: file,
            line: line)
        settings.tap()
    }
}
