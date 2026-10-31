#if os(iOS)
import SwiftUI
import Testing
import UIKit

@testable import SwiftUICalendar

/// An iPad window is rarely the whole screen: Split View, Slide Over and Stage Manager hand the
/// calendar any width from a phone's to the full screen's, and the size class flips between compact
/// and regular somewhere in that range. A phone-sized grid must stay reachable on either side of the
/// flip, and a two-month fold on a wide screen must never grow its panels.
///
/// Real multitasking windows cannot be driven from a test, so these host the calendar at the widths
/// those windows produce and force each size class explicitly.
@MainActor
@Suite("Multitasking widths", .serialized)
struct CalendarMultitaskingWidthTests {
    nonisolated private static let modes: [CalendarConfiguration.ScrollMode] = [
        .none, .vertical, .horizontal,
    ]
    nonisolated private static let sizeClasses: [UIUserInterfaceSizeClass] = [.compact, .regular]
    nonisolated private static let widths: [CGFloat] = [
        320, 375, 507, 678, 820, 1180,
    ]
    nonisolated private static let heights: [CGFloat] = [420, 1180]

    /// Size class × width × height as tuples because Swift Testing zips at most two argument
    /// collections.
    nonisolated private static let windows: [(UIUserInterfaceSizeClass, CGSize)] =
        sizeClasses.flatMap { sizeClass in
            widths.flatMap { width in
                heights.map { (sizeClass, CGSize(width: width, height: $0)) }
            }
        }

    private func measure(
        mode: CalendarConfiguration.ScrollMode,
        sizeClass: UIUserInterfaceSizeClass,
        size: CGSize,
        regions: [CGRect] = []
    ) throws -> [CGRect] {
        let model = CalendarViewModel.snapshot(selection: .single(nil))
        let month = try #require(model.monthIdentifier())
        // The pager realizes neighboring months beside the current one, so only a single month's
        // cells say anything about the window. The vertical list realizes several at once and is
        // measured across all of them.
        let frames =
            mode == .vertical
            ? MeasuredDayFrames()
            : MeasuredDayFrames(month: month, calendar: model.engine.calendar)
        let theme = Theme()
        theme.day.setDayContent { MeasuringDayView(context: $0, frames: frames) }
        let hosted = hostView(
            CalendarView(model: model, theme: theme, configuration: .init(scrollMode: mode))
                .environment(\.calendarFoldRegions, regions),
            size: size)
        defer { hosted.window.isHidden = true }
        hosted.hosting.traitOverrides.horizontalSizeClass = sizeClass
        settle(hosted.hosting.view)
        return Array(frames.inMonth.values)
    }

    @Test(
        "Cells keep the touch target, stay inside the window, and only grow at a regular width",
        arguments: modes, windows)
    func cellsFitTheWindow(
        mode: CalendarConfiguration.ScrollMode,
        window: (sizeClass: UIUserInterfaceSizeClass, size: CGSize)
    ) throws {
        let (sizeClass, size) = window
        let (width, height) = (size.width, size.height)
        let frames = try measure(mode: mode, sizeClass: sizeClass, size: size)
        let metrics = CalendarMetrics.default
        #expect(!frames.isEmpty, "\(mode)/\(sizeClass.rawValue) at \(width)x\(height): no cells")
        if sizeClass == .compact {
            for frame in frames {
                #expect(
                    frame.width <= metrics.maxCellSize + 0.5
                        && frame.height <= metrics.maxCellSize + 0.5,
                    "\(mode) at \(width)x\(height): a compact width grew the cell to \(frame)")
            }
        }
        for frame in frames {
            #expect(
                frame.width >= metrics.minCellSize - 0.5,
                "\(mode)/\(sizeClass.rawValue) at \(width)x\(height): cell \(frame) is below the touch target"
            )
        }
        // Below this the grid overflows into a horizontal scroll by design, so only wider windows
        // promise every column inside the viewport.
        guard width >= 404 else { return }
        for frame in frames {
            #expect(
                frame.minX >= -0.5 && frame.maxX <= width + 0.5,
                "\(mode)/\(sizeClass.rawValue) at \(width)x\(height): cell \(frame) leaves the window"
            )
        }
    }

    @Test(
        "A two-month fold on a regular width keeps the phone-sized panels",
        arguments: modes)
    func foldedPanelsDoNotGrow(mode: CalendarConfiguration.ScrollMode) throws {
        let size = CGSize(width: 1300, height: 800)
        let frames = try measure(
            mode: mode, sizeClass: .regular, size: size,
            regions: [CGRect(x: 630, y: 0, width: 40, height: size.height)])
        #expect(!frames.isEmpty)
        for frame in frames {
            #expect(
                frame.height <= CalendarMetrics.default.maxCellSize + 0.5,
                "\(mode): a folded panel's cell grew to \(frame)")
        }
    }

    @Test(
        "A tabletop fold on a regular width keeps the phone-sized panels",
        arguments: modes)
    func tabletopPanelsDoNotGrow(mode: CalendarConfiguration.ScrollMode) throws {
        let size = CGSize(width: 800, height: 900)
        let frames = try measure(
            mode: mode, sizeClass: .regular, size: size,
            regions: [CGRect(x: 0, y: 430, width: size.width, height: 40)])
        #expect(!frames.isEmpty)
        for frame in frames {
            #expect(
                frame.height <= CalendarMetrics.default.maxCellSize + 0.5,
                "\(mode): a tabletop panel's cell grew to \(frame)")
        }
    }
}
#endif
