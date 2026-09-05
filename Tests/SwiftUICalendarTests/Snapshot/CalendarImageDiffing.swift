#if os(macOS)
  import AppKit
  import SnapshotTesting

  /// Compare exact pixels without the framework's Core Image difference-image renderer.
  /// Some headless/beta SDK configurations cannot produce that diagnostic image and trap.
  /// Reference and actual PNGs remain attached on mismatch.
  func calendarImageStrategy(size: CGSize) -> Snapshotting<NSView, NSImage> {
    var strategy = Snapshotting<NSView, NSImage>.image(size: size)
    let encode = strategy.diffing.toData
    strategy.diffing.diffV2 = { reference, actual in
      guard let expected = calendarPixels(reference), let received = calendarPixels(actual) else {
        return ("Could not decode snapshot pixels.", [])
      }
      guard expected != received else { return nil }
      return (
        "Snapshot pixels differ from the reference.",
        [
          .data(encode(reference), name: "reference.png"),
          .data(encode(actual), name: "failure.png"),
        ]
      )
    }
    return strategy
  }

  private func calendarPixels(_ image: NSImage) -> Data? {
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
      let context = CGContext(
        data: nil, width: cgImage.width, height: cgImage.height,
        bitsPerComponent: 8, bytesPerRow: cgImage.width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
      let bytes = context.data
    else { return nil }
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
    var dimensions = [cgImage.width, cgImage.height]
    var result = dimensions.withUnsafeMutableBytes { Data($0) }
    result.append(Data(bytes: bytes, count: cgImage.width * cgImage.height * 4))
    return result
  }
#endif
