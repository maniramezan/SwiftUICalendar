import SnapshotTesting
import SwiftUI
import Testing

@testable import SwiftUICalendar

#if TCA
  import ComposableArchitecture
  import SwiftUICalendarTCA
#endif

@MainActor
@Suite("Externally owned calendar snapshots", .enabled(if: snapshotsEnabled))
struct ControlledCalendarSnapshotTests {
  @Test(
    "Controlled rendering supports every mode and both writing directions",
    arguments: [CalendarConfiguration.ScrollMode.none, .horizontal, .vertical],
    [Calendar.Identifier.gregorian, .persian])
  func controlled(mode: CalendarConfiguration.ScrollMode, identifier: Calendar.Identifier) {
    let model = CalendarViewModel.snapshot(identifier: identifier)
    assertCalendarSnapshot(
      of: CalendarView(state: model.state, configuration: CalendarConfiguration(scrollMode: mode)) {
        _ in
      },
      width: 390, height: 600, named: "controlled-\(identifier)-\(mode)")
  }

  #if TCA
    @Test("TCA renders reducer state and observes parent-driven changes")
    func tcaRendering() async throws {
      let initial = CalendarViewModel.snapshot(identifier: .persian).state
      let store = Store(initialState: CalendarFeature.State(calendar: initial)) {
        CalendarFeature()
      }
      #if os(macOS)
        let size = CGSize(width: 390, height: 600)
        let hosted = hostView(
          TCACalendarView(store: store).frame(width: size.width, height: size.height)
            .environment(\.colorScheme, .light).background(Color.white), size: size)
        defer { hosted.window.contentView = nil }
        withSnapshotTesting(record: globalRecordMode) {
          assertSnapshot(
            of: hosted.hosting, as: calendarImageStrategy(size: size), named: "tca-persian")
        }
        store.send(.view(.setCalendar(.gregorian)))
        store.send(.view(.offsetMonths(1)))
        try await Task.sleep(for: .milliseconds(100))
        hosted.hosting.layoutSubtreeIfNeeded()
        #expect(store.calendar.visibleMonth.month == 7)
        withSnapshotTesting(record: globalRecordMode) {
          assertSnapshot(
            of: hosted.hosting, as: calendarImageStrategy(size: size), named: "tca-july")
        }
      #else
        assertCalendarSnapshot(
          of: TCACalendarView(store: store), width: 390, height: 600, named: "tca-persian")
      #endif
    }

  #endif
}
