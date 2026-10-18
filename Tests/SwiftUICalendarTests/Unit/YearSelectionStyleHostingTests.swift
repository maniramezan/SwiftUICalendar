import Foundation
import SwiftUI
import Testing

@testable import SwiftUICalendar

#if os(macOS)

@MainActor
@Suite("Year Selection Style Hosting Tests")
struct YearSelectionStyleHostingTests {

    @Test(
        "Month navigation preserves measured header bounds",
        arguments: [Font.caption, .title, .largeTitle])
    func monthHeaderBounds(font: Font) {
        let items = [MonthItem(id: 5, title: "May"), MonthItem(id: 9, title: "September")]
        let sizes = items.map { selected in
            let hosted = hostView(
                CalendarNavigationHeaderView(
                    items: items, selectedItem: .constant(selected), onPrevious: {}, onNext: {}
                )
                .font(font)
                .fixedSize())
            defer { hosted.window.contentView = nil }
            return hosted.hosting.fittingSize
        }
        #expect(abs(sizes[0].width - sizes[1].width) < 0.5)
        #expect(sizes.allSatisfy { $0.height >= 44 })
        #expect(sizes[0].width >= 132)
    }

    @Test("macOS wheel fallback inherits the same font and bounds as the year menu")
    func wheelFallbackTypography() {
        let item = YearItem(id: 2026, title: "2026")
        let items = [item]
        var widths: [CGFloat] = []
        for font in [Font.caption, .largeTitle] {
            let wheel = hostView(
                YearWheelPickerView(items: items, currentValue: .constant(item))
                    .font(font).fixedSize())
            let menu = hostView(
                YearMenuPickerView(items: items, currentValue: .constant(item))
                    .font(font).fixedSize())
            #expect(abs(wheel.hosting.fittingSize.width - menu.hosting.fittingSize.width) < 0.5)
            #expect(abs(wheel.hosting.fittingSize.height - menu.hosting.fittingSize.height) < 0.5)
            widths.append(wheel.hosting.fittingSize.width)
            wheel.window.contentView = nil
            menu.window.contentView = nil
        }
        #expect(widths[1] > widths[0])
    }

    @Test("Wheel style year picker renders without crashing")
    func wheelStylePickerRendersWithoutCrashing() {
        let viewModel = CalendarViewModel.snapshot(identifier: .gregorian)
        let theme = Theme()

        let hosted = hostView(
            CalendarHeaderYearView()
                .environment(viewModel)
                .environment(theme)
                .environment(
                    \.calendarConfiguration,
                    CalendarConfiguration(yearSelection: .init(style: .wheel))
                )
        )
        hosted.window.contentView = nil

        #expect(hosted.hosting.fittingSize.width >= 0)
    }

    @Test("Menu style year picker renders without crashing")
    func menuStylePickerRendersWithoutCrashing() {
        let viewModel = CalendarViewModel.snapshot(identifier: .gregorian)
        let theme = Theme()

        let hosted = hostView(
            CalendarHeaderYearView()
                .environment(viewModel)
                .environment(theme)
                .environment(
                    \.calendarConfiguration,
                    CalendarConfiguration(yearSelection: .init(style: .menu))
                )
        )
        hosted.window.contentView = nil

        #expect(hosted.hosting.fittingSize.width >= 0)
    }

    @Test("Custom decade-grid year picker renders without crashing")
    func customStylePickerRendersWithoutCrashing() {
        let viewModel = CalendarViewModel.snapshot(identifier: .gregorian)
        let theme = Theme()

        let hosted = hostView(
            CalendarHeaderYearView()
                .environment(viewModel)
                .environment(theme)
                .environment(
                    \.calendarConfiguration,
                    CalendarConfiguration(
                        yearSelection: .init(style: .custom, minYear: 2000, maxYear: 2050)
                    )
                )
        )
        hosted.window.contentView = nil

        #expect(hosted.hosting.fittingSize.width >= 0)
    }

    @Test("Shared year picker presentations render short and long lists", arguments: [1, 3, 201])
    func sharedPickerListLengths(count: Int) {
        let items = (2025..<(2025 + count)).map { YearItem(id: $0, title: "\($0)") }
        let selection = Binding.constant(items[0])
        let menu = hostView(YearMenuPickerView(items: items, currentValue: selection))
        let wheel = hostView(YearWheelPickerView(items: items, currentValue: selection))
        #expect(menu.hosting.fittingSize.width > 0)
        #expect(wheel.hosting.fittingSize.width > 0)
        menu.window.contentView = nil
        wheel.window.contentView = nil
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

    @Test("Decade grid popover content renders paging header and year grid")
    func decadeGridPopoverContentRendersWithoutCrashing() {
        let currentValue = Binding.constant(YearItem(id: 2026, title: "2026"))
        let pageStart = Binding.constant(YearDecadeGrid.pageStart(for: 2026))
        let isPresented = Binding.constant(true)

        let view = YearDecadeGridPopoverContent(
            minYear: 2000,
            maxYear: 2050,
            pageStart: pageStart,
            currentValue: currentValue,
            formatTitle: { "\($0)" },
            isPresented: isPresented
        )

        let hosted = hostView(view, size: CGSize(width: 220, height: 260))
        hosted.window.contentView = nil

        #expect(hosted.hosting.fittingSize.width >= 0)
    }
}

#endif
