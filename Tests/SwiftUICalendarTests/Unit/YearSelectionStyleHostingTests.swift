import Foundation
import SwiftUI
import Testing

@testable import SwiftUICalendar

#if os(macOS)

  @MainActor
  @Suite("Year Selection Style Hosting Tests")
  struct YearSelectionStyleHostingTests {

    @Test("Wheel style year picker renders without crashing")
    func wheelStylePickerRendersWithoutCrashing() {
      let viewModel = CalendarViewModel.snapshot(identifier: .gregorian)
      let theme = Theme()
      theme.yearSelection.style = .wheel

      let hosted = hostView(
        CalendarHeaderYearView()
          .environment(viewModel)
          .environment(theme)
      )
      hosted.window.contentView = nil

      #expect(hosted.hosting.fittingSize.width >= 0)
    }

    @Test("Menu style year picker renders without crashing")
    func menuStylePickerRendersWithoutCrashing() {
      let viewModel = CalendarViewModel.snapshot(identifier: .gregorian)
      let theme = Theme()
      theme.yearSelection.style = .menu

      let hosted = hostView(
        CalendarHeaderYearView()
          .environment(viewModel)
          .environment(theme)
      )
      hosted.window.contentView = nil

      #expect(hosted.hosting.fittingSize.width >= 0)
    }

    @Test("Custom decade-grid year picker renders without crashing")
    func customStylePickerRendersWithoutCrashing() {
      let viewModel = CalendarViewModel.snapshot(identifier: .gregorian)
      let theme = Theme()
      theme.yearSelection.style = .custom
      theme.yearSelection.minYear = 2000
      theme.yearSelection.maxYear = 2050

      let hosted = hostView(
        CalendarHeaderYearView()
          .environment(viewModel)
          .environment(theme)
      )
      hosted.window.contentView = nil

      #expect(hosted.hosting.fittingSize.width >= 0)
    }

    @Test("YearMenuPickerView renders directly without crashing")
    func yearMenuPickerViewRendersDirectly() {
      let currentValue = Binding<YearItem>.constant(YearItem(id: 2026, title: "2026"))
      let view = YearMenuPickerView(
        items: (2020...2030).map { YearItem(id: $0, title: "\($0)") },
        currentValue: currentValue
      )

      let hosted = hostView(view)
      hosted.window.contentView = nil

      #expect(hosted.hosting.fittingSize.width >= 0)
    }

    @Test("YearDecadeGridPickerView renders directly without crashing")
    func yearDecadeGridPickerViewRendersDirectly() {
      let currentValue = Binding<YearItem>.constant(YearItem(id: 2026, title: "2026"))
      let view = YearDecadeGridPickerView(
        minYear: 2000,
        maxYear: 2050,
        currentValue: currentValue,
        formatTitle: { "\($0)" }
      )

      let hosted = hostView(view)
      hosted.window.contentView = nil

      #expect(hosted.hosting.fittingSize.width >= 0)
    }
  }

#endif
