#if os(macOS)
    import AppKit
    import Foundation
    import SwiftUI
    import Testing

    @testable import SwiftUICalendar

    /// Where days actually land on screen, per writing direction.
    ///
    /// Text snapshots record the model's reading order, which was right all along; the bug was a
    /// second, manual row reversal on top of SwiftUI's own right-to-left mirroring, so Persian and
    /// Hebrew weeks read backwards. Only measured geometry catches that, so this suite asserts it.
    @MainActor
    @Suite("Calendar writing direction", .serialized)
    struct CalendarWritingDirectionTests {
        private static let size = CGSize(width: 700, height: 900)

        @Test(
            "Days advance in reading order and weeks start at the leading edge",
            arguments: [
                CalendarConfiguration.ScrollMode.none, .vertical, .horizontal,
            ], [Calendar.Identifier.gregorian, .persian, .hebrew])
        func readingOrder(
            mode: CalendarConfiguration.ScrollMode, identifier: Calendar.Identifier
        ) throws {
            let model = CalendarViewModel.snapshot(identifier: identifier, selection: .single(nil))
            let month = try #require(model.monthIdentifier())
            let calendar = model.engine.calendar
            let rightToLeft = model.layoutDirection == .rightToLeft
            let frames = MeasuredDayFrames(month: month, calendar: calendar)
            let theme = Theme()
            theme.day.setDayContent { context in
                MeasuringDayView(context: context, frames: frames)
            }
            let hosted = hostView(
                CalendarView(model: model, theme: theme, configuration: .init(scrollMode: mode)),
                size: Self.size)
            defer { hosted.window.contentView = nil }
            #expect(waitForStableRender(hosted.hosting))

            let days = frames.inMonth.sorted { $0.key < $1.key }
            try #require(days.count >= 28, "\(mode)/\(identifier): measured \(days.count) days")

            var comparedPairs = 0
            for (current, next) in zip(days, days.dropFirst()) {
                // Only neighbours within one week share a row.
                guard abs(current.value.midY - next.value.midY) < 1 else { continue }
                comparedPairs += 1
                if rightToLeft {
                    #expect(
                        next.value.midX < current.value.midX,
                        "\(mode)/\(identifier): \(next.key) should sit left of \(current.key)")
                } else {
                    #expect(
                        next.value.midX > current.value.midX,
                        "\(mode)/\(identifier): \(next.key) should sit right of \(current.key)")
                }
            }
            #expect(comparedPairs >= 20)

            // Every week's first day — the locale's, e.g. Saturday for Persian — is at the edge
            // reading starts from: rightmost for right-to-left, leftmost otherwise.
            let edge =
                rightToLeft
                ? days.map(\.value.midX).max() : days.map(\.value.midX).min()
            let weekStarts = days.filter {
                calendar.component(.weekday, from: $0.key) == calendar.firstWeekday
            }
            #expect(!weekStarts.isEmpty)
            for start in weekStarts {
                #expect(
                    abs(start.value.midX - (edge ?? .nan)) < 1,
                    "\(mode)/\(identifier): week start \(start.key) is not at the leading edge")
            }
        }
    }
#endif
