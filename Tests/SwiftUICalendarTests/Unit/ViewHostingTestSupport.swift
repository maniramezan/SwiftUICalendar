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

#endif
