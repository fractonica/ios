import SwiftUI

/// The durations of DESIGN.md §10. Nothing blinks, bounces or pulses; with
/// Reduce Motion every one of these becomes a cut (`nil` animation).
enum Motion {
    /// Scale change: the zoom between focus levels and the limb's turn.
    case zoom
    /// Screen change.
    case screen
    /// The Earth annotations appearing or leaving.
    case mode
    /// A phase glyph changing state: redrawn, cross-faded.
    case glyph
    /// A bezel word handing the light to the next threshold.
    case threshold
    /// A bead turning from hollow to bone.
    case bead

    /// The animation, or `nil` (a cut) when Reduce Motion is on.
    func animation(reduceMotion: Bool) -> Animation? {
        guard !reduceMotion else { return nil }
        switch self {
        case .zoom: return .easeInOut(duration: 0.32)
        case .screen: return .easeInOut(duration: 0.24)
        case .mode: return .easeInOut(duration: 0.2)
        case .glyph: return .linear(duration: 0.12)
        case .threshold: return .linear(duration: 0.6)
        case .bead: return .linear(duration: 0.4)
        }
    }
}
