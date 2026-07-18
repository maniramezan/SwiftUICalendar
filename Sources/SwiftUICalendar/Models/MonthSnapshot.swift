import Foundation

public struct MonthIdentifier: Hashable, Sendable {
  public let month: Int
  public let year: Int

  public init(month: Int, year: Int) {
    self.month = month
    self.year = year
  }
}

struct MonthSnapshot: Identifiable, Equatable, Sendable {
  struct Day: Identifiable, Equatable, Sendable {
    let id: String
    let date: Date?
    let day: Int
    let dayLabel: String
    let month: Int
    let year: Int
    let isInDisplayedMonth: Bool
    let isToday: Bool
    let isSelected: Bool
  }

  let id: MonthIdentifier
  let title: String
  let days: [Day]

  var rowCount: Int {
    max(1, (days.count + 6) / 7)
  }
}
