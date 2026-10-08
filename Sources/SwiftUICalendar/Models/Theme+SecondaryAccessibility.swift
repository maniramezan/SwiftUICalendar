import Foundation

extension Theme.Day.SecondaryLabelMode {
    @MainActor
    func accessibilityLabel(for date: Date, primaryCalendar: Calendar) -> String? {
        let identifier: Calendar.Identifier
        switch self {
        case .none, .custom:
            return nil
        case .calendar(let value):
            identifier = value
        case .persian:
            identifier = .persian
        case .hebrew:
            identifier = .hebrew
        case .islamic:
            identifier = .islamic
        case .japanese:
            identifier = .japanese
        }
        // Preserve the visual secondary label without speaking the primary date twice.
        guard identifier != primaryCalendar.identifier else { return "" }
        var calendar = Calendar(identifier: identifier)
        calendar.locale = primaryCalendar.locale
        calendar.timeZone = primaryCalendar.timeZone
        let locale = calendar.locale ?? .current
        let name =
            locale.localizedString(for: identifier)
            ?? String(describing: identifier)
        let formatter = CalendarRenderCache.shared.templateFormatter(
            template: "GyMMMMd", calendar: calendar)
        return String(
            format: "Calendar.Day.SecondaryDate".localized(locale: locale), locale: locale,
            name, formatter.string(from: date))
    }
}
