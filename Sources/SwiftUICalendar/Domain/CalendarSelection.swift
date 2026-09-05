import Foundation

/// Value selection state, independent of SwiftUI observation and main-actor ownership.
public enum CalendarSelection: Equatable, Sendable {
  /// A single selected date.
  ///
  /// Tapping the selected date again clears the selection.
  case single(_ date: Date? = nil)
  /// A contiguous range defined by start and end dates.
  ///
  /// The first tap sets the start. The second tap sets the end, automatically sorting the
  /// two dates if the user taps an earlier date second.
  case range(Date? = nil, Date? = nil)
  /// Multiple discrete selected dates.
  ///
  /// Tapping an already selected day removes that date from the set.
  case multiple(Set<Date> = [])
}

extension CalendarSelection {
  func normalized(in calendar: Calendar) -> Self {
    switch self {
    case .single(let date):
      return .single(date.map(calendar.startOfDay(for:)))
    case .range(let start, let end):
      let start = start.map(calendar.startOfDay(for:))
      let end = end.map(calendar.startOfDay(for:))
      guard let start, let end else { return .range(start, end) }
      return .range(min(start, end), max(start, end))
    case .multiple(let dates):
      return .multiple(Set(dates.map(calendar.startOfDay(for:))))
    }
  }

  func contains(_ date: Date, in calendar: Calendar) -> Bool {
    let date = calendar.startOfDay(for: date)
    switch normalized(in: calendar) {
    case .single(let selected):
      return selected == date
    case .range(let start, let end):
      guard let start else { return false }
      return start <= date && date <= (end ?? start)
    case .multiple(let dates):
      return dates.contains(date)
    }
  }

  func selecting(_ date: Date, in calendar: Calendar) -> Self {
    let date = calendar.startOfDay(for: date)
    switch normalized(in: calendar) {
    case .single(let selected):
      return .single(selected == date ? nil : date)
    case .range(let start, let end):
      if let start, end == nil {
        return start == date ? .range(nil, nil) : .range(min(start, date), max(start, date))
      }
      return .range(date, nil)
    case .multiple(var dates):
      if dates.contains(date) { dates.remove(date) } else { dates.insert(date) }
      return .multiple(dates)
    }
  }
}
