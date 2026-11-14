import Foundation

@MainActor
final class RealizedCalendarMonths {
    private var months: Set<MonthIdentifier> = []

    func insert(_ month: MonthIdentifier) {
        months.insert(month)
    }

    func remove(_ month: MonthIdentifier) {
        months.remove(month)
    }

    func contains(_ month: MonthIdentifier) -> Bool {
        months.contains(month)
    }
}
