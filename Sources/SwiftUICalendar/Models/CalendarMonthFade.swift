import SwiftUI

@MainActor
@Observable
final class CalendarMonthFade {
    enum Phase {
        case idle
        case fadingOut
        case fadingIn
    }

    private(set) var displayedMonth: MonthIdentifier
    private(set) var targetMonth: MonthIdentifier
    private(set) var phase = Phase.idle
    var opacity: Double = 1
    private var generation = 0
    private var pendingSelection: Date?

    init(month: MonthIdentifier) {
        displayedMonth = month
        targetMonth = month
    }

    func begin(to month: MonthIdentifier, selecting date: Date? = nil) -> Int? {
        guard month != targetMonth || date != nil else { return nil }
        targetMonth = month
        pendingSelection = date
        guard phase != .fadingOut else { return nil }
        generation += 1
        phase = .fadingOut
        return generation
    }

    func finishFadeOut(_ token: Int, model: CalendarViewModel) throws -> Bool {
        guard token == generation, phase == .fadingOut else { return false }
        if let pendingSelection {
            try model.navigate(to: model.engine.clamped(pendingSelection))
        }
        displayedMonth = targetMonth
        phase = .fadingIn
        return true
    }

    func finishFadeIn(_ token: Int, model: CalendarViewModel) {
        guard token == generation, phase == .fadingIn else { return }
        let selectedDate = pendingSelection
        pendingSelection = nil
        phase = .idle
        if let selectedDate {
            model.select(selectedDate)
        }
    }

    func cancel(showing month: MonthIdentifier) {
        generation += 1
        pendingSelection = nil
        displayedMonth = month
        targetMonth = month
        opacity = 1
        phase = .idle
    }
}
