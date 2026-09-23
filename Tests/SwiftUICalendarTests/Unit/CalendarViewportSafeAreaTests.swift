#if os(iOS)
    import SwiftUI
    import Testing
    import UIKit

    @testable import SwiftUICalendar

    /// Device safe areas exist only on iOS, so this is the one place the viewport's hard insets meet
    /// a real notch. It runs under `xcodebuild test` on a simulator; `swift test` on macOS skips it.
    @MainActor
    @Suite("Calendar viewport safe area", .serialized)
    struct CalendarViewportSafeAreaTests {
        private func measure(
            size: CGSize,
            safeArea: UIEdgeInsets,
            mode: CalendarConfiguration.ScrollMode,
            sizing: CalendarConfiguration.GridSizing = .adaptive
        ) throws -> [CGRect] {
            let model = CalendarViewModel.snapshot(selection: .single(nil))
            let month = try #require(model.monthIdentifier())
            let frames = MeasuredDayFrames(month: month, calendar: model.engine.calendar)
            let theme = Theme()
            theme.day.setDayContent { context in
                MeasuringDayView(context: context, frames: frames)
            }
            let hosted = hostView(
                CalendarView(
                    model: model, theme: theme,
                    configuration: .init(scrollMode: mode, gridSizing: sizing)),
                size: size, safeArea: safeArea)
            defer { hosted.window.isHidden = true }
            settle(hosted.hosting.view)
            return Array(frames.inMonth.values)
        }

        /// A flexible grid fills whatever width it is given, so it is the configuration that would
        /// actually reach under a notch if the horizontal safe area were dropped or double-counted.
        @Test(
            "Landscape grids stay clear of the notch",
            arguments: [
                CalendarConfiguration.ScrollMode.none, .vertical, .horizontal,
            ],
            [
                UIEdgeInsets(top: 0, left: 59, bottom: 21, right: 59),
                UIEdgeInsets(top: 0, left: 59, bottom: 21, right: 0),
            ])
        func landscapeAvoidsNotch(
            mode: CalendarConfiguration.ScrollMode, safeArea: UIEdgeInsets
        ) throws {
            let size = CGSize(width: 852, height: 393)
            // Only cells actually on screen. A 393pt-tall landscape window scrolls most rows out of
            // view, and a scrolled-out cell's last geometry report can predate the safe-area pass —
            // it can never sit under the notch, because it is not on screen at all.
            let frames = try measure(size: size, safeArea: safeArea, mode: mode, sizing: .flexible)
                .filter { $0.minY >= 0 && $0.maxY <= size.height }
            #expect(frames.count >= 7, "\(mode): fewer than a week of cells on screen")
            let margin = CalendarMetrics.default.calendarMargin
            for frame in frames {
                #expect(
                    frame.minX >= safeArea.left + margin - 0.5,
                    "\(mode): a day cell at \(frame) reaches into the leading safe area")
                #expect(
                    frame.maxX <= size.width - safeArea.right - margin + 0.5,
                    "\(mode): a day cell at \(frame) reaches into the trailing safe area")
            }
        }

        @Test(
            "Portrait phones show every day without scrolling",
            arguments: [
                CalendarConfiguration.ScrollMode.none, .vertical, .horizontal,
            ], [375.0, 393.0, 402.0])
        func portraitPhonesFit(mode: CalendarConfiguration.ScrollMode, width: CGFloat) throws {
            let frames = try measure(
                size: CGSize(width: width, height: 852),
                safeArea: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0), mode: mode)
            #expect(frames.count >= 28)
            for frame in frames {
                #expect(
                    frame.minX >= -0.5 && frame.maxX <= width + 0.5,
                    "\(mode) at \(width): a day cell at \(frame) is off screen")
            }
        }
    }
#endif
