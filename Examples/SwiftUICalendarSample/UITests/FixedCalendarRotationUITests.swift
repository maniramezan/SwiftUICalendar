import XCTest

/// Regression coverage for the exact bug captured in a real device recording: after rotating
/// landscape -> portrait, the fixed (`.none` scroll mode) calendar grid rendered at a stale,
/// wider-than-viewport size, symmetrically clipping the Sunday and Saturday columns off both
/// edges of the screen and showing only 5 of 7 weekday columns.
final class FixedCalendarRotationUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  func testFixedCalendarShowsAllWeekdayColumnsAfterLandscapeToPortraitRotation() throws {
    let app = XCUIApplication()
    app.launch()
    // Default configuration is scroll mode `.none` — no settings change needed.

    XCUIDevice.shared.orientation = .portrait
    Thread.sleep(forTimeInterval: 1.5)

    XCUIDevice.shared.orientation = .landscapeLeft
    Thread.sleep(forTimeInterval: 2.5)

    XCUIDevice.shared.orientation = .portrait
    Thread.sleep(forTimeInterval: 2.5)

    let windowFrame = app.windows.firstMatch.frame

    // The weekday header row is intentionally `.accessibilityHidden(true)`, so verify column
    // count via the actual day-cell buttons instead: collect the distinct x-positions (rounded)
    // of every day-of-month button. A correctly laid-out grid has 7 distinct columns; the
    // captured bug rendered only 5 (Sunday and Saturday clipped off both edges).
    let dayButtons = app.buttons.matching(
      NSPredicate(
        format:
          "label MATCHES '.*(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) [0-9]+, [0-9]+.*'")
    )
    let dayCellCount = dayButtons.count
    XCTAssertGreaterThan(dayCellCount, 0, "no day cells found after rotation")

    var distinctColumnXPositions = Set<Int>()
    for index in 0..<dayCellCount {
      let button = dayButtons.element(boundBy: index)
      guard button.exists else { continue }
      distinctColumnXPositions.insert(Int(button.frame.minX.rounded()))
    }
    XCTAssertEqual(
      distinctColumnXPositions.count, 7,
      "expected 7 weekday columns after rotation, found \(distinctColumnXPositions.count) — "
        + "columns may be clipped off the viewport edges"
    )

    // Today's day cell must be fully visible (not cropped at an edge). Distinguish the day cell
    // (label like "Jul 19, 2026, Today, Selected") from the standalone "Today" nav button.
    let today = app.buttons.matching(NSPredicate(format: "label CONTAINS ', Today'")).firstMatch
    XCTAssertTrue(today.waitForExistence(timeout: 3))
    let todayFrame = today.frame
    XCTAssertGreaterThanOrEqual(
      todayFrame.minX, 0, "today's cell is cropped off the left edge after rotation")
    XCTAssertLessThanOrEqual(
      todayFrame.maxX, windowFrame.width, "today's cell is cropped off the right edge after rotation")
    XCTAssertGreaterThan(todayFrame.width, 20, "today's cell is a sliver, not a full cell")
  }
}
