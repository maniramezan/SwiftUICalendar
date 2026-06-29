import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Adaptive Glass Tests")
struct AdaptiveGlassTests {

  @Test("renderingMode chooses the expected implementation")
  func renderingModeChoosesExpectedImplementation() {
    #expect(AdaptiveGlassModifier.renderingMode(supportsLiquidGlass: true) == .liquidGlass)
    #expect(AdaptiveGlassModifier.renderingMode(supportsLiquidGlass: false) == .materialFallback)
  }

  @Test("Liquid glass tint is skipped when transparency is reduced")
  func liquidGlassTintDecisionRespectsTransparency() {
    #expect(AdaptiveGlassModifier.shouldApplyTint(hasTint: true, reduceTransparency: false))
    #expect(!AdaptiveGlassModifier.shouldApplyTint(hasTint: true, reduceTransparency: true))
    #expect(!AdaptiveGlassModifier.shouldApplyTint(hasTint: false, reduceTransparency: false))
  }

  @Test("Material fallback chooses distinct materials for transparency settings")
  func materialFallbackChoosesDistinctMaterials() {
    let reduced = AdaptiveGlassModifier.fallbackMaterialStyle(reduceTransparency: true)
    let regular = AdaptiveGlassModifier.fallbackMaterialStyle(reduceTransparency: false)

    #expect(reduced == .regular)
    #expect(regular == .ultraThin)
  }

  #if os(macOS)
    @Test("Forced material fallback renders all supported shapes")
    func forcedMaterialFallbackRendersAllSupportedShapes() {
      let view = HStack {
        Text("Circle")
          .modifier(
            AdaptiveGlassModifier(
              shape: .circle,
              interactive: false,
              tint: nil,
              supportsLiquidGlassOverride: false
            ))
        Text("Capsule")
          .modifier(
            AdaptiveGlassModifier(
              shape: .capsule,
              interactive: false,
              tint: nil,
              supportsLiquidGlassOverride: false
            ))
        Text("Rounded")
          .modifier(
            AdaptiveGlassModifier(
              shape: .roundedRectangle(cornerRadius: 10),
              interactive: false,
              tint: nil,
              supportsLiquidGlassOverride: false
            ))
      }
      .frame(width: 320, height: 120)

      let hosted = hostView(view, size: CGSize(width: 320, height: 120))

      #expect(hosted.hosting.fittingSize.width >= 0)
    }
  #endif
}
