import SwiftUICalendarAccessibility
import XCTest

/// At a large text size the calendar must keep all seven columns reachable and keep its
/// header out of the day grid. Text only scales on iOS, so macOS-hosted tests cannot see this: it
/// once let the header's month and year controls grow inside a one-row frame and overlap the first
/// week.
final class DynamicTypeUITests: SampleUITestCase {
    private static let weekdayColumnCount = 7
    private static let dayCellTimeout: TimeInterval = 10
    private static let frameTolerance: CGFloat = 0.5
    private static let sizeFlag = "-UIPreferredContentSizeCategoryName"

    override func setUpWithError() throws {
        try super.setUpWithError()
    }

    func testNormalTextYearControlHasAccessibleHeight() {
        let app = launch(size: "UICTContentSizeCategoryL")
        let year = app.descendants(matching: .any)[CalendarAccessibilityID.yearButton].firstMatch
        XCTAssertTrue(year.waitForExistence(timeout: Self.dayCellTimeout))
        XCTAssertGreaterThanOrEqual(year.frame.height, 44)
    }

    func testAccessibilityTextKeepsEdgeColumnsReachable() throws {
        let app = launch(size: "UICTContentSizeCategoryAccessibilityXXXL")
        for mode in CalendarScrollMode.allCases {
            app.chooseScrollMode(mode)
            let days = app.buttons.matching(
                NSPredicate(format: "identifier BEGINSWITH %@", CalendarAccessibilityID.dayPrefix))
            XCTAssertTrue(days.firstMatch.waitForExistence(timeout: Self.dayCellTimeout))
            let populated = days.allElementsBoundByIndex.filter { $0.frame.width > 0 }
            let firstRowY = try XCTUnwrap(populated.map { $0.frame.minY }.min())
            let row = populated.filter { abs($0.frame.minY - firstRowY) < 1 }
            let leading = try XCTUnwrap(row.min { $0.frame.minX < $1.frame.minX })
            let trailing = try XCTUnwrap(row.max { $0.frame.maxX < $1.frame.maxX })
            XCTAssertTrue(leading.isHittable)
            let window = app.windows.firstMatch.frame
            if trailing.frame.maxX > window.maxX {
                leading.swipeLeft()
            }
            XCTAssertTrue(
                trailing.isHittable, "The trailing date must be reachable without changing months")
            XCTAssertLessThanOrEqual(trailing.frame.maxX, window.maxX + Self.frameTolerance)
        }
    }

    func testAccessibilityTextKeepsTheHeaderAboveTheFirstWeek() throws {
        let app = launch(size: "UICTContentSizeCategoryAccessibilityXXXL")
        // The vertical calendar scrolls its months under the header, so only the modes that lay the
        // month out below it have a stable first row to compare against.
        for mode in [CalendarScrollMode.none, .horizontal] {
            app.chooseScrollMode(mode)
            let days = app.buttons.matching(
                NSPredicate(format: "identifier BEGINSWITH %@", CalendarAccessibilityID.dayPrefix))
            XCTAssertTrue(days.firstMatch.waitForExistence(timeout: Self.dayCellTimeout))
            let firstRowTop =
                (0..<days.count)
                .map { days.element(boundBy: $0).frame }
                .filter { $0.width > 0 }
                .map(\.minY)
                .min() ?? 0
            for identifier in [
                CalendarAccessibilityID.monthButton, CalendarAccessibilityID.yearButton,
            ] {
                let control = app.descendants(matching: .any)[identifier].firstMatch
                XCTAssertTrue(control.waitForExistence(timeout: Self.dayCellTimeout), identifier)
                XCTAssertLessThanOrEqual(
                    control.frame.maxY, firstRowTop + Self.frameTolerance,
                    "\(mode): \(identifier) ends at \(control.frame.maxY), below the first week at \(firstRowTop)"
                )
            }
        }
    }

    // MARK: - Helpers

    private func launch(size: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [Self.sizeFlag, size]
        app.launch()
        return app
    }

    private func columnPositionsInsideWindow(of app: XCUIApplication) -> Set<Int> {
        let days = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", CalendarAccessibilityID.dayPrefix))
        XCTAssertTrue(
            days.firstMatch.waitForExistence(timeout: Self.dayCellTimeout), "no day cell appeared")
        let bounds = app.windows.firstMatch.frame
        var positions = Set<Int>()
        for index in 0..<days.count {
            let frame = days.element(boundBy: index).frame
            guard frame.width > 0,
                frame.minX >= bounds.minX - Self.frameTolerance,
                frame.maxX <= bounds.maxX + Self.frameTolerance
            else { continue }
            positions.insert(Int(frame.minX.rounded()))
        }
        return positions
    }
}
