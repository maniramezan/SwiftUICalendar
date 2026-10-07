#if os(macOS)
import AppKit
import SwiftUI
import Testing

@testable import SwiftUICalendar

/// A custom day view is told the square it is given through `CalendarDayContext.cellSize`, so it
/// can size its content without a `GeometryReader`. These tests pin that the number it reads is the
/// size the calendar actually proposes.
@MainActor
@Suite("Day context sizing", .serialized)
struct CalendarDayContextSizingTests {
    // MARK: Fixtures

    nonisolated static let modes: [CalendarConfiguration.ScrollMode] = [
        .none, .vertical, .horizontal,
    ]

    nonisolated static let widths: [CGFloat] = [343, 375, 428, 900]

    private func context(cellSize: CGSize? = nil) -> CalendarDayContext {
        CalendarDayContext(
            date: .now, day: 1, dayLabel: "1", isToday: false, isSelected: false,
            isInCurrentMonth: true, theme: Theme.default.day, typography: Typography.default,
            onSelect: { _ in }, cellSize: cellSize)
    }

    // MARK: Context

    @Test("A hand-built context defaults to the minimum touch target")
    func defaultCellSizeIsTheTouchTarget() {
        let minimum = CalendarMetrics.default.minCellSize
        #expect(context().cellSize == CGSize(width: minimum, height: minimum))
    }

    @Test("A hand-built context keeps the size it is given")
    func explicitCellSizeIsKept() {
        #expect(
            context(cellSize: CGSize(width: 57, height: 60)).cellSize
                == CGSize(width: 57, height: 60))
    }

    // MARK: Hosted

    /// Records, per day, the size the cell was given next to the size its context claims.
    @MainActor
    final class SizeLog {
        var entries: [Date: (claimed: CGSize, actual: CGSize)] = [:]
    }

    struct SizeProbeDayView: CalendarDayView {
        let context: CalendarDayContext
        var log: SizeLog?

        init(context: CalendarDayContext) {
            self.context = context
        }

        init(context: CalendarDayContext, log: SizeLog) {
            self.context = context
            self.log = log
        }

        var body: some View {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onGeometryChange(for: CGSize.self) { geometry in
                    geometry.size
                } action: { size in
                    guard context.isInCurrentMonth else { return }
                    log?.entries[context.date] = (context.cellSize, size)
                }
        }
    }

    @Test(
        "cellSize equals the square a custom day view is proposed", arguments: modes, widths)
    func cellSizeMatchesTheProposedSquare(
        mode: CalendarConfiguration.ScrollMode, width: CGFloat
    ) throws {
        let model = CalendarViewModel.snapshot(selection: .single(nil))
        let log = SizeLog()
        let theme = Theme()
        theme.day.setDayContent { SizeProbeDayView(context: $0, log: log) }
        let size = CGSize(width: width, height: 900)
        let hosted = hostView(
            CalendarView(model: model, theme: theme, configuration: .init(scrollMode: mode)),
            size: size)
        defer { hosted.window.contentView = nil }
        #expect(waitForStableRender(hosted.hosting))

        #expect(
            log.entries.count >= 28, "\(mode) at \(width): only \(log.entries.count) days laid out")
        for (date, entry) in log.entries {
            #expect(
                abs(entry.actual.width - entry.claimed.width) < 0.5
                    && abs(entry.actual.height - entry.claimed.height) < 0.5,
                "\(mode) at \(width): \(date) claims \(entry.claimed) but is given \(entry.actual)")
            #expect(
                min(entry.claimed.width, entry.claimed.height)
                    >= CalendarMetrics.default.minCellSize - 0.5,
                "\(mode) at \(width): cellSize \(entry.claimed) is below the touch target")
        }
    }
}
#endif
