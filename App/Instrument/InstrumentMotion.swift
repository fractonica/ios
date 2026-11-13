import SwiftUI
import FractonicaKit

/// The animated state of the instrument (DESIGN.md §10), as one vector that
/// SwiftUI interpolates and `MotionCanvas` hands to the drawing every frame.
///
/// `zoom` is a position on the ladder of focus levels: 6 is the Helion's
/// instrument, 6.5 is half way through the zoom from the Helion to θ. The
/// other three are clocks that advance by one per change (see ``Clock``).
struct InstrumentMotion: VectorArithmetic, Sendable {
    var zoom: Double = 0
    var glyph: Double = 0
    var threshold: Double = 0
    var bead: Double = 0
    /// 0 pure ... 1 Earth.
    var earth: Double = 0

    static let zero = InstrumentMotion()

    static func + (lhs: InstrumentMotion, rhs: InstrumentMotion) -> InstrumentMotion {
        InstrumentMotion(zoom: lhs.zoom + rhs.zoom, glyph: lhs.glyph + rhs.glyph,
                         threshold: lhs.threshold + rhs.threshold, bead: lhs.bead + rhs.bead, earth: lhs.earth + rhs.earth)
    }

    static func - (lhs: InstrumentMotion, rhs: InstrumentMotion) -> InstrumentMotion {
        InstrumentMotion(zoom: lhs.zoom - rhs.zoom, glyph: lhs.glyph - rhs.glyph,
                         threshold: lhs.threshold - rhs.threshold, bead: lhs.bead - rhs.bead, earth: lhs.earth - rhs.earth)
    }

    mutating func scale(by factor: Double) {
        zoom *= factor
        glyph *= factor
        threshold *= factor
        bead *= factor
        earth *= factor
    }

    var magnitudeSquared: Double {
        zoom * zoom + glyph * glyph + threshold * threshold + bead * bead + earth * earth
    }
}

/// A cross-fade that can be restarted any number of times: every change adds
/// one to `target` and animates `value` towards it; the progress of the
/// latest change is how far `value` has come through the last unit. At rest
/// (and before any change) the progress is 1: the new state is fully shown.
struct FadeClock: Equatable {
    private(set) var target = 0.0

    /// Starts a new fade and returns the value to animate to.
    mutating func advance() -> Double {
        target += 1
        return target
    }

    /// Progress of the latest fade for an animated `value`, 0...1.
    func progress(at value: Double) -> Double {
        min(max(value - (target - 1), 0), 1)
    }
}

/// What can change in steps on the instrument, and so cross-fades instead of
/// jumping: the centre glyphs, the next threshold, the count of lit beads.
struct InstrumentSteps: Equatable {
    var focus: Level
    var digits: [Int]
    var quarter: Quarter?
    var beads: Int

    init(_ reading: InstrumentReading) {
        focus = reading.focus
        digits = reading.live?.odometer.digits ?? []
        quarter = reading.live?.cycle.quarter
        beads = reading.beadsLit
    }
}
