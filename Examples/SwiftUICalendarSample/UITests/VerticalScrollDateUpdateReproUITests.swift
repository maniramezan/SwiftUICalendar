import SwiftUICalendarAccessibility
import XCTest

@MainActor
final class VerticalScrollDateUpdateReproUITests: SampleUITestCase {
    func testVerticalScrollMovesInBothDirectionsForMVVM() async throws {
        let app = sampleApplication()
        app.launch()
        configure(app, architecture: .mvvm)
        try await assertBidirectionalScrolling(app)
    }

    func testVerticalScrollMovesInBothDirectionsForTCA() async throws {
        let app = sampleApplication()
        app.launch()
        configure(app, architecture: .tca)
        try await assertBidirectionalScrolling(app)
    }

    func testSwitchingArchitectureResetsToCurrentMonth() async throws {
        let app = sampleApplication()
        app.launch()
        configure(app, architecture: .mvvm)

        let initialHeaders = try visibleMonthHeaders(app)
        let currentHeader = try XCTUnwrap(initialHeaders.first?.identifier)

        verticalList(in: app).swipeUp(velocity: .slow)
        let leftViewport = try await waitForHeaders(in: app) { headers in
            !headers.contains { $0.identifier == currentHeader }
        }
        XCTAssertTrue(leftViewport)

        app.openSettings()
        app.option(
            SampleArchitecture.tca.accessibilityIdentifier,
            in: CalendarSampleAccessibilityID.stateOwnerPicker
        ).tap()
        app.dismissSettings()

        let returnedToViewport = try await waitForHeaders(in: app) { headers in
            headers.contains { $0.identifier == currentHeader }
        }
        XCTAssertTrue(returnedToViewport)
    }

    func testTCAPathRendersCalendar() throws {
        let app = sampleApplication()
        app.launch()

        configure(app, architecture: .tca)

        let dayButtons = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", CalendarAccessibilityID.dayPrefix))
        XCTAssertTrue(
            dayButtons.firstMatch.waitForExistence(timeout: 5),
            "The TCA-hosted calendar should render day buttons")
    }

    private func configure(_ app: XCUIApplication, architecture: SampleArchitecture) {
        app.chooseScrollMode(.vertical, architecture: architecture)
        XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 5))
    }

    private func assertBidirectionalScrolling(_ app: XCUIApplication) async throws {
        let initial = try visibleMonthHeaders(app).map(\.ordinal)
        XCTAssertFalse(initial.isEmpty)

        verticalList(in: app).swipeUp(velocity: .slow)
        let movedUp = try await waitForMonthMovement(
            in: app, beyond: initial.max() ?? 0, direction: 1)
        XCTAssertTrue(movedUp)
        let afterUp = try visibleMonthHeaders(app).map(\.ordinal)
        XCTAssertGreaterThan(afterUp.max() ?? 0, initial.max() ?? 0)
        XCTAssertLessThanOrEqual((afterUp.max() ?? 0) - (initial.max() ?? 0), 12)

        verticalList(in: app).swipeDown(velocity: .slow)
        let movedDown = try await waitForMonthMovement(
            in: app, beyond: afterUp.max() ?? 0, direction: -1)
        XCTAssertTrue(movedDown)
        let afterDown = try visibleMonthHeaders(app).map(\.ordinal)
        XCTAssertLessThan(afterDown.max() ?? 0, afterUp.max() ?? 0)
        XCTAssertGreaterThanOrEqual(afterDown.min() ?? 0, (initial.min() ?? 0) - 12)
    }

    private func verticalList(in app: XCUIApplication) -> XCUIElement {
        // The outer horizontal-overflow viewport includes the fixed header. A downward swipe
        // starting there hits header controls, not the vertical list nested inside it.
        app.scrollViews.element(boundBy: app.scrollViews.count - 1)
    }

    private struct VisibleMonthHeader {
        let identifier: String
        let ordinal: Int
    }

    private func visibleMonthHeaders(_ app: XCUIApplication) throws -> [VisibleMonthHeader] {
        // One snapshot keeps every frame in the same update and avoids live hit-testing RPCs for
        // retained LazyVStack rows. Labels only need to intersect the actual vertical viewport.
        let window = try app.windows.firstMatch.snapshot()
        let elements = window.flattened
        let verticalScroll = try XCTUnwrap(elements.last { $0.elementType == .scrollView })
        let viewport = verticalScroll.frame.intersection(window.frame)
        return elements.compactMap { header in
            guard header.elementType == .staticText,
                !header.frame.isEmpty,
                header.frame.intersects(viewport),
                let month = CalendarAccessibilityID.parseVerticalMonthHeader(header.identifier)
            else { return nil }
            return VisibleMonthHeader(
                identifier: header.identifier, ordinal: month.year * 12 + month.month)
        }
    }

    private func waitForMonthMovement(
        in app: XCUIApplication,
        beyond boundary: Int,
        direction: Int
    ) async throws -> Bool {
        try await waitForHeaders(in: app) { headers in
            guard let candidate = headers.map(\.ordinal).max() else { return false }
            return direction > 0 ? candidate > boundary : candidate < boundary
        }
    }

    private func waitForHeaders(
        in app: XCUIApplication,
        matching predicate: ([VisibleMonthHeader]) -> Bool
    ) async throws -> Bool {
        let deadline = ContinuousClock.now + .seconds(5)
        repeat {
            if predicate(try visibleMonthHeaders(app)) { return true }
            // Yield the runner's main actor instead of re-entering live XCTest queries from an
            // XCTNSPredicateExpectation callback while a scroll is settling.
            try await Task.sleep(for: .milliseconds(100))
        } while ContinuousClock.now < deadline
        return false
    }
}
