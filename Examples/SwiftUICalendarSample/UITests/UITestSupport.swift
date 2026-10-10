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
    /// Longest the settings panel is given to appear before the toggle is tapped again.
    fileprivate static let settingsPresentationTimeout: TimeInterval = 6
    fileprivate static let settingsRetryTaps = 2

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

    /// Resolves a segmented-control option by its own accessibility identifier.
    ///
    /// The lookup is by identifier, not scoped to the picker: iPhone exposes a segmented control's
    /// options as children of the picker, but iPad exposes them as sibling buttons next to a childless
    /// picker, so a picker-scoped query only ever worked on iPhone. Option identifiers are unique
    /// (`scroll-mode-horizontal` is not the "Horizontal Height" row), and `matching(identifier:)`
    /// never falls back to a label, so the query cannot resolve to a longer row that merely starts
    /// with the same text. `pickerIdentifier` only names the picker in a failure message.
    ///
    /// The form is scrolled first and the picker is never awaited on its own: the picker's
    /// identifier rides a lazily-rendered row that only enters the hierarchy once the section
    /// scrolls into a short landscape sheet, so waiting for it up front deadlocks.
    func option(
        _ optionIdentifier: String, in pickerIdentifier: String,
        file: StaticString = #filePath, line: UInt = #line
    ) -> XCUIElement {
        let option = buttons.matching(identifier: optionIdentifier).firstMatch
        let form = scrollViews.firstMatch
        for _ in 0..<4 where !option.waitForExistence(timeout: 1) {
            form.swipeUp()
        }
        // `openSettings` has already confirmed the panel is up; give a slow form time to render.
        _ = option.waitForExistence(timeout: Self.settingsPresentationTimeout)
        if !option.exists { attachHierarchy(named: "\(optionIdentifier) missing") }
        XCTAssertTrue(
            option.exists, "'\(optionIdentifier)' not found for '\(pickerIdentifier)'", file: file,
            line: line)
        return option
    }

    /// Keeps the hierarchy and a screenshot with the failure, so a missing control can be diagnosed
    /// from the result bundle instead of by rerunning on the same device.
    private func attachHierarchy(named name: String) {
        XCTContext.runActivity(named: name) { activity in
            let hierarchy = XCTAttachment(string: debugDescription)
            hierarchy.name = "\(name) hierarchy"
            hierarchy.lifetime = .keepAlways
            activity.add(hierarchy)
            let screenshot = XCTAttachment(screenshot: self.screenshot())
            screenshot.name = "\(name) screenshot"
            screenshot.lifetime = .keepAlways
            activity.add(screenshot)
        }
    }

    /// Opens the settings sheet or inspector, whichever the current width presents, and waits until
    /// it is actually up.
    ///
    /// On iPad the first tap after a launch is sometimes lost: the inspector's navigation bar reads
    /// "Settings" but its form never renders, and it does not appear on its own (about one launch in
    /// three in a 13-launch measurement, at every text size). One more tap opens it every time. So the
    /// toggle is tapped again after a wait — once per attempt and only while nothing has appeared,
    /// because a tap on an open inspector closes it.
    func openSettings(file: StaticString = #filePath, line: UInt = #line) {
        let settings = buttons[CalendarSampleAccessibilityID.settings]
        XCTAssertTrue(
            settings.waitForExistence(timeout: 5), "Settings button not found", file: file,
            line: line)
        settings.tap()
        for _ in 0..<Self.settingsRetryTaps
        where !settingsAreShowing(timeout: Self.settingsPresentationTimeout) {
            settings.tap()
        }
        if !settingsAreShowing(timeout: Self.settingsPresentationTimeout) {
            attachHierarchy(named: "settings did not open")
        }
    }

    /// Whether the settings panel is up: the sheet's Done button, or the first row of the form.
    private func settingsAreShowing(timeout: TimeInterval) -> Bool {
        let done = buttons[CalendarSampleAccessibilityID.done]
        let firstRow = descendants(matching: .any)[CalendarSampleAccessibilityID.stateOwnerPicker]
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if done.exists || firstRow.exists { return true }
            Thread.sleep(forTimeInterval: 0.25)
        } while Date() < deadline
        return done.exists || firstRow.exists
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
