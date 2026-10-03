import SwiftUICalendarAccessibility
import XCTest

/// Drives the header with the shared identifiers instead of localized labels, so the same query
/// works in any locale and stays in step with the identifiers the views actually apply.
final class HeaderControlUITests: SampleUITestCase {
    func testNextMonthButtonAdvancesTheGrid() throws {
        let app = XCUIApplication()
        app.launch()
        // The sample opens in `.none` scroll mode, which shows a single month grid.

        let calendar = Calendar.current
        let now = Date()
        let thisMonth = calendar.dateComponents([.year, .month], from: now)
        let nextDate = try XCTUnwrap(calendar.date(byAdding: .month, value: 1, to: now))
        let next = calendar.dateComponents([.year, .month], from: nextDate)
        let thisFirst = CalendarAccessibilityID.day(
            year: thisMonth.year!, month: thisMonth.month!, day: 1)
        let nextFirst = CalendarAccessibilityID.day(
            year: next.year!, month: next.month!, day: 1)

        XCTAssertTrue(
            app.buttons[thisFirst].waitForExistence(timeout: 5), "the current month is not rendered"
        )

        let nextMonth = app.buttons[CalendarAccessibilityID.nextMonthButton]
        XCTAssertTrue(nextMonth.waitForExistence(timeout: 5), "next month button not found")
        nextMonth.tap()

        XCTAssertTrue(
            app.buttons[nextFirst].waitForExistence(timeout: 5),
            "the next month did not render after tapping the next month button")
        XCTAssertFalse(
            app.buttons[thisFirst].exists, "the previous month is still rendered after paging")
    }

    func testYearButtonOpensTheYearPicker() throws {
        let app = XCUIApplication()
        app.launch()

        let yearButton = app.buttons[CalendarAccessibilityID.yearButton]
        XCTAssertTrue(yearButton.waitForExistence(timeout: 5), "year button not found")
        yearButton.tap()

        let done = app.buttons[CalendarAccessibilityID.yearPickerDoneButton]
        XCTAssertTrue(done.waitForExistence(timeout: 5), "the year picker did not present its Done")
        done.tap()
        XCTAssertFalse(
            done.waitForExistence(timeout: 2), "Done did not dismiss the year picker")
    }
}
