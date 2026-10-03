import Foundation
import SwiftUI
import Testing

@testable import SwiftUICalendar

/// Structural baselines for every calendar system in every scroll mode, and for every grid sizing
/// at narrow and wide widths — the permutations the focused snapshot suites do not enumerate.
@MainActor
@Suite("Variant matrix structural snapshots", .enabled(if: snapshotsEnabled))
struct CalendarVariantMatrixSnapshotTests {
    @Test(
        "Every calendar system renders in every scroll mode",
        arguments: CalendarVariantMatrixTests.identifiers,
        [CalendarConfiguration.ScrollMode.none, .vertical, .horizontal])
    func identifierByMode(
        identifier: Calendar.Identifier, mode: CalendarConfiguration.ScrollMode
    ) {
        let vm = CalendarViewModel.snapshot(identifier: identifier)
        assertCalendarStructure(
            model: vm, configuration: CalendarConfiguration(scrollMode: mode),
            monthSpan: mode == .none ? 0 : 1, named: "\(identifier)-\(mode)")
    }

    @Test(
        "Every grid sizing resolves its layout in every scroll mode and width",
        arguments: CalendarVariantMatrixTests.sizingCombos)
    func gridSizing(
        sizing: CalendarConfiguration.GridSizing, mode: CalendarConfiguration.ScrollMode,
        width: CGFloat
    ) {
        let vm = CalendarViewModel.snapshot()
        assertCalendarStructure(
            model: vm, configuration: CalendarConfiguration(scrollMode: mode, gridSizing: sizing),
            width: width, named: "\(sizing)-\(mode)-\(Int(width))")
    }
}
