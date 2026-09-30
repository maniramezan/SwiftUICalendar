import Components
import SwiftUI

/// Calendar-specific outlines and highlight styling for the shared adaptive surface.
enum AdaptiveGlassShape {
    case circle
    case capsule
    case roundedRectangle(cornerRadius: CGFloat)

    var surfaceShape: AdaptiveSurfaceShape {
        switch self {
        case .circle: .circle
        case .capsule: .capsule
        case .roundedRectangle: .roundedRectangle
        }
    }

    var cornerRadius: CGFloat? {
        guard case .roundedRectangle(let radius) = self else { return nil }
        return radius
    }

    var usesHairlineBorder: Bool {
        if case .roundedRectangle = self { return true }
        return false
    }
}

/// Keeps calendar appearance decisions local while Components owns glass and material rendering.
struct AdaptiveGlassModifier: ViewModifier {
    let shape: AdaptiveGlassShape
    let interactive: Bool
    let tint: Color?
    @Environment(\.calendarMetrics) private var metrics

    func body(content: Content) -> some View {
        content.designAdaptiveSurface(
            tint: tint,
            interactive: interactive,
            cornerRadius: shape.cornerRadius,
            shape: shape.surfaceShape,
            fallbackBorderColor: .white.opacity(
                shape.usesHairlineBorder
                    ? metrics.glassHairlineBorderOpacity : metrics.glassBorderOpacity),
            fallbackBorderWidth: shape.usesHairlineBorder
                ? metrics.hairlineStroke : metrics.thinStroke
        )
    }
}

extension View {
    func adaptiveGlass(shape: AdaptiveGlassShape, interactive: Bool = false, tint: Color? = nil)
        -> some View
    {
        modifier(AdaptiveGlassModifier(shape: shape, interactive: interactive, tint: tint))
    }
}
