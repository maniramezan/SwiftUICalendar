import Foundation
import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Release regression structural snapshots", .enabled(if: snapshotsEnabled))
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
    assertCalendarStructure(
      model: vm, configuration: CalendarConfiguration(scrollMode: mode),
      monthSpan: mode == .none ? 0 : 1, named: "chinese-leap-\(mode)")
  }

  @Test("Japanese historical era labels and dates")
  func japaneseHistoricalEra() throws {
    let vm = CalendarViewModel.snapshot(identifier: .japanese)
    let date = try #require(
      Calendar(identifier: .gregorian).date(from: DateComponents(year: 1900, month: 1, day: 1)))
    try vm.navigate(to: date)
    assertCalendarStructure(model: vm, named: "meiji-33")
  }

  #if os(macOS)
    private static let verticalConfig = CalendarConfiguration(scrollMode: .vertical)
    private static let mountSize = CGSize(width: 390, height: 600)

    @MainActor
    private func verticalCalendar(_ vm: CalendarViewModel) -> some View {
      CalendarView(model: vm, configuration: Self.verticalConfig)
        .frame(width: Self.mountSize.width, height: Self.mountSize.height)
        .environment(\.colorScheme, .light)
    }

    /// The LazyVStack anchor-recovery guard. After switching calendar systems on an already-mounted
    /// vertical calendar:
    ///   1. the visible month resolves to the new system and the tree settles (`waitForStableRender`);
    ///   2. the structural assertion pins what that settled tree resolves;
    ///   3. the *mounted pixels* are non-blank and differ between the two systems — so a blank or a
    ///      stale/frozen LazyVStack (which the model check alone would miss) fails here.
    @Test("Mounted vertical calendar resets its anchor after switching systems")
    func mountedVerticalSwitch() throws {
      let vm = CalendarViewModel.snapshot()
      let hosted = hostView(verticalCalendar(vm), size: Self.mountSize)
      defer { hosted.window.contentView = nil }

      let blank = hostView(
        Color.clear.frame(width: Self.mountSize.width, height: Self.mountSize.height),
        size: Self.mountSize)
      defer { blank.window.contentView = nil }
      let blankFrame = renderPNGData(blank.hosting)

      var frames: [Calendar.Identifier: Data] = [:]
      for identifier in [Calendar.Identifier.persian, .gregorian] {
        vm.updateCalendar(identifier: identifier)
        #expect(waitForStableRender(hosted.hosting), "render did not stabilize for \(identifier)")

        let expected = try #require(vm.monthIdentifier())
        #expect(expected.calendarIdentifier == identifier)

        assertCalendarStructure(
          model: vm, configuration: Self.verticalConfig, monthSpan: 1,
          named: "switched-\(identifier)")

        let frame = try #require(renderPNGData(hosted.hosting))
        #expect(frame != blankFrame, "mounted \(identifier) calendar rendered blank")
        frames[identifier] = frame
      }

      #expect(
        frames[.persian] != frames[.gregorian],
        "switching calendar systems did not re-render the mounted tree")
    }
  #endif
}
