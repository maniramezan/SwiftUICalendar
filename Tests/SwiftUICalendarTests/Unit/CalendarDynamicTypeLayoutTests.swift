#if os(macOS)
import AppKit
import SwiftUI
import Testing

@testable import SwiftUICalendar

/// Dynamic Type may make rows taller; it must never push a column past the viewport, and the size a
/// custom day view reads from its context must be the size it is actually given.
@MainActor
@Suite("Dynamic Type layout", .serialized)
struct CalendarDynamicTypeLayoutTests {
    // MARK: Fixtures

    /// Text size and the row-height factor the policy promises for it, written out here so a wrong
    /// table cannot agree with itself.
    nonisolated static let sizes: [(DynamicTypeSize, CGFloat)] = [
        (.large, 1.0), (.xxxLarge, 1.0), (.accessibility5, 1.0),
    ]

    /// Every scroll mode × width × text size as tuples, since Swift Testing zips at most two
    /// argument collections.
    nonisolated static let cases:
        [(CalendarConfiguration.ScrollMode, CGFloat, DynamicTypeSize, CGFloat)] =
            [CalendarConfiguration.ScrollMode.none, .vertical, .horizontal].flatMap { mode in
                [CGFloat(359), 375, 430].flatMap { width in
                    sizes.map { (mode, width, $0.0, $0.1) }
                }
            }

    /// Logs only the visible month: the horizontal pager keeps its neighbors laid out off screen, and
    /// their cells sit outside the clip by design.
    @MainActor
    final class FrameLog {
        let month: MonthIdentifier
        let calendar: Calendar
        var entries: [Date: (claimed: CGSize, frame: CGRect)] = [:]

        init(month: MonthIdentifier, calendar: Calendar) {
            self.month = month
            self.calendar = calendar
        }

        func shouldRecord(_ date: Date) -> Bool {
            CalendarEngine(calendar: calendar).month(containing: date) == month
        }
    }

    struct FrameProbeDayView: CalendarDayView {
        let context: CalendarDayContext
        var log: FrameLog?

        init(context: CalendarDayContext) {
            self.context = context
        }

        init(context: CalendarDayContext, log: FrameLog) {
            self.context = context
            self.log = log
        }

        var body: some View {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onGeometryChange(for: CGRect.self) { geometry in
                    geometry.frame(in: .global)
                } action: { frame in
                    guard context.isInCurrentMonth, let log, log.shouldRecord(context.date) else {
                        return
                    }
                    log.entries[context.date] = (context.cellSize, frame)
                }
        }
    }

    private func makeLog(for model: CalendarViewModel) throws -> FrameLog {
        FrameLog(
            month: try #require(model.monthIdentifier()), calendar: model.engine.calendar)
    }

    private func mount(
        mode: CalendarConfiguration.ScrollMode, size: CGSize, textSize: DynamicTypeSize
    ) throws -> (window: NSWindow, hosting: NSView, log: FrameLog) {
        let model = CalendarViewModel.snapshot(selection: .single(nil))
        let log = try makeLog(for: model)
        let theme = Theme()
        let minimumSize: (CalendarDaySizingContext) -> CGSize = { context in
            context.dynamicTypeSize.isAccessibilitySize
                ? CGSize(width: 70, height: 100) : CGSize(width: 44, height: 44)
        }
        theme.day.setDayContent(minimumSize: minimumSize) {
            FrameProbeDayView(context: $0, log: log)
        }
        let hosted = hostView(
            CalendarView(model: model, theme: theme, configuration: .init(scrollMode: mode))
                .environment(\.dynamicTypeSize, textSize),
            size: size)
        return (hosted.window, hosted.hosting, log)
    }

    private func scrollViews(in view: NSView) -> [NSScrollView] {
        let current = (view as? NSScrollView).map { [$0] } ?? []
        return current + view.subviews.flatMap { scrollViews(in: $0) }
    }

    // MARK: Tests

    @Test(
        "Rows grow by the scale, columns stay inside the clip, and cellSize is the size given",
        arguments: cases)
    func rowsGrowColumnsHold(
        mode: CalendarConfiguration.ScrollMode, width: CGFloat, textSize: DynamicTypeSize,
        scale: CGFloat
    ) throws {
        let size = CGSize(width: width, height: 1400)
        let mounted = try mount(mode: mode, size: size, textSize: textSize)
        let log = mounted.log
        defer { mounted.window.contentView = nil }
        #expect(waitForStableRender(mounted.hosting))

        let label = "\(mode) at \(width) / \(textSize)"
        #expect(log.entries.count >= 28, "\(label): only \(log.entries.count) days laid out")

        for (date, entry) in log.entries {
            // The width is the grid's, so text size never changes it; the height is the scaled row.
            #expect(
                entry.claimed.height >= (textSize.isAccessibilitySize ? 100 : 44),
                "\(label): \(date) claims \(entry.claimed), expected height \(entry.claimed.width * scale)"
            )
            #expect(
                abs(entry.frame.width - entry.claimed.width) < 0.5
                    && abs(entry.frame.height - entry.claimed.height) < 0.5,
                "\(label): \(date) claims \(entry.claimed) but is given \(entry.frame.size)")
            #expect(
                min(entry.claimed.width, entry.claimed.height)
                    >= CalendarMetrics.default.minCellSize - 0.5,
                "\(label): \(date) is below the touch target")
        }

        // Taller rows must not widen the grid: every column stays inside the scroll view's clip.
        let clipper = try #require(
            scrollViews(in: mounted.hosting).last, "\(label): no scroll container")
        let clip = clipper.contentView.convert(clipper.contentView.bounds, to: mounted.hosting)
        for entry in log.entries.values where !textSize.isAccessibilitySize {
            #expect(
                entry.frame.minX >= clip.minX - 0.5 && entry.frame.maxX <= clip.maxX + 0.5,
                "\(label): cell \(entry.frame) is clipped (visible \(clip.minX)–\(clip.maxX))")
        }
    }

    @Test(
        "Week rows stay reachable by scrolling at the largest text size",
        arguments: [CalendarConfiguration.ScrollMode.none, .horizontal], [180.0, 240.0])
    func rowsReachableAtLargestSize(
        mode: CalendarConfiguration.ScrollMode, height: CGFloat
    ) throws {
        let size = CGSize(width: 375, height: height)
        let mounted = try mount(mode: mode, size: size, textSize: .accessibility5)
        defer { mounted.window.contentView = nil }
        #expect(waitForStableRender(mounted.hosting))

        let scrolls = scrollViews(in: mounted.hosting)
        #expect(scrolls.count >= 2, "\(mode) at \(height): needs a vertical overflow fallback")
        let rows = try #require(scrolls.last)
        let document = try #require(rows.documentView)
        #expect(document.frame.height > rows.contentView.bounds.height)
        let bottom = max(0, document.frame.height - rows.contentView.bounds.height)
        rows.contentView.scroll(to: CGPoint(x: 0, y: bottom))
        rows.reflectScrolledClipView(rows.contentView)
        #expect(waitForStableRender(mounted.hosting))
        #expect(abs(rows.documentVisibleRect.maxY - document.frame.maxY) < 1)
    }
}
#endif
