import SwiftUI

/// A shared previous/next chevron row used by the header's month and year controls.
///
/// Wraps arbitrary center content (a picker trigger) between two chevron buttons so every
/// year-selection style shares identical navigation chrome.
struct CalendarHeaderChevronRow<Content: View>: View {
  let onPrevious: () -> Void
  let onNext: () -> Void
  var isPreviousDisabled: Bool = false
  var isNextDisabled: Bool = false
  @ViewBuilder var content: () -> Content

  var body: some View {
    HStack {
      Button(action: onPrevious) {
        Image(systemName: "chevron.backward")
          .font(.body.weight(.semibold))
          .frame(width: 28, height: 28)
          .adaptiveGlass(shape: .circle, interactive: true)
      }
      // Plain style so the glass circle is the only chrome; macOS otherwise draws a bordered
      // push-button background around it.
      .buttonStyle(.plain)
      .accessibilityLabel("Calendar.Navigation.Previous".localized)
      .opacity(isPreviousDisabled ? 0.4 : 1.0)
      .disabled(isPreviousDisabled)

      content()

      Button(action: onNext) {
        Image(systemName: "chevron.forward")
          .font(.body.weight(.semibold))
          .frame(width: 28, height: 28)
          .adaptiveGlass(shape: .circle, interactive: true)
      }
      // Plain style so the glass circle is the only chrome; macOS otherwise draws a bordered
      // push-button background around it.
      .buttonStyle(.plain)
      .accessibilityLabel("Calendar.Navigation.Next".localized)
      .opacity(isNextDisabled ? 0.4 : 1.0)
      .disabled(isNextDisabled)
    }
  }
}
