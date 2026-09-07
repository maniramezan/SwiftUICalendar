import Foundation
import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("CalendarBodyVerticalView Layout Tests")
struct CalendarBodyVerticalViewLayoutTests {
  @Test("vertical destination preserves a distant month across a year boundary")
  func followsDistantPositionAcrossYearBoundary() throws {
    let vm = CalendarViewModel.test(identifier: .gregorian, selection: .single(nil))
    let calendar = Calendar(identifier: .gregorian)
    let currentDate = try #require(
      calendar.date(from: DateComponents(year: 2026, month: 7, day: 13)))
    try vm.navigate(to: currentDate)

    let reported = try #require(vm.monthIdentifier(offset: -18))
    let date = try #require(vm.engine.navigationDate(in: reported, preferredDay: 1))
    try vm.navigate(to: date)

    #expect(vm.visibleMonth == reported)
  }

  #if os(macOS)
    @Test("hosted vertical view follows external navigation without crashing")
    func hostedVerticalViewFollowsExternalNavigation() throws {
      let viewModel = CalendarViewModel.snapshot(selection: .single(nil))
      let view = CalendarBodyVerticalView()
        .environment(viewModel)
        .environment(Theme())
        .environment(Typography.default)
        .environment(\.locale, viewModel.locale)
        .environment(\.layoutDirection, viewModel.layoutDirection)

      let hosted = hostView(view, size: CGSize(width: 390, height: 600))

      // Drive the external-navigation synchronization path while hosted.
      let gregorian = Calendar(identifier: .gregorian)
      let target = try #require(
        gregorian.date(from: DateComponents(year: 2026, month: 3, day: 1)))
      try viewModel.navigate(to: target)
      hosted.hosting.layoutSubtreeIfNeeded()
      if let bitmap = hosted.hosting.bitmapImageRepForCachingDisplay(in: hosted.hosting.bounds) {
        hosted.hosting.cacheDisplay(in: hosted.hosting.bounds, to: bitmap)
      }
      hosted.window.contentView = nil

      #expect(viewModel.visibleMonth == MonthIdentifier(month: 3, year: 2026))
    }

  #endif
}
