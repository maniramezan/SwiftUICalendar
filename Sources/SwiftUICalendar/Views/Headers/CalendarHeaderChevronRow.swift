import SwiftUI

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
        // The chevrons keep their compact frames, with no enlarged content shape. The month and year
        // rows put a next and a previous chevron only a few points apart, so a touch-floor
        // content shape on each made their hit areas overlap: a tap on the visible edge of one fired
        // the other. iOS already extends touches to small controls, so they stay easy to hit.
        HStack(spacing: metrics.chevronSpacing) {
            Button(action: onPrevious) {
                Image(systemName: "chevron.backward")
                    .font(.body.weight(.semibold))
                    .frame(width: metrics.compactControlSize, height: metrics.compactControlSize)
                    .adaptiveGlass(shape: .circle, interactive: true)
            }
            // Plain style so the glass circle is the only chrome; macOS otherwise draws a bordered
            // push-button background around it.
            .buttonStyle(.plain)
            .accessibilityLabel("Calendar.Navigation.Previous".localized)
            .accessibilityIdentifier(previousIdentifier)
            .opacity(isPreviousDisabled ? metrics.disabledOpacity : 1.0)
            .disabled(isPreviousDisabled)

            content()

            Button(action: onNext) {
                Image(systemName: "chevron.forward")
                    .font(.body.weight(.semibold))
                    .frame(width: metrics.compactControlSize, height: metrics.compactControlSize)
                    .adaptiveGlass(shape: .circle, interactive: true)
            }
            // Plain style so the glass circle is the only chrome; macOS otherwise draws a bordered
            // push-button background around it.
            .buttonStyle(.plain)
            .accessibilityLabel("Calendar.Navigation.Next".localized)
            .accessibilityIdentifier(nextIdentifier)
            .opacity(isNextDisabled ? metrics.disabledOpacity : 1.0)
            .disabled(isNextDisabled)
        }
    }
}
