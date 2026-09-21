#if os(macOS)

    import AppKit
    import SwiftUI
    import Testing

    @testable import SwiftUICalendar

    @MainActor
    func hostView<V: View>(
        _ view: V,
        size: CGSize = CGSize(width: 390, height: 420)
    ) -> (window: NSWindow, hosting: NSHostingView<V>) {
        let hosting = NSHostingView(rootView: view)
        hosting.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(
            contentRect: hosting.frame,
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        window.layoutIfNeeded()
        hosting.layoutSubtreeIfNeeded()
        if let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) {
            hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        } else {
            hosting.displayIfNeeded()
        }
        return (window, hosting)
    }

    /// Forces a full layout pass and renders the view to PNG data. Used to compare actual
    /// rendered pixel content between two hosting scenarios (e.g. a fresh render at some size vs.
    /// an existing view resized to that size, as happens during a live device rotation).
    @MainActor
    func renderPNGData(_ view: NSView) -> Data? {
        view.layoutSubtreeIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        return bitmap.representation(using: .png, properties: [:])
    }

    /// Pumps the main run loop until `view` renders `requiredStableFrames` consecutive identical
    /// frames, or `timeout` elapses.
    ///
    /// A fixed `Task.sleep` is not a render-complete signal for a SwiftUI `NSHostingView`: after a
    /// live model mutation the tree settles asynchronously over several run-loop turns (observation
    /// delivery, `onChange`, `LazyVStack` scroll re-anchoring, implicit animations). Waiting for the
    /// rendered pixels to stop changing makes that settle deterministic regardless of wall-clock
    /// timing or how busy the shared run loop is under parallel test execution.
    ///
    /// Note that pumping the run loop does let other main-queue work run, so a concurrently
    /// executing `@MainActor` test can interleave here. Suites that host a live view and then assert
    /// on the settled tree should be `.serialized` for that reason.
    ///
    /// A view that renders *nothing* also produces identical consecutive frames, so a `true` return
    /// means "the pixels stopped changing", not "the content arrived". Pair this with
    /// ``expectNonBlankRender(_:size:_:sourceLocation:)`` whenever an empty render would otherwise
    /// surface as a confusing downstream assertion on empty model state.
    ///
    /// Returns `true` if the render stabilized, `false` if it timed out (the caller may still
    /// snapshot the last frame; a genuinely wrong render is then caught by the assertion).
    @discardableResult
    @MainActor
    func waitForStableRender(
        _ view: NSView,
        timeout: TimeInterval = 5,
        minimumFrames: Int = 8,
        requiredStableFrames: Int = 4,
        pollInterval: TimeInterval = 1.0 / 60.0
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        var previous: Data?
        var identicalRun = 1
        var pumped = 0
        while Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(pollInterval))
            pumped += 1
            let frame = renderPNGData(view)
            identicalRun = (frame != nil && frame == previous) ? identicalRun + 1 : 1
            previous = frame
            if pumped >= minimumFrames && identicalRun >= requiredStableFrames { return true }
        }
        return false
    }

    // MARK: - Blank-render Detection

    /// Renders an empty view at `size`, to compare a hosted view's pixels against.
    ///
    /// ``waitForStableRender(_:timeout:minimumFrames:requiredStableFrames:pollInterval:)`` reports
    /// success as soon as consecutive frames stop changing, and a view that renders nothing
    /// stabilizes immediately. Comparing against this reference turns a silently blank render into
    /// an explicit failure instead of a puzzling assertion on empty collected state further down.
    @MainActor
    func blankFrameData(size: CGSize) -> Data? {
        let blank = hostView(
            Color.clear.frame(width: size.width, height: size.height), size: size)
        defer { blank.window.contentView = nil }
        return renderPNGData(blank.hosting)
    }

    /// Fails when `view` rendered nothing at `size`, and returns its rendered frame.
    @discardableResult
    @MainActor
    func expectNonBlankRender(
        _ view: NSView,
        size: CGSize,
        _ context: @autoclosure () -> String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> Data? {
        let frame = renderPNGData(view)
        #expect(
            frame != nil, "render produced no frame (\(context()))", sourceLocation: sourceLocation)
        #expect(
            frame != blankFrameData(size: size),
            "view rendered blank (\(context()))", sourceLocation: sourceLocation)
        return frame
    }

    // MARK: - Day-frame Measurement

    /// Collects the on-screen frame of every day cell a hosted calendar lays out.
    ///
    /// Shared by the resize and safe-area suites so both measure day geometry the same way.
    @MainActor
    final class MeasuredDayFrames {
        /// Frames of days belonging to the month they are displayed in, keyed by date.
        var inMonth: [Date: CGRect] = [:]

        /// Horizontal span covered by the measured in-month cells, or `nil` when none were measured.
        var span: CGFloat? {
            guard let minX = inMonth.values.map(\.minX).min(),
                let maxX = inMonth.values.map(\.maxX).max()
            else { return nil }
            return maxX - minX
        }

        /// Width of the widest measured in-month cell, or `nil` when none were measured.
        var widestCell: CGFloat? {
            inMonth.values.map(\.width).max()
        }

        func reset() {
            inMonth.removeAll()
        }

        init() {}
    }

    /// A day cell that reports its own frame into a ``MeasuredDayFrames`` box.
    ///
    /// Install it with `theme.day.setDayContent { MeasuringDayView(context: $0, frames: box) }`.
    struct MeasuringDayView: CalendarDayView {
        let context: CalendarDayContext
        var frames: MeasuredDayFrames?

        init(context: CalendarDayContext) {
            self.context = context
        }

        init(context: CalendarDayContext, frames: MeasuredDayFrames) {
            self.context = context
            self.frames = frames
        }

        var body: some View {
            Text(context.dayLabel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onGeometryChange(for: CGRect.self) { geometry in
                    geometry.frame(in: .global)
                } action: { frame in
                    guard context.isInCurrentMonth, let frames else { return }
                    frames.inMonth[context.date] = frame
                }
        }
    }

#endif
