import OSLog
import SwiftCommons
import SwiftUI

/// Announces settled navigation without observing intermediate scroll positions or layout.
///
/// A month change is announced only after the visible month has stopped changing, and at low
/// priority so it queues behind VoiceOver's own speech instead of interrupting the focused element.
struct CalendarAccessibility: ViewModifier {
    @Environment(CalendarViewModel.self) private var model
    @Environment(\.accessibilityVoiceOverEnabled) private var systemVoiceOver
    @Environment(\.calendarVoiceOverOverride) private var voiceOverOverride
    @Environment(\.calendarAnnouncer) private var announcer
    @State private var tracker = MonthAnnouncementTracker()
    private let logger = Logger.swiftUICalendar(for: Self.self)

    private var voiceOver: Bool { voiceOverOverride ?? systemVoiceOver }

    /// How long the visible month must hold still before it is announced.
    static let settleDelay: Duration = .milliseconds(400)

    func body(content: Content) -> some View {
        content
            .accessibilityAction(named: Text("Calendar.Navigation.PreviousMonth".localized)) {
                navigate(previous: true)
            }
            .accessibilityAction(named: Text("Calendar.Navigation.NextMonth".localized)) {
                navigate(previous: false)
            }
            .task(id: model.visibleMonth) {
                await announceSettledMonth(model.visibleMonth)
            }
            .onChange(of: model.selection) { _, selection in
                guard voiceOver,
                    let message = Self.rangeAnnouncement(selection, calendar: model.engine.calendar)
                else { return }
                announcer.post(AttributedString(message))
            }
    }

    private func announceSettledMonth(_ month: MonthIdentifier) async {
        // The month shown when the calendar appears is context, not navigation.
        guard tracker.shouldAnnounce(month) else { return }
        guard voiceOver else { return }
        do {
            try await announcer.sleep(Self.settleDelay)
        } catch {
            // A newer month replaced this one before it settled.
            logger.debug("Month announcement superseded before it settled")
            return
        }
        tracker.markAnnounced(month)
        logger.debug(
            "Announcing settled month \(month.year, privacy: .public)-\(month.month, privacy: .public)"
        )
        var message = AttributedString(
            model.monthSymbol(for: month) + " " + model.yearTitle(month.year))
        message.accessibilitySpeechAnnouncementPriority = .low
        announcer.post(message)
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
    /// Reports VoiceOver as on or off regardless of the system, since the system value is read-only.
    /// For tests; `nil` follows the system.
    @Entry var calendarVoiceOverOverride: Bool? = nil
    @Entry var calendarAnnouncer = CalendarAnnouncer.system
}

/// Where the calendar's VoiceOver announcements go. Injectable so a test can observe what would be
/// spoken, and when, without a screen reader running.
struct CalendarAnnouncer: Sendable {
    let post: @MainActor @Sendable (AttributedString) -> Void
    /// Waits out the settle delay. Injectable so a test decides when a month has "settled" instead
    /// of racing the wall clock.
    let sleep: @Sendable (Duration) async throws -> Void

    init(
        post: @escaping @MainActor @Sendable (AttributedString) -> Void,
        sleep: @escaping @Sendable (Duration) async throws -> Void = {
            try await Task.sleep(for: $0)
        }
    ) {
        self.post = post
        self.sleep = sleep
    }

    static let system = CalendarAnnouncer { message in
        AccessibilityNotification.Announcement(message).post()
    }
}

/// Remembers which month was last on screen so only a change is announced.
@MainActor
final class MonthAnnouncementTracker {
    private var announced: MonthIdentifier?

    /// `true` when `month` differs from the last month seen. The first month seen is recorded
    /// without being announced.
    func shouldAnnounce(_ month: MonthIdentifier) -> Bool {
        guard let announced else {
            announced = month
            return false
        }
        return announced != month
    }

    func markAnnounced(_ month: MonthIdentifier) {
        announced = month
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
