import XCTest

final class VerticalScrollDateUpdateReproUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  func testVerticalScrollMovesInBothDirectionsForMVVM() throws {
    let app = XCUIApplication()
    app.launch()
    configure(app, architecture: "MVVM")
    assertBidirectionalScrolling(app)
  }

  func testVerticalScrollMovesInBothDirectionsForTCA() throws {
    let app = XCUIApplication()
    app.launch()
    configure(app, architecture: "TCA")
    assertBidirectionalScrolling(app)
  }

  func testSwitchingArchitectureResetsToCurrentMonth() throws {
    let app = XCUIApplication()
    app.launch()
    configure(app, architecture: "MVVM")

    let currentHeaderElement = app.staticTexts.matching(
      NSPredicate(format: "identifier BEGINSWITH 'vertical-month-header-'")
    ).firstMatch
    XCTAssertTrue(currentHeaderElement.waitForExistence(timeout: 5))
    let currentHeader = currentHeaderElement.identifier

    app.scrollViews.firstMatch.swipeUp(velocity: .slow)
    XCTAssertTrue(waitForHeaderToLeaveViewport(currentHeader, in: app))

    app.buttons["Settings"].tap()
    let architecturePicker = app.segmentedControls["state-owner-picker"]
    XCTAssertTrue(architecturePicker.waitForExistence(timeout: 5))
    architecturePicker.buttons["TCA"].tap()
    app.buttons["Done"].tap()

    XCTAssertTrue(app.staticTexts[currentHeader].waitForExistence(timeout: 5))
  }

  func testTCAPathRendersCalendar() throws {
    let app = XCUIApplication()
    app.launch()

    configure(app, architecture: "TCA")

    let dayButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] ','"))
    let rendered = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "count > 0"), object: dayButtons)
    XCTAssertEqual(
      XCTWaiter.wait(for: [rendered], timeout: 5), .completed,
      "The TCA-hosted calendar should render day buttons")
  }

  private func configure(_ app: XCUIApplication, architecture: String) {
    app.buttons["Settings"].tap()
    let scrollPicker = app.segmentedControls["scroll-mode-picker"]
    XCTAssertTrue(scrollPicker.waitForExistence(timeout: 5))
    scrollPicker.buttons["Vertical"].tap()

    let architecturePicker = app.segmentedControls["state-owner-picker"]
    XCTAssertTrue(architecturePicker.waitForExistence(timeout: 5))
    architecturePicker.buttons[architecture].tap()
    app.buttons["Done"].tap()
    XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 5))
  }

  private func assertBidirectionalScrolling(_ app: XCUIApplication) {
    let initial = visibleMonthOrdinals(app)
    XCTAssertFalse(initial.isEmpty)

    app.scrollViews.firstMatch.swipeUp(velocity: .slow)
    XCTAssertTrue(waitForMonthMovement(in: app, beyond: initial.max() ?? 0, direction: 1))
    let afterUp = visibleMonthOrdinals(app)
    XCTAssertGreaterThan(afterUp.max() ?? 0, initial.max() ?? 0)
    XCTAssertLessThanOrEqual((afterUp.max() ?? 0) - (initial.max() ?? 0), 12)

    app.scrollViews.firstMatch.swipeDown(velocity: .slow)
    XCTAssertTrue(waitForMonthMovement(in: app, beyond: afterUp.max() ?? 0, direction: -1))
    let afterDown = visibleMonthOrdinals(app)
    XCTAssertLessThan(afterDown.max() ?? 0, afterUp.max() ?? 0)
    XCTAssertGreaterThanOrEqual(afterDown.min() ?? 0, (initial.min() ?? 0) - 12)
  }

  private func visibleMonthOrdinals(_ app: XCUIApplication) -> [Int] {
    let headers = app.staticTexts.matching(
      NSPredicate(format: "identifier BEGINSWITH 'vertical-month-header-'")
    )
    var ordinals: [Int] = []
    for index in 0..<headers.count {
      let components = headers.element(boundBy: index).identifier.split(separator: "-")
      guard components.count == 5,
        let year = Int(components[3]),
        let month = Int(components[4])
      else { continue }
      ordinals.append(year * 12 + month)
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

  private func waitForHeaderToLeaveViewport(_ identifier: String, in app: XCUIApplication) -> Bool {
    let predicate = NSPredicate { _, _ in
      !app.staticTexts[identifier].isHittable
    }
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
    return XCTWaiter.wait(for: [expectation], timeout: 5) == .completed
  }
}
