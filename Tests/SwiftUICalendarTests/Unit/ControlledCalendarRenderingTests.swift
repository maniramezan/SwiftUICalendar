import ComposableArchitecture
import Foundation
import SwiftUI
import SwiftUICalendarTCA
import Testing

@testable import SwiftUICalendar

/// Covers the externally owned (TCA) rendering path end to end.
///
/// The gap these close: `CalendarFeatureTests` exercises the reducer with no view at all, the
/// structural snapshots are model-derived and never run a SwiftUI `body`, and the rendering smoke
/// tests only ever mounted `CalendarView(model:)` — the stable-identity MVVM initializer. Nothing
/// mounted `TCACalendarView`, so `CalendarView.init(state:…onAction:)` and the fresh
/// `CalendarViewModel` projection it builds per store mutation were never executed under test.
@MainActor
@Suite("Controlled calendar rendering")
struct ControlledCalendarRenderingTests {

  private func state(_ identifier: Calendar.Identifier = .gregorian) -> CalendarState {
    CalendarViewModel.snapshot(identifier: identifier, selection: .single(nil)).state
  }

  @Test("a rebuilt rendering projection reuses cached month geometry")
  func rebuiltProjectionReusesCachedGeometry() throws {
    let cache = CalendarRenderCache()
    let state = state()

    // `CalendarView.init(state:…onAction:)` builds one of these per store mutation, so a scroll
    // produces a new projection every frame. The cache has to outlive them.
    for _ in 0..<10 {
      let projection = CalendarViewModel(state: state)
      projection.renderCache = cache
      _ = projection.monthSnapshot(for: projection.visibleMonth)
    }

    #expect(cache.monthGeometryCount == 1)
  }

  @Test("projections over different calendars keep their own cached geometry")
  func distinctCalendarProjectionsDoNotCollide() throws {
    let cache = CalendarRenderCache()

    for identifier in [Calendar.Identifier.gregorian, .persian] {
      let projection = CalendarViewModel(state: state(identifier))
      projection.renderCache = cache
      _ = projection.monthSnapshot(for: projection.visibleMonth)
    }

    #expect(cache.monthGeometryCount == 2)
  }

  @Test("a rebuilt projection resolves the same grid as the one that cached it")
  func rebuiltProjectionMatchesOriginal() throws {
    let cache = CalendarRenderCache()
    let state = state(.persian)

    let first = CalendarViewModel(state: state)
    first.renderCache = cache
    let original = try #require(first.monthSnapshot(for: first.visibleMonth))

    let second = CalendarViewModel(state: state)
    second.renderCache = cache
    let rebuilt = try #require(second.monthSnapshot(for: second.visibleMonth))

    #expect(original == rebuilt)
  }

  #if os(macOS)
    private func mount<V: View>(_ view: V, size: CGSize) {
      let hosted = hostView(view, size: size)
      defer { hosted.window.contentView = nil }
      waitForStableRender(hosted.hosting, timeout: 2)
      #expect(hosted.hosting.fittingSize.width >= 0)
    }

    @Test(
      "TCACalendarView mounts for every scroll mode",
      arguments: [CalendarConfiguration.ScrollMode.none, .vertical, .horizontal],
      [Calendar.Identifier.gregorian, .persian])
    func tcaCalendarViewMounts(
      mode: CalendarConfiguration.ScrollMode, identifier: Calendar.Identifier
    ) {
      let store = Store(initialState: CalendarFeature.State(calendar: state(identifier))) {
        CalendarFeature()
      }

      mount(
        TCACalendarView(store: store, configuration: CalendarConfiguration(scrollMode: mode)),
        size: CGSize(width: 390, height: 620))
    }

    @Test("TCACalendarView keeps rendering as the store drives it through months")
    func tcaCalendarViewFollowsStoreMutations() throws {
      let store = Store(initialState: CalendarFeature.State(calendar: state())) {
        CalendarFeature()
      }
      let view = TCACalendarView(
        store: store, configuration: CalendarConfiguration(scrollMode: .vertical))
      let hosted = hostView(view, size: CGSize(width: 390, height: 620))
      defer { hosted.window.contentView = nil }
      waitForStableRender(hosted.hosting, timeout: 2)

      // Each of these rebuilds the rendering projection, which is the path that regressed.
      for _ in 0..<6 {
        store.send(.view(.offsetMonths(1)))
        hosted.hosting.layoutSubtreeIfNeeded()
      }

      #expect(CalendarViewModel(state: store.calendar).visibleMonth.month == 12)
    }
  #endif
}
