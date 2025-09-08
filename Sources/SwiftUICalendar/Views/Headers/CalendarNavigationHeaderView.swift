import SwiftUI
import SwiftUIComponents

struct CalendarNavigationHeaderView<Item: CalendarHeaderItem>: View {
    let items: [Item]
    let selectedItem: Binding<Item>
    let onPrevious: () -> Void
    let onNext: () -> Void
    var isPreviousDisabled: Bool = false
    var isNextDisabled: Bool = false

    var body: some View {
        HStack {
            Button(action: onPrevious) {
                Image(systemName: "chevron.backward")
                    .font(.body.weight(.semibold))
                    .frame(width: 28, height: 28)
                    .adaptiveGlass(shape: .circle, interactive: true)
            }
            .opacity(isPreviousDisabled ? 0.4 : 1.0)
            .disabled(isPreviousDisabled)

            MenuPicker(items: items, currentValue: selectedItem)

            Button(action: onNext) {
                Image(systemName: "chevron.forward")
                    .font(.body.weight(.semibold))
                    .frame(width: 28, height: 28)
                    .adaptiveGlass(shape: .circle, interactive: true)
            }
            .opacity(isNextDisabled ? 0.4 : 1.0)
            .disabled(isNextDisabled)
        }
    }
}
