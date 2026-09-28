import XCTest

extension XCUIApplication {
    /// Selects a scroll mode from settings and dismisses the presentation.
    ///
    /// The settings form is lazy, and in a landscape-height sheet the layout section starts below the
    /// fold, so its options only enter the hierarchy once the form is scrolled to them.
    func chooseScrollMode(_ mode: String, file: StaticString = #filePath, line: UInt = #line) {
        let settings = buttons["Settings"]
        XCTAssertTrue(
            settings.waitForExistence(timeout: 5), "Settings button not found", file: file,
            line: line)
        settings.tap()
        let picker = descendants(matching: .any)["scroll-mode-picker"]
        XCTAssertTrue(
            picker.waitForExistence(timeout: 5), "Scroll mode picker not found", file: file,
            line: line)
        let option = picker.buttons[mode]
        let form = scrollViews.firstMatch
        for _ in 0..<4 where !option.waitForExistence(timeout: 1) {
            form.swipeUp()
        }
        XCTAssertTrue(
            option.exists, "scroll mode '\(mode)' not found in settings", file: file, line: line)
        option.tap()
        dismissSettings(file: file, line: line)
    }

    /// Closes the compact sheet or regular-width inspector.
    func dismissSettings(file: StaticString = #filePath, line: UInt = #line) {
        let done = buttons["Done"]
        if done.waitForExistence(timeout: 1) {
            done.tap()
            return
        }

        let settings = buttons["Settings"]
        XCTAssertTrue(
            settings.waitForExistence(timeout: 5), "Settings button not found", file: file,
            line: line)
        settings.tap()
    }
}
