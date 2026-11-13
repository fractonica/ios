import CFractonica

/// A time-lapse preset (`frc_rate_t`, SPEC §15.5): a whole count of a unit
/// shown per Blink of real time. There are eleven, from real time up to a
/// Gamma per Blink.
public struct TimeLapseRate: Hashable, Sendable {
    /// The unit shown per Blink.
    public let unit: Unit
    /// How many of it; 0 for real time.
    public let count: Int
    /// Displayed time per real time: 1, 5, 25, 325, 1 625 ...
    public let factor: UInt64

    init(_ raw: frc_rate_t) {
        unit = Unit(raw: frc_unit_t(UInt32(raw.unit))) ?? .blink
        count = Int(raw.count)
        factor = raw.factor
    }

    /// The eleven presets in order: real time, 5ν, λ, 13λ, ι, 4ι, η, 11η, ε,
    /// δ, γ per Blink (`frc_rate_preset`).
    public static let presets: [TimeLapseRate] = (0 ..< UInt8(FRC_RATE_COUNT)).compactMap { index in
        var raw = frc_rate_t()
        return frc_rate_preset(index, &raw) == FRC_OK ? TimeLapseRate(raw) : nil
    }

    /// Real time: one Blink per Blink.
    public static var realTime: TimeLapseRate { presets[0] }

    /// Whether this is real time.
    public var isRealTime: Bool { count == 0 }

    /// `"real time"`, `"4ι per Blink"` (`frc_format_rate`).
    public var text: String {
        var raw = frc_rate_t(unit: UInt8(unit.raw.rawValue), count: UInt8(clamping: count), factor: factor)
        return CoreText.infallible { frc_format_rate(&raw, $0, $1) }
    }
}

/// A frequency said in cycles per Blink, **pB** (SPEC §15.5), as the exact
/// ratio `numerator / denominator`. This is how pure mode says a rate.
public struct BlinkRate: Hashable, Sendable {
    public let numerator: UInt64
    public let denominator: UInt64

    public init(numerator: UInt64, denominator: UInt64) {
        self.numerator = numerator
        self.denominator = denominator
    }

    /// `"7 pB"`, `"2 772 pB"`, `"34.2 pB"`, `"0.75 pB"`; a rate below 1 pB
    /// whose reciprocal is whole, and any rate slower than 1 per 25 Blinks,
    /// `"1 per N Blinks"` (`"1 per 5 Blinks"`, `"1 per 58 500 Blinks"`;
    /// design ruling 3); `"—"` for a zero part (`frc_format_per_blink`).
    public var text: String {
        CoreText.infallible { frc_format_per_blink(numerator, denominator, $0, $1) }
    }
}

extension Level {
    /// The true rate of this level in cycles per Blink, exact and reduced
    /// (`frc_level_per_blink`): ξ 7, ο 77, π 693, ρ 2 772; Helion 1 / 58 500.
    /// - Throws: ``FractonicaError/overflow`` when the value does not fit
    ///   64 bits (levels above 35).
    public func cyclesPerBlink() throws -> BlinkRate {
        var numerator: UInt64 = 0
        var denominator: UInt64 = 0
        try check(frc_level_per_blink(raw, &numerator, &denominator))
        return BlinkRate(numerator: numerator, denominator: denominator)
    }
}
