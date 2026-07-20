import XCTest

final class RotationScrollUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  func testHorizontalCalendarResetsScrollPositionAfterRotatingFromScrolledLandscape() throws {
    let app = XCUIApplication()
    app.launch()

    app.buttons["Settings"].tap()
    XCTAssertTrue(app.buttons["Horizontal"].waitForExistence(timeout: 5))
    app.buttons["Horizontal"].tap()
    app.buttons["Done"].tap()

    XCUIDevice.shared.orientation = .landscapeLeft
    Thread.sleep(forTimeInterval: 2.0)

    // Scroll down within the landscape viewport, where six rows may not fit in the
    // shorter height and a vertical scroll is needed.
    app.swipeUp()
    Thread.sleep(forTimeInterval: 1.0)

    XCUIDevice.shared.orientation = .portrait
    Thread.sleep(forTimeInterval: 2.5)

    let windowFrame = app.windows.firstMatch.frame

    // The first day of the current month must be visible within the portrait window — not
    // scrolled off-screen due to a stale scroll offset carried over from the landscape state.
    let dayOne = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Jul 1,'")).firstMatch
    XCTAssertTrue(dayOne.waitForExistence(timeout: 3))
    let dayOneFrame = dayOne.frame
    XCTAssertTrue(
      dayOneFrame.minY >= 0 && dayOneFrame.maxY <= windowFrame.height,
      "first day of month scrolled off-screen after rotating from a scrolled landscape state: frame=\(dayOneFrame) window=\(windowFrame)"
    )
  }
}
