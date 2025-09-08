import Foundation
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("CalendarViewModel Selection Tests")
struct CalendarViewModelSelectionTests {

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day))!
    }

    // MARK: - Single Selection

    @Test("Single: selects a date")
    func singleSelectsDate() {
        let vm = CalendarViewModel.test()
        let date = makeDate(year: 2025, month: 6, day: 15)
        vm.select(date)
        guard case .single(let selected) = vm.selection else {
            Issue.record("Expected single selection")
            return
        }
        #expect(selected != nil)
    }

    @Test("Single: deselects on re-tap")
    func singleDeselectsOnReTap() {
        let vm = CalendarViewModel.test()
        let date = makeDate(year: 2025, month: 6, day: 15)
        vm.select(date)
        vm.select(date)
        guard case .single(let selected) = vm.selection else {
            Issue.record("Expected single selection")
            return
        }
        #expect(selected == nil)
    }

    @Test("Single: replaces old selection")
    func singleReplacesOldSelection() {
        let vm = CalendarViewModel.test()
        let date1 = makeDate(year: 2025, month: 6, day: 10)
        let date2 = makeDate(year: 2025, month: 6, day: 20)
        vm.select(date1)
        vm.select(date2)
        guard case .single(let selected) = vm.selection, let selected else {
            Issue.record("Expected single selection with a value")
            return
        }
        let cal = Calendar(identifier: .gregorian)
        #expect(cal.isDate(selected, inSameDayAs: date2))
    }

    // MARK: - Range Selection

    @Test("Range: sets start then end")
    func rangeSetsStartThenEnd() {
        let vm = CalendarViewModel.test(selection: .range())
        let start = makeDate(year: 2025, month: 6, day: 1)
        let end = makeDate(year: 2025, month: 6, day: 10)
        vm.select(start)
        vm.select(end)
        guard case .range(let s, let e) = vm.selection else {
            Issue.record("Expected range selection")
            return
        }
        #expect(s != nil)
        #expect(e != nil)
    }

    @Test("Range: swaps when end is before start")
    func rangeSwapsWhenEndBeforeStart() {
        let vm = CalendarViewModel.test(selection: .range())
        let later = makeDate(year: 2025, month: 6, day: 20)
        let earlier = makeDate(year: 2025, month: 6, day: 5)
        vm.select(later)
        vm.select(earlier)
        guard case .range(let s, let e) = vm.selection, let start = s, let end = e else {
            Issue.record("Expected range with both start and end set")
            return
        }
        #expect(start <= end, "Start should be on or before end after swap")
    }

    @Test("Range: resets to new start on third tap")
    func rangeResetsOnThirdTap() {
        let vm = CalendarViewModel.test(selection: .range())
        vm.select(makeDate(year: 2025, month: 6, day: 1))
        vm.select(makeDate(year: 2025, month: 6, day: 10))
        vm.select(makeDate(year: 2025, month: 6, day: 15))
        guard case .range(let s, let e) = vm.selection else {
            Issue.record("Expected range selection")
            return
        }
        #expect(s != nil)
        #expect(e == nil)
    }

    @Test("Range: isSelected within range")
    func rangeIsSelectedWithinRange() {
        let start = makeDate(year: 2025, month: 6, day: 1)
        let end = makeDate(year: 2025, month: 6, day: 10)
        let vm = CalendarViewModel.test(selection: .range(start, end))
        let mid = makeDate(year: 2025, month: 6, day: 5)
        #expect(vm.isSelected(date: mid))
    }

    @Test("Range: isSelected outside range")
    func rangeIsNotSelectedOutsideRange() {
        let start = makeDate(year: 2025, month: 6, day: 1)
        let end = makeDate(year: 2025, month: 6, day: 10)
        let vm = CalendarViewModel.test(selection: .range(start, end))
        let outside = makeDate(year: 2025, month: 6, day: 20)
        #expect(!vm.isSelected(date: outside))
    }

    @Test("Range: deselects start when tapped again")
    func rangeDeselectsStartOnReTap() {
        let vm = CalendarViewModel.test(selection: .range())
        let start = makeDate(year: 2025, month: 6, day: 1)
        vm.select(start)
        vm.select(start)
        guard case .range(let s, let e) = vm.selection else {
            Issue.record("Expected range selection")
            return
        }
        #expect(s == nil)
        #expect(e == nil)
    }

    // MARK: - Multiple Selection

    @Test("Multiple: adds dates independently")
    func multipleAddsDates() {
        let vm = CalendarViewModel.test(selection: .multiple())
        let date1 = makeDate(year: 2025, month: 6, day: 1)
        let date2 = makeDate(year: 2025, month: 6, day: 15)
        vm.select(date1)
        vm.select(date2)
        guard case .multiple(let dates) = vm.selection else {
            Issue.record("Expected multiple selection")
            return
        }
        #expect(dates.count == 2)
    }

    @Test("Multiple: removes on re-tap")
    func multipleRemovesOnReTap() {
        let vm = CalendarViewModel.test(selection: .multiple())
        let date = makeDate(year: 2025, month: 6, day: 1)
        vm.select(date)
        vm.select(date)
        guard case .multiple(let dates) = vm.selection else {
            Issue.record("Expected multiple selection")
            return
        }
        #expect(dates.isEmpty)
    }

    @Test("Multiple: all three selections are independently tracked")
    func multipleIndependentSelections() {
        let vm = CalendarViewModel.test(selection: .multiple())
        let date1 = makeDate(year: 2025, month: 6, day: 1)
        let date2 = makeDate(year: 2025, month: 6, day: 15)
        let date3 = makeDate(year: 2025, month: 6, day: 30)
        vm.select(date1)
        vm.select(date2)
        vm.select(date3)
        #expect(vm.isSelected(date: date1))
        #expect(vm.isSelected(date: date2))
        #expect(vm.isSelected(date: date3))
    }

    // MARK: - Date Normalization

    @Test("Normalization: date with time component matches start of day")
    func normalizesDateToStartOfDay() {
        let vm = CalendarViewModel.test()
        var comps = DateComponents()
        comps.year = 2025
        comps.month = 6
        comps.day = 15
        comps.hour = 14
        comps.minute = 30
        let dateWithTime = Calendar(identifier: .gregorian).date(from: comps)!
        vm.select(dateWithTime)
        let startOfDay = Calendar(identifier: .gregorian).startOfDay(for: dateWithTime)
        #expect(vm.isSelected(date: startOfDay))
    }
}
