#if os(macOS)
import AppKit
import SwiftUI

struct HorizontalScrollWheelRegion: NSViewRepresentable {
    let threshold: CGFloat
    let isEnabled: Bool
    let onPage: (Int) -> Void

    func makeCoordinator() -> HorizontalScrollWheelMonitor {
        HorizontalScrollWheelMonitor(threshold: threshold, onPage: onPage)
    }

    func makeNSView(context: Context) -> NSView {
        let view = ScrollWheelTrackingView()
        context.coordinator.start(in: view)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.threshold = threshold
        context.coordinator.isEnabled = isEnabled
        context.coordinator.onPage = onPage
    }

    static func dismantleNSView(_ view: NSView, coordinator: HorizontalScrollWheelMonitor) {
        coordinator.stop()
    }
}
private final class ScrollWheelTrackingView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
#endif
