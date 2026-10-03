import SwiftUICalendarAccessibility
import TestCommons
import TestCommonsXCUI
import XCTest

/// Locale-sensitive scenarios, run under several system languages by the
/// `SwiftUICalendarSampleLocales` test plan: each plan configuration sets the app's language and
/// region, so these tests carry no launch arguments and no per-locale branches.
///
/// Queries use the shared identifiers, never localized labels, so every language resolves the same
/// elements. The grid's direction follows the calendar system rather than the device language, so
/// the expectations are the same in every configuration: Gregorian reads left to right and Persian
/// right to left.
///
/// Run with `xcodebuild test -testPlan SwiftUICalendarSampleLocales`.
final class LocaleDirectionUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Helpers

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        return app
    }

    private var dayButtons: (XCUIApplication) -> XCUIElementQuery {
        { app in
            app.buttons.matching(
                NSPredicate(format: "identifier BEGINSWITH %@", CalendarAccessibilityID.dayPrefix))
        }
    }

    /// Finds two consecutive day numbers that share a row and returns their frames, in whichever
    /// calendar system is displayed (identifiers carry that system's year, month, and day).
    private func adjacentDays(in app: XCUIApplication) throws -> (first: CGRect, second: CGRect) {
        let days = dayButtons(app)
        XCTAssertTrue(days.firstMatch.waitForExistence(timeout: 10), "no days are rendered")
        var byNumber: [Int: CGRect] = [:]
        for element in days.allElementsBoundByIndex {
            guard let number = element.identifier.split(separator: "-").last.flatMap({ Int($0) }),
                element.isHittable
            else { continue }
            byNumber[number] = element.frame
        }
        if let pair = ReadingOrder.firstAdjacentPair(in: byNumber, successor: { $0 + 1 }) {
            return pair
        }
        throw XCTSkip("no two adjacent days share a row")
    }

    private func assertReadingOrder(_ app: XCUIApplication, rightToLeft: Bool) throws {
        let pair = try adjacentDays(in: app)
        XCTAssertReadingOrder(
            first: pair.first, second: pair.second,
            direction: rightToLeft ? .rightToLeft : .leftToRight)
    }

    /// Switches the sample to the Persian calendar. Segment labels are localized, so the segment is
    /// picked by position (Gregorian, Persian) rather than by label.
    private func choosePersianCalendar(_ app: XCUIApplication) {
        app.openSettings()
        XCTAssertTrue(
            app.buttons[CalendarSampleAccessibilityID.done].waitForExistence(timeout: 20),
            "settings did not present")
        let picker = app.descendants(matching: .any)[CalendarSampleAccessibilityID.calendarPicker]
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "calendar picker not found")
        let persian = picker.buttons.element(boundBy: 1)
        XCTAssertTrue(persian.waitForExistence(timeout: 5), "Persian segment not found")
        persian.tap()
        app.dismissSettings()
    }

    // MARK: Writing direction

    func testGregorianGridReadsLeftToRight() throws {
        try assertReadingOrder(launchApp(), rightToLeft: false)
    }

    func testPersianCalendarMirrorsTheGrid() throws {
        let app = launchApp()
        choosePersianCalendar(app)
        try assertReadingOrder(app, rightToLeft: true)
    }

    // MARK: Header controls

    func testNextMonthButtonAdvancesTheGrid() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let thisMonth = calendar.dateComponents([.year, .month], from: now)
        let nextMonth = calendar.dateComponents(
            [.year, .month], from: try XCTUnwrap(calendar.date(byAdding: .month, value: 1, to: now))
        )
        let app = launchApp()
        let thisFirst = app.buttons[
            CalendarAccessibilityID.day(
                year: try XCTUnwrap(thisMonth.year), month: try XCTUnwrap(thisMonth.month),
                day: 1)]
        XCTAssertTrue(thisFirst.waitForExistence(timeout: 20), "month not rendered")
        let next = app.buttons[CalendarAccessibilityID.nextMonthButton]
        XCTAssertTrue(next.waitForExistence(timeout: 5), "no next button")
        next.tap()
        let nextFirst = app.buttons[
            CalendarAccessibilityID.day(
                year: try XCTUnwrap(nextMonth.year), month: try XCTUnwrap(nextMonth.month),
                day: 1)]
        XCTAssertTrue(nextFirst.waitForExistence(timeout: 15), "next month did not render")
    }

    func testYearPickerOpensAndDismisses() throws {
        let app = launchApp()
        let yearButton = app.buttons[CalendarAccessibilityID.yearButton]
        XCTAssertTrue(yearButton.waitForExistence(timeout: 20), "year button not found")
        yearButton.tap()
        let done = app.buttons[CalendarAccessibilityID.yearPickerDoneButton]
        XCTAssertTrue(done.waitForExistence(timeout: 15), "year picker did not present")
        done.tap()
        XCTAssertFalse(done.waitForExistence(timeout: 2), "Done did not dismiss the year picker")
    }

    // MARK: Horizontal paging direction

    /// Swiping toward the leading edge advances to the next month, so the physical direction
    /// flips with the calendar system's layout direction.
    private func assertSwipePagesToNextMonth(
        _ app: XCUIApplication, rightToLeft: Bool
    ) {
        let first = dayButtons(app).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        let before = first.identifier
        let window = app.windows.firstMatch
        if rightToLeft {
            window.swipeRight()
        } else {
            window.swipeLeft()
        }
        // Paging settles over several run-loop turns, so poll rather than sleep a fixed time.
        let deadline = Date().addingTimeInterval(8)
        while dayButtons(app).firstMatch.identifier == before, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.25)
        }
        XCTAssertNotEqual(
            before, dayButtons(app).firstMatch.identifier,
            "a swipe toward the leading edge should page to the next month")
    }

    func testHorizontalSwipePagesGregorianLeftToRight() throws {
        let app = launchApp()
        app.chooseScrollMode(.horizontal)
        assertSwipePagesToNextMonth(app, rightToLeft: false)
    }

    func testHorizontalSwipePagesPersianRightToLeft() throws {
        let app = launchApp()
        choosePersianCalendar(app)
        app.chooseScrollMode(.horizontal)
        assertSwipePagesToNextMonth(app, rightToLeft: true)
    }
}
