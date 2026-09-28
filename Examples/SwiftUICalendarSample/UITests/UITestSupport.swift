import XCTest

extension XCUIApplication {
    /// Selects a scroll mode from the settings sheet and dismisses it.
    ///
    /// The settings form is lazy, and in a landscape-height sheet the layout section starts below the
    /// fold, so its options only enter the hierarchy once the form is scrolled to them.
    func chooseScrollMode(_ mode: String, file: StaticString = #filePath, line: UInt = #line) {
        let settings = buttons["Settings"]
        XCTAssertTrue(
            settings.waitForExistence(timeout: 5), "Settings button not found", file: file,
            line: line)
        settings.tap()
        let option = buttons[mode]
        let form = collectionViews.firstMatch
        for _ in 0..<4 where !option.waitForExistence(timeout: 1) {
            form.swipeUp()
        }
        XCTAssertTrue(
            option.exists, "scroll mode '\(mode)' not found in settings", file: file, line: line)
        option.tap()
        buttons["Done"].tap()
    }
}
