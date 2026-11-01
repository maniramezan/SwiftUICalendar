import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Calendar fold layout")
struct CalendarFoldLayoutTests {
    private let size = CGSize(width: 900, height: 800)
    private let minimum = CGSize(width: 332, height: 132)

    private func resolve(
        _ regions: [CGRect], companion: Bool = true,
        direction: LayoutDirection = .leftToRight
    ) -> CalendarFoldLayout {
        CalendarFoldLayout.resolve(
            size: size, blocked: regions, minimumPaneSize: minimum,
            allowsCompanion: companion, layoutDirection: direction)
    }

    @Test("A flat display uses the whole viewport")
    func flat() {
        let layout = resolve([])
        #expect(layout.mode == .single)
        #expect(layout.primary == CGRect(origin: .zero, size: size))
        #expect(layout.secondary == nil)
    }

    @Test(
        "Book posture shows consecutive panels in reading order",
        arguments: [LayoutDirection.leftToRight, .rightToLeft])
    func book(direction: LayoutDirection) {
        let layout = resolve([CGRect(x: 430, y: 0, width: 40, height: 800)], direction: direction)
        let left = CGRect(x: 0, y: 0, width: 430, height: 800)
        let right = CGRect(x: 470, y: 0, width: 430, height: 800)
        #expect(layout.mode == .book)
        #expect(layout.primary == (direction == .leftToRight ? left : right))
        #expect(layout.secondary == (direction == .leftToRight ? right : left))
    }

    @Test(
        "Tabletop posture keeps panels above and below the fold",
        arguments: [LayoutDirection.leftToRight, .rightToLeft])
    func tabletop(direction: LayoutDirection) {
        let layout = resolve([CGRect(x: 0, y: 380, width: 900, height: 40)], direction: direction)
        #expect(layout.mode == .tabletop)
        #expect(layout.primary == CGRect(x: 0, y: 0, width: 900, height: 380))
        #expect(layout.secondary == CGRect(x: 0, y: 420, width: 900, height: 380))
    }

    @Test("A missing adjacent month keeps a single complete calendar")
    func noAdjacentMonth() {
        let layout = resolve([CGRect(x: 430, y: 0, width: 40, height: 800)], companion: false)
        #expect(layout.mode == .single)
        #expect(layout.primary == CGRect(x: 0, y: 0, width: 430, height: 800))
        #expect(layout.secondary == nil)
    }

    @Test("An undersized panel falls back to the largest usable panel")
    func narrowPanel() {
        let layout = resolve([CGRect(x: 520, y: 0, width: 60, height: 800)])
        #expect(layout.mode == .single)
        #expect(layout.primary == CGRect(x: 0, y: 0, width: 520, height: 800))
        #expect(layout.secondary == nil)
        let short = resolve([CGRect(x: 0, y: 80, width: 900, height: 40)])
        #expect(short.mode == .single)
        #expect(short.primary == CGRect(x: 0, y: 120, width: 900, height: 680))
    }

    @Test("Readable content minimum controls whether both months fit")
    func readableMinimum() {
        let layout = CalendarFoldLayout.resolve(
            size: size, blocked: [CGRect(x: 430, y: 0, width: 40, height: 800)],
            minimumPaneSize: CGSize(width: 500, height: 132),
            allowsCompanion: true, layoutDirection: .leftToRight)
        #expect(layout.mode == .single)
        #expect(layout.primary.width == 430)
    }

    @Test("Overlapping and multiple folds leave a genuinely usable rectangle")
    func overlappingRegions() {
        let layout = resolve([
            CGRect(x: 300, y: 0, width: 100, height: 800),
            CGRect(x: 380, y: 0, width: 120, height: 800),
        ])
        #expect(layout.primary == CGRect(x: 500, y: 0, width: 400, height: 800))
        #expect(layout.secondary == nil)
    }

    @Test("Offscreen regions are ignored and partial intersections are clamped")
    func clipping() {
        #expect(resolve([CGRect(x: 1000, y: 0, width: 40, height: 800)]) == resolve([]))
        let layout = resolve([CGRect(x: 700, y: -100, width: 300, height: 1000)])
        #expect(layout.primary == CGRect(x: 0, y: 0, width: 700, height: 800))
    }

    @Test("Degenerate regions and fully blocked viewports never produce blank geometry")
    func degenerateRegions() {
        #expect(resolve([.null, .infinite, .zero]) == resolve([]))
        #expect(resolve([CGRect(x: -1, y: -1, width: 902, height: 802)]) == resolve([]))
        let empty = CalendarFoldLayout.resolve(
            size: .zero, blocked: [CGRect(x: 1, y: 1, width: 40, height: 800)],
            minimumPaneSize: minimum, allowsCompanion: true, layoutDirection: .leftToRight)
        #expect(empty.primary == .zero)
        #expect(empty.secondary == nil)
    }

    @Test("A single narrow panel still triggers real horizontal overflow")
    func narrowPanelOverflows() {
        let layout = resolve([CGRect(x: 300, y: 0, width: 600, height: 800)])
        let viewport = CalendarViewportLayout(
            width: layout.primary.width, cellWidth: 44, margins: 16,
            preferredSpacing: 8, minimumSpacing: 4)
        #expect(layout.primary.width == 300)
        #expect(viewport.overflows)
        #expect(viewport.contentWidth == 348)
    }
}

#if os(macOS)
import AppKit

/// Hosted coverage for the displacement itself, not just the band arithmetic. This is only
/// reachable because the fold source is injected: were the hinge read from
/// `GeometryProxy.reservedRegions`, no test could produce one.
@MainActor
@Suite("Calendar fold displacement", .serialized)
struct CalendarFoldDisplacementTests {
    private static let size = CGSize(width: 900, height: 800)

    @Test(
        "Overflow scroll viewport stays inside the free fold band",
        arguments: [
            LayoutDirection.leftToRight, .rightToLeft,
        ])
    func overflowViewportAvoidsFold(direction: LayoutDirection) throws {
        let hosted = hostView(
            CalendarViewport { _ in Color.blue.frame(height: 100) }
                .environment(\.calendarFoldRegions, [CGRect(x: 300, y: 0, width: 100, height: 200)])
                .environment(\.layoutDirection, direction),
            size: CGSize(width: 700, height: 200))
        defer { hosted.window.contentView = nil }
        #expect(waitForStableRender(hosted.hosting))

        func scrollViews(in view: NSView) -> [NSScrollView] {
            (view as? NSScrollView).map { [$0] }
                ?? view.subviews.flatMap { scrollViews(in: $0) }
        }
        let scroll = try #require(scrollViews(in: hosted.hosting).first)
        let viewport = scroll.convert(scroll.bounds, to: hosted.hosting)
        #expect(abs(viewport.width - 300) < 1)
        if direction == .leftToRight {
            #expect(viewport.maxX <= 301)
        } else {
            #expect(viewport.minX >= 399)
        }
        let document = try #require(scroll.documentView)
        #expect(document.frame.width > viewport.width)
    }

    /// Right-to-left calendars flip leading and trailing padding, which once put the Persian
    /// grid at 382–878 — straight across a fold at 520–580 that the Gregorian grid cleared.
    @Test(
        "Day cells keep clear of a blocked band",
        arguments: [
            CalendarConfiguration.ScrollMode.none, .vertical, .horizontal,
        ], [Calendar.Identifier.gregorian, .persian, .hebrew])
    func daysAvoidTheBand(
        mode: CalendarConfiguration.ScrollMode, identifier: Calendar.Identifier
    ) throws {
        // Hinge past the middle, so the grid belongs in the wider band to its left.
        let blocked: ClosedRange<CGFloat> = 520...580
        let model = CalendarViewModel.snapshot(identifier: identifier, selection: .single(nil))
        let month = try #require(model.monthIdentifier())
        let frames = MeasuredDayFrames(month: month, calendar: model.engine.calendar)
        let theme = Theme()
        theme.day.setDayContent { context in
            MeasuringDayView(context: context, frames: frames)
        }
        let hosted = hostView(
            CalendarView(model: model, theme: theme, configuration: .init(scrollMode: mode))
                .environment(
                    \.calendarFoldRegions,
                    [
                        CGRect(
                            x: blocked.lowerBound, y: 0,
                            width: blocked.upperBound - blocked.lowerBound, height: 800)
                    ]),
            size: Self.size)
        defer { hosted.window.contentView = nil }
        #expect(waitForStableRender(hosted.hosting))
        expectNonBlankRender(hosted.hosting, size: Self.size, "folded \(mode)")
        #expect(frames.inMonth.count >= 28)

        for (date, frame) in frames.inMonth {
            let intersects = frame.maxX > blocked.lowerBound && frame.minX < blocked.upperBound
            #expect(
                !intersects,
                "a day cell overlapped the fold in \(mode) mode: \(frame) vs \(blocked) (\(date))"
            )
        }
        // Cells must not have been shrunk below the touch floor to fit beside the fold.
        let widest = try #require(frames.widestCell)
        #expect(widest >= CalendarMetrics.default.minCellSize)
    }

    /// Proves the displacement actually moved something: at this container width the grid is
    /// already at its capped natural width, so an unfolded calendar centers it straight across
    /// the band the hinge would occupy. Folded, the same grid has to clear that band entirely.
    @Test(
        "Displacement moves a grid that would otherwise cross the fold",
        arguments: [Calendar.Identifier.gregorian, .persian])
    func displacementMovesTheGrid(identifier: Calendar.Identifier) throws {
        let blocked: ClosedRange<CGFloat> = 520...580
        let model = CalendarViewModel.snapshot(identifier: identifier, selection: .single(nil))
        let month = try #require(model.monthIdentifier())

        func bounds(foldRanges: [ClosedRange<CGFloat>]) throws -> (
            minX: CGFloat, maxX: CGFloat
        ) {
            let frames = MeasuredDayFrames(month: month, calendar: model.engine.calendar)
            let theme = Theme()
            theme.day.setDayContent { context in
                MeasuringDayView(context: context, frames: frames)
            }
            let hosted = hostView(
                CalendarView(model: model, theme: theme, configuration: .init())
                    .environment(
                        \.calendarFoldRegions,
                        foldRanges.map {
                            CGRect(
                                x: $0.lowerBound, y: 0, width: $0.upperBound - $0.lowerBound,
                                height: 800)
                        }),
                size: Self.size)
            defer { hosted.window.contentView = nil }
            #expect(waitForStableRender(hosted.hosting))
            let minX = try #require(frames.inMonth.values.map(\.minX).min())
            let maxX = try #require(frames.inMonth.values.map(\.maxX).max())
            return (minX, maxX)
        }

        let unfolded = try bounds(foldRanges: [])
        #expect(
            unfolded.maxX > blocked.lowerBound && unfolded.minX < blocked.upperBound,
            "\(identifier): the unfolded grid must cross the band, or this proves nothing")

        let folded = try bounds(foldRanges: [blocked])
        #expect(
            folded.maxX <= blocked.lowerBound,
            "\(identifier): the folded grid must clear the band")
        #expect(
            folded.minX < unfolded.minX,
            "\(identifier): the folded grid must have moved into the wider band")
        // Same grid, just relocated: displacement must not resize it.
        #expect(abs((folded.maxX - folded.minX) - (unfolded.maxX - unfolded.minX)) < 0.5)
    }
}
#endif
