import XCTest

/// The vertically scrolling calendar fills a ±20-year window around the current month and then
/// jumps to it. A `LazyVStack` can drop a jump made before its rows have laid out, and when it did
/// the calendar opened at the start of the window — twenty years in the past. Landscape, where the
/// first layout pass is already final, is where it happened.
final class VerticalLandscapeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
    }

    func testVerticalCalendarOpensOnTheCurrentMonthInLandscape() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launch()

        app.chooseScrollMode("Vertical")
        Thread.sleep(forTimeInterval: 1.5)

        let now = Date()
        let month = now.formatted(.dateTime.month(.wide))
        let year = now.formatted(.dateTime.year())
        let window = app.windows.firstMatch.frame
        let currentMonthDays = app.buttons.matching(
            NSPredicate(
                format: "label BEGINSWITH %@ AND label CONTAINS %@", "\(month) ", ", \(year)"))
        let visible = (0..<currentMonthDays.count)
            .map { currentMonthDays.element(boundBy: $0).frame }
            .filter { $0.minY >= 0 && $0.maxY <= window.height && $0.width > 0 }
        XCTAssertFalse(
            visible.isEmpty,
            "no day of \(month) \(year) is on screen in landscape; the vertical calendar opened elsewhere"
        )

        let twentyYearsAgo = String(Int(year).map { $0 - 20 } ?? 0)
        let ancientDays = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", ", \(twentyYearsAgo)"))
        let ancientVisible = (0..<ancientDays.count)
            .map { ancientDays.element(boundBy: $0).frame }
            .filter { $0.minY >= 0 && $0.maxY <= window.height && $0.width > 0 }
        XCTAssertTrue(
            ancientVisible.isEmpty,
            "the vertical calendar opened \(twentyYearsAgo), at the start of its window")
    }
}
