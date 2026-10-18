import Foundation
import SwiftUI
import Testing

@testable import SwiftUICalendar

#if os(macOS)
import AppKit
#endif

@MainActor
@Suite("Range band geometry")
struct CalendarRangeBandTests {
    @Test("Adjacent interior cells meet halfway across the gutter")
    func joinsAcrossGutter() {
        let band = geometry(.interior, leading: true, trailing: true)
        #expect(band.rect == CGRect(x: -4, y: 0, width: 52, height: 44))
        #expect(!band.roundsLeft && !band.roundsRight)
    }

    @Test("Endpoints connect from the center, leaving their outer halves clear")
    func endpoints() {
        #expect(geometry(.start, trailing: true).rect == CGRect(x: 22, y: 0, width: 26, height: 44))
        #expect(geometry(.end, leading: true).rect == CGRect(x: -4, y: 0, width: 26, height: 44))
        #expect(geometry(.start).rect.width == 0)
        #expect(geometry(.startAndEnd).rect.width == 0)
    }

    @Test("Week and hidden month boundaries cap the band inside the column")
    func boundaries() {
        let band = geometry(.interior)
        #expect(band.rect == CGRect(x: 0, y: 0, width: 44, height: 44))
        #expect(band.roundsLeft && band.roundsRight)
    }

    @Test("RTL mirrors endpoints and rounded continuation edges")
    func rightToLeft() {
        let start = geometry(.start, trailing: true, rtl: true)
        #expect(start.rect == CGRect(x: -4, y: 0, width: 26, height: 44))
        #expect(!start.roundsLeft && start.roundsRight)
        let end = geometry(.end, leading: true, rtl: true)
        #expect(end.rect == CGRect(x: 22, y: 0, width: 26, height: 44))
    }

    #if os(macOS)
    @Test(
        "Rendered start band extends toward the next date in each writing direction",
        arguments: [LayoutDirection.leftToRight, .rightToLeft])
    func renderedDirection(direction: LayoutDirection) throws {
        let hosted = hostView(
            CalendarRangeBand(
                position: .start, columnWidth: 44, gap: 8, height: 44,
                joinsLeading: false, joinsTrailing: true, color: .blue
            )
            .environment(\.layoutDirection, direction)
            .background(Color.white),
            size: CGSize(width: 44, height: 44))
        defer { hosted.window.contentView = nil }
        let data = try #require(renderPNGData(hosted.hosting))
        let bitmap = try #require(NSBitmapImageRep(data: data))
        let left = try #require(
            bitmap.colorAt(x: bitmap.pixelsWide / 4, y: bitmap.pixelsHigh / 2)?.usingColorSpace(
                .deviceRGB))
        let right = try #require(
            bitmap.colorAt(x: bitmap.pixelsWide * 3 / 4, y: bitmap.pixelsHigh / 2)?.usingColorSpace(
                .deviceRGB))
        let leftBlue = left.blueComponent - left.redComponent
        let rightBlue = right.blueComponent - right.redComponent
        if direction == .rightToLeft {
            #expect(leftBlue > rightBlue + 0.05)
        } else {
            #expect(rightBlue > leftBlue + 0.05)
        }
    }
    #endif

    private func geometry(
        _ position: CalendarRangePosition, leading: Bool = false, trailing: Bool = false,
        rtl: Bool = false
    ) -> CalendarRangeBandGeometry {
        CalendarRangeBandGeometry(
            position: position, columnWidth: 44, gap: 8, height: 44,
            joinsLeading: leading, joinsTrailing: trailing, rightToLeft: rtl)
    }
}
