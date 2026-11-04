import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Calendar ideal height")
struct CalendarIdealHeightTests {
    @Test("Ideal height includes tall custom rows and the measured weekday header")
    func tallContentHeight() {
        let metrics = CalendarMetrics.default.resolvingContent(
            cell: CGSize(width: 44, height: 100), weekday: CGSize(width: 0, height: 80))
        #expect(metrics.sixRowHeight(cell: 44, controls: 104) == 836)
        #expect(metrics.idealGrownHeight(width: 390, hostHeight: nil, controls: 104) == 836)
    }

    @Test("A height bound respects both measured floors before growing cells")
    func measuredFloorsBoundGrowth() {
        let metrics = CalendarMetrics.default.resolvingContent(
            cell: CGSize(width: 44, height: 100), weekday: CGSize(width: 0, height: 80))
        let fitted = metrics.growingCells(toFitHeight: 836, controls: 104)
        #expect(fitted.maxCellSize == 100)
        let tooShort = metrics.growingCells(toFitHeight: 835, controls: 104)
        #expect(tooShort.maxCellSize == 64)
    }

    @Test("The weekday height floor is retained at the minimum cell width")
    func minimumWidthWeekdayFloor() {
        #expect(CalendarMetrics.default.sixRowHeight(cell: 44, controls: 104) == 444)
    }

    @Test("Book folds use the standard ideal height without removing a companion")
    func bookFoldHeight() {
        let metrics = CalendarMetrics.default
        let ideal = CalendarIdealHeight(
            metrics: metrics, showsHeader: true, growsCells: true, hostHeight: nil,
            foldRegions: [CGRect(x: 630, y: 0, width: 40, height: 1100)],
            allowsCompanion: true)
        #expect(abs(ideal(1300) - 568.8) < 0.001)
        var single = ideal
        single.allowsCompanion = false
        #expect(single(1300) > 900)
    }

    @Test("Tabletop folds reserve standard height below the division")
    func tabletopFoldHeight() {
        let ideal = CalendarIdealHeight(
            metrics: .default, showsHeader: true, growsCells: true, hostHeight: nil,
            foldRegions: [CGRect(x: 0, y: 430, width: 900, height: 40)],
            allowsCompanion: true)
        #expect(abs(ideal(900) - 1038.8) < 0.001)
    }

    @Test("A division outside the viewport does not suppress cell growth")
    func outsideFold() {
        let ideal = CalendarIdealHeight(
            metrics: .default, showsHeader: true, growsCells: true, hostHeight: nil,
            foldRegions: [CGRect(x: 2000, y: 0, width: 40, height: 1100)],
            allowsCompanion: true)
        #expect(ideal(1300) > 900)
    }

    @Test("Unequal book panels reserve enough height for the wider month's cells")
    func asymmetricBookFold() {
        let ideal = CalendarIdealHeight(
            metrics: .default, showsHeader: true, growsCells: true, hostHeight: nil,
            foldRegions: [CGRect(x: 340, y: 0, width: 40, height: 1100)],
            allowsCompanion: true)
        #expect(abs(ideal(1300) - 568.8) < 0.001)
    }
}
