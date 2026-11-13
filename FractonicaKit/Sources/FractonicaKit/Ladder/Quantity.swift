import CFractonica

/// An exact-to-17-digits decimal value, `mantissa × 10^exponent`
/// (`frc_sci_t`): a period in seconds, a frequency in hertz or a length in
/// metres, rounded half-to-even once from the exact rational.
///
/// **Earth mode only.** These are Earth units; pure mode says the same facts
/// as spans and rates (`Notation/Span.swift`, `Notation/Rate.swift`,
/// `Notation/PureWording.swift`).
public struct Quantity: Hashable, Sendable {
    /// Exactly 17 significant digits: `10^16 <= mantissa < 10^17`.
    public let mantissa: UInt64
    /// The power of ten.
    public let exponent: Int

    init(_ raw: frc_sci_t) {
        mantissa = raw.mantissa
        exponent = Int(raw.exp10)
    }

    /// A value of the caller's own, to be written by the core's formatter
    /// (``text(_:digits:)``): a device's rate, a band's edge. The mantissa is
    /// brought to the 17 significant digits `frc_sci_t` requires by moving
    /// the power of ten (`Quantity(digits: 48, exponent: 3)` is 48 kHz), so
    /// the value is unchanged.
    /// - Returns: `nil` for a zero mantissa or one of more than 17 digits.
    public init?(digits: UInt64, exponent: Int) {
        guard digits > 0, digits < 100_000_000_000_000_000 else { return nil }
        var mantissa = digits
        var exponent = exponent
        while mantissa < 10_000_000_000_000_000 {
            mantissa *= 10
            exponent -= 1
        }
        self.mantissa = mantissa
        self.exponent = exponent
    }

    private var raw: frc_sci_t { frc_sci_t(mantissa: mantissa, exp10: Int16(clamping: exponent)) }

    /// The nearest double (`frc_sci_to_double`). For plotting on a
    /// logarithmic rule; text comes from ``text(_:digits:)``.
    public var value: Double {
        var raw = self.raw
        return frc_sci_to_double(&raw)
    }

    /// The value the way SPEC §16.1 tabulates it (`frc_format_quantity`):
    /// `"310.9 ms"`, `"5.052 h"`, `"72.12 y"`, `"3.216 Hz"`, `"93.21 Mm"`,
    /// and outside the SI prefixes `"2.454 × 10⁻²⁵ s"`.
    /// - Parameter digits: significant digits, 1...9.
    public func text(_ kind: QuantityKind, digits: Int = 4) -> String {
        var raw = self.raw
        return CoreText.infallible { frc_format_quantity(&raw, kind.raw, Quantity.clampDigits(digits), $0, $1) }
    }

    /// The core takes 1...9 significant digits (and reads 0 as 4).
    static func clampDigits(_ digits: Int) -> UInt8 {
        UInt8(min(max(digits, 1), 9))
    }
}

/// What a ``Quantity`` measures; it selects the unit ladder of its text
/// (`frc_quantity_t`).
public enum QuantityKind: Hashable, Sendable, CaseIterable {
    /// Seconds: ys ... ms, s, min, h, d, y.
    case time
    /// Hertz: pHz ... YHz.
    case frequency
    /// Metres: ym ... Pm.
    case length

    var raw: frc_quantity_t {
        switch self {
        case .time: return FRC_QUANTITY_TIME
        case .frequency: return FRC_QUANTITY_FREQUENCY
        case .length: return FRC_QUANTITY_LENGTH
        }
    }
}
