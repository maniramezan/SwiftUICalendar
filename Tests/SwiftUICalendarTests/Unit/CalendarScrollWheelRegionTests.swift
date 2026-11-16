#if os(macOS)
import AppKit
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Calendar scroll wheel regions")
struct CalendarScrollWheelRegionTests {
    @Test("Only the calendar under the pointer in the event window accepts paging")
    func windowAndPointer() {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 600, height: 400), styleMask: [.borderless],
            backing: .buffered, defer: false)
        let other = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 600, height: 400), styleMask: [.borderless],
            backing: .buffered, defer: false)
        let first = NSView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        let second = NSView(frame: CGRect(x: 250, y: 0, width: 200, height: 200))
        window.contentView?.addSubview(first)
        window.contentView?.addSubview(second)
        let a = HorizontalScrollWheelMonitor(threshold: 30) { _ in }
        let b = HorizontalScrollWheelMonitor(threshold: 30) { _ in }
        a.start(in: first)
        b.start(in: second)
        defer {
            a.stop()
            b.stop()
        }
        #expect(a.contains(window: window, location: CGPoint(x: 50, y: 50)))
        #expect(!b.contains(window: window, location: CGPoint(x: 50, y: 50)))
        #expect(!a.contains(window: other, location: CGPoint(x: 50, y: 50)))
        #expect(!a.contains(window: nil, location: CGPoint(x: 50, y: 50)))
        #expect(!a.contains(window: window, location: CGPoint(x: 550, y: 50)))
        first.isHidden = true
        #expect(!a.contains(window: window, location: CGPoint(x: 50, y: 50)))
    }

    @Test("Clipped portions of a calendar do not accept pointer events")
    func clippedRegion() {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 600, height: 400), styleMask: [.borderless],
            backing: .buffered, defer: false)
        let scroll = NSScrollView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        let document = NSView(frame: CGRect(x: 0, y: 0, width: 600, height: 200))
        scroll.documentView = document
        window.contentView?.addSubview(scroll)
        let monitor = HorizontalScrollWheelMonitor(threshold: 30) { _ in }
        monitor.start(in: document)
        defer { monitor.stop() }
        #expect(monitor.contains(window: window, location: CGPoint(x: 50, y: 50)))
        #expect(!monitor.contains(window: window, location: CGPoint(x: 300, y: 50)))
    }

    @Test("Configuration updates replace threshold, callback and enabled state")
    func configurationUpdates() {
        var oldPages: [Int] = []
        var newPages: [Int] = []
        let monitor = HorizontalScrollWheelMonitor(threshold: 30) { oldPages.append($0) }
        monitor.fold(deltaX: -20, deltaY: 0, isMomentum: false, didBegin: true, didEnd: false)
        monitor.isEnabled = false
        monitor.fold(deltaX: -100, deltaY: 0, isMomentum: false, didBegin: false, didEnd: false)
        monitor.onPage = { newPages.append($0) }
        monitor.threshold = 60
        monitor.isEnabled = true
        monitor.fold(deltaX: -40, deltaY: 0, isMomentum: false, didBegin: false, didEnd: false)
        #expect(newPages.isEmpty)
        monitor.fold(deltaX: -25, deltaY: 0, isMomentum: false, didBegin: false, didEnd: false)
        #expect(newPages == [1])
        #expect(oldPages.isEmpty)
    }
}
#endif
