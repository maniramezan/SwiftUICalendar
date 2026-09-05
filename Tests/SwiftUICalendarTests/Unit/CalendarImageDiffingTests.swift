#if os(macOS)
  import AppKit
  import Testing

  @MainActor
  @Suite("Snapshot comparison rejects visual regressions")
  struct CalendarImageDiffingTests {
    @Test("Equal pixels pass and changed pixels fail")
    func exactPixels() throws {
      let white = try image(red: 1)
      let black = try image(red: 0)
      let compare = calendarImageStrategy(size: CGSize(width: 4, height: 4)).diffing.diffV2
      #expect(compare(white, white) == nil)
      #expect(compare(white, black) != nil)
    }

    private func image(red: CGFloat) throws -> NSImage {
      let context = try #require(
        CGContext(
          data: nil, width: 4, height: 4,
          bitsPerComponent: 8, bytesPerRow: 16, space: CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
      context.setFillColor(CGColor(red: red, green: red, blue: red, alpha: 1))
      context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
      return NSImage(cgImage: try #require(context.makeImage()), size: CGSize(width: 4, height: 4))
    }
  }
#endif
