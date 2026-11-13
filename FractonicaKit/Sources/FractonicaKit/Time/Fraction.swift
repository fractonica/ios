import CFractonica

/// A fraction of a whole in unsigned 0.32 fixed point (the core's
/// `frc_frac_t`): `raw == 0` is 0 and `2^32` would be 1.
///
/// Used for the phase of a cycle or sync (how much of it is done) and for the
/// part of a Blink in a ``Span``. It is for drawing (how much of an arc is
/// lit). Decisions use indices, quarters and instants, never a phase
/// (core/AGENTS.md, "Common mistakes").
public struct Fraction: Hashable, Comparable, Sendable {
    /// The 32 fraction bits.
    public var raw: UInt32

    public init(raw: UInt32) {
        self.raw = raw
    }

    public static let zero = Fraction(raw: 0)
    /// One half (`FRC_FRAC_HALF`).
    public static let half = Fraction(raw: FRC_FRAC_HALF)
    /// One quarter (`FRC_FRAC_QUARTER`).
    public static let quarter = Fraction(raw: FRC_FRAC_QUARTER)

    /// The fraction as a number in `0 ..< 1` (`frc_frac_to_double`, exact).
    public var value: Double { frc_frac_to_double(raw) }

    public static func < (lhs: Fraction, rhs: Fraction) -> Bool {
        lhs.raw < rhs.raw
    }
}
