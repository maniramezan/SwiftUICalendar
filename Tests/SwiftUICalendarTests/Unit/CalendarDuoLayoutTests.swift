#if os(macOS)
import AppKit
import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Calendar Duo layouts", .serialized)
struct CalendarDuoLayoutTests {
    nonisolated private static let modes: [CalendarConfiguration.ScrollMode] = [
        .none, .vertical, .horizontal,
    ]
    nonisolated private static let widths: [CGFloat] = [
        320, 332, 343, 355, 356, 359, 375, 393, 402, 404, 430,
    ]

    @Test(
        "Every panel fits readable columns or exposes real overflow",
        arguments: modes, widths)
    func panelWidths(mode: CalendarConfiguration.ScrollMode, width: CGFloat) throws {
        let mounted = try mount(
            mode: mode, size: CGSize(width: width * 2 + 40, height: 900),
            regions: [CGRect(x: width, y: 0, width: 40, height: 900)])
        defer { mounted.window.contentView = nil }
        #expect(waitForStableRender(mounted.hosting))
        let panels = panelScrollViews(in: mounted.hosting)
        #expect(panels.count == (width >= 332 ? 2 : 1))
        try expectReachableColumns(
            scroll: #require(panels.first), frames: mounted.probe.primary.inMonth,
            host: mounted.hosting, minimum: 44)
        if width >= 332 {
            try expectReachableColumns(
                scroll: #require(panels.last), frames: mounted.probe.companion.inMonth,
                host: mounted.hosting, minimum: 44)
            let primaryTop = try #require(mounted.probe.primary.inMonth.values.map(\.minY).min())
            let companionTop = try #require(
                mounted.probe.companion.inMonth.values.map(\.minY).min())
            #expect(abs(primaryTop - companionTop) < 1)
        }
    }

    @Test(
        "Short tabletop panels keep every week reachable",
        arguments: modes, [CGFloat(132), 180, 240])
    func shortTabletop(mode: CalendarConfiguration.ScrollMode, height: CGFloat) throws {
        let mounted = try mount(
            mode: mode, size: CGSize(width: 430, height: height * 2 + 40 + 16),
            regions: [CGRect(x: 0, y: height, width: 430, height: 40)])
        defer { mounted.window.contentView = nil }
        #expect(waitForStableRender(mounted.hosting))
        for panel in panelScrollViews(in: mounted.hosting) {
            let viewport = panel.convert(panel.bounds, to: mounted.hosting)
            #expect(abs(viewport.height - height - 8) < 1)
            let scrolls = allScrollViews(in: panel)
            #expect(scrolls.count >= 2)
            let rows = try #require(scrolls.last)
            let document = try #require(rows.documentView)
            #expect(document.frame.height > rows.contentView.bounds.height)
            for _ in 0..<3 {
                let end = document.frame.height - rows.contentView.bounds.height
                rows.contentView.scroll(to: CGPoint(x: 0, y: end))
                rows.reflectScrolledClipView(rows.contentView)
                #expect(waitForStableRender(mounted.hosting))
                if abs(rows.documentVisibleRect.maxY - document.frame.maxY) < 1 { break }
            }
            #expect(abs(rows.documentVisibleRect.maxY - document.frame.maxY) < 1)
        }
    }

    @Test(
        "Book panels respect readable custom content at every text size",
        arguments: modes, [DynamicTypeSize.large, .xxxLarge, .accessibility5])
    func dynamicType(mode: CalendarConfiguration.ScrollMode, textSize: DynamicTypeSize) throws {
        let mounted = try mount(
            mode: mode, size: CGSize(width: 790, height: 1200),
            regions: [CGRect(x: 375, y: 0, width: 40, height: 1200)], textSize: textSize)
        defer { mounted.window.contentView = nil }
        #expect(waitForStableRender(mounted.hosting))
        let panels = panelScrollViews(in: mounted.hosting)
        #expect(panels.count == (textSize.isAccessibilitySize ? 1 : 2))
        try expectReachableColumns(
            scroll: #require(panels.first), frames: mounted.probe.primary.inMonth,
            host: mounted.hosting, minimum: textSize.isAccessibilitySize ? 70 : 44)
    }

    @Test(
        "Live book, tabletop, and flat transitions preserve navigation and selection",
        arguments: modes, [Calendar.Identifier.gregorian, .persian])
    func postureTransitions(
        mode: CalendarConfiguration.ScrollMode, identifier: Calendar.Identifier
    ) throws {
        let mounted = try mount(mode: mode, identifier: identifier)
        defer { mounted.window.contentView = nil }
        mounted.model.select(mounted.model.currentDate)
        let month = mounted.model.visibleMonth
        let selection = mounted.model.selection
        let regions: [[CGRect]] = [
            [], [CGRect(x: 430, y: 0, width: 40, height: 800)],
            [CGRect(x: 0, y: 380, width: 900, height: 40)],
            [CGRect(x: 520, y: 0, width: 60, height: 800)],
            [CGRect(x: 430, y: 0, width: 40, height: 800)], [],
        ]
        var primaryViewport: NSScrollView?
        for blocked in regions {
            mounted.pose.regions = blocked
            mounted.probe.primary.reset()
            mounted.probe.companion.reset()
            mounted.probe.primaryContexts.removeAll()
            mounted.probe.companionContexts.removeAll()
            #expect(waitForStableRender(mounted.hosting))
            expectNonBlankRender(
                mounted.hosting, size: CGSize(width: 900, height: 800), "Duo \(mode)/\(identifier)")
            #expect(mounted.model.visibleMonth == month)
            #expect(mounted.model.selection == selection)
            let panels = panelScrollViews(in: mounted.hosting)
            if let primaryViewport {
                #expect(panels.first === primaryViewport)
            } else {
                primaryViewport = panels.first
            }
            #expect(
                panels.count == (blocked.first?.width == 40 || blocked.first?.height == 40 ? 2 : 1))
            for panel in panels {
                let clip = panel.convert(panel.bounds, to: mounted.hosting)
                for fold in blocked {
                    let physical = fold.offsetBy(dx: 0, dy: 8)
                    #expect(!clip.intersects(physical))
                }
            }
            if panels.count == 2 {
                #expect(mounted.probe.companion.inMonth.count >= 28)
                let primaryClip = try #require(panels.first).convert(
                    #require(panels.first).bounds, to: mounted.hosting)
                let secondaryClip = try #require(panels.last).convert(
                    #require(panels.last).bounds, to: mounted.hosting)
                if blocked.first?.width == 40 {
                    if mounted.model.layoutDirection == .leftToRight {
                        #expect(primaryClip.maxX < secondaryClip.minX)
                    } else {
                        #expect(primaryClip.minX > secondaryClip.maxX)
                    }
                } else {
                    #expect(primaryClip.maxY < secondaryClip.minY)
                }
            }
        }
    }

    @Test(
        "Selecting across month panels completes one shared range",
        arguments: modes, [Calendar.Identifier.gregorian, .persian])
    func sharedRange(
        mode: CalendarConfiguration.ScrollMode, identifier: Calendar.Identifier
    ) throws {
        let mounted = try mount(
            mode: mode, identifier: identifier, selection: .range(nil, nil),
            regions: [CGRect(x: 430, y: 0, width: 40, height: 800)])
        defer { mounted.window.contentView = nil }
        #expect(waitForStableRender(mounted.hosting))
        let month = mounted.model.visibleMonth
        let start = try #require(mounted.probe.primaryContexts.values.max { $0.date < $1.date })
        let end = try #require(mounted.probe.companionContexts.values.min { $0.date < $1.date })
        start.onSelect(start.date)
        #expect(waitForStableRender(mounted.hosting))
        end.onSelect(end.date)
        #expect(waitForStableRender(mounted.hosting))
        #expect(mounted.model.visibleMonth == month)
        #expect(mounted.model.isSelected(date: start.date))
        #expect(mounted.model.isSelected(date: end.date))
        #expect(mounted.probe.primaryContexts[start.date]?.rangePosition == .start)
        #expect(mounted.probe.companionContexts[end.date]?.rangePosition == .end)
    }

    @Test("The last allowed month never duplicates itself in the companion panel")
    func lastAllowedMonth() throws {
        let mounted = try mount(
            lastMonthOnly: true, regions: [CGRect(x: 430, y: 0, width: 40, height: 800)])
        defer { mounted.window.contentView = nil }
        #expect(waitForStableRender(mounted.hosting))
        #expect(panelScrollViews(in: mounted.hosting).count == 1)
        #expect(mounted.model.monthIdentifier(offset: 1) == nil)
    }

    @Test("Tall folded vertical panels contain exactly one month each and report one layout")
    func verticalMonthIsolation() throws {
        let mounted = try mount(
            mode: .vertical, size: CGSize(width: 900, height: 1400),
            regions: [CGRect(x: 430, y: 0, width: 40, height: 1400)])
        defer { mounted.window.contentView = nil }
        #expect(waitForStableRender(mounted.hosting))
        #expect(mounted.probe.primaryRenderedMonths == [mounted.model.visibleMonth])
        #expect(mounted.probe.layoutReports.count == 1)
    }

    private func mount(
        mode: CalendarConfiguration.ScrollMode = .none,
        identifier: Calendar.Identifier = .gregorian,
        selection: CalendarViewModel.Selection = .single(nil),
        lastMonthOnly: Bool = false,
        size: CGSize = CGSize(width: 900, height: 800), regions: [CGRect] = [],
        textSize: DynamicTypeSize = .large
    ) throws -> Mounted {
        let pinned = CalendarViewModel.snapshot(identifier: identifier, selection: selection)
        var state = pinned.state
        if lastMonthOnly { try state.setDateRange(.onOrBefore(pinned.currentDate)) }
        let model = CalendarViewModel(state: state)
        let next = model.monthIdentifier(offset: 1) ?? model.visibleMonth
        let probe = PanelProbe(model: model, next: next)
        let theme = Theme()
        let minimumSize: (CalendarDaySizingContext) -> CGSize = {
            $0.dynamicTypeSize.isAccessibilitySize
                ? CGSize(width: 70, height: 100) : CGSize(width: 44, height: 44)
        }
        theme.day.setDayContent(minimumSize: minimumSize) { PanelDay(context: $0, probe: probe) }
        let pose = DuoTestPose()
        pose.regions = regions
        let hosted = hostView(
            DuoTestCalendar(model: model, theme: theme, mode: mode, pose: pose)
                .environment(\.dynamicTypeSize, textSize)
                .onCalendarLayoutChange { probe.layoutReports.append($0) }, size: size)
        return Mounted(
            window: hosted.window, hosting: hosted.hosting, model: model, probe: probe, pose: pose)
    }

    private func expectReachableColumns(
        scroll: NSScrollView, frames: [Date: CGRect], host: NSView, minimum: CGFloat
    ) throws {
        #expect(frames.count >= 28)
        for frame in frames.values {
            #expect(frame.width >= minimum - 0.5)
            #expect(frame.height >= 44)
        }
        let clipper = try #require(allScrollViews(in: scroll).last)
        let clip = clipper.contentView.convert(clipper.contentView.bounds, to: host)
        if scroll.contentView.bounds.width >= minimum * 7 + 24 {
            for frame in frames.values {
                #expect(frame.minX >= clip.minX - 0.5 && frame.maxX <= clip.maxX + 0.5)
            }
        } else {
            let document = try #require(scroll.documentView)
            let end = document.frame.width - scroll.contentView.bounds.width
            #expect(end > 0)
            for offset in [CGFloat(0), end] {
                scroll.contentView.scroll(to: CGPoint(x: offset, y: 0))
                scroll.reflectScrolledClipView(scroll.contentView)
                #expect(waitForStableRender(host))
                #expect(abs(scroll.contentView.bounds.minX - offset) < 1)
            }
        }
    }

    private func panelScrollViews(in view: NSView) -> [NSScrollView] {
        if let scroll = view as? NSScrollView { return [scroll] }
        return view.subviews.flatMap { panelScrollViews(in: $0) }
    }

    private func allScrollViews(in view: NSView) -> [NSScrollView] {
        ((view as? NSScrollView).map { [$0] } ?? [])
            + view.subviews.flatMap { allScrollViews(in: $0) }
    }

    private struct Mounted {
        let window: NSWindow
        let hosting: NSView
        let model: CalendarViewModel
        let probe: PanelProbe
        let pose: DuoTestPose
    }
}

@MainActor
@Observable
private final class DuoTestPose {
    var regions: [CGRect] = []
}

@MainActor
private final class PanelProbe {
    let primary: MeasuredDayFrames
    let companion: MeasuredDayFrames
    var primaryContexts: [Date: CalendarDayContext] = [:]
    var companionContexts: [Date: CalendarDayContext] = [:]
    var primaryRenderedMonths: Set<MonthIdentifier> = []
    var layoutReports: [CalendarLayoutInfo] = []

    init(model: CalendarViewModel, next: MonthIdentifier) {
        primary = MeasuredDayFrames(month: model.visibleMonth, calendar: model.engine.calendar)
        companion = MeasuredDayFrames(month: next, calendar: model.engine.calendar)
    }

    func record(context: CalendarDayContext, companionPanel: Bool, frame: CGRect? = nil) {
        if context.isInCurrentMonth, !companionPanel {
            primaryRenderedMonths.insert(
                CalendarEngine(calendar: context.calendar).month(containing: context.date))
        }
        let frames = companionPanel ? companion : primary
        guard context.isInCurrentMonth, frames.shouldRecord(context.date) else { return }
        if let frame { frames.inMonth[context.date] = frame }
        if companionPanel {
            companionContexts[context.date] = context
        } else {
            primaryContexts[context.date] = context
        }
    }
}

private struct PanelDay: CalendarDayView {
    let context: CalendarDayContext
    var probe: PanelProbe?
    @Environment(\.calendarIsCompanionPanel) private var companionPanel

    init(context: CalendarDayContext) {
        self.context = context
    }

    init(context: CalendarDayContext, probe: PanelProbe) {
        self.context = context
        self.probe = probe
    }

    var body: some View {
        Text(context.dayLabel)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onGeometryChange(for: CGRect.self) {
                $0.frame(in: .global)
            } action: {
                probe?.record(context: context, companionPanel: companionPanel, frame: $0)
            }
            .onChange(of: context.isSelected, initial: true) { _, _ in
                probe?.record(context: context, companionPanel: companionPanel)
            }
    }
}

private struct DuoTestCalendar: View {
    let model: CalendarViewModel
    let theme: Theme
    let mode: CalendarConfiguration.ScrollMode
    let pose: DuoTestPose

    var body: some View {
        CalendarView(model: model, theme: theme, configuration: .init(scrollMode: mode))
            .environment(\.calendarFoldRegions, pose.regions)
    }
}
#endif
