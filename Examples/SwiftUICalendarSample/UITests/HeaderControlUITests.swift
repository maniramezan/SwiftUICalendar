import SwiftUICalendarAccessibility
import Vision
import XCTest

/// Drives the header with the shared identifiers instead of localized labels, so the same query
/// works in any locale and stays in step with the identifiers the views actually apply.
final class HeaderControlUITests: SampleUITestCase {
    /// A calendar that first appears in a scrolling mode, with no host scroll view around it, must
    /// draw its days where it lays them out. A scroll view that never scrolled vertically was once
    /// handed the navigation bar's top inset at launch, behind SwiftUI's back: the grid was drawn
    /// about 146pt below its laid-out frames, so a finger on a visible day hit another one, while
    /// every query by identifier still passed. Switching modes from Settings never showed it, so
    /// the drawn day is found by OCR and tapped by screen position.
    @MainActor
    func testFreshLaunchPhysicalDayTapSelectsTheDrawnDay() throws {
        for mode in [CalendarScrollMode.vertical, .horizontal] {
            let app = sampleApplication()
            app.launchArguments = SampleLaunchFixture.arguments(
                architecture: .mvvm, selectionMode: .single, scrollMode: mode)
            app.launch()
            let selected = try dayFifteen(in: app)
            XCTAssertTrue(selected.waitForExistence(timeout: 10), "\(mode): day 15 missing")
            let screenshot = try tapDrawnDayFifteen(in: app)
            XCTAssertTrue(
                selected.isSelected, "\(mode): the physical day 15 tap selected a different date")
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "fresh-\(mode)-ocr-day-15-tap"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

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

        let selected = try dayFifteen(in: app)
        XCTAssertTrue(selected.waitForExistence(timeout: 5))
        let screenshot = try tapDrawnDayFifteen(in: app)

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

    // MARK: - Helpers

    /// Day 15 of the current month: never an overflow day, so its identifier is unique.
    @MainActor
    private func dayFifteen(in app: XCUIApplication) throws -> XCUIElement {
        let calendar = Calendar.current
        let date = try XCTUnwrap(calendar.date(bySetting: .day, value: 15, of: Date()))
        let components = calendar.dateComponents([.year, .month], from: date)
        return app.buttons[
            CalendarAccessibilityID.day(
                year: try XCTUnwrap(components.year),
                month: try XCTUnwrap(components.month),
                day: 15)]
    }

    /// Finds the drawn "15" in a screenshot and taps that screen position, so the tap goes wherever
    /// the day is drawn rather than where the accessibility tree says it is. The topmost match is
    /// the current month's when a following month is also on screen.
    @MainActor
    private func tapDrawnDayFifteen(in app: XCUIApplication) throws -> XCUIScreenshot {
        let screenshot = app.screenshot()
        let image = try XCTUnwrap(screenshot.image.cgImage)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: image).perform([request])
        let matches = (request.results ?? []).filter { observation in
            observation.topCandidates(1).first?.string == "15"
        }
        // Vision's normalized boxes have their origin at the bottom left.
        let box = try XCTUnwrap(
            matches.max { $0.boundingBox.midY < $1.boundingBox.midY },
            "No visible day labeled 15"
        ).boundingBox
        app.coordinate(withNormalizedOffset: CGVector(dx: box.midX, dy: 1 - box.midY)).tap()
        return screenshot
    }
}
