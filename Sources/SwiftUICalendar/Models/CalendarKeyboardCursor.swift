import SwiftUI

// MARK: - Keyboard Navigation

/// Presentation state owned by one calendar view, independent of date selection and state ownership.
@MainActor
@Observable
final class CalendarKeyboardCursor {
    // The focused date is normalized once when navigation changes.
    var date: Date?
    var isActive = false

    func isFocused(_ day: Date) -> Bool {
        isActive && date == day
    }

    @discardableResult
    func move(days: Int, model: CalendarViewModel) throws -> Bool {
        let engine = model.engine
        guard
            let destination = engine.calendar.date(
                byAdding: .day, value: days, to: date ?? model.currentDate),
            engine.containsDay(destination)
        else { return false }
        let target = engine.clamped(destination)
        try model.navigate(to: target)
        date = engine.calendar.startOfDay(for: target)
        return true
    }

    func select(model: CalendarViewModel) {
        guard let date, model.engine.containsDay(date) else { return }
        model.select(date)
    }

    static func dayOffset(for key: KeyEquivalent, direction: LayoutDirection) -> Int? {
        switch key {
        case .leftArrow: direction == .rightToLeft ? 1 : -1
        case .rightArrow: direction == .rightToLeft ? -1 : 1
        case .upArrow: -7
        case .downArrow: 7
        default: nil
        }
    }
}
