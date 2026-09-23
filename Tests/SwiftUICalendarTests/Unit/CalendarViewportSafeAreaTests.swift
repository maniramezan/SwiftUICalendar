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
            sizing: CalendarConfiguration.GridSizing = .adaptive,
            identifier: Calendar.Identifier = .gregorian,
            anyMonth: Bool = false
        ) throws -> [CGRect] {
            let model = CalendarViewModel.snapshot(identifier: identifier, selection: .single(nil))
            let month = try #require(model.monthIdentifier())
            let frames =
                anyMonth
                ? MeasuredDayFrames()
                : MeasuredDayFrames(month: month, calendar: model.engine.calendar)
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
        /// Persian lays out right to left. The notch is physical, so its inset has to land on the
        /// notch's side even though the calendar pads by leading and trailing edges — and this
        /// configuration once hung layout outright.
        @Test(
            "Landscape grids stay clear of the notch",
            arguments: [
                (CalendarConfiguration.ScrollMode.none, Calendar.Identifier.gregorian),
                (.vertical, .gregorian), (.horizontal, .gregorian),
                (.none, .persian), (.vertical, .persian), (.horizontal, .persian),
            ],
            [
                UIEdgeInsets(top: 0, left: 59, bottom: 21, right: 59),
                UIEdgeInsets(top: 0, left: 59, bottom: 21, right: 0),
            ])
        func landscapeAvoidsNotch(
            configuration: (
                mode: CalendarConfiguration.ScrollMode, identifier: Calendar.Identifier
            ),
            safeArea: UIEdgeInsets
        ) throws {
            let (mode, identifier) = configuration
            let size = CGSize(width: 852, height: 393)
            // Only cells actually on screen. A 393pt-tall landscape window scrolls most rows out of
            // view, and a scrolled-out cell's last geometry report can be stale. For the vertical list
            // any month counts, because which one it rests on here is an artifact of this
            // harness — it pumps the run loop from inside a main-actor test, so SwiftUI's follow-up
            // scroll never runs. `VerticalLandscapeUITests` checks the month in the real app.
            let frames = try measure(
                size: size, safeArea: safeArea, mode: mode, sizing: .flexible,
                identifier: identifier, anyMonth: mode == .vertical
            )
            .filter { $0.minY >= 0 && $0.maxY <= size.height }
            #expect(
                frames.count >= 7, "\(mode)/\(identifier): fewer than a week of cells on screen")
            let margin = CalendarMetrics.default.calendarMargin
            for frame in frames {
                #expect(
                    frame.minX >= safeArea.left + margin - 0.5,
                    "\(mode)/\(identifier): a day cell at \(frame) reaches into the left safe area")
                #expect(
                    frame.maxX <= size.width - safeArea.right - margin + 0.5,
                    "\(mode)/\(identifier): a day cell at \(frame) reaches into the right safe area"
                )
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
