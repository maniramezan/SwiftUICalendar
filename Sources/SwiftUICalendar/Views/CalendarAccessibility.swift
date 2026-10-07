import OSLog
import SwiftCommons
import SwiftUI

/// Announces settled navigation without observing intermediate scroll positions or layout.
struct CalendarAccessibility: ViewModifier {
    @Environment(CalendarViewModel.self) private var model
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    private let logger = Logger.swiftUICalendar(for: Self.self)

    func body(content: Content) -> some View {
        content
            .accessibilityAction(named: Text("Calendar.Navigation.PreviousMonth".localized)) {
                navigate(previous: true)
            }
            .accessibilityAction(named: Text("Calendar.Navigation.NextMonth".localized)) {
                navigate(previous: false)
            }
            .onChange(of: model.visibleMonth) { _, month in
                guard voiceOver else { return }
                AccessibilityNotification.Announcement(
                    model.monthSymbol(for: month) + " " + model.yearTitle(month.year)
                ).post()
            }
            .onChange(of: model.selection) { _, selection in
                guard voiceOver,
                    let message = Self.rangeAnnouncement(selection, calendar: model.engine.calendar)
                else { return }
                AccessibilityNotification.Announcement(message).post()
            }
    }

    private func navigate(previous: Bool) {
        guard previous ? model.canNavigateToPreviousMonth : model.canNavigateToNextMonth else {
            return
        }
        do {
            if previous {
                try model.updateMonthToPreviousMonth()
            } else {
                try model.updateMonthToNextMonth()
            }
        } catch {
            logger.error(
                "Accessibility navigation failed", error: error, context: "month navigation")
        }
    }

    static func rangeAnnouncement(_ selection: CalendarSelection, calendar: Calendar) -> String? {
        guard case .range(let start?, let end) = selection else { return nil }
        let formatter = DateFormatter.formatter(template: "yMMMMEEEEd", calendar: calendar)
        let locale = calendar.locale ?? .current
        if let end {
            return String(
                format: "Calendar.Selection.RangeComplete".localized(locale: locale),
                locale: locale,
                formatter.string(from: start), formatter.string(from: end))
        }
        return String(
            format: "Calendar.Selection.RangeStart".localized(locale: locale), locale: locale,
            formatter.string(from: start))
    }
}

extension EnvironmentValues {
    @Entry var calendarRevealDate: CalendarDateRevealer? = nil
}

/// Stable environment identity across viewport updates.
@MainActor
final class CalendarDateRevealer {
    var enabled = false
    var action: ((String) -> Void)?

    func callAsFunction(_ identity: String) {
        if enabled { action?(identity) }
    }
}

struct CalendarDayAccessibilityFocus: ViewModifier {
    let id: MonthSnapshot.Day.ID
    @AccessibilityFocusState private var focused: Bool
    @Environment(\.calendarRevealDate) private var reveal

    func body(content: Content) -> some View {
        content.accessibilityFocused($focused)
            .onChange(of: focused) { _, isFocused in
                if isFocused { reveal?(id) }
            }
    }
}
