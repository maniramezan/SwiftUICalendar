#if os(macOS)
import AppKit
import SwiftUI
import Testing

@testable import SwiftUICalendar

/// A macOS window is freely resizable and has no size classes, so its cells grow with the window:
/// into spare height for the fixed and horizontal months, never in the scrolling list, never in a
/// two-month fold, and never below the standard ceiling when the window is short.
@MainActor
@Suite("macOS window cell growth", .serialized)
struct CalendarMacWindowGrowthTests {
    private let base = CalendarMetrics.default.maxCellSize

    private func mount(
        mode: CalendarConfiguration.ScrollMode, size: CGSize, regions: [CGRect] = []
    ) throws -> (
        frames: MeasuredDayFrames, window: NSWindow, hosting: NSView
    ) {
        let model = CalendarViewModel.snapshot(selection: .single(nil))
        let month = try #require(model.monthIdentifier())
        let frames = MeasuredDayFrames(month: month, calendar: model.engine.calendar)
        frames.forgetsDisappearedDays = true
        let theme = Theme()
        theme.day.setDayContent { MeasuringDayView(context: $0, frames: frames) }
        let hosted = hostView(
            CalendarView(model: model, theme: theme, configuration: .init(scrollMode: mode))
                .environment(\.calendarFoldRegions, regions),
            size: size)
        #expect(waitForStableRender(hosted.hosting))
        expectNonBlankRender(hosted.hosting, size: size, "\(mode) at \(size)")
        return (frames, hosted.window, hosted.hosting)
    }

    @Test("A tall window grows a fixed or horizontal month past the standard ceiling")
    func tallWindowGrows() throws {
        for mode in [CalendarConfiguration.ScrollMode.none, .horizontal] {
            let size = CGSize(width: 1100, height: 1000)
            let mounted = try mount(mode: mode, size: size)
            defer { mounted.window.contentView = nil }
            let widest = try #require(mounted.frames.widestCell)
            #expect(widest > base + 0.5, "\(mode): cells stayed at \(widest)")
            for frame in mounted.frames.inMonth.values {
                #expect(
                    frame.height <= base * CalendarMetrics.default.regularCellScale + 0.5,
                    "\(mode): cell \(frame) passed the growth ceiling")
                #expect(
                    frame.maxY <= size.height + 0.5,
                    "\(mode): cell \(frame) runs past the bottom of the window")
            }
        }
    }

    @Test(
        "A short window keeps the standard ceiling",
        arguments: [
            CalendarConfiguration.ScrollMode.none, .horizontal,
        ])
    func shortWindowKeepsCeiling(mode: CalendarConfiguration.ScrollMode) throws {
        let mounted = try mount(mode: mode, size: CGSize(width: 1100, height: 420))
        defer { mounted.window.contentView = nil }
        let widest = try #require(mounted.frames.widestCell)
        for frame in mounted.frames.inMonth.values {
            #expect(frame.height <= base + 0.5, "\(mode): cell \(frame) grew in a short window")
        }
        #expect(widest > 0)
    }

    @Test("The vertical list keeps the standard ceiling however tall the window is")
    func verticalKeepsCeiling() throws {
        let mounted = try mount(mode: .vertical, size: CGSize(width: 1100, height: 1000))
        defer { mounted.window.contentView = nil }
        #expect(!mounted.frames.inMonth.isEmpty)
        for frame in mounted.frames.inMonth.values {
            #expect(frame.height <= base + 0.5, "vertical: cell \(frame) grew")
        }
    }

    @Test(
        "A two-month fold keeps the standard ceiling in each panel",
        arguments: [
            CalendarConfiguration.ScrollMode.none, .horizontal,
        ])
    func foldKeepsCeiling(mode: CalendarConfiguration.ScrollMode) throws {
        let size = CGSize(width: 1300, height: 1000)
        let mounted = try mount(
            mode: mode, size: size,
            regions: [CGRect(x: 630, y: 0, width: 40, height: size.height)])
        defer { mounted.window.contentView = nil }
        #expect(!mounted.frames.inMonth.isEmpty)
        for frame in mounted.frames.inMonth.values {
            #expect(frame.height <= base + 0.5, "\(mode): a folded panel's cell grew to \(frame)")
        }
    }

    @Test("Resizing a window taller grows the cells, and shorter shrinks them back")
    func liveResizeFollowsHeight() throws {
        let tall = CGSize(width: 1100, height: 1000)
        let short = CGSize(width: 1100, height: 420)
        let mounted = try mount(mode: .none, size: short)
        defer { mounted.window.contentView = nil }
        let shortCell = try #require(mounted.frames.widestCell)
        #expect(shortCell <= base + 0.5)

        mounted.frames.reset()
        mounted.window.setContentSize(tall)
        #expect(waitForStableRender(mounted.hosting))
        let grown = try #require(mounted.frames.widestCell)
        #expect(grown > base + 0.5, "cells stayed at \(grown) after the window grew")

        mounted.frames.reset()
        mounted.window.setContentSize(short)
        #expect(waitForStableRender(mounted.hosting))
        let shrunk = try #require(mounted.frames.widestCell)
        #expect(shrunk <= base + 0.5, "cells stayed at \(shrunk) after the window shrank")
    }
}
#endif
