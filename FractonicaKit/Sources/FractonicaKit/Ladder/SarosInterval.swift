import CFractonica

/// The length of a Saros interval, `numerator / denominator` **milliseconds**
/// (`frc_interval_t`). The spectral ladder is laid from one: every period,
/// frequency and length in Earth units depends on which interval the caller
/// chooses (SPEC §16.1). Pure-mode wordings do not need one.
///
/// - ``reference``: the interval SPEC's tables use. The default everywhere.
/// - ``Catalogue/meanInterval``: the series' mean; its level 12 is the Blink of §15.5.
/// - ``Catalogue/interval(at:)``: the interval that holds an instant.
public struct SarosInterval: Hashable, Sendable {
    public let numerator: UInt64
    public let denominator: UInt64

    init(_ raw: frc_interval_t) {
        numerator = raw.num
        denominator = raw.den
    }

    var raw: frc_interval_t { frc_interval_t(num: numerator, den: denominator) }

    /// An interval of `numerator / denominator` milliseconds. The ladder
    /// functions refuse an interval with a zero part.
    public init(numerator: UInt64, denominator: UInt64 = 1) {
        self.numerator = numerator
        self.denominator = denominator
    }

    /// The 2010 – 2028 interval of Saros 141, 568 972 877 000 ms
    /// (`FRC_INTERVAL_REFERENCE_MS`): the one SPEC's tables use.
    public static let reference = SarosInterval(numerator: FRC_INTERVAL_REFERENCE_MS)

    /// A nominal scale from any Alpha length in milliseconds
    /// (`frc_interval_of_alpha_ms`: interval = alpha / 4).
    public init(alphaMilliseconds: UInt64) {
        self.init(frc_interval_of_alpha_ms(alphaMilliseconds))
    }
}

extension Catalogue {
    /// The Saros interval that holds `instant` (`frc_interval_at`); the
    /// closing instant belongs to the last interval.
    /// - Throws: ``FractonicaError/outOfRange`` outside the catalogue.
    public func interval(at instant: Instant) throws -> SarosInterval {
        SarosInterval(try read(into: frc_interval_t()) { frc_interval_at($0, instant.microseconds, $1) })
    }

    /// The series' mean interval, not reduced to lowest terms
    /// (`frc_interval_mean`; Saros 141: 39 259 007 522 784 / 69 ms).
    public var meanInterval: SarosInterval {
        SarosInterval(withRaw { frc_interval_mean($0) })
    }
}
