import Foundation
import SwiftCommons
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("CalendarView structural snapshots", .enabled(if: snapshotsEnabled))
struct CalendarViewSnapshotTests {

    private let snapshotWidth: CGFloat = 390

    @Test(
        "Resizable iPad calendar",
        arguments: [
            CalendarConfiguration.ScrollMode.none, .vertical, .horizontal,
        ], [Calendar.Identifier.gregorian, .persian])
    func resizableCalendar(mode: CalendarConfiguration.ScrollMode, identifier: Calendar.Identifier)
    {
        let model = CalendarViewModel.snapshot(identifier: identifier, selection: .single(nil))
        assertCalendarStructure(
            model: model, configuration: .init(scrollMode: mode),
            width: 600, named: "ipad-\(mode)-\(identifier)")
    }

    @Test("Fixed calendar with header")
    func fixedCalendarWithHeader() throws {
        let vm = CalendarViewModel.snapshot(selection: .single(nil))
        try vm.navigate(toMonth: SwiftCommons.MonthIdentifier(month: 6, year: 2025))
        assertCalendarStructure(
            model: vm, configuration: CalendarConfiguration(showsHeader: true),
            width: snapshotWidth, named: "fixed-calendar-with-header")
    }

    @Test("Fixed calendar without header")
    func fixedCalendarWithoutHeader() {
        let vm = CalendarViewModel.snapshot(selection: .single(nil))
        assertCalendarStructure(
            model: vm, configuration: CalendarConfiguration(showsHeader: false),
            width: snapshotWidth, named: "fixed-calendar-without-header")
    }

    @Test("Vertical scroll mode")
    func verticalCalendar() throws {
        let vm = CalendarViewModel.snapshot(selection: .single(nil))
        // Exercise a distant settlement and return to the pinned month before asserting
        // that navigation preserves the vertical rendering structure.
        let original = vm.visibleMonth
        let distant = try #require(vm.monthIdentifier(offset: 60))
        try vm.navigate(toMonth: distant)
        try vm.navigate(toMonth: original)
        assertCalendarStructure(
            model: vm, configuration: CalendarConfiguration(scrollMode: .vertical),
            width: snapshotWidth, monthSpan: 1, named: "vertical-calendar")
    }

    @Test("Horizontal scroll mode")
    func horizontalCalendar() {
        let vm = CalendarViewModel.snapshot(selection: .single(nil))
        assertCalendarStructure(
            model: vm, configuration: CalendarConfiguration(scrollMode: .horizontal),
            width: snapshotWidth, monthSpan: 1, named: "horizontal-calendar")
    }

    @Test("Horizontal calendar in a short landscape viewport")
    func horizontalCalendarInShortLandscapeViewport() {
        let vm = CalendarViewModel.snapshot(selection: .single(nil))
        assertCalendarStructure(
            model: vm, configuration: CalendarConfiguration(scrollMode: .horizontal),
            width: 844, monthSpan: 1, named: "horizontal-calendar-short-landscape")
    }

    @Test("Flexible grid fills a landscape horizontal calendar")
    func flexibleHorizontalCalendarInLandscapeViewport() {
        let vm = CalendarViewModel.snapshot(selection: .single(nil))
        assertCalendarStructure(
            model: vm,
            configuration: CalendarConfiguration(scrollMode: .horizontal, gridSizing: .flexible),
            width: 844, monthSpan: 1, named: "horizontal-calendar-flexible-landscape")
    }

    @Test("Adaptive horizontal calendar in a portrait viewport")
    func adaptiveHorizontalCalendarInPortraitViewport() {
        let vm = CalendarViewModel.snapshot(selection: .single(nil))
        assertCalendarStructure(
            model: vm, configuration: CalendarConfiguration(scrollMode: .horizontal),
            width: 390, monthSpan: 1, named: "horizontal-calendar-adaptive-portrait")
    }

    @Test("Persian header and localized weekday titles")
    func calendarHeader() {
        let vm = CalendarViewModel.snapshot(identifier: .persian, selection: .single(nil))
        assertCalendarStructure(
            model: vm, configuration: CalendarConfiguration(showsHeader: true),
            width: snapshotWidth, named: "calendar-header-persian")
    }
}
