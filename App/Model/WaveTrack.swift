import FractonicaKit

/// The cycles of one level laid one after another along a line (the wave,
/// the Sun's lane of Helions), and the two conversions a drawing of them
/// needs: how far along the line an instant is, and which instant a distance
/// along the line is. Distances are in **cycles of the level** (the view
/// multiplies by its points per cycle).
///
/// A place on the line is a cycle's index and its phase, both the core's:
/// `frc_cycle_at` reads them at an instant, `frc_time_at_phase` gives the
/// instant of a phase (the inverse the core provides for a scrub). The phase
/// is linear in POSITION, not in time, so the line agrees with the drawing
/// of the wave even across an eclipse inside a coarse cycle. Its grain is
/// the phase's, 2⁻³² of a cycle: 4 µs of a Helion, half a second of an Alpha.
enum WaveTrack {
    /// 2³², the phase's denominator (`frc_frac_t`).
    private static let phaseScale = 4_294_967_296.0

    /// How many cycles of `level` lie from `origin` to `other` along the
    /// line: negative when `other` is earlier. `nil` when either is outside
    /// the catalogue.
    static func cycles(in clock: Catalogue, level: Level, from origin: Instant, to other: Instant) -> Double? {
        guard let here = try? clock.cycle(level, at: origin), let there = try? clock.cycle(level, at: other) else {
            return nil
        }
        let whole = there.index >= here.index
            ? Double(there.index - here.index) : -Double(here.index - there.index)
        return whole + there.phase.value - here.phase.value
    }

    /// The instant `cycles` cycles of `level` along the line from `origin`
    /// (negative: earlier), kept inside the catalogue (design/README.md
    /// ruling 7: time travel clamps).
    static func instant(in clock: Catalogue, level: Level, from origin: Instant, movedBy cycles: Double) -> Instant {
        guard cycles.isFinite, let here = try? clock.cycle(level, at: origin) else { return clock.clamped(origin) }
        guard cycles != 0 else { return origin }
        // The place counted from the start of the cycle `origin` is in.
        let place = here.phase.value + cycles
        let whole = place.rounded(.down)
        let index: UInt64
        if whole < 0 {
            guard -whole < 1e18, UInt64(-whole) <= here.index else { return clock.first }
            index = here.index - UInt64(-whole)
        } else {
            guard whole < 1e18 else { return clock.last }
            let (sum, overflow) = here.index.addingReportingOverflow(UInt64(whole))
            guard !overflow, sum < clock.cycleCount(level) else { return clock.last }
            index = sum
        }
        let phase = Fraction(raw: UInt32(min(max((place - whole) * phaseScale, 0), phaseScale - 1)))
        // A phase of the last (clipped) cycle beyond the closing instant has no instant.
        guard let moved = clock.instant(level, index: index, atPhase: phase) else { return clock.last }
        return clock.clamped(moved)
    }
}
