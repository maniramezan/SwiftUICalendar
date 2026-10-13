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

    @MainActor
    func testNormalTextYearControlHasAccessibleHeight() {
        let app = launch(size: "UICTContentSizeCategoryL")
        let year = app.descendants(matching: .any)[CalendarAccessibilityID.yearButton].firstMatch
        XCTAssertTrue(year.waitForExistence(timeout: Self.dayCellTimeout))
        XCTAssertGreaterThanOrEqual(year.frame.height, 44)
        let month = app.descendants(matching: .any)[CalendarAccessibilityID.monthButton].firstMatch
        XCTAssertGreaterThanOrEqual(month.frame.width, 44)
        XCTAssertGreaterThanOrEqual(month.frame.height, 44)
        let settings = app.buttons[CalendarSampleAccessibilityID.settings]
        XCTAssertTrue(settings.exists)
        XCTAssertGreaterThanOrEqual(settings.frame.width, 44)
        XCTAssertGreaterThanOrEqual(settings.frame.height, 44)
    }

    @MainActor
    func testSettingsRemainDismissibleAfterRotation() {
        let app = launch(size: "UICTContentSizeCategoryAccessibilityXXXL")
        app.openSettings()
        XCUIDevice.shared.orientation = .landscapeLeft
        XCUIDevice.shared.orientation = .portrait
        let done = app.buttons[CalendarSampleAccessibilityID.done]
        XCTAssertTrue(done.waitForExistence(timeout: Self.dayCellTimeout))
        done.tap()
        let month = app.descendants(matching: .any)[CalendarAccessibilityID.monthButton].firstMatch
        XCTAssertTrue(month.waitForExistence(timeout: Self.dayCellTimeout))
        XCTAssertTrue(month.isHittable)
        XCTAssertTrue(done.waitForNonExistence(timeout: Self.dayCellTimeout))
    }

    @MainActor
    func testAccessibilityTextKeepsEdgeColumnsReachable() throws {
        for mode in CalendarScrollMode.allCases {
            // Each mode starts at the leading edge; retained overflow offsets are valid UI state.
            let app = launch(size: "UICTContentSizeCategoryAccessibilityXXXL")
            app.chooseScrollMode(mode)
            let row = try visibleFullRow(in: app)
            let leading = try XCTUnwrap(row.first)
            let trailing = try XCTUnwrap(row.last)
            XCTAssertTrue(leading.isHittable)
            let window = app.windows.firstMatch.frame
            // Maximum text can require more than one viewport of horizontal travel.
            // Swipe inside the visible row, not on a leading cell that is now offscreen.
            for _ in 0..<4 where trailing.frame.maxX > window.maxX + Self.frameTolerance {
                let visibleY = max(window.minY + 1, min(window.maxY - 1, leading.frame.midY))
                let origin = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
                let start = origin.withOffset(
                    CGVector(dx: window.width * 0.85, dy: visibleY - window.minY))
                let end = origin.withOffset(
                    CGVector(dx: window.width * 0.15, dy: visibleY - window.minY))
                start.press(forDuration: 0.05, thenDragTo: end)
            }
            XCTAssertTrue(
                trailing.isHittable, "The trailing date must be reachable without changing months")
            XCTAssertLessThanOrEqual(trailing.frame.maxX, window.maxX + Self.frameTolerance)
        }
    }

    @MainActor
    func testAccessibilityTextKeepsTheHeaderAboveTheFirstWeek() throws {
        let app = launch(size: "UICTContentSizeCategoryAccessibilityXXXL")
        // The vertical calendar scrolls its months under the header, so only the modes that lay the
        // month out below it have a stable first row to compare against.
        for mode in [CalendarScrollMode.none, .horizontal] {
            app.chooseScrollMode(mode)
            let days = app.buttons.matching(
                NSPredicate(format: "identifier BEGINSWITH %@", CalendarAccessibilityID.dayPrefix))
            XCTAssertTrue(days.firstMatch.waitForExistence(timeout: Self.dayCellTimeout))
            // One snapshot instead of a query per day and control. Every query is answered on the
            // app's main thread, and on a busy CI simulator each took 12 to 55 seconds, so the
            // three dozen this check used to make outlasted the test's time allowance.
            let elements = try app.snapshot().flattened
            let firstRowTop = try XCTUnwrap(
                elements
                    .filter {
                        $0.elementType == .button
                            && $0.identifier.hasPrefix(CalendarAccessibilityID.dayPrefix)
                            && $0.frame.width > 0
                    }
                    .map(\.frame.minY)
                    .min(),
                "\(mode): no day cell in the snapshot")
            for identifier in [
                CalendarAccessibilityID.monthButton, CalendarAccessibilityID.yearButton,
            ] {
                let control = try XCTUnwrap(
                    elements.first { $0.identifier == identifier }, "\(mode): no \(identifier)")
                XCTAssertLessThanOrEqual(
                    control.frame.maxY, firstRowTop + Self.frameTolerance,
                    "\(mode): \(identifier) ends at \(control.frame.maxY), below the first week at \(firstRowTop)"
                )
            }
        }
    }

    // MARK: - Helpers

    @MainActor
    private func visibleFullRow(in app: XCUIApplication) throws -> [XCUIElement] {
        let days = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", CalendarAccessibilityID.dayPrefix))
        XCTAssertTrue(days.firstMatch.waitForExistence(timeout: Self.dayCellTimeout))
        for attempt in 0..<4 {
            // Find the row in one snapshot rather than querying every day cell's frame; only the
            // chosen row's cells are resolved as live elements.
            let snapshot = try app.snapshot()
            let window = snapshot.frame
            let populated = snapshot.flattened.filter {
                $0.elementType == .button
                    && $0.identifier.hasPrefix(CalendarAccessibilityID.dayPrefix)
                    && $0.frame.width > 0 && $0.frame.height > 0
            }
            let rows = Dictionary(grouping: populated) { Int($0.frame.minY.rounded()) }
            for y in rows.keys.sorted() {
                let row = rows[y, default: []].sorted { $0.frame.minX < $1.frame.minX }
                guard row.count == Self.weekdayColumnCount, let first = row.first,
                    window.contains(first.frame)
                else { continue }
                let elements = row.map { app.buttons[$0.identifier] }
                guard elements[0].isHittable else { continue }
                return elements
            }
            // Full Dynamic Type may put the first full week below the viewport. Reveal it;
            // never confuse an offscreen cached row with a clipped or unreachable date.
            if attempt < 3 { app.swipeUp(velocity: .slow) }
        }
        XCTFail("No complete week could be revealed at maximum text size")
        return []
    }

    @MainActor
    private func launch(size: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [Self.sizeFlag, size]
        app.launch()
        return app
    }

    @MainActor
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
