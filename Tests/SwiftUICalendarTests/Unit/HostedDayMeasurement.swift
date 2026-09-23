import SwiftUI

@testable import SwiftUICalendar

// MARK: - Day-frame Measurement

/// Collects the on-screen frame of every day cell a hosted calendar lays out.
///
/// Shared by the resize and safe-area suites so both measure day geometry the same way.
@MainActor
final class MeasuredDayFrames {
    /// Restricts measurement to a single month. The vertically scrolling body keeps several
    /// months realized at once, and a row realized before the width settled keeps its old frame,
    /// so mixing months would compare geometry from two different layout passes.
    let month: MonthIdentifier?
    let calendar: Calendar

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

    /// Records every displayed day of every realized month.
    init() {
        month = nil
        calendar = Calendar(identifier: .gregorian)
    }

    /// Records only the displayed days of `month`.
    init(month: MonthIdentifier, calendar: Calendar) {
        self.month = month
        self.calendar = calendar
    }

    func shouldRecord(_ date: Date) -> Bool {
        guard let month else { return true }
        return CalendarEngine(calendar: calendar).month(containing: date) == month
    }
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
                guard context.isInCurrentMonth, let frames,
                    frames.shouldRecord(context.date)
                else { return }
                frames.inMonth[context.date] = frame
            }
    }
}

#if os(iOS)
    import UIKit

    // MARK: - UIKit Hosting

    /// Hosts `view` in a window of `size`, adding `safeArea` on top of the window's own insets.
    ///
    /// The macOS hosted suites cannot produce a device safe area, so this is how the iOS suites
    /// exercise notch and home-indicator insets.
    @MainActor
    func hostView<V: View>(
        _ view: V,
        size: CGSize,
        safeArea: UIEdgeInsets = .zero
    ) -> (window: UIWindow, hosting: UIHostingController<V>) {
        let hosting = UIHostingController(rootView: view)
        hosting.additionalSafeAreaInsets = safeArea
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = hosting
        window.isHidden = false
        return (window, hosting)
    }

    /// Lays out and pumps the run loop until the hosted tree has settled.
    ///
    /// Measuring frames rather than pixels, so a bounded number of layout-and-run-loop passes is
    /// enough: geometry callbacks land within a few turns of the run loop.
    @MainActor
    func settle(_ view: UIView, passes: Int = 40) {
        for _ in 0..<passes {
            view.setNeedsLayout()
            view.layoutIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(1.0 / 60.0))
        }
    }
#endif
