import Foundation
import SwiftUI
import Testing

@testable import SwiftUICalendar

#if os(macOS)

  /// Mounts the calendar views across the axes that matter (scroll mode, calendar system, day
  /// renderer, container width) and asserts they render without crashing. The structural snapshots
  /// verify *what* the model resolves; these verify the SwiftUI `body` code actually builds for every
  /// configuration. Deterministic and baseline-free — no pixels.
  @MainActor
  @Suite("Calendar rendering smoke tests")
  struct CalendarRenderingSmokeTests {

    private func mount<V: View>(_ view: V, size: CGSize = CGSize(width: 390, height: 560)) {
      let hosted = hostView(view, size: size)
      defer { hosted.window.contentView = nil }
      waitForStableRender(hosted.hosting, timeout: 2)
      #expect(hosted.hosting.fittingSize.width >= 0)
    }

    private func bodyEnvironment<V: View>(_ view: V, vm: CalendarViewModel, theme: Theme)
      -> some View
    {
      view
        .environment(vm)
        .environment(theme)
        .environment(Typography.default)
        .environment(\.locale, vm.locale)
        .environment(\.layoutDirection, vm.layoutDirection)
    }

    // MARK: CalendarView across scroll modes / systems

    @Test(
      "CalendarView mounts for every scroll mode and writing direction",
      arguments: [CalendarConfiguration.ScrollMode.none, .vertical, .horizontal],
      [Calendar.Identifier.gregorian, .persian])
    func calendarViewMounts(mode: CalendarConfiguration.ScrollMode, identifier: Calendar.Identifier)
    {
      let vm = CalendarViewModel.snapshot(identifier: identifier, selection: .single(nil))
      mount(
        CalendarView(model: vm, configuration: CalendarConfiguration(scrollMode: mode)),
        size: CGSize(width: 390, height: 620))
    }

    @Test("CalendarView mounts without a header and with the flexible grid")
    func calendarViewConfigVariants() {
      let vm = CalendarViewModel.snapshot(selection: .single(nil))
      mount(CalendarView(model: vm, configuration: CalendarConfiguration(showsHeader: false)))
      mount(
        CalendarView(
          model: vm,
          configuration: CalendarConfiguration(scrollMode: .horizontal, gridSizing: .flexible)),
        size: CGSize(width: 844, height: 320))
    }

    @Test("CalendarView mounts with the square dual day renderer on a wide container")
    func calendarViewSquareWide() {
      let vm = CalendarViewModel.snapshot(selection: .single(nil))
      let theme = Theme()
      theme.day.useSquareDualCalendarDayView(secondaryLabel: .persian)
      mount(
        CalendarView(model: vm, theme: theme, configuration: CalendarConfiguration()),
        size: CGSize(width: 700, height: 560))
    }

    // MARK: Body views directly

    @Test(
      "Body views mount for each scroll mode",
      arguments: [Calendar.Identifier.gregorian, .persian, .hebrew])
    func bodyViewsMount(identifier: Calendar.Identifier) {
      let vm = CalendarViewModel.snapshot(identifier: identifier, selection: .single(nil))
      let theme = Theme()
      mount(bodyEnvironment(CalendarBodyView(), vm: vm, theme: theme))
      mount(
        bodyEnvironment(CalendarBodyVerticalView(), vm: vm, theme: theme),
        size: CGSize(width: 390, height: 600))
      mount(
        bodyEnvironment(CalendarBodyHorizontalView(viewModel: vm), vm: vm, theme: theme))
    }

    @Test("Header views mount with localized content")
    func headerViewsMount() {
      let vm = CalendarViewModel.snapshot(identifier: .persian, selection: .single(nil))
      mount(
        bodyEnvironment(CalendarHeaderView(), vm: vm, theme: Theme()),
        size: CGSize(width: 390, height: 80))
      mount(
        bodyEnvironment(CalendarWeekHeaderView(weekDays: vm.headerTitles), vm: vm, theme: Theme()),
        size: CGSize(width: 390, height: 48))
    }

    // MARK: Day cells

    @Test(
      "Day cells mount for every state",
      arguments: [
        (isToday: false, isSelected: false, inMonth: true),
        (isToday: true, isSelected: false, inMonth: true),
        (isToday: false, isSelected: true, inMonth: true),
        (isToday: true, isSelected: true, inMonth: true),
        (isToday: false, isSelected: false, inMonth: false),
      ])
    func dayCellsMount(state: (isToday: Bool, isSelected: Bool, inMonth: Bool)) {
      let date = Calendar(identifier: .gregorian)
        .date(from: DateComponents(year: 2025, month: 6, day: 15))!
      let theme = Theme()
      theme.day.emptyDayBorderColor = .pink
      theme.day.emptyDayBorderColorWidth = 1
      let context = CalendarDayContext(
        date: date, day: 15, dayLabel: "15",
        isToday: state.isToday, isSelected: state.isSelected, isInCurrentMonth: state.inMonth,
        theme: theme.day, typography: Typography.default, onSelect: { _ in },
        secondaryLabel: state.inMonth ? "25" : nil)
      mount(
        CircleDayView(context: context).frame(width: 44, height: 44),
        size: CGSize(width: 44, height: 44))
      mount(
        SquareDualCalendarDayView(context: context).frame(width: 50, height: 50),
        size: CGSize(width: 50, height: 50))
    }
  }

#endif
