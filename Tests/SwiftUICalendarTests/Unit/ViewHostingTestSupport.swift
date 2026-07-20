#if os(macOS)

  import AppKit
  import SwiftUI

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

#endif
