import Foundation

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
