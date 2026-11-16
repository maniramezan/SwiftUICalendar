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
            let tapped = try tapDrawnDay(in: app)
            XCTAssertTrue(
                tapped.day.isSelected,
                "\(mode): the physical tap on day \(tapped.number) selected a different date")
            let attachment = XCTAttachment(screenshot: tapped.screenshot)
            attachment.name = "fresh-\(mode)-ocr-day-tap"
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

        let tapped = try tapDrawnDay(in: app)
        let selected = tapped.day
        let screenshot = tapped.screenshot

        XCTAssertTrue(selected.waitForExistence(timeout: 5))
        XCTAssertTrue(
            selected.isSelected,
            "The physical tap on day \(tapped.number) selected a different date")
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
        attachment.name = "fixed-month-ocr-day-tap"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Helpers

    /// Days that are never another month's overflow in the current month's grid: a leading overflow
    /// day is at least 23 and a trailing one sits below the month's own copy of the number.
    private static let tappableDays = 10...22
    private static let dayGridTimeout: TimeInterval = 10

    private struct DrawnDayTap {
        let number: Int
        let day: XCUIElement
        let screenshot: XCUIScreenshot
    }

    @MainActor
    private func currentMonthDay(_ number: Int, in app: XCUIApplication) throws -> XCUIElement {
        let components = Calendar.current.dateComponents([.year, .month], from: Date())
        return app.buttons[
            CalendarAccessibilityID.day(
                year: try XCTUnwrap(components.year),
                month: try XCTUnwrap(components.month),
                day: number)]
    }

    /// Finds a drawn day number in a screenshot and taps that screen position, so the tap goes
    /// wherever the day is drawn rather than where the accessibility tree says it is.
    ///
    /// No single day can be relied on. Vision reads nothing inside the today marker, and in the
    /// first or last column the sliver of the neighbouring month that the horizontal pager lets
    /// peek in joins the number: a fixed "15" failed on the 15th of every month, and on other days
    /// in a month whose 15th falls in the first column. So today is skipped and, of the days
    /// Vision does read, the one nearest the horizontal centre is tapped. The topmost match for a
    /// number is the current month's when a following month is also on screen.
    @MainActor
    private func tapDrawnDay(in app: XCUIApplication) throws -> DrawnDayTap {
        let today = Calendar.current.component(.day, from: Date())
        let anyDay = try currentMonthDay(Self.tappableDays.lowerBound, in: app)
        XCTAssertTrue(
            anyDay.waitForExistence(timeout: Self.dayGridTimeout), "the current month is missing")
        let screenshot = app.screenshot()
        let image = try XCTUnwrap(screenshot.image.cgImage)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: image).perform([request])
        // Vision's normalized boxes have their origin at the bottom left.
        var topmost: [Int: CGRect] = [:]
        for observation in request.results ?? [] {
            guard let text = observation.topCandidates(1).first?.string, let number = Int(text),
                Self.tappableDays.contains(number), number != today
            else { continue }
            let box = observation.boundingBox
            if let known = topmost[number], known.midY >= box.midY { continue }
            topmost[number] = box
        }
        let read = topmost.keys.sorted().map(String.init).joined(separator: ", ")
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "ocr-input"
        attachment.lifetime = .deleteOnSuccess
        add(attachment)
        let choice = try XCTUnwrap(
            topmost.min { abs($0.value.midX - 0.5) < abs($1.value.midX - 0.5) },
            "No drawn day between \(Self.tappableDays.lowerBound) and "
                + "\(Self.tappableDays.upperBound) was recognized")
        XCTContext.runActivity(named: "OCR read days \(read); tapping \(choice.key)") { _ in }
        let box = choice.value
        app.coordinate(withNormalizedOffset: CGVector(dx: box.midX, dy: 1 - box.midY)).tap()
        return DrawnDayTap(
            number: choice.key, day: try currentMonthDay(choice.key, in: app),
            screenshot: screenshot)
    }
}
