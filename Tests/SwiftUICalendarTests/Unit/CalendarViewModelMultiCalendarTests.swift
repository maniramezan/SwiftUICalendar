import Foundation
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("CalendarViewModel Multi-Calendar Tests")
struct CalendarViewModelMultiCalendarTests {

  // MARK: - Persian

  @MainActor
  @Suite("Persian")
  struct PersianTests {

    // MARK: Month-length correctness

    @Test("months 1–6 have 31 days")
    func persianMonths1To6Have31Days() {
      let vm = CalendarViewModel.test(identifier: .persian)
      for month in 1...6 {
        let metadata = vm.monthMetadata(month: month, year: 1404)
        #expect(metadata?.numberOfDays == 31, "Persian month \(month) of 1404 should have 31 days")
      }
    }

    @Test("months 7–11 have 30 days")
    func persianMonths7To11Have30Days() {
      let vm = CalendarViewModel.test(identifier: .persian)
      for month in 7...11 {
        let metadata = vm.monthMetadata(month: month, year: 1404)
        #expect(metadata?.numberOfDays == 30, "Persian month \(month) of 1404 should have 30 days")
      }
    }

    @Test("Esfand (month 12) has 29 days in non-leap year 1404")
    func persianEsfandHas29DaysInNonLeapYear() {
      let vm = CalendarViewModel.test(identifier: .persian)
      let metadata = vm.monthMetadata(month: 12, year: 1404)
      #expect(metadata?.numberOfDays == 29)
    }

    @Test("Esfand (month 12) has 30 days in leap year 1403")
    func persianEsfandHas30DaysInLeapYear() {
      let vm = CalendarViewModel.test(identifier: .persian)
      let metadata = vm.monthMetadata(month: 12, year: 1403)
      #expect(metadata?.numberOfDays == 30)
    }

    // MARK: Navigation at year boundary

    @Test("next month from Esfand wraps to Farvardin of next year")
    func persianNextMonthFromEsfandWrapsToFarvardin() throws {
      let persianCal = Calendar(identifier: .persian)
      let esfandDate = persianCal.date(from: DateComponents(year: 1404, month: 12, day: 1))!
      let vm = CalendarViewModel.test(identifier: .persian)
      vm.currentDate = esfandDate
      try vm.updateMonthToNextMonth()
      #expect(vm.currentMonth == 1)
      #expect(vm.currentYear == 1405)
    }

    @Test("previous month from Farvardin wraps to Esfand of previous year")
    func persianPreviousMonthFromFarvardinWrapsToEsfand() throws {
      let persianCal = Calendar(identifier: .persian)
      let farvardinDate = persianCal.date(from: DateComponents(year: 1404, month: 1, day: 1))!
      let vm = CalendarViewModel.test(identifier: .persian)
      vm.currentDate = farvardinDate
      try vm.updateMonthToPreviousMonth()
      #expect(vm.currentMonth == 12)
      #expect(vm.currentYear == 1403)
    }

    // MARK: Selection

    @Test("Persian date selected by native DateComponents is detected as selected")
    func persianNativeDateIsDetectedAsSelected() {
      let persianCal = Calendar(identifier: .persian)
      let persianDate = persianCal.date(from: DateComponents(year: 1404, month: 3, day: 15))!
      let vm = CalendarViewModel.test(identifier: .persian)
      vm.select(persianDate)
      #expect(vm.isSelected(date: persianDate))
    }

    // MARK: Range selection

    @Test("range selection spanning Khordad→Tir is correctly bounded")
    func persianRangeSpanningKhordadToTirIsBounded() {
      let persianCal = Calendar(identifier: .persian)
      let start = persianCal.date(from: DateComponents(year: 1404, month: 3, day: 25))!
      let end = persianCal.date(from: DateComponents(year: 1404, month: 4, day: 10))!
      let vm = CalendarViewModel.test(identifier: .persian, selection: .range(start, end))

      let insideRange = persianCal.date(from: DateComponents(year: 1404, month: 4, day: 1))!
      #expect(vm.isSelected(date: insideRange))

      let beforeRange = persianCal.date(from: DateComponents(year: 1404, month: 3, day: 20))!
      #expect(!vm.isSelected(date: beforeRange))

      let afterRange = persianCal.date(from: DateComponents(year: 1404, month: 4, day: 15))!
      #expect(!vm.isSelected(date: afterRange))
    }
  }

  // MARK: - Hebrew

  @MainActor
  @Suite("Hebrew")
  struct HebrewTests {

    // Note: Locale(calendarIdentifier: .hebrew) returns the system locale with a Hebrew
    // The Hebrew calendar's native script is right-to-left, so the calendar lays out RTL even
    // on a non-Hebrew system whose resolved locale language would otherwise report LTR.
    @Test("layoutDirection is rightToLeft for the Hebrew calendar")
    func hebrewLayoutDirectionIsRTL() {
      let vm = CalendarViewModel.test(identifier: .hebrew)
      #expect(vm.layoutDirection == .rightToLeft)
    }

    @Test("year range is in Hebrew era (minYear > 5000, maxYear > 5000)")
    func hebrewYearRangeIsInHebrewEra() {
      let vm = CalendarViewModel.test(identifier: .hebrew)
      #expect(vm.minYear > 5000)
      #expect(vm.maxYear > 5000)
    }

    @Test("monthSymbols has at least 12 entries")
    func hebrewMonthSymbolsHasAtLeast12Entries() {
      let vm = CalendarViewModel.test(identifier: .hebrew)
      #expect(vm.monthSymbols.count >= 12)
    }

    @Test("navigating forward past Elul wraps to Tishri of next year")
    func hebrewNavigatingForwardFromElulWrapsToTishri() throws {
      let hebrewCal = Calendar(identifier: .hebrew)
      // Hebrew year 5785 is a non-leap year; Elul is month 13.
      let elulDate = hebrewCal.date(from: DateComponents(year: 5785, month: 13, day: 1))!
      let vm = CalendarViewModel.test(identifier: .hebrew)
      vm.currentDate = elulDate
      try vm.updateMonthToNextMonth()
      #expect(vm.currentMonth == 1)  // Tishri
      #expect(vm.currentYear == 5786)
    }

    @Test("navigating backward from Tishri wraps to Elul of previous year")
    func hebrewNavigatingBackwardFromTishriWrapsToElul() throws {
      let hebrewCal = Calendar(identifier: .hebrew)
      let tishriDate = hebrewCal.date(from: DateComponents(year: 5786, month: 1, day: 1))!
      let vm = CalendarViewModel.test(identifier: .hebrew)
      vm.currentDate = tishriDate
      try vm.updateMonthToPreviousMonth()
      #expect(vm.currentMonth == 13)  // Elul of 5785 (non-leap year)
      #expect(vm.currentYear == 5785)
    }

    @Test("leap year month navigation includes Adar I")
    func hebrewLeapYearNavigationIncludesAdarI() throws {
      let hebrewCal = Calendar(identifier: .hebrew)
      let shevatDate = hebrewCal.date(from: DateComponents(year: 5784, month: 5, day: 1))!
      let vm = CalendarViewModel.test(identifier: .hebrew)
      vm.currentDate = shevatDate

      try vm.updateMonthToNextMonth()
      #expect(vm.currentMonth == 6)

      try vm.updateMonthToNextMonth()
      #expect(vm.currentMonth == 7)
    }

    @Test("single selection in Hebrew calendar is detected as selected")
    func hebrewSingleSelectionIsDetected() {
      let hebrewCal = Calendar(identifier: .hebrew)
      let hebrewDate = hebrewCal.date(from: DateComponents(year: 5785, month: 7, day: 15))!
      let vm = CalendarViewModel.test(identifier: .hebrew)
      vm.select(hebrewDate)
      #expect(vm.isSelected(date: hebrewDate))
    }
  }

  // MARK: - Islamic (Umm al-Qura)

  @MainActor
  @Suite("Islamic Umm al-Qura")
  struct IslamicTests {

    // The Islamic calendar's native script is right-to-left, so the calendar lays out RTL even
    // on a non-Arabic system whose resolved locale language would otherwise report LTR.
    @Test("layoutDirection is rightToLeft for the Islamic calendar")
    func islamicLayoutDirectionIsRTL() {
      let vm = CalendarViewModel.test(identifier: .islamicUmmAlQura)
      #expect(vm.layoutDirection == .rightToLeft)
    }

    @Test("year range is in Islamic era (minYear > 1300, maxYear > 1300)")
    func islamicYearRangeIsInIslamicEra() {
      let vm = CalendarViewModel.test(identifier: .islamicUmmAlQura)
      #expect(vm.minYear > 1300)
      #expect(vm.maxYear > 1300)
    }

    @Test("headerTitles has 7 entries")
    func islamicHeaderTitlesHasSevenEntries() {
      let vm = CalendarViewModel.test(identifier: .islamicUmmAlQura)
      #expect(vm.headerTitles.count == 7)
    }

    @Test("monthSymbols has 12 entries")
    func islamicMonthSymbolsHas12Entries() {
      let vm = CalendarViewModel.test(identifier: .islamicUmmAlQura)
      #expect(vm.monthSymbols.count == 12)
    }

    @Test("navigating forward from Dhul Hijjah (month 12) wraps to Muharram of next year")
    func islamicNavigatingForwardFromDhulHijjahWrapsToMuharram() throws {
      let islamicCal = Calendar(identifier: .islamicUmmAlQura)
      let dhulHijjahDate = islamicCal.date(from: DateComponents(year: 1446, month: 12, day: 1))!
      let vm = CalendarViewModel.test(identifier: .islamicUmmAlQura)
      vm.currentDate = dhulHijjahDate
      try vm.updateMonthToNextMonth()
      #expect(vm.currentMonth == 1)  // Muharram
      #expect(vm.currentYear == 1447)
    }

    @Test("navigating backward from Muharram (month 1) wraps to Dhul Hijjah of previous year")
    func islamicNavigatingBackwardFromMuharramWrapsToDhulHijjah() throws {
      let islamicCal = Calendar(identifier: .islamicUmmAlQura)
      let muharramDate = islamicCal.date(from: DateComponents(year: 1447, month: 1, day: 1))!
      let vm = CalendarViewModel.test(identifier: .islamicUmmAlQura)
      vm.currentDate = muharramDate
      try vm.updateMonthToPreviousMonth()
      #expect(vm.currentMonth == 12)  // Dhul Hijjah
      #expect(vm.currentYear == 1446)
    }

    @Test("single selection is detected as selected")
    func islamicSingleSelectionIsDetected() {
      let islamicCal = Calendar(identifier: .islamicUmmAlQura)
      let islamicDate = islamicCal.date(from: DateComponents(year: 1446, month: 9, day: 15))!
      let vm = CalendarViewModel.test(identifier: .islamicUmmAlQura)
      vm.select(islamicDate)
      #expect(vm.isSelected(date: islamicDate))
    }
  }

  // MARK: - Chinese

  @MainActor
  @Suite("Chinese")
  struct ChineseTests {

    @Test("layoutDirection is leftToRight")
    func chineseLayoutDirectionIsLTR() {
      let vm = CalendarViewModel.test(identifier: .chinese)
      #expect(vm.layoutDirection == .leftToRight)
    }

    @Test("headerTitles has 7 entries")
    func chineseHeaderTitlesHasSevenEntries() {
      let vm = CalendarViewModel.test(identifier: .chinese)
      #expect(vm.headerTitles.count == 7)
    }

    @Test("monthSymbols is non-empty")
    func chineseMonthSymbolsIsNonEmpty() {
      let vm = CalendarViewModel.test(identifier: .chinese)
      #expect(!vm.monthSymbols.isEmpty)
    }

    @Test("navigating forward advances month")
    func chineseNavigatingForwardAdvancesDate() throws {
      let vm = CalendarViewModel.test(identifier: .chinese)
      let dateBefore = vm.currentDate
      try vm.updateMonthToNextMonth()
      #expect(vm.currentDate != dateBefore)
    }

    @Test("navigating backward retreats month")
    func chineseNavigatingBackwardRetreatsDate() throws {
      let vm = CalendarViewModel.test(identifier: .chinese)
      let dateBefore = vm.currentDate
      try vm.updateMonthToPreviousMonth()
      #expect(vm.currentDate != dateBefore)
    }
  }
}
