import SwiftUICalendarAccessibility
import XCTest

/// Every scroll mode must lay out all seven weekday columns inside the window, on the smallest
/// supported phones and in both orientations. A grid wider than its viewport silently clips its last
/// column (a 375pt iPhone SE lost Saturday this way), and the unit tests only see macOS-hosted
/// geometry, so this measures what a simulator actually lays out.
///
/// Only horizontal extents are judged. Vertical position depends on scroll offset, and a vertical
/// calendar legitimately keeps its rows below the fold of a landscape phone.
final class WeekdayColumnsReachableUITests: XCTestCase {
    private static let weekdayColumnCount = 7
    private static let rotationTimeout: TimeInterval = 10
    private static let dayCellTimeout: TimeInterval = 10
    private static let frameTolerance: CGFloat = 0.5

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
    }

    func testEveryScrollModeLaysOutAllWeekdayColumnsInPortrait() throws {
        assertAllWeekdayColumnsInWindow(orientation: .portrait)
    }

    func testEveryScrollModeLaysOutAllWeekdayColumnsInLandscape() throws {
        assertAllWeekdayColumnsInWindow(orientation: .landscapeLeft)
    }

    // MARK: - Helpers

    private func assertAllWeekdayColumnsInWindow(orientation: UIDeviceOrientation) {
        let app = XCUIApplication()
        app.launch()
        for mode in CalendarScrollMode.allCases {
            XCUIDevice.shared.orientation = .portrait
            app.chooseScrollMode(mode)
            XCUIDevice.shared.orientation = orientation
            waitForWindow(in: app, matching: orientation)
            let columns = columnPositionsInsideWindow(of: app)
            if columns.count < Self.weekdayColumnCount {
                let screenshot = XCTAttachment(screenshot: app.screenshot())
                screenshot.name = "\(mode)-orientation-\(orientation.rawValue)"
                screenshot.lifetime = .keepAlways
                add(screenshot)
            }
            XCTAssertGreaterThanOrEqual(
                columns.count, Self.weekdayColumnCount,
                "\(mode) in orientation \(orientation.rawValue): only \(columns.count) of "
                    + "\(Self.weekdayColumnCount) weekday columns lie inside the window: "
                    + "\(columns.sorted())")
        }
    }

    /// Blocks until the app's window reports the geometry of `orientation`. The accessibility tree
    /// keeps the pre-rotation frames for a moment after the device orientation changes, so reading
    /// cells immediately would measure the old layout against the new window.
    private func waitForWindow(in app: XCUIApplication, matching orientation: UIDeviceOrientation) {
        let wantsLandscape = orientation.isLandscape
        let settled = NSPredicate { _, _ in
            let frame = app.windows.firstMatch.frame
            return (frame.width > frame.height) == wantsLandscape
        }
        let expectation = XCTNSPredicateExpectation(predicate: settled, object: nil)
        XCTAssertEqual(
            XCTWaiter().wait(for: [expectation], timeout: Self.rotationTimeout), .completed,
            "the window never took the geometry of orientation \(orientation.rawValue)")
    }

    /// Distinct leading edges of the day cells that lie fully inside the window horizontally. A column
    /// clipped by the viewport has a trailing edge past the window, so it is not counted.
    private func columnPositionsInsideWindow(of app: XCUIApplication) -> Set<Int> {
        let days = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", CalendarAccessibilityID.dayPrefix))
        XCTAssertTrue(
            days.firstMatch.waitForExistence(timeout: Self.dayCellTimeout),
            "no day cell appeared")
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
