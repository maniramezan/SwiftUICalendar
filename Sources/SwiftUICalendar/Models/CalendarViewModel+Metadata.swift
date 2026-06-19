import Foundation
import SwiftCommons

// MARK: - Month metadata, grid sizing, and date resolution

extension CalendarViewModel {

  func monthMetadata(offset: Int) -> MonthMetadata? {
    if offset == 0 {
      return MonthMetadata(
        month: currentMonth,
        year: currentYear,
        numberOfDays: numberOfDaysInMonth
      )
    }
    guard let targetDate = date(byAddingMonths: offset, to: currentDate) else {
      return nil
    }
    let month = calendar.month(from: targetDate)
    let year = calendar.year(from: targetDate)
    let numberOfDays = (try? calendar.numberOfDays(for: targetDate)) ?? numberOfDaysInMonth
    return MonthMetadata(month: month, year: year, numberOfDays: numberOfDays)
  }

  func monthMetadata(month: Int, year: Int) -> MonthMetadata? {
    months(in: year).first(where: { $0.month == month })
  }

  func monthMetadata(month: Int, year: Int, offset: Int) -> MonthMetadata? {
    guard let date = firstDate(month: month, year: year),
      let targetDate = self.date(byAddingMonths: offset, to: date)
    else {
      return nil
    }

    let targetMonth = calendar.month(from: targetDate)
    let targetYear = calendar.year(from: targetDate)
    let numberOfDays = (try? calendar.numberOfDays(for: targetDate)) ?? numberOfDaysInMonth
    return MonthMetadata(month: targetMonth, year: targetYear, numberOfDays: numberOfDays)
  }

  func months(in year: Int) -> [MonthMetadata] {
    guard let startDate = firstDate(month: 1, year: year) else {
      return []
    }

    var months: [MonthMetadata] = []
    var visitedMonths = Set<Int>()
    var date = startDate

    while calendar.year(from: date) == year {
      let month = calendar.month(from: date)
      if visitedMonths.insert(month).inserted {
        let numberOfDays = (try? calendar.numberOfDays(for: date)) ?? 0
        months.append(MonthMetadata(month: month, year: year, numberOfDays: numberOfDays))
      }

      guard let nextDate = calendar.date(byAdding: .month, value: 1, to: date) else {
        break
      }
      date = nextDate
    }

    return months
  }

  /// Returns the absolute date for a day in the currently displayed month, or `nil` if the
  /// components cannot be resolved in the active calendar.
  func date(for day: Int) -> Date? {
    guard
      let date = calendar.date(
        from: DateComponents(year: currentYear, month: currentMonth, day: day))
    else {
      logger.error("Cannot create date from components for day: \(day)")
      return nil
    }
    return date
  }

  /// Returns the absolute date for a day/month/year in the active calendar, or `nil` if the
  /// components cannot be resolved.
  ///
  /// Returns `nil` rather than a placeholder so callers never mistake a failed calculation for a
  /// real (and possibly "today"/"selected") date.
  func date(for day: Int, month: Int, year: Int) -> Date? {
    guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
      logger.error(
        "Cannot create date from components for day: \(day) month: \(month) year: \(year)")
      return nil
    }
    return date
  }

  func startOfMonthDay(month: Int, year: Int) -> Int {
    guard let date = firstDate(month: month, year: year) else {
      return 1
    }
    return (try? calendar.startOfMonthDay(for: date)) ?? 1
  }

  func numberOfDaysInMonth(month: Int, year: Int) -> Int {
    guard let date = firstDate(month: month, year: year) else {
      return numberOfDaysInMonth
    }
    return (try? calendar.numberOfDays(for: date)) ?? numberOfDaysInMonth
  }

  func rowCount(month: Int, year: Int) -> Int {
    let leadingEmptyDaysCount = max(startOfMonthDay(month: month, year: year) - 1, 0)
    let totalDaysToRender = leadingEmptyDaysCount + numberOfDaysInMonth(month: month, year: year)
    let remainder = totalDaysToRender % 7
    let trailingEmptyDaysCount = remainder == 0 ? 0 : 7 - remainder
    return max(1, (totalDaysToRender + trailingEmptyDaysCount) / 7)
  }

  func monthSymbol(for month: Int) -> String {
    monthSymbol(for: month, year: currentYear)
  }

  func monthSymbol(for month: Int, year: Int) -> String {
    guard let date = firstDate(month: month, year: year) else {
      return ""
    }

    return calendar.monthSymbol(for: date)
  }

  func firstDate(month: Int, year: Int) -> Date? {
    calendar.date(from: DateComponents(year: year, month: month, day: 1))
  }

  func isToday(_ day: Int) -> Bool {
    calendar.isToday(day: day, month: currentMonth, year: currentYear)
  }

  func isToday(day: Int, month: Int, year: Int) -> Bool {
    calendar.isToday(day: day, month: month, year: year)
  }
}
