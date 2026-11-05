import SwiftUICalendarAccessibility
import Vision
import XCTest

/// Drives the header with the shared identifiers instead of localized labels, so the same query
/// works in any locale and stays in step with the identifiers the views actually apply.
final class HeaderControlUITests: SampleUITestCase {
    @MainActor
    func testHorizontalNavigationAndSettingsPreserveSelection() throws {
        let app = sampleApplication()
        app.launch()
        app.chooseScrollMode(.horizontal)
        let calendar = Calendar.current
        let today = Date()
        let selectedDate = try XCTUnwrap(calendar.date(bySetting: .day, value: 15, of: today))
        let selected = app.buttons[app.dayIdentifier(for: selectedDate)]
        XCTAssertTrue(selected.waitForExistence(timeout: 5))
        selected.tap()
        for _ in 0..<3 {
            app.openSettings()
            app.dismissSettings()
            XCTAssertTrue(selected.isSelected)
            XCTAssertTrue(selected.isHittable)
        }
        app.buttons[CalendarAccessibilityID.nextMonthButton].tap()
        app.buttons[CalendarAccessibilityID.previousMonthButton].tap()
        XCTAssertTrue(selected.waitForExistence(timeout: 5))
        XCTAssertTrue(selected.isSelected)
        XCTAssertTrue(selected.isHittable)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "horizontal-after-settings-and-navigation"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testMonthNavigationAndYearPicker() throws {
        let app = sampleApplication()
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

        let yearButton = app.buttons[CalendarAccessibilityID.yearButton]
        XCTAssertTrue(yearButton.waitForExistence(timeout: 5), "year button not found")
        yearButton.tap()

        let done = app.buttons[CalendarAccessibilityID.yearPickerDoneButton]
        XCTAssertTrue(done.waitForExistence(timeout: 5), "the year picker did not present its Done")
        done.tap()
        XCTAssertTrue(
            done.waitForNonExistence(timeout: 5), "Done did not dismiss the year picker")
    }

    @MainActor
    func testFixedMonthPhysicalDayTapSelectsOCRLocatedDate() throws {
        let app = sampleApplication()
        app.launch()

        let calendar = Calendar.current
        let today = Date()
        let selectedDate = try XCTUnwrap(calendar.date(bySetting: .day, value: 15, of: today))
        let components = calendar.dateComponents([.year, .month], from: selectedDate)
        let selected = app.buttons[
            CalendarAccessibilityID.day(
                year: try XCTUnwrap(components.year),
                month: try XCTUnwrap(components.month),
                day: 15)]
        XCTAssertTrue(selected.waitForExistence(timeout: 5))

        let screenshot = app.screenshot()
        let image = try XCTUnwrap(screenshot.image.cgImage)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: image).perform([request])
        let dayFifteen = try XCTUnwrap(
            request.results?.filter { observation in
                observation.topCandidates(1).first?.string == "15"
            })
        XCTAssertEqual(dayFifteen.count, 1, "Expected one visible day labeled 15")
        let box = try XCTUnwrap(dayFifteen.first).boundingBox
        app.coordinate(
            withNormalizedOffset: CGVector(
                dx: box.midX,
                dy: 1 - box.midY
            )
        ).tap()

        XCTAssertTrue(selected.waitForExistence(timeout: 5))
        XCTAssertTrue(selected.isSelected, "The physical day 15 tap selected a different date")
        let monthButton = app.buttons[CalendarAccessibilityID.monthButton]
        let originalMonth = monthButton.label
        app.buttons[CalendarAccessibilityID.nextMonthButton].tap()
        let advancedHeader = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", originalMonth),
            object: monthButton)
        XCTAssertEqual(XCTWaiter.wait(for: [advancedHeader], timeout: 5), .completed)
        app.buttons[CalendarAccessibilityID.previousMonthButton].tap()
        XCTAssertEqual(monthButton.label, originalMonth)
        XCTAssertTrue(selected.isSelected, "Returning to the month changed the selected date")

        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "fixed-month-ocr-day-15-tap"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
