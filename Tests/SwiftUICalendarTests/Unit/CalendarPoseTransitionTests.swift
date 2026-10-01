#if os(macOS)
import AppKit
import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Calendar pose transitions", .serialized)
struct CalendarPoseTransitionTests {
    @Test(
        "Folding and unfolding keeps the mounted calendar clear of the hinge",
        arguments: [CalendarConfiguration.ScrollMode.none, .vertical, .horizontal],
        [Calendar.Identifier.gregorian, .persian])
    func liveFoldTransitions(
        mode: CalendarConfiguration.ScrollMode, identifier: Calendar.Identifier
    ) throws {
        let model = CalendarViewModel.snapshot(identifier: identifier)
        model.select(model.currentDate)
        let month = model.visibleMonth
        let selection = model.selection
        let frames = MeasuredDayFrames(month: month, calendar: model.engine.calendar)
        let theme = Theme()
        theme.day.setDayContent { MeasuringDayView(context: $0, frames: frames) }
        let pose = CalendarTestPose()
        let size = CGSize(width: 900, height: 800)
        let hosted = hostView(
            PoseCalendar(model: model, theme: theme, mode: mode, pose: pose), size: size)
        defer { hosted.window.contentView = nil }

        let folds: [[ClosedRange<CGFloat>]] = [[], [520...580], [300...600], [300...400], []]
        for blocked in folds {
            pose.foldRanges = blocked
            #expect(waitForStableRender(hosted.hosting))
            expectNonBlankRender(hosted.hosting, size: size, "live fold \(mode)/\(identifier)")
            #expect(frames.inMonth.count >= 28)
            #expect(model.visibleMonth == month)
            #expect(model.selection == selection)
            let columns = try #require(firstScrollView(in: hosted.hosting))
            let viewport = columns.convert(columns.bounds, to: hosted.hosting)
            for fold in blocked {
                #expect(viewport.maxX <= fold.lowerBound || viewport.minX >= fold.upperBound)
            }
            if viewport.width < CalendarMetrics.default.minCalendarWidth {
                // Offscreen cells may span the fold in document coordinates, but the scroll view
                // clips them to the free band and must expose both ends of that document.
                let document = try #require(columns.documentView)
                let end = max(0, document.frame.width - columns.contentView.bounds.width)
                #expect(end > 0)
                for offset in [CGFloat(0), end] {
                    columns.contentView.scroll(to: CGPoint(x: offset, y: 0))
                    columns.reflectScrolledClipView(columns.contentView)
                    #expect(waitForStableRender(hosted.hosting))
                    #expect(abs(columns.contentView.bounds.minX - offset) < 1)
                }
            }
            for frame in frames.inMonth.values {
                #expect(frame.width >= CalendarMetrics.default.minCellSize)
                if viewport.width >= CalendarMetrics.default.minCalendarWidth {
                    for fold in blocked {
                        #expect(frame.maxX <= fold.lowerBound || frame.minX >= fold.upperBound)
                    }
                }
            }
        }
    }

    @Test(
        "Multitasking width and size-class transitions keep dates reachable",
        arguments: [CalendarConfiguration.ScrollMode.none, .vertical, .horizontal],
        [Calendar.Identifier.gregorian, .persian])
    func multitaskingTransitions(
        mode: CalendarConfiguration.ScrollMode, identifier: Calendar.Identifier
    ) throws {
        let model = CalendarViewModel.snapshot(identifier: identifier)
        model.select(model.currentDate)
        let month = model.visibleMonth
        let selection = model.selection
        let frames = MeasuredDayFrames(month: month, calendar: model.engine.calendar)
        let theme = Theme()
        theme.day.setDayContent { MeasuringDayView(context: $0, frames: frames) }
        let pose = CalendarTestPose()
        let hosted = hostView(
            PoseCalendar(model: model, theme: theme, mode: mode, pose: pose),
            size: CGSize(width: 1024, height: 768))
        defer { hosted.window.contentView = nil }

        for (width, sizeClass) in [
            (1024.0, UserInterfaceSizeClass.regular), (507.0, .compact),
            (320.0, .compact), (680.0, .regular), (1024.0, .regular),
        ] {
            pose.sizeClass = sizeClass
            let size = CGSize(width: width, height: 768)
            hosted.window.setContentSize(size)
            #expect(waitForStableRender(hosted.hosting))
            expectNonBlankRender(hosted.hosting, size: size, "multitasking \(mode)/\(identifier)")
            #expect(frames.inMonth.count >= 28)
            #expect(model.visibleMonth == month)
            #expect(model.selection == selection)
            for frame in frames.inMonth.values {
                #expect(frame.width >= CalendarMetrics.default.minCellSize)
            }

            if width < CalendarMetrics.default.minCalendarWidth {
                // The grid must overflow into a real scroll container rather than clip dates.
                let columns = try #require(firstScrollView(in: hosted.hosting))
                let document = try #require(columns.documentView)
                #expect(document.frame.width > columns.contentView.bounds.width)
                let end = max(0, document.frame.width - columns.contentView.bounds.width)
                for offset in [CGFloat(0), end] {
                    columns.contentView.scroll(to: CGPoint(x: offset, y: 0))
                    columns.reflectScrolledClipView(columns.contentView)
                    #expect(waitForStableRender(hosted.hosting))
                    #expect(abs(columns.contentView.bounds.minX - offset) < 1)
                }
            } else {
                for frame in frames.inMonth.values {
                    #expect(frame.minX >= 0 && frame.maxX <= width)
                }
            }
        }
    }

    private func firstScrollView(in view: NSView) -> NSScrollView? {
        if let scroll = view as? NSScrollView { return scroll }
        return view.subviews.lazy.compactMap { firstScrollView(in: $0) }.first
    }
}

@MainActor
@Observable
private final class CalendarTestPose {
    var foldRanges: [ClosedRange<CGFloat>] = []
    var sizeClass: UserInterfaceSizeClass = .regular
}

private struct PoseCalendar: View {
    let model: CalendarViewModel
    let theme: Theme
    let mode: CalendarConfiguration.ScrollMode
    let pose: CalendarTestPose

    var body: some View {
        CalendarView(model: model, theme: theme, configuration: .init(scrollMode: mode))
            .environment(\.calendarFoldRanges, pose.foldRanges)
            .environment(\.horizontalSizeClass, pose.sizeClass)
    }
}
#endif
