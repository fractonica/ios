import SwiftUI

/// A full-screen drawing in design coordinates.
///
///     DesignCanvas { ink in
///         ink.circle(CGPoint(x: 196.5, y: 277), radius: 102, stroke: ink.palette.etch2)
///     }
///
/// The closure gets an ``Ink`` whose context is already transformed by the
/// environment's ``DesignSpace``, so the numbers of DESIGN.md §7 can be used
/// as they are written. A canvas is one picture to assistive technology and
/// takes no touches: it is hidden from accessibility and from hit testing.
/// Lay `.designFrame(…)` elements over it for both.
struct DesignCanvas: View {
    @Environment(\.designSpace) private var space
    @Environment(\.theme) private var theme
    @Environment(\.displayScale) private var displayScale
    let draw: (inout Ink) -> Void

    init(_ draw: @escaping (inout Ink) -> Void) {
        self.draw = draw
    }

    var body: some View {
        let space = space, theme = theme, displayScale = displayScale, draw = draw
        Canvas { context, _ in
            context.translateBy(x: space.origin.x, y: space.origin.y)
            context.scaleBy(x: space.scale, y: space.scale)
            var theme = theme
            theme.engravedFloor = space.engravedFloor
            var ink = Ink(
                context: context, theme: theme, layout: space.layout,
                pixelsPerPoint: space.scale * displayScale,
                pixelOrigin: CGPoint(x: space.origin.x * displayScale, y: space.origin.y * displayScale)
            )
            draw(&ink)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

/// A ``DesignCanvas`` whose drawing depends on a value SwiftUI animates: the
/// closure is called for every frame with the interpolated value. This is how
/// the zoom between focus levels, the limb's turn and the cross-fades of
/// DESIGN.md §10 reach a canvas.
///
///     MotionCanvas(value: earthBlend) { ink, blend in … }
///         .animation(Motion.mode.animation(reduceMotion: reduceMotion), value: earthBlend)
struct MotionCanvas<Value: VectorArithmetic & Sendable>: View, Animatable {
    var value: Value
    let draw: (inout Ink, Value) -> Void

    init(value: Value, _ draw: @escaping (inout Ink, Value) -> Void) {
        self.value = value
        self.draw = draw
    }

    // Nonisolated because `Animatable` is: SwiftUI reads and writes it while
    // interpolating. `value` is a Sendable stored property of a value type,
    // which may be touched from anywhere.
    nonisolated var animatableData: Value {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        let value = value, draw = draw
        DesignCanvas { ink in draw(&ink, value) }
    }
}
