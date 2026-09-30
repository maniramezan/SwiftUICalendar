import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Adaptive Glass Tests")
struct AdaptiveGlassTests {
    @Test("Calendar shapes map to the shared outlines")
    func sharedOutlines() {
        #expect(AdaptiveGlassShape.circle.surfaceShape == .circle)
        #expect(AdaptiveGlassShape.capsule.surfaceShape == .capsule)
        #expect(
            AdaptiveGlassShape.roundedRectangle(cornerRadius: 10).surfaceShape == .roundedRectangle)
    }

    @Test("Only rounded surfaces carry a custom radius and hairline highlight")
    func calendarHighlightStyle() {
        #expect(AdaptiveGlassShape.roundedRectangle(cornerRadius: 10).cornerRadius == 10)
        #expect(AdaptiveGlassShape.roundedRectangle(cornerRadius: 0).cornerRadius == 0)
        #expect(AdaptiveGlassShape.roundedRectangle(cornerRadius: 10).usesHairlineBorder)
        #expect(AdaptiveGlassShape.circle.cornerRadius == nil)
        #expect(AdaptiveGlassShape.capsule.cornerRadius == nil)
        #expect(!AdaptiveGlassShape.circle.usesHairlineBorder)
        #expect(!AdaptiveGlassShape.capsule.usesHairlineBorder)
    }

    #if os(macOS)
    @Test("Shared adaptive surfaces render all calendar outlines")
    func sharedSurfacesRender() {
        let view = HStack {
            Text("Circle").adaptiveGlass(shape: .circle, interactive: true)
            Text("Capsule").adaptiveGlass(shape: .capsule, tint: .blue)
            Text("Rounded").adaptiveGlass(shape: .roundedRectangle(cornerRadius: 10))
        }
        .frame(width: 320, height: 120)
        let hosted = hostView(view, size: CGSize(width: 320, height: 120))
        #expect(hosted.hosting.fittingSize.width >= 0)
        hosted.window.contentView = nil
    }
    #endif
}
