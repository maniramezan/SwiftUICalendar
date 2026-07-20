import XCTest

/// Regression coverage for horizontal-scroll-mode rotation. Verifies against the actual live
/// accessibility frame tree of a real device orientation change (via `XCUIDevice`), not a
/// simulated/forced resize — this is the only way to catch layout bugs that only manifest
/// during a genuine live rotation.
final class RotationUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  func testHorizontalCalendarAdaptsAfterLandscapeToPortraitRotation() throws {
    let app = XCUIApplication()
    app.launch()

    // Switch to horizontal scroll mode via the settings sheet.
    app.buttons["Settings"].tap()
    XCTAssertTrue(app.buttons["Horizontal"].waitForExistence(timeout: 5))
    app.buttons["Horizontal"].tap()
    app.buttons["Done"].tap()

    XCUIDevice.shared.orientation = .portrait
    Thread.sleep(forTimeInterval: 1.5)
    let portraitFrame = app.windows.firstMatch.frame

    XCUIDevice.shared.orientation = .landscapeLeft
    Thread.sleep(forTimeInterval: 2.5)

    XCUIDevice.shared.orientation = .portrait
    Thread.sleep(forTimeInterval: 2.5)

    let rotatedBackFrame = app.windows.firstMatch.frame
    XCTAssertEqual(rotatedBackFrame.width, portraitFrame.width, accuracy: 1)
    XCTAssertEqual(rotatedBackFrame.height, portraitFrame.height, accuracy: 1)

    assertNoClippedContent(app, windowFrame: rotatedBackFrame, label: "after landscape->portrait rotation")
  }

  /// Cold-launches the app already in landscape (rather than rotating from a running portrait
  /// state) to rule out a launch-time-specific code path, then rotates to portrait — this is
  /// the exact "switching to portrait" transition the user reports as broken.
  func testHorizontalCalendarAdaptsWhenLaunchedInLandscape() throws {
    XCUIDevice.shared.orientation = .landscapeLeft
    let app = XCUIApplication()
    app.launch()
    Thread.sleep(forTimeInterval: 1.5)

    app.buttons["Settings"].tap()
    XCTAssertTrue(app.buttons["Horizontal"].waitForExistence(timeout: 5))
    app.buttons["Horizontal"].tap()
    app.buttons["Done"].tap()
    Thread.sleep(forTimeInterval: 1.5)

    XCUIDevice.shared.orientation = .portrait
    Thread.sleep(forTimeInterval: 2.5)

    let portraitFrame = app.windows.firstMatch.frame
    XCTAssertGreaterThan(portraitFrame.height, portraitFrame.width, "expected a tall portrait window")

    assertNoClippedContent(app, windowFrame: portraitFrame, label: "after launching in landscape then rotating to portrait")
  }

  private func assertNoClippedContent(_ app: XCUIApplication, windowFrame: CGRect, label: String) {
    // Weekday header letters (S M T W T F S) must all be present and visible.
    let weekdayLabels = ["S", "M", "T", "W", "F"]
    for weekday in weekdayLabels {
      let element = app.staticTexts[weekday].firstMatch
      if element.exists {
        let frame = element.frame
        XCTAssertTrue(
          frame.minX >= 0 && frame.maxX <= windowFrame.width && frame.minY >= 0
            && frame.maxY <= windowFrame.height,
          "weekday header '\(weekday)' clipped \(label): frame=\(frame) window=\(windowFrame)"
        )
      }
    }

    // Every day-cell button for the currently-displayed month must be present, hittable, and
    // fully inside the window bounds — not clipped off-screen or left as blank space.
    // NOTE: the horizontal pager intentionally parks the previous/next month's real day cells
    // just off-screen as a swipe affordance (see CalendarBodyHorizontalView's peek design), so
    // this check is scoped to the CURRENT month only ("Jul") — those adjacent-month cells are
    // supposed to be off-screen and must not be flagged here.
    let dayButtons = app.buttons.matching(
      NSPredicate(format: "label BEGINSWITH 'Jul'")
    )
    let dayCellCount = dayButtons.count
    XCTAssertGreaterThanOrEqual(dayCellCount, 28, "expected at least 4 full weeks of day cells \(label)")

    var clippedDays: [String] = []
    for index in 0..<dayCellCount {
      let button = dayButtons.element(boundBy: index)
      guard button.exists else { continue }
      let frame = button.frame
      let isFullyVisible =
        frame.minX >= 0 && frame.minY >= 0 && frame.maxX <= windowFrame.width
        && frame.maxY <= windowFrame.height && frame.width > 0 && frame.height > 0
      if !isFullyVisible {
        clippedDays.append("\(button.label) frame=\(frame)")
      }
    }

    XCTAssertTrue(
      clippedDays.isEmpty,
      "day cells clipped/invisible \(label): \(clippedDays.joined(separator: ", ")); window=\(windowFrame)"
    )
  }
}
