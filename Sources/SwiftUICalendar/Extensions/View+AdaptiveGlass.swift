import SwiftUI

enum AdaptiveGlassShape {
    case circle
    case capsule
    case roundedRectangle(cornerRadius: CGFloat)
}

enum AdaptiveGlassRenderingMode {
    case liquidGlass
    case materialFallback
}

enum AdaptiveGlassMaterialStyle {
    case regular
    case ultraThin
}

struct AdaptiveGlassModifier: ViewModifier {
    let shape: AdaptiveGlassShape
    let interactive: Bool
    let tint: Color?
    let supportsLiquidGlassOverride: Bool?
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    init(
        shape: AdaptiveGlassShape,
        interactive: Bool,
        tint: Color?,
        supportsLiquidGlassOverride: Bool? = nil
    ) {
        self.shape = shape
        self.interactive = interactive
        self.tint = tint
        self.supportsLiquidGlassOverride = supportsLiquidGlassOverride
    }

    static var supportsLiquidGlass: Bool {
        if #available(anyAppleOS 26, *) {
            return true
        }
        return false
    }

    static func renderingMode(supportsLiquidGlass: Bool) -> AdaptiveGlassRenderingMode {
        supportsLiquidGlass ? .liquidGlass : .materialFallback
    }

    static func shouldApplyTint(hasTint: Bool, reduceTransparency: Bool) -> Bool {
        hasTint && !reduceTransparency
    }

    static func fallbackMaterialStyle(reduceTransparency: Bool) -> AdaptiveGlassMaterialStyle {
        reduceTransparency ? .regular : .ultraThin
    }

    private var effectiveSupportsLiquidGlass: Bool {
        supportsLiquidGlassOverride ?? Self.supportsLiquidGlass
    }

    func body(content: Content) -> some View {
        switch Self.renderingMode(supportsLiquidGlass: effectiveSupportsLiquidGlass) {
        case .liquidGlass:
            if #available(anyAppleOS 26, *) {
                content.modifier(
                    LiquidGlassModifier(
                        shape: shape, interactive: interactive,
                        tint: tint, reduceTransparency: reduceTransparency))
            } else {
                content.modifier(
                    MaterialFallbackModifier(shape: shape, reduceTransparency: reduceTransparency))
            }
        case .materialFallback:
            content.modifier(
                MaterialFallbackModifier(shape: shape, reduceTransparency: reduceTransparency))
        }
    }
}

@available(anyAppleOS 26, *)
private struct LiquidGlassModifier: ViewModifier {
    let shape: AdaptiveGlassShape
    let interactive: Bool
    let tint: Color?
    let reduceTransparency: Bool

    private var effect: Glass {
        var e: Glass =
            reduceTransparency ? .identity : (interactive ? .regular.interactive() : .regular)
        if AdaptiveGlassModifier.shouldApplyTint(
            hasTint: tint != nil, reduceTransparency: reduceTransparency),
            let tint
        {
            e = e.tint(tint)
        }
        return e
    }

    func body(content: Content) -> some View {
        let e = effect
        switch shape {
        case .circle:
            content.glassEffect(e, in: .circle)
        case .capsule:
            content.glassEffect(e, in: .capsule)
        case .roundedRectangle(let r):
            content.glassEffect(e, in: RoundedRectangle(cornerRadius: r))
        }
    }
}

private struct MaterialFallbackModifier: ViewModifier {
    let shape: AdaptiveGlassShape
    let reduceTransparency: Bool
    @Environment(\.calendarMetrics) private var metrics

    static func material(style: AdaptiveGlassMaterialStyle) -> Material {
        switch style {
        case .regular:
            .regularMaterial
        case .ultraThin:
            .ultraThinMaterial
        }
    }

    private var material: Material {
        Self.material(
            style: AdaptiveGlassModifier.fallbackMaterialStyle(
                reduceTransparency: reduceTransparency))
    }

    func body(content: Content) -> some View {
        // A thinner, fainter edge on the rounded rectangle: its corner radius already draws the
        // shape, so a full-weight outline on top of it would read as a border around a border.
        let highlight = Color.white.opacity(metrics.glassBorderOpacity)
        let hairlineHighlight = Color.white.opacity(metrics.glassHairlineBorderOpacity)
        switch shape {
        case .circle:
            content.background(Circle().fill(material))
                .overlay(Circle().stroke(highlight, lineWidth: metrics.thinStroke))
        case .capsule:
            content.background(Capsule().fill(material))
                .overlay(Capsule().stroke(highlight, lineWidth: metrics.thinStroke))
        case .roundedRectangle(let r):
            content.background(RoundedRectangle(cornerRadius: r).fill(material))
                .overlay(
                    RoundedRectangle(cornerRadius: r).stroke(
                        hairlineHighlight, lineWidth: metrics.hairlineStroke))
        }
    }
}

extension View {
    func adaptiveGlass(shape: AdaptiveGlassShape, interactive: Bool = false, tint: Color? = nil)
        -> some View
    {
        modifier(AdaptiveGlassModifier(shape: shape, interactive: interactive, tint: tint))
    }
}
