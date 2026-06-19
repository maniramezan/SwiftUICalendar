import Foundation

// MARK: - Selection state mutation and queries

extension CalendarViewModel {

  func isSelected(_ day: Int) -> Bool {
    guard let date = date(for: day) else { return false }
    return isSelected(date: date)
  }

  func isSelected(date: Date) -> Bool {
    let normalized = normalizedDate(date)
    switch selection {
    case .single(let selectedDate):
      guard let selectedDate else { return false }
      return isSameDay(selectedDate, normalized)
    case .range(let start, let end):
      if let start, let end {
        let normalizedStart = normalizedDate(start)
        let normalizedEnd = normalizedDate(end)
        return normalized >= normalizedStart && normalized <= normalizedEnd
      } else if let start {
        return isSameDay(start, normalized)
      } else {
        return false
      }
    case .multiple(let dates):
      return dates.contains { stored in
        isSameDay(stored, normalized)
      }
    }
  }

  func select(_ date: Date) {
    let normalized = normalizedDate(date)
    switch selection {
    case .single(let selectedDate):
      // Toggle: deselect if tapping the already selected date
      if let selectedDate, isSameDay(selectedDate, normalized) {
        selection = .single(nil)
      } else {
        selection = .single(normalized)
      }

    case .range(let start, let end):
      // Keep existing behavior, plus a small toggle:
      // If only start is set and user taps it again, clear it.
      if end == nil, let start, isSameDay(start, normalized) {
        selection = .range(nil, nil)
        return
      }

      if start == nil {
        selection = .range(normalized, nil)
      } else if end == nil, let start {
        let normalizedStart = normalizedDate(start)
        if normalized >= normalizedStart {
          selection = .range(normalizedStart, normalized)
        } else {
          selection = .range(normalized, normalizedStart)
        }
      } else {
        selection = .range(normalized, nil)
      }

    case .multiple(var dates):
      if let existing = dates.first(where: { isSameDay($0, normalized) }) {
        dates.remove(existing)
      } else {
        dates.insert(normalized)
      }
      selection = .multiple(dates)
    }
  }

  private func normalizedDate(_ date: Date) -> Date {
    calendar.startOfDay(for: date)
  }

  private func isSameDay(_ lhs: Date, _ rhs: Date) -> Bool {
    calendar.isDate(lhs, inSameDayAs: rhs)
  }
}
