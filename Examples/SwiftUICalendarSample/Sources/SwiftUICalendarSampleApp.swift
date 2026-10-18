import SwiftUI

@main
struct SwiftUICalendarSampleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        .commands {
            CalendarSettingsCommands()
        }
        #endif
    }
}
