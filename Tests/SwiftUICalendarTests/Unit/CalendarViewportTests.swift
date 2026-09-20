import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Calendar viewport")
struct CalendarViewportTests {
    @Test("Narrow windows preserve the minimum width", arguments: [0.0, 240.0, 320.0])
    func narrow(width: CGFloat) {
        let layout = CalendarViewportLayout(width: width, minimumWidth: 356)
        #expect(layout.contentWidth == 356)
        #expect(layout.overflows)
    }

    @Test("Fitting windows do not overflow", arguments: [356.0, 600.0, 1024.0])
    func fitting(width: CGFloat) {
        let layout = CalendarViewportLayout(width: width, minimumWidth: 356)
        #expect(layout.contentWidth == width)
        #expect(!layout.overflows)
    }

    #if os(macOS)
        @Test("Narrow viewport exposes horizontal scrolling and preserves content height")
        func hostedOverflow() throws {
            let hosted = hostView(
                CalendarViewport { _ in
                    HStack {
                        Text("First day")
                        Spacer()
                        Text("Last day")
                    }
                    .frame(height: 400)
                }, size: CGSize(width: 240, height: 500))
            defer { hosted.window.contentView = nil }
            #expect(waitForStableRender(hosted.hosting))
            #expect(hosted.hosting.fittingSize.height >= 400)
        }
    #endif
}
