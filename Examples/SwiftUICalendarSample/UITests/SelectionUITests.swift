import SwiftUICalendarAccessibility
import XCTest

/// Exercises real day buttons and selected traits; screenshots preserve the cross-month appearance.
@MainActor
final class SelectionUITests: SampleUITestCase {
    func testRangeAcrossMonthsMVVM() throws { try crossMonthRanges(architecture: .mvvm) }
    func testRangeAcrossMonthsTCA() throws { try crossMonthRanges(architecture: .tca) }
    func testMultipleSelectionMVVM() throws { try multipleSelections(architecture: .mvvm) }
    func testMultipleSelectionTCA() throws { try multipleSelections(architecture: .tca) }

    func testRangeReverseAcrossMonthBoundary() throws {
        let app = configured(.range, mode: .horizontal, architecture: .tca)
        let month = try monthDates()
        app.buttons[CalendarAccessibilityID.nextMonthButton].tap()
        day(5, month: month.next, in: app).tap()
        app.buttons[CalendarAccessibilityID.previousMonthButton].tap()
        let start = month.lastDay - 2
        day(start, month: month.current, in: app).tap()
        expectSelected(start...month.lastDay, month: month.current, in: app)
        XCTAssertTrue(day(start, month: month.current, in: app).label.contains("Range start"))
        app.buttons[CalendarAccessibilityID.nextMonthButton].tap()
        expectSelected(1...5, month: month.next, in: app)
        XCTAssertTrue(day(5, month: month.next, in: app).label.contains("Range end"))
        attach(app, name: "reversed-cross-month-range")
    }

    func testRangeReverseResetAndDeselect() throws {
        let app = configured(.range, mode: .none, architecture: .mvvm)
        let month = try monthDates()
        day(15, month: month.current, in: app).tap()
        day(10, month: month.current, in: app).tap()
        expectSelected(10...15, month: month.current, in: app)
        XCTAssertTrue(day(10, month: month.current, in: app).label.contains("Range start"))
        XCTAssertTrue(day(15, month: month.current, in: app).label.contains("Range end"))
        day(20, month: month.current, in: app).tap()
        XCTAssertFalse(day(12, month: month.current, in: app).isSelected)
        XCTAssertTrue(day(20, month: month.current, in: app).isSelected)
        day(20, month: month.current, in: app).tap()
        XCTAssertFalse(day(20, month: month.current, in: app).isSelected)
    }

    func testHorizontalSwipesDoNotSelectRangeOrMultipleDates() throws {
        for selection in [SampleSelectionMode.range, .multiple] {
            let app = configured(selection, mode: .horizontal, architecture: .mvvm)
            let month = try monthDates()
            let first = day(10, month: month.current, in: app)
            let last = day(15, month: month.current, in: app)
            first.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(
                    forDuration: 0.05,
                    thenDragTo: last.coordinate(
                        withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
            // Return with Today rather than selecting a day to navigate.
            app.buttons[CalendarAccessibilityID.todayButton].tap()
            for number in 1...28 {
                XCTAssertFalse(day(number, month: month.current, in: app).isSelected)
            }
        }
    }

    private func crossMonthRanges(architecture: SampleArchitecture) throws {
        for mode in CalendarScrollMode.allCases {
            let app = configured(.range, mode: mode, architecture: architecture)
            let month = try monthDates()
            let start = month.lastDay - 2
            day(start, month: month.current, in: app).tap()
            app.buttons[CalendarAccessibilityID.nextMonthButton].tap()
            day(5, month: month.next, in: app).tap()
            expectSelected(1...5, month: month.next, in: app)
            XCTAssertFalse(day(6, month: month.next, in: app).isSelected)
            XCTAssertTrue(day(5, month: month.next, in: app).label.contains("Range end"))
            XCTAssertTrue(
                day(2, month: month.next, in: app).label.contains("Within selected range"))
            attach(app, name: "range-next-\(mode)-\(architecture)")
            app.buttons[CalendarAccessibilityID.previousMonthButton].tap()
            expectSelected(start...month.lastDay, month: month.current, in: app)
            XCTAssertFalse(day(start - 1, month: month.current, in: app).isSelected)
            XCTAssertTrue(day(start, month: month.current, in: app).label.contains("Range start"))
            attach(app, name: "range-start-\(mode)-\(architecture)")
        }
    }

    private func multipleSelections(architecture: SampleArchitecture) throws {
        for mode in CalendarScrollMode.allCases {
            let app = configured(.multiple, mode: mode, architecture: architecture)
            let month = try monthDates()
            day(10, month: month.current, in: app).tap()
            day(12, month: month.current, in: app).tap()
            day(15, month: month.current, in: app).tap()
            day(12, month: month.current, in: app).tap()
            XCTAssertTrue(day(10, month: month.current, in: app).isSelected)
            XCTAssertFalse(day(12, month: month.current, in: app).isSelected)
            XCTAssertTrue(day(15, month: month.current, in: app).isSelected)
            XCTAssertFalse(day(11, month: month.current, in: app).isSelected)
            app.buttons[CalendarAccessibilityID.nextMonthButton].tap()
            day(5, month: month.next, in: app).tap()
            XCTAssertTrue(day(5, month: month.next, in: app).isSelected)
            app.buttons[CalendarAccessibilityID.previousMonthButton].tap()
            XCTAssertTrue(day(10, month: month.current, in: app).isSelected)
            XCTAssertFalse(day(12, month: month.current, in: app).isSelected)
            XCTAssertTrue(day(15, month: month.current, in: app).isSelected)
            attach(app, name: "multiple-\(mode)-\(architecture)")
        }
    }

    private func configured(
        _ selection: SampleSelectionMode, mode: CalendarScrollMode, architecture: SampleArchitecture
    ) -> XCUIApplication {
        let app = sampleApplication()
        app.launchArguments = [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL",
        ]
        app.launch()
        app.openSettings()
        app.option(
            architecture.accessibilityIdentifier, in: CalendarSampleAccessibilityID.stateOwnerPicker
        ).tap()
        app.option(
            selection.accessibilityIdentifier, in: CalendarSampleAccessibilityID.selectionPicker
        ).tap()
        app.option(mode.accessibilityIdentifier, in: CalendarSampleAccessibilityID.scrollModePicker)
            .tap()
        app.dismissSettings()
        return app
    }

    private func monthDates() throws -> (current: Date, next: Date, lastDay: Int) {
        let calendar = Calendar(identifier: .gregorian)
        let interval = try XCTUnwrap(calendar.dateInterval(of: .month, for: Date()))
        let count = try XCTUnwrap(calendar.range(of: .day, in: .month, for: interval.start))
        return (interval.start, interval.end, count.count)
    }

    private func day(_ number: Int, month: Date, in app: XCUIApplication) -> XCUIElement {
        let calendar = Calendar(identifier: .gregorian)
        var parts = calendar.dateComponents([.year, .month], from: month)
        parts.day = number
        let id = CalendarAccessibilityID.day(year: parts.year!, month: parts.month!, day: number)
        let matches = app.buttons.matching(identifier: id)
        if !matches.firstMatch.exists {
            XCTAssertTrue(matches.firstMatch.waitForExistence(timeout: 5), "Missing day \(id)")
        }
        // Adjacent realized months can each expose an overflow copy of the same date.
        if let visible = matches.allElementsBoundByIndex.first(where: { $0.isHittable }) {
            return visible
        }
        let grid = app.scrollViews.firstMatch
        for _ in 0..<5 {
            let frame = matches.firstMatch.frame
            let viewport = app.windows.firstMatch.frame
            if frame.midY < viewport.midY {
                grid.swipeDown()
            } else {
                grid.swipeUp()
            }
            if let visible = matches.allElementsBoundByIndex.first(where: { $0.isHittable }) {
                return visible
            }
        }
        attach(app, name: "unreachable-\(id)")
        XCTFail("Day is not reachable: \(id)")
        return matches.firstMatch
    }

    private func expectSelected(_ days: ClosedRange<Int>, month: Date, in app: XCUIApplication) {
        for number in days {
            XCTAssertTrue(
                day(number, month: month, in: app).isSelected, "Day \(number) should be selected")
        }
    }

    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
