import SwiftUI
import SwiftUICalendarAccessibility

/// A shared previous/next chevron row used by the header's month and year controls.
///
/// Wraps arbitrary center content (a picker trigger) between two chevron buttons so every
/// year-selection style shares identical navigation chrome. The chevrons take their identifiers as
/// parameters because the same row pages months in one header and years in the other, and a shared
/// identifier would make every query ambiguous.
struct CalendarHeaderChevronRow<Content: View>: View {
    @Environment(\.calendarMetrics) private var metrics
    let previousIdentifier: String
    let nextIdentifier: String
    let onPrevious: () -> Void
    let onNext: () -> Void
    var isPreviousDisabled: Bool = false
    var isNextDisabled: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        // Reserve actual interaction space instead of overlapping expanded hit regions.
        HStack(spacing: metrics.chevronSpacing) {
            Button(action: onPrevious) {
                Image(systemName: "chevron.backward")
                    .font(.body.weight(.semibold))
                    .frame(minWidth: 44, minHeight: 44)
                    .adaptiveGlass(shape: .circle, interactive: true)
            }
            // Plain style so the glass circle is the only chrome; macOS otherwise draws a bordered
            // push-button background around it.
            .buttonStyle(.plain)
            .accessibilityLabel(
                (previousIdentifier == CalendarAccessibilityID.previousYearButton
                    ? "Calendar.Navigation.PreviousYear" : "Calendar.Navigation.PreviousMonth")
                    .localized
            )
            .accessibilityIdentifier(previousIdentifier)
            .opacity(isPreviousDisabled ? metrics.disabledOpacity : 1.0)
            .disabled(isPreviousDisabled)

            content()

            Button(action: onNext) {
                Image(systemName: "chevron.forward")
                    .font(.body.weight(.semibold))
                    .frame(minWidth: 44, minHeight: 44)
                    .adaptiveGlass(shape: .circle, interactive: true)
            }
            // Plain style so the glass circle is the only chrome; macOS otherwise draws a bordered
            // push-button background around it.
            .buttonStyle(.plain)
            .accessibilityLabel(
                (nextIdentifier == CalendarAccessibilityID.nextYearButton
                    ? "Calendar.Navigation.NextYear" : "Calendar.Navigation.NextMonth").localized
            )
            .accessibilityIdentifier(nextIdentifier)
            .opacity(isNextDisabled ? metrics.disabledOpacity : 1.0)
            .disabled(isNextDisabled)
        }
    }
}
