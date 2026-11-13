import CFractonica

/// An exact position in Saros units: `ordinal + numerator / denominator`
/// (the core's `frc_position_t`, SPEC §2.2).
///
/// Eclipse `k` is position `k`; between eclipses position is linear in time.
/// The app rarely needs it: cycles, dates and spans are read directly.
public struct Position: Hashable, Sendable {
    /// The eclipse at or before the instant.
    public let ordinal: Int
    /// Time elapsed inside that Saros interval, in microseconds.
    public let numerator: UInt64
    /// Length of that Saros interval, in microseconds.
    public let denominator: UInt64

    init(_ raw: frc_position_t) {
        ordinal = Int(raw.ordinal)
        numerator = raw.num
        denominator = raw.den
    }

    /// The position as a number, about 1e-14 Saros of error
    /// (`frc_position_to_double`). Display only.
    public var value: Double {
        var raw = frc_position_t(ordinal: UInt16(ordinal), num: numerator, den: denominator)
        return frc_position_to_double(&raw)
    }
}

extension Catalogue {
    /// The position of `instant` (`frc_position_at`). The closing instant
    /// reads as one microsecond before it.
    /// - Throws: ``FractonicaError/outOfRange`` outside the catalogue.
    public func position(at instant: Instant) throws -> Position {
        Position(try read(into: frc_position_t()) { frc_position_at($0, instant.microseconds, $1) })
    }

    /// The instant of the rational position `numerator / denominator` Saros
    /// units: the first microsecond at or after it (`frc_time_at_position`).
    /// `nil` beyond the catalogue or for a zero denominator.
    public func instant(atPosition numerator: UInt64, over denominator: UInt64) -> Instant? {
        Instant(raw: withRaw { frc_time_at_position($0, numerator, denominator) })
    }
}
