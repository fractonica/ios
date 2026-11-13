import CFractonica

// The spectral ladder (SPEC §16): what one cycle of a level IS in Earth units,
// for all 63 levels. Every function takes the Saros interval the ladder is
// laid from, `.reference` (SPEC's tables) unless the caller says otherwise.
//
// EARTH MODE ONLY: seconds, hertz and metres never appear in pure mode. The
// pure wordings of the same facts are `Level.span`, `Level.cyclesPerBlink()`
// and Notation/PureWording.swift.

extension Level {
    // MARK: Exact values (17 digits)

    /// T(L), the period of one cycle in seconds (`frc_period`).
    /// - Throws: ``FractonicaError/invalidArgument`` for an interval with a zero part.
    public func period(_ interval: SarosInterval = .reference) throws -> Quantity {
        var out = frc_sci_t()
        try check(frc_period(raw, interval.raw, &out))
        return Quantity(out)
    }

    /// f(L), the frequency in hertz (`frc_frequency`).
    public func frequency(_ interval: SarosInterval = .reference) throws -> Quantity {
        var out = frc_sci_t()
        try check(frc_frequency(raw, interval.raw, &out))
        return Quantity(out)
    }

    /// The distance covered in one period at `speed`, in metres (`frc_length`).
    public func length(_ interval: SarosInterval = .reference, speed: Speed = .light) throws -> Quantity {
        var out = frc_sci_t()
        try check(frc_length(raw, interval.raw, speed.raw, &out))
        return Quantity(out)
    }

    // MARK: Text

    /// `"5.052 h"`, `"310.9 ms"`, `"2.454 × 10⁻²⁵ s"` (`frc_format_period`).
    /// Empty for an interval with a zero part.
    /// - Parameter digits: significant digits, 1...9.
    public func periodText(_ interval: SarosInterval = .reference, digits: Int = 4) -> String {
        (try? CoreText.make { frc_format_period(raw, interval.raw, Quantity.clampDigits(digits), $0, $1) }) ?? ""
    }

    /// `"54.98 µHz"`, `"3.216 Hz"` (`frc_format_frequency`).
    public func frequencyText(_ interval: SarosInterval = .reference, digits: Int = 4) -> String {
        (try? CoreText.make { frc_format_frequency(raw, interval.raw, Quantity.clampDigits(digits), $0, $1) }) ?? ""
    }

    /// `"93.21 Mm"`, `"656.3 nm"` (`frc_format_length`).
    public func lengthText(
        _ interval: SarosInterval = .reference, speed: Speed = .light, digits: Int = 4
    ) -> String {
        (try? CoreText.make {
            frc_format_length(raw, interval.raw, speed.raw, Quantity.clampDigits(digits), $0, $1)
        }) ?? ""
    }

    // MARK: Doubles (for a logarithmic rule; never for text)

    /// The period in seconds as the nearest double (`frc_period_seconds`);
    /// 0 for an interval with a zero part.
    public func periodSeconds(_ interval: SarosInterval = .reference) -> Double {
        frc_period_seconds(raw, interval.raw)
    }

    /// The frequency in hertz as the nearest double (`frc_frequency_hz`).
    public func frequencyHertz(_ interval: SarosInterval = .reference) -> Double {
        frc_frequency_hz(raw, interval.raw)
    }

    /// The length in metres as the nearest double (`frc_length_metres`).
    public func lengthMetres(_ interval: SarosInterval = .reference, speed: Speed = .light) -> Double {
        frc_length_metres(raw, interval.raw, speed.raw)
    }

    // MARK: Band

    /// The band the rung's frequency falls in (`frc_band`), compared on the
    /// exact frequency. On the reference interval ζ1 (level 29) is `.visible`.
    public func band(_ interval: SarosInterval = .reference) -> Band {
        Band(raw: frc_band(raw, interval.raw))
    }

    // MARK: Devices that make a rung (SPEC §16.4)

    /// One period counted by a timer that runs at `rate` ticks per second,
    /// rounded once from the exact value (`frc_device_ticks`).
    /// - Throws: ``FractonicaError/refused`` for a period under half a tick;
    ///   ``FractonicaError/overflow`` if the count does not fit 64 bits;
    ///   ``FractonicaError/invalidArgument`` for a zero rate.
    public func deviceTicks(rate: UInt64, interval: SarosInterval = .reference) throws -> UInt64 {
        var ticks: UInt64 = 0
        try check(frc_device_ticks(raw, interval.raw, rate, &ticks))
        return ticks
    }

    /// The phase increment per sample of an oscillator with a phase of `bits`
    /// bits at `rate` samples per second (`frc_device_step`).
    /// - Throws: ``FractonicaError/refused`` for a frequency above half the
    ///   rate or a step that rounds to nothing;
    ///   ``FractonicaError/invalidArgument`` for a zero rate or bits outside 1...64.
    public func deviceStep(rate: UInt64, bits: Int, interval: SarosInterval = .reference) throws -> UInt64 {
        guard let bits = UInt8(exactly: bits) else { throw FractonicaError.invalidArgument }
        var step: UInt64 = 0
        try check(frc_device_step(raw, interval.raw, rate, bits, &step))
        return step
    }
}
