import SwiftUICalendarAccessibility
import XCTest

@MainActor
final class VerticalScrollDateUpdateReproUITests: SampleUITestCase {
    func testVerticalScrollMovesInBothDirectionsForMVVM() throws {
        let app = XCUIApplication()
        app.launch()
        configure(app, architecture: .mvvm)
        assertBidirectionalScrolling(app)
    }

    func testVerticalScrollMovesInBothDirectionsForTCA() throws {
        let app = XCUIApplication()
        app.launch()
        configure(app, architecture: .tca)
        assertBidirectionalScrolling(app)
    }

    func testSwitchingArchitectureResetsToCurrentMonth() throws {
        let app = XCUIApplication()
        app.launch()
        configure(app, architecture: .mvvm)

        let currentHeaderElement = app.staticTexts.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@",
                CalendarAccessibilityID.verticalMonthHeaderPrefix)
        ).firstMatch
        XCTAssertTrue(currentHeaderElement.waitForExistence(timeout: 5))
        let currentHeader = currentHeaderElement.identifier

        verticalList(in: app).swipeUp(velocity: .slow)
        XCTAssertTrue(waitForHeaderToLeaveViewport(currentHeader, in: app))

        app.openSettings()
        app.option(
            SampleArchitecture.tca.accessibilityIdentifier,
            in: CalendarSampleAccessibilityID.stateOwnerPicker
        ).tap()
        app.dismissSettings()

        XCTAssertTrue(app.staticTexts[currentHeader].waitForExistence(timeout: 5))
    }

    func testTCAPathRendersCalendar() throws {
        let app = XCUIApplication()
        app.launch()

        configure(app, architecture: .tca)

        let dayButtons = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", CalendarAccessibilityID.dayPrefix))
        let rendered = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count > 0"), object: dayButtons)
        XCTAssertEqual(
            XCTWaiter.wait(for: [rendered], timeout: 5), .completed,
            "The TCA-hosted calendar should render day buttons")
    }

    private func configure(_ app: XCUIApplication, architecture: SampleArchitecture) {
        app.chooseScrollMode(.vertical, architecture: architecture)
        XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 5))
    }

    private func assertBidirectionalScrolling(_ app: XCUIApplication) {
        let initial = visibleMonthOrdinals(app)
        XCTAssertFalse(initial.isEmpty)

        verticalList(in: app).swipeUp(velocity: .slow)
        XCTAssertTrue(waitForMonthMovement(in: app, beyond: initial.max() ?? 0, direction: 1))
        let afterUp = visibleMonthOrdinals(app)
        XCTAssertGreaterThan(afterUp.max() ?? 0, initial.max() ?? 0)
        XCTAssertLessThanOrEqual((afterUp.max() ?? 0) - (initial.max() ?? 0), 12)

        verticalList(in: app).swipeDown(velocity: .slow)
        XCTAssertTrue(waitForMonthMovement(in: app, beyond: afterUp.max() ?? 0, direction: -1))
        let afterDown = visibleMonthOrdinals(app)
        XCTAssertLessThan(afterDown.max() ?? 0, afterUp.max() ?? 0)
        XCTAssertGreaterThanOrEqual(afterDown.min() ?? 0, (initial.min() ?? 0) - 12)
    }

    private func verticalList(in app: XCUIApplication) -> XCUIElement {
        // The outer horizontal-overflow viewport includes the fixed header. A downward swipe
        // starting there hits header controls, not the vertical list nested inside it.
        app.scrollViews.element(boundBy: app.scrollViews.count - 1)
    }

    private func visibleMonthOrdinals(_ app: XCUIApplication) -> [Int] {
        let headers = app.staticTexts.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@",
                CalendarAccessibilityID.verticalMonthHeaderPrefix)
        )
        var ordinals: [Int] = []
        for index in 0..<headers.count {
            let header = headers.element(boundBy: index)
            // Lazy stacks retain offscreen months. Their presence does not mean they are visible.
            guard header.isHittable,
                header.frame.intersects(app.windows.firstMatch.frame)
            else { continue }
            guard
                let month = CalendarAccessibilityID.parseVerticalMonthHeader(
                    header.identifier
                )
            else { continue }
            ordinals.append(month.year * 12 + month.month)
        }
        return ordinals
    }

    private func waitForMonthMovement(
        in app: XCUIApplication,
        beyond boundary: Int,
        direction: Int
    ) -> Bool {
        let predicate = NSPredicate { _, _ in
            let values = self.visibleMonthOrdinals(app)
            guard let candidate = values.max() else { return false }
            return direction > 0 ? candidate > boundary : candidate < boundary
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        return XCTWaiter.wait(for: [expectation], timeout: 5) == .completed
    }

    private func waitForHeaderToLeaveViewport(_ identifier: String, in app: XCUIApplication) -> Bool
    {
        let predicate = NSPredicate { _, _ in
            !app.staticTexts[identifier].isHittable
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        return XCTWaiter.wait(for: [expectation], timeout: 5) == .completed
    }
}
