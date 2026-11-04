#if os(macOS)
import AppKit
import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Month transition presentation", .serialized)
struct CalendarMonthTransitionTests {
    struct SelectionMarker: CalendarDayView {
        let context: CalendarDayContext

        init(context: CalendarDayContext) {
            self.context = context
        }

        var body: some View {
            if context.isSelected {
                Color(red: 1, green: 0, blue: 1)
            } else {
                Color.clear
            }
        }
    }

    private func markerRows(in view: NSView) throws -> Set<Int> {
        let data = try #require(renderPNGData(view))
        let bitmap = try #require(NSBitmapImageRep(data: data))
        let pixels = try #require(bitmap.bitmapData)
        let components = bitmap.samplesPerPixel
        #expect(bitmap.bitsPerSample == 8)
        #expect(!bitmap.isPlanar)
        let red = bitmap.bitmapFormat.contains(.alphaFirst) ? 1 : 0
        var rows: Set<Int> = []
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                let pixel = pixels + y * bitmap.bytesPerRow + x * components
                if pixel[red] > 180 && pixel[red + 1] < 170 && pixel[red + 2] > 180 {
                    rows.insert(y)
                    break
                }
            }
        }
        return rows
    }

    @Test(
        "A shared overflow date crossfades between rows without traveling through other weeks",
        arguments: [Calendar.Identifier.gregorian, .persian], [-1, 1])
    func sharedDateDoesNotMoveThroughRows(identifier: Calendar.Identifier, direction: Int) throws {
        let model = CalendarViewModel.test(identifier: identifier, selection: .single(nil))
        let calendar = model.engine.calendar
        let start = try #require(
            Calendar(identifier: .gregorian).date(
                from: DateComponents(year: 2027, month: 2, day: 5)))
        try model.navigate(to: start)
        var sharedDate: Date?
        for _ in 0..<12 {
            let nextMonth = try #require(model.monthIdentifier(offset: direction))
            let snapshot = try #require(model.monthSnapshot(for: model.visibleMonth))
            sharedDate =
                snapshot.days.last { day in
                    guard let date = day.date else { return false }
                    return model.engine.month(containing: date) == nextMonth
                }?.date
            if sharedDate != nil { break }
            try model.updateMonth(byAdding: 1)
        }
        let destination = try #require(sharedDate)
        model.select(destination, navigating: false)
        let theme = Theme()
        theme.day.setDayContent { SelectionMarker(context: $0) }
        let hosted = hostView(
            CalendarView(model: model, theme: theme, configuration: .init(showsHeader: false)),
            size: CGSize(width: 390, height: 900))
        hosted.window.orderFront(nil)
        defer {
            hosted.window.orderOut(nil)
            hosted.window.contentView = nil
        }
        #expect(waitForStableRender(hosted.hosting))
        let before = try markerRows(in: hosted.hosting)
        #expect(!before.isEmpty)
        try model.navigate(to: destination)
        var samples: [Set<Int>] = []
        let deadline = Date().addingTimeInterval(0.35)
        repeat {
            RunLoop.current.run(until: Date().addingTimeInterval(1.0 / 60.0))
            samples.append(try markerRows(in: hosted.hosting))
        } while Date() < deadline
        #expect(waitForStableRender(hosted.hosting))
        let after = try markerRows(in: hosted.hosting)
        #expect(!after.isEmpty)
        #expect(before.isDisjoint(with: after))
        let endpointRows = before.union(after)
        let allowed = Set(endpointRows.flatMap { [$0 - 1, $0, $0 + 1] })
        for (index, sample) in samples.enumerated() {
            let unexpectedRows = sample.subtracting(allowed)
            #expect(
                unexpectedRows.isEmpty, "Frame \(index) drew the selection between week rows")
        }
        #expect(model.selection == .single(calendar.startOfDay(for: destination)))
    }
}
#endif
