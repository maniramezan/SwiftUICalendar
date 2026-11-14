import SwiftUI

#if os(iOS)
import UIKit
#endif

/// The drag that pages the horizontal month carousel.
///
/// On iOS a SwiftUI `DragGesture` on the carousel, even as a simultaneous gesture, kept vertical
/// drags that started on the day grid from reaching the enclosing scroll view: when a month at a
/// large text size did not fit, a 402pt-tall landscape iPhone could never reveal its last weeks.
/// iOS therefore pages with a UIKit pan that only begins when the finger moves mostly sideways,
/// leaving every other drag to the scroll view. macOS keeps the SwiftUI drag.
struct HorizontalPagingGesture: ViewModifier {
    let isEnabled: Bool
    let onChanged: (_ translation: CGSize) -> Void
    let onEnded: (_ translation: CGSize, _ predictedEndTranslation: CGSize) -> Void

    func body(content: Content) -> some View {
        #if os(iOS)
        content.gesture(
            HorizontalPanGesture(isEnabled: isEnabled, onChanged: onChanged, onEnded: onEnded))
        #else
        content.simultaneousGesture(
            DragGesture()
                .onChanged { onChanged($0.translation) }
                .onEnded { onEnded($0.translation, $0.predictedEndTranslation) },
            including: isEnabled ? .all : .subviews
        )
        #endif
    }
}

#if os(iOS)
struct HorizontalPanGesture: UIGestureRecognizerRepresentable {
    let isEnabled: Bool
    let onChanged: (_ translation: CGSize) -> Void
    let onEnded: (_ translation: CGSize, _ predictedEndTranslation: CGSize) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        pan.isEnabled = isEnabled
        return pan
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        recognizer.isEnabled = isEnabled
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let point = recognizer.translation(in: recognizer.view)
        let translation = CGSize(width: point.x, height: point.y)
        switch recognizer.state {
        case .changed:
            onChanged(translation)
        case .ended:
            let velocity = recognizer.velocity(in: recognizer.view)
            onEnded(
                translation,
                CGSize(
                    width: translation.width + Self.projectedDistance(velocity: velocity.x),
                    height: translation.height + Self.projectedDistance(velocity: velocity.y)))
        case .cancelled, .failed:
            // No direction: the carousel snaps back instead of paging.
            onEnded(.zero, .zero)
        default:
            break
        }
    }

    /// How far a release at `velocity` (points per second) would carry, using the deceleration a
    /// scroll view applies, so a quick flick pages the way `DragGesture`'s prediction did.
    static func projectedDistance(velocity: CGFloat) -> CGFloat {
        let rate = UIScrollView.DecelerationRate.normal.rawValue
        return velocity / 1000 * rate / (1 - rate)
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        /// Begins only for a mostly horizontal pan; a vertical one is left to the scroll view.
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y)
        }

        /// Runs beside the scroll view's own pan, as the simultaneous SwiftUI drag did.
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}
#endif
