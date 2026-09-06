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

  /// Pumps the main run loop until `view` renders `requiredStableFrames` consecutive identical
  /// frames, or `timeout` elapses.
  ///
  /// A fixed `Task.sleep` is not a render-complete signal for a SwiftUI `NSHostingView`: after a
  /// live model mutation the tree settles asynchronously over several run-loop turns (observation
  /// delivery, `onChange`, `LazyVStack` scroll re-anchoring, implicit animations). Waiting for the
  /// rendered pixels to stop changing makes that settle deterministic regardless of wall-clock
  /// timing or how busy the shared run loop is under parallel test execution. Because the whole
  /// wait is synchronous, the calling test never suspends and no other `@MainActor` test can
  /// interleave between the wait and the snapshot.
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

#endif
