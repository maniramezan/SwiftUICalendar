import SnapshotTesting
import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Release regression snapshots", .enabled(if: snapshotsEnabled))
struct ReleaseRegressionSnapshotTests {
  @Test(
    "Chinese leap month is rendered in each scroll mode",
    arguments: [CalendarConfiguration.ScrollMode.none, .horizontal, .vertical])
  func chineseLeapMonth(mode: CalendarConfiguration.ScrollMode) throws {
    let vm = CalendarViewModel.snapshot(identifier: .chinese)
    let date = try #require(
      Calendar(identifier: .gregorian).date(from: DateComponents(year: 2025, month: 7, day: 25)))
    try vm.navigate(to: date)
    #expect(vm.visibleMonth.isLeapMonth)
    assertCalendarSnapshot(
      of: CalendarView(model: vm, configuration: CalendarConfiguration(scrollMode: mode)),
      width: 390, height: 600, named: "chinese-leap-\(mode)")
  }

  @Test("Japanese historical era labels and dates")
  func japaneseHistoricalEra() throws {
    let vm = CalendarViewModel.snapshot(identifier: .japanese)
    let date = try #require(
      Calendar(identifier: .gregorian).date(from: DateComponents(year: 1900, month: 1, day: 1)))
    try vm.navigate(to: date)
    assertCalendarSnapshot(of: CalendarView(model: vm), width: 390, height: 460, named: "meiji-33")
  }

  @Test("Reduce Motion keeps the horizontal calendar fully rendered")
  func reducedMotion() {
    let vm = CalendarViewModel.snapshot(identifier: .persian)
    assertCalendarSnapshot(
      of: CalendarBodyHorizontalView(viewModel: vm, reduceMotion: true)
        .environment(vm).environment(Theme()).environment(Typography.default)
        .environment(\.locale, vm.locale).environment(\.layoutDirection, vm.layoutDirection),
      width: 390, height: 460, named: "persian-reduced-motion")
  }

  #if os(macOS)
    @Test("Mounted vertical calendar resets its anchor after switching systems")
    func mountedVerticalSwitch() throws {
      let size = CGSize(width: 390, height: 600)
      let vm = CalendarViewModel.snapshot()
      let view = CalendarView(
        model: vm, configuration: CalendarConfiguration(scrollMode: .vertical)
      )
      .frame(width: size.width, height: size.height)
      .environment(\.colorScheme, .light)
      .background(Color.white)
      let hosted = hostView(view, size: size)
      defer { hosted.window.contentView = nil }
      for identifier in [Calendar.Identifier.persian, .gregorian] {
        vm.updateCalendar(identifier: identifier)
        // Wait for the already-mounted tree to fully settle (observation delivery, onChange,
        // LazyVStack scroll re-anchoring) instead of guessing a sleep duration. The wait is
        // synchronous, so the snapshot below sees a stable frame regardless of run-loop load.
        #expect(waitForStableRender(hosted.hosting), "render did not stabilize for \(identifier)")
        let expected = try #require(vm.monthIdentifier())
        #expect(expected.calendarIdentifier == identifier)
        withSnapshotTesting(record: globalRecordMode) {
          assertSnapshot(
            of: hosted.hosting, as: calendarImageStrategy(size: size),
            named: "switched-\(identifier)")
        }
      }
    }
  #endif

}
