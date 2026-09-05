import Foundation

/// Calendar month identity, including the era and leap-month distinction.
/// Use `CalendarViewModel.visibleMonth` when referring to an existing month.
public struct MonthIdentifier: Hashable, Sendable {
  public let month: Int
  public let year: Int
  public let calendarIdentifier: Calendar.Identifier
  public let era: Int
  public let isLeapMonth: Bool

  /// Creates a month identifier. The defaults describe a Gregorian month in the common era.
  public init(
    month: Int, year: Int, calendarIdentifier: Calendar.Identifier = .gregorian,
    era: Int = 1, isLeapMonth: Bool = false
  ) {
    self.month = month
    self.year = year
    self.calendarIdentifier = calendarIdentifier
    self.era = era
    self.isLeapMonth = isLeapMonth
  }
}
