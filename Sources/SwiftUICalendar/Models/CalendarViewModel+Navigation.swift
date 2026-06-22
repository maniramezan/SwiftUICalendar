import Foundation
import SwiftCommons

// MARK: - Month and year navigation

extension CalendarViewModel {

  var canNavigateToPreviousMonth: Bool {
    guard let updatedDate = date(byAddingMonths: -1, to: currentDate) else {
      return false
    }
    return isWithinSupportedYear(updatedDate)
  }

  var canNavigateToNextMonth: Bool {
    guard let updatedDate = date(byAddingMonths: 1, to: currentDate) else {
      return false
    }
    return isWithinSupportedYear(updatedDate)
  }

  var canNavigateToPreviousYear: Bool {
    guard let updatedDate = try? calendar.previousYear(for: currentDate) else {
      return false
    }
    return isWithinSupportedYear(updatedDate)
  }

  var canNavigateToNextYear: Bool {
    guard let updatedDate = try? calendar.nextYear(for: currentDate) else {
      return false
    }
    return isWithinSupportedYear(updatedDate)
  }

  func updateMonthToNextMonth() throws {
    guard let startOfCurrentMonth = firstDate(month: currentMonth, year: currentYear),
      let updatedDate = calendar.date(byAdding: .month, value: 1, to: startOfCurrentMonth),
      isWithinSupportedYear(updatedDate)
    else {
      throw Calendar.CalendarError.cannotCalculateNextMonthFirstDate
    }

    currentDate = updatedDate
  }

  func updateMonth(byAdding months: Int) throws {
    guard let updatedDate = date(byAddingMonths: months, to: currentDate) else {
      throw Calendar.CalendarError.cannotCalculateDate
    }
    guard isWithinSupportedYear(updatedDate) else {
      throw Calendar.CalendarError.cannotCalculateDate
    }

    currentDate = updatedDate
  }

  func updateMonthToPreviousMonth() throws {
    guard let startOfCurrentMonth = firstDate(month: currentMonth, year: currentYear),
      let updatedDate = calendar.date(byAdding: .month, value: -1, to: startOfCurrentMonth),
      isWithinSupportedYear(updatedDate)
    else {
      throw Calendar.CalendarError.cannotCalculatePreviousMonthFirstDate
    }

    currentDate = updatedDate
  }

  func updateYearToNextYear() throws {
    let updatedDate = try calendar.nextYear(for: currentDate)
    guard isWithinSupportedYear(updatedDate) else {
      throw Calendar.CalendarError.cannotCalculateDate
    }

    currentDate = updatedDate
  }

  func updateYearToPreviousYear() throws {
    let updatedDate = try calendar.previousYear(for: currentDate)
    guard isWithinSupportedYear(updatedDate) else {
      throw Calendar.CalendarError.cannotCalculateDate
    }

    currentDate = updatedDate
  }

  func copy(addMonths: Int) throws -> CalendarViewModel {
    let calendarViewModel = CalendarViewModel(
      calendar: calendar,
      currentDate: currentDate,
      selection: selection,
      locale: locale)
    try calendarViewModel.updateMonth(byAdding: addMonths)
    return calendarViewModel
  }

  // MARK: - Today navigation

  func goToToday() {
    let today = Date()
    currentDate = today

    if case .single = selection {
      selection = .single(calendar.startOfDay(for: today))
    }
  }
}
