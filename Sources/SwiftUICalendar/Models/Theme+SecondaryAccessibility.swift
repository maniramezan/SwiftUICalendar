import Foundation

/// Spoken description of a day's secondary-calendar date, resolved once and applied to every day.
///
/// Resolving the secondary calendar, its localized name, the format string, and the date formatter
/// costs several `Calendar` and `Locale` lookups, so a month grid builds one of these per body and
/// asks it for each cell, instead of repeating that work 42 times.
struct SecondaryAccessibilityResolver {
    private enum Resolution {
        /// No secondary calendar is shown, so there is nothing extra to speak.
        case unavailable
        /// The secondary calendar is the primary one; speaking it would repeat the date.
        case sameAsPrimary
        case secondary(locale: Locale, name: String, format: String, formatter: DateFormatter)
    }

    private let resolution: Resolution

    @MainActor
    fileprivate init(mode: Theme.Day.SecondaryLabelMode, primaryCalendar: Calendar) {
        let identifier: Calendar.Identifier
        switch mode {
        case .none, .custom:
            resolution = .unavailable
            return
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
        guard identifier != primaryCalendar.identifier else {
            resolution = .sameAsPrimary
            return
        }
        var calendar = Calendar(identifier: identifier)
        calendar.locale = primaryCalendar.locale
        calendar.timeZone = primaryCalendar.timeZone
        let locale = calendar.locale ?? .current
        resolution = .secondary(
            locale: locale,
            name: locale.localizedString(for: identifier) ?? String(describing: identifier),
            format: "Calendar.Day.SecondaryDate".localized(locale: locale),
            formatter: CalendarRenderCache.shared.templateFormatter(
                template: "GyMMMMd", calendar: calendar))
    }

    /// The spoken secondary date: `nil` when none applies, `""` when it would repeat the primary.
    func label(for date: Date) -> String? {
        switch resolution {
        case .unavailable:
            nil
        case .sameAsPrimary:
            ""
        case .secondary(let locale, let name, let format, let formatter):
            String(format: format, locale: locale, name, formatter.string(from: date))
        }
    }
}

extension Theme.Day.SecondaryLabelMode {
    /// Resolves the secondary calendar once for a whole grid of days.
    @MainActor
    func accessibilityResolver(primaryCalendar: Calendar) -> SecondaryAccessibilityResolver {
        SecondaryAccessibilityResolver(mode: self, primaryCalendar: primaryCalendar)
    }

    @MainActor
    func accessibilityLabel(for date: Date, primaryCalendar: Calendar) -> String? {
        accessibilityResolver(primaryCalendar: primaryCalendar).label(for: date)
    }
}
