import Foundation

/// The levels a two-finger gesture on the instrument has moved the focus
/// by: a pinch (one level per factor of the ring ratio) OR a twist (one
/// level per letter of the limb), never both at once.
///
/// A pinch nearly always twists a little and a twist nearly always pinches a
/// little. Summing the two let a stray 4° of twist add a level to a pinch.
/// So the first of the two to mean a step owns the gesture until the
/// fingers lift: a pinch as soon as it rounds to one level, a twist only
/// past ``rotationThreshold`` (a deliberate turn, well beyond the 4° a pinch
/// wobbles), counting its first step there and one more per limb step
/// beyond. A pure value type: `InstrumentView` holds one in `@State`.
struct TwoFingerSteps: Equatable, Sendable {
    enum Owner: Equatable, Sendable {
        case pinch, twist
    }

    /// How far a twist must turn before it counts, in degrees.
    static let rotationThreshold: Double = 15

    private(set) var owner: Owner?
    private(set) var pinchSteps = 0
    private(set) var twistSteps = 0
    /// The angle at which the twist took the gesture.
    private var twistStart: Double = 0

    /// Levels to add to the focus the gesture began on (+: finer).
    var steps: Int { pinchSteps + twistSteps }

    /// The pinch has reached `magnification`; `ratio` is the scale of one
    /// level (the first counter ring over the hero ring, about 1.37).
    mutating func pinch(magnification: Double, ratio: Double) {
        guard owner != .twist, ratio > 1 else { return }
        let steps = Int((log(max(magnification, 0.01)) / log(ratio)).rounded())
        if owner == nil, steps != 0 { owner = .pinch }
        if owner == .pinch { pinchSteps = steps }
    }

    /// The twist has reached `degrees` (clockwise positive); `step` is the
    /// limb's angle per letter.
    mutating func twist(degrees: Double, step: Double) {
        guard owner != .pinch, step > 0 else { return }
        if owner == nil {
            guard abs(degrees) >= TwoFingerSteps.rotationThreshold else { return }
            owner = .twist
            twistStart = degrees
        }
        let first = twistStart > 0 ? 1 : -1
        twistSteps = first + Int(((degrees - twistStart) / step).rounded())
    }
}
