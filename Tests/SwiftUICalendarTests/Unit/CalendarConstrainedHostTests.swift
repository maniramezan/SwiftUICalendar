#if os(macOS)
import AppKit
import SwiftUI
import Testing

@testable import SwiftUICalendar

/// Hosts rarely hand the calendar the whole screen: a card inset, a split-view column, or an inline
/// editor beneath it all shrink the viewport. These tests pin what the calendar promises in those
/// constrained viewports, so a host-side layout regression surfaces here as well as in the host.
///
/// - Phone widths minus a typical host inset (375 − 2 × 16 = 343) sit below the 356pt grid minimum:
///   the grid must overflow *and* scroll so no weekday column is unreachable.
/// - Heights down to a header-and-a-sliver (a landscape phone with an editor beside or below the
///   calendar) must keep every week row reachable by scrolling.
@MainActor
@Suite("Constrained host viewports", .serialized)
struct CalendarConstrainedHostTests {
    // MARK: Fixtures

    /// An iPhone SE (375) minus a typical host inset, just either side of the 356pt grid minimum,
    /// then full-width phones. The vertical body pads each month by a further 16pt per side, so every
    /// width below 356 + 48 = 404 leaves the grid less room than its minimum unless margins give way.
    nonisolated static let hostInsetWidths: [CGFloat] = [
        320, 332, 343, 355, 359, 375, 393, 402, 404, 430,
    ]

    nonisolated static let modes: [CalendarConfiguration.ScrollMode] = [
        .none, .vertical, .horizontal,
    ]

    /// Mode × width × height as tuples because Swift Testing zips at most two argument collections.
    nonisolated static let shortHosts: [(CalendarConfiguration.ScrollMode, CGSize)] =
        [CalendarConfiguration.ScrollMode.none, .horizontal].flatMap { mode in
            [CGFloat(375), 800].flatMap { width in
                [CGFloat(132), 180, 240].map { (mode, CGSize(width: width, height: $0)) }
            }
        }

    private struct Mounted {
        let frames: MeasuredDayFrames
        let hosted: (window: NSWindow, hosting: NSView)
        let size: CGSize
    }

    private func mount(
        mode: CalendarConfiguration.ScrollMode, size: CGSize
    ) throws -> Mounted {
        let model = CalendarViewModel.snapshot(selection: .single(nil))
        let month = try #require(model.monthIdentifier())
        let frames = MeasuredDayFrames(month: month, calendar: model.engine.calendar)
        let theme = Theme()
        theme.day.setDayContent { MeasuringDayView(context: $0, frames: frames) }
        let hosted = hostView(
            CalendarView(model: model, theme: theme, configuration: .init(scrollMode: mode)),
            size: size)
        #expect(waitForStableRender(hosted.hosting))
        expectNonBlankRender(hosted.hosting, size: size, "\(mode) at \(size)")
        return Mounted(frames: frames, hosted: (hosted.window, hosted.hosting), size: size)
    }

    private func scrollViews(in view: NSView) -> [NSScrollView] {
        let current = (view as? NSScrollView).map { [$0] } ?? []
        return current + view.subviews.flatMap { scrollViews(in: $0) }
    }

    // MARK: Width

    @Test(
        "Every weekday column is on screen, or reachable by scrolling, at host-inset widths",
        arguments: modes, hostInsetWidths)
    func everyColumnReachable(
        mode: CalendarConfiguration.ScrollMode, width: CGFloat
    ) throws {
        let mounted = try mount(mode: mode, size: CGSize(width: width, height: 900))
        defer { mounted.hosted.window.contentView = nil }
        let metrics = CalendarMetrics.default
        #expect(mounted.frames.inMonth.count >= 28)
        let widest = try #require(mounted.frames.widestCell)
        #expect(
            widest >= metrics.minCellSize,
            "\(mode) at \(width): cells shrank below the minimum touch target (\(widest))")

        if width >= 7 * metrics.minCellSize + 6 * CalendarLayoutConfiguration().minimumColumnSpacing
        {
            // Fits: no scrolling needed, so nothing may be clipped by the viewport edge.
            for frame in mounted.frames.inMonth.values {
                #expect(
                    frame.minX >= -0.5 && frame.maxX <= width + 0.5,
                    "\(mode) at \(width): a day cell at \(frame) is outside the viewport"
                )
            }
            // The innermost scroll view clips its content. A grid that overflows the margins padded
            // around it stays inside the viewport yet is cut off by this clip, so measure against it.
            let clipper = try #require(
                scrollViews(in: mounted.hosted.hosting).last,
                "\(mode) at \(width): no scroll container")
            let clip = clipper.contentView.convert(
                clipper.contentView.bounds, to: mounted.hosted.hosting)
            for frame in mounted.frames.inMonth.values {
                #expect(
                    frame.minX >= clip.minX - 0.5 && frame.maxX <= clip.maxX + 0.5,
                    "\(mode) at \(width): cell \(frame) is clipped by its scroll view (\(clip.minX)–\(clip.maxX))"
                )
            }
            return
        }

        // Overflows: the outer viewport must scroll horizontally far enough to expose the last column.
        let outer = try #require(
            scrollViews(in: mounted.hosted.hosting).first,
            "\(mode) at \(width): no scroll container")
        let document = try #require(outer.documentView)
        let clip = outer.contentView.bounds.width
        #expect(
            document.frame.width > clip,
            "\(mode) at \(width): grid overflows the viewport but cannot scroll horizontally")
        let trailingEdge = max(0, document.frame.width - clip)
        outer.contentView.scroll(to: CGPoint(x: trailingEdge, y: outer.contentView.bounds.minY))
        outer.reflectScrolledClipView(outer.contentView)
        #expect(waitForStableRender(mounted.hosted.hosting))
        let rightmost = try #require(mounted.frames.inMonth.values.map(\.maxX).max())
        #expect(
            rightmost <= width + 0.5,
            "\(mode) at \(width): after scrolling to the end the last column still ends at \(rightmost)"
        )
    }

    // MARK: Height

    @Test(
        "Week rows stay reachable when the host leaves only a sliver of height",
        arguments: shortHosts)
    func rowsReachableInShortHost(
        mode: CalendarConfiguration.ScrollMode, size: CGSize
    ) throws {
        let (width, height) = (size.width, size.height)
        let mounted = try mount(mode: mode, size: size)
        defer { mounted.hosted.window.contentView = nil }
        let scrolls = scrollViews(in: mounted.hosted.hosting)
        #expect(
            scrolls.count >= 2, "\(mode) at \(width)×\(height) needs a vertical overflow fallback")
        let rows = try #require(scrolls.last)
        let document = try #require(rows.documentView)
        #expect(
            rows.contentView.bounds.height <= height,
            "\(mode) at \(width)×\(height): the row viewport is taller than its host")
        #expect(
            document.frame.height > rows.contentView.bounds.height,
            "\(mode) at \(width)×\(height): rows overflow the host but cannot scroll")
        let bottom = max(0, document.frame.height - rows.contentView.bounds.height)
        rows.contentView.scroll(to: CGPoint(x: 0, y: bottom))
        rows.reflectScrolledClipView(rows.contentView)
        #expect(waitForStableRender(mounted.hosted.hosting))
        #expect(abs(rows.documentVisibleRect.maxY - document.frame.maxY) < 1)
        for frame in mounted.frames.inMonth.values {
            #expect(frame.height >= CalendarMetrics.default.minCellSize)
        }
    }
}
#endif
