#if os(macOS)
import AppKit
import SwiftUI
import Testing

@testable import SwiftUICalendar

/// `onCalendarLayoutChange` is how a host learns the width the calendar needs, and
/// `CalendarLayoutConfiguration.Overflow.minimumSize` is how a host takes over overflow from the
/// calendar. These tests mount the public API in a real hosting view and pin both contracts.
@MainActor
@Suite("Calendar layout observer and host-owned overflow", .serialized)
struct CalendarLayoutObserverTests {
    // MARK: Fixtures

    nonisolated static let modes: [CalendarConfiguration.ScrollMode] = [
        .none, .vertical, .horizontal,
    ]

    /// Narrower than seven minimum cells plus six minimum gaps with the default theme.
    private static let narrowWidth: CGFloat = 320
    /// Comfortably wider than that minimum.
    private static let wideWidth: CGFloat = 600
    private static let height: CGFloat = 700

    @MainActor
    private final class LayoutRecorder {
        var infos: [CalendarLayoutInfo] = []
    }

    private struct Mounted {
        let frames: MeasuredDayFrames
        let recorder: LayoutRecorder
        let window: NSWindow
        let hosting: NSView
    }

    private func mount(
        mode: CalendarConfiguration.ScrollMode,
        overflow: CalendarLayoutConfiguration.Overflow = .automatic,
        width: CGFloat
    ) throws -> Mounted {
        let model = CalendarViewModel.snapshot(selection: .single(nil))
        let month = try #require(model.monthIdentifier())
        let frames = MeasuredDayFrames(month: month, calendar: model.engine.calendar)
        let recorder = LayoutRecorder()
        let theme = Theme()
        theme.day.setDayContent { MeasuringDayView(context: $0, frames: frames) }
        let size = CGSize(width: width, height: Self.height)
        let hosted = hostView(
            CalendarView(
                model: model, theme: theme,
                configuration: .init(
                    scrollMode: mode, layout: CalendarLayoutConfiguration(overflow: overflow))
            )
            .onCalendarLayoutChange { recorder.infos.append($0) },
            size: size)
        #expect(waitForStableRender(hosted.hosting))
        expectNonBlankRender(hosted.hosting, size: size, "\(mode)/\(overflow) at \(width)")
        return Mounted(
            frames: frames, recorder: recorder, window: hosted.window, hosting: hosted.hosting)
    }

    private func scrollViews(in view: NSView) -> [NSScrollView] {
        let current = (view as? NSScrollView).map { [$0] } ?? []
        return current + view.subviews.flatMap { scrollViews(in: $0) }
    }

    /// Whether any scroll view in the tree holds content wider than the area it shows.
    private func scrollsHorizontally(_ view: NSView) -> Bool {
        scrollViews(in: view).contains { scroll in
            guard let document = scroll.documentView else { return false }
            return document.frame.width > scroll.contentView.bounds.width + 0.5
        }
    }

    private var expectedMinimumWidth: CGFloat {
        let metrics = CalendarMetrics.default
        return CalendarGrid.columnWidthDivisor * metrics.minCellSize
            + CalendarGrid.columnGapCount * CalendarLayoutConfiguration().minimumColumnSpacing
    }

    // MARK: Observer

    @Test(
        "The observer reports the minimum width and overflow, then updates on resize",
        arguments: modes)
    func reportsAndUpdates(mode: CalendarConfiguration.ScrollMode) throws {
        let mounted = try mount(mode: mode, width: Self.narrowWidth)
        defer { mounted.window.contentView = nil }

        let narrow = try #require(mounted.recorder.infos.last, "\(mode): observer never fired")
        #expect(narrow.overflowsHorizontally)
        #expect(abs(narrow.minimumWidth - expectedMinimumWidth) < 0.5)
        #expect(narrow.minimumWidth > Self.narrowWidth)
        #expect(narrow.minimumCellSize.width == CalendarMetrics.default.minCellSize)
        #expect(narrow.columnSpacing >= CalendarLayoutConfiguration().minimumColumnSpacing)

        mounted.window.setContentSize(CGSize(width: Self.wideWidth, height: Self.height))
        #expect(waitForStableRender(mounted.hosting))
        let wide = try #require(mounted.recorder.infos.last)
        #expect(!wide.overflowsHorizontally, "\(mode): still overflowing after widening")
        #expect(wide.minimumWidth == narrow.minimumWidth)
        #expect(wide.columnSpacing >= narrow.columnSpacing)
    }

    @Test("The observer does not fire again when nothing about the layout changed")
    func deduplicatesUnchangedLayout() throws {
        let mounted = try mount(mode: .none, width: Self.wideWidth)
        defer { mounted.window.contentView = nil }
        #expect(!mounted.recorder.infos.isEmpty)

        mounted.window.setContentSize(CGSize(width: Self.wideWidth, height: Self.height + 40))
        #expect(waitForStableRender(mounted.hosting))
        let repeats = zip(mounted.recorder.infos, mounted.recorder.infos.dropFirst())
            .filter { $0 == $1 }
        #expect(repeats.isEmpty, "consecutive identical layout reports: \(repeats.count)")
    }

    // MARK: Overflow

    @Test(
        "Automatic overflow scrolls the grid inside the calendar at a narrow width",
        arguments: modes)
    func automaticOverflowScrolls(mode: CalendarConfiguration.ScrollMode) throws {
        let mounted = try mount(mode: mode, overflow: .automatic, width: Self.narrowWidth)
        defer { mounted.window.contentView = nil }
        #expect(scrollsHorizontally(mounted.hosting), "\(mode): automatic overflow did not scroll")
    }

    @Test(
        "Minimum-size overflow keeps readable cells and leaves scrolling to the host",
        arguments: modes)
    func minimumSizeLeavesOverflowToHost(mode: CalendarConfiguration.ScrollMode) throws {
        let mounted = try mount(mode: mode, overflow: .minimumSize, width: Self.narrowWidth)
        defer { mounted.window.contentView = nil }

        // The calendar claims its minimum width, so it never overflows itself; the host does.
        let info = try #require(mounted.recorder.infos.last)
        #expect(!info.overflowsHorizontally)
        #expect(info.minimumWidth > Self.narrowWidth)
        #expect(
            !scrollsHorizontally(mounted.hosting),
            "\(mode): the calendar scrolled columns itself instead of leaving it to the host")
        let widest = try #require(mounted.frames.widestCell)
        #expect(
            widest >= CalendarMetrics.default.minCellSize,
            "\(mode): cells shrank to \(widest) instead of requesting more width")
        let span = try #require(mounted.frames.span)
        #expect(
            span >= info.minimumWidth - 0.5, "\(mode): grid span \(span) < \(info.minimumWidth)")
    }
}
#endif
