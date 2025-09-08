import SwiftUI

enum AdaptiveGlassShape {
    case circle
    case capsule
    case roundedRectangle(cornerRadius: CGFloat)
}

struct AdaptiveGlassModifier: ViewModifier {
    let shape: AdaptiveGlassShape
    let interactive: Bool
    let tint: Color?
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if #available(iOS 26, macOS 26, *) {
            content.modifier(LiquidGlassModifier(shape: shape, interactive: interactive,
                                                  tint: tint, reduceTransparency: reduceTransparency))
        } else {
            content.modifier(MaterialFallbackModifier(shape: shape, reduceTransparency: reduceTransparency))
        }
    }
}

@available(iOS 26, macOS 26, *)
private struct LiquidGlassModifier: ViewModifier {
    let shape: AdaptiveGlassShape
    let interactive: Bool
    let tint: Color?
    let reduceTransparency: Bool

    private var effect: Glass {
        var e: Glass = reduceTransparency ? .identity : (interactive ? .regular.interactive() : .regular)
        if let tint, !reduceTransparency {
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

    private var material: Material { reduceTransparency ? .regularMaterial : .ultraThinMaterial }

    func body(content: Content) -> some View {
        switch shape {
        case .circle:
            content.background(Circle().fill(material))
                   .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
        case .capsule:
            content.background(Capsule().fill(material))
                   .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
        case .roundedRectangle(let r):
            content.background(RoundedRectangle(cornerRadius: r).fill(material))
                   .overlay(RoundedRectangle(cornerRadius: r).stroke(Color.white.opacity(0.15), lineWidth: 0.5))
        }
    }
}

extension View {
    func adaptiveGlass(shape: AdaptiveGlassShape, interactive: Bool = false, tint: Color? = nil) -> some View {
        modifier(AdaptiveGlassModifier(shape: shape, interactive: interactive, tint: tint))
    }
}
