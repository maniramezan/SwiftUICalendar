#if os(macOS)
import SwiftUI

/// Opens the configuration inspector in the active calendar window.
struct CalendarSettingsCommands: Commands {
    @FocusedBinding(\.calendarSettingsPresentation) private var isSettingsPresented: Bool?

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") {
                isSettingsPresented = true
            }
            .keyboardShortcut(",", modifiers: .command)
            .disabled(isSettingsPresented == nil)
        }
    }
}

private struct CalendarSettingsPresentationKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {
    var calendarSettingsPresentation: Binding<Bool>? {
        get { self[CalendarSettingsPresentationKey.self] }
        set { self[CalendarSettingsPresentationKey.self] = newValue }
    }
}
#endif
