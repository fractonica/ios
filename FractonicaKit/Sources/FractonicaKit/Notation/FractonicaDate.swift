import CFractonica

/// A moment said in Fractonica terms (`frc_date_t`, SPEC §15.3): ordinals of
/// the major periods and the Nuclide, the Helion **numbered from 1**, and
/// **counts from 0** of completed Preons, Flavons and Blinks.
///
///     let date = try Catalogue.saros141.date(at: instant)
///     date.text(.full)                      // "Alpha Hexafracton Valley, …, ε#5 34η 29ι 21λ 3ν"
///     date.text(.short, finest: .preon)     // "Delta Trifracton End ε#5 34η 29ι"
///     date.stamp                            // "α#6 β#4 γ#9 δ#3 ε#5 34η 29ι 21λ 3ν"
///
/// A date names a Blink; ``Catalogue/instant(of:)`` gives its first microsecond.
public struct FractonicaDate: Hashable, Sendable {
    /// 1 ... Alphas in the catalogue (global).
    public var alpha: Int
    /// 1...5 in its Alpha.
    public var beta: Int
    /// 1...13 in its Beta.
    public var gamma: Int
    /// 1...5 in its Gamma.
    public var delta: Int
    /// 1...5: the Nuclide in its Delta.
    public var epsilon: Int
    /// 1...77: the Helion in its Nuclide.
    public var eta: Int
    /// 0...35: Preons completed in the Helion.
    public var iota: Int
    /// 0...64: Flavons completed in the Preon.
    public var lambda: Int
    /// 0...24: Blinks completed in the Flavon.
    public var nu: Int
    /// The quarters the four major periods are in (the words after their
    /// names). ``Catalogue/instant(of:)`` ignores them: the counts imply them.
    public var alphaQuarter: Quarter
    public var betaQuarter: Quarter
    public var gammaQuarter: Quarter
    public var deltaQuarter: Quarter

    public init(
        alpha: Int, beta: Int, gamma: Int, delta: Int, epsilon: Int,
        eta: Int = 1, iota: Int = 0, lambda: Int = 0, nu: Int = 0,
        alphaQuarter: Quarter = .peak, betaQuarter: Quarter = .peak,
        gammaQuarter: Quarter = .peak, deltaQuarter: Quarter = .peak
    ) {
        self.alpha = alpha
        self.beta = beta
        self.gamma = gamma
        self.delta = delta
        self.epsilon = epsilon
        self.eta = eta
        self.iota = iota
        self.lambda = lambda
        self.nu = nu
        self.alphaQuarter = alphaQuarter
        self.betaQuarter = betaQuarter
        self.gammaQuarter = gammaQuarter
        self.deltaQuarter = deltaQuarter
    }

    init(_ raw: frc_date_t) {
        alpha = Int(raw.alpha)
        beta = Int(raw.beta)
        gamma = Int(raw.gamma)
        delta = Int(raw.delta)
        epsilon = Int(raw.epsilon)
        eta = Int(raw.eta)
        iota = Int(raw.iota)
        lambda = Int(raw.lambda)
        nu = Int(raw.nu)
        alphaQuarter = Quarter(field: raw.quarter.0)
        betaQuarter = Quarter(field: raw.quarter.1)
        gammaQuarter = Quarter(field: raw.quarter.2)
        deltaQuarter = Quarter(field: raw.quarter.3)
    }

    /// The date as the core takes it. A field that does not fit its C type is
    /// clamped; the core then refuses it as out of its range.
    var raw: frc_date_t {
        frc_date_t(
            alpha: UInt16(clamping: alpha), beta: UInt8(clamping: beta), gamma: UInt8(clamping: gamma),
            delta: UInt8(clamping: delta), epsilon: UInt8(clamping: epsilon), eta: UInt8(clamping: eta),
            iota: UInt8(clamping: iota), lambda: UInt8(clamping: lambda), nu: UInt8(clamping: nu),
            quarter: (
                UInt8(alphaQuarter.raw.rawValue), UInt8(betaQuarter.raw.rawValue),
                UInt8(gammaQuarter.raw.rawValue), UInt8(deltaQuarter.raw.rawValue)
            )
        )
    }

    // MARK: Fields by unit (for the stamp's tumblers)

    /// The field of `unit`: an ordinal from 1 for Alpha ... Nuclide and the
    /// Helion, a count from 0 for Preon, Flavon and Blink.
    public subscript(unit: Unit) -> Int {
        get {
            switch unit {
            case .alpha: return alpha
            case .beta: return beta
            case .gamma: return gamma
            case .delta: return delta
            case .nuclide: return epsilon
            case .helion: return eta
            case .preon: return iota
            case .flavon: return lambda
            case .blink: return nu
            }
        }
        set {
            switch unit {
            case .alpha: alpha = newValue
            case .beta: beta = newValue
            case .gamma: gamma = newValue
            case .delta: delta = newValue
            case .nuclide: epsilon = newValue
            case .helion: eta = newValue
            case .preon: iota = newValue
            case .flavon: lambda = newValue
            case .blink: nu = newValue
            }
        }
    }

    /// The quarter of a major period; `nil` for a minor unit.
    public func quarter(of unit: Unit) -> Quarter? {
        switch unit {
        case .alpha: return alphaQuarter
        case .beta: return betaQuarter
        case .gamma: return gammaQuarter
        case .delta: return deltaQuarter
        default: return nil
        }
    }

    // MARK: Text

    /// The date written out (`frc_format_date`).
    /// - Parameters:
    ///   - form: see ``DateForm``.
    ///   - finest: the last unit shown, `.delta` ... `.blink` (a coarser value
    ///     is treated as `.delta`).
    public func text(_ form: DateForm = .full, finest: Unit = .blink) -> String {
        var raw = self.raw
        return CoreText.infallible { frc_format_date(&raw, form.raw, finest.raw, $0, $1) }
    }

    /// The stamp (SPEC §15.3): letters down to the Blink,
    /// `"α#6 β#4 γ#9 δ#3 ε#5 34η 29ι 21λ 3ν"`. It identifies a moment exactly
    /// and reads back with ``init(parsing:context:)``.
    public var stamp: String { text(.letters, finest: .blink) }

    /// One term of the stamp, exactly as the stamp writes it
    /// (`frc_format_date_term`): `"α#6"`, `"ε#5"` for Alpha ... Nuclide,
    /// `"34η"`, `"29ι"`, `"3ν"` for Helion ... Blink. The quarters are not read.
    public func term(_ unit: Unit) -> String {
        var raw = self.raw
        return CoreText.infallible { frc_format_date_term(&raw, unit.raw, $0, $1) }
    }

    /// The nine terms of the stamp, Alpha first (``term(_:)`` of every unit):
    /// joined by single spaces they are ``stamp``.
    public var terms: [String] { Unit.allCases.map(term) }

    // MARK: Parsing

    /// Reads a date from any form ``text(_:finest:)`` writes, and from plain
    /// ASCII shorthand (`"a#6 b#4 g#9 d#3 e#5 34h 29i"`); see `frc_parse_date`
    /// for the rules. A leading Pentad and quarter words are skipped. The
    /// quarters of the result are `.peak`: pass it through
    /// ``Catalogue/instant(of:)`` and ``Catalogue/date(at:)`` to normalise.
    /// - Parameter context: supplies the parts a short form leaves out at the
    ///   coarse end; `nil` requires a full date.
    /// - Throws: ``FractonicaError/unparsable`` for text that is not a date;
    ///   ``FractonicaError/invalidArgument`` for a field out of range.
    public init(parsing text: String, context: FractonicaDate? = nil) throws {
        self = try FractonicaDate.parse(text, context: context).date
    }

    /// The same, also returning the finest unit that was written.
    public static func parse(
        _ text: String, context: FractonicaDate? = nil
    ) throws -> (date: FractonicaDate, finest: Unit) {
        var out = frc_date_t()
        var finest = FRC_UNIT_BLINK
        let status: frc_status_t
        if let context {
            var rawContext = context.raw
            status = frc_parse_date(text, &rawContext, &out, &finest)
        } else {
            status = frc_parse_date(text, nil, &out, &finest)
        }
        try check(status)
        return (FractonicaDate(out), Unit(raw: finest) ?? .blink)
    }
}

/// How a date is written (`frc_date_form_t`, SPEC §15.3).
public enum DateForm: Hashable, Sendable, CaseIterable {
    /// `Alpha Hexafracton Valley, Beta Tetrafracton Valley, Gamma Nonafracton Valley, Delta Trifracton End, ε#5 34η 29ι`
    case full
    /// `Delta Trifracton End ε#5 34η 29ι`
    case short
    /// `α#6 β#4 γ#9 δ#3 ε#5 34η 29ι` (down to the Blink: the stamp)
    case letters
    /// `δ#3 ε#5 34η 29ι`
    case shortLetters

    var raw: frc_date_form_t {
        switch self {
        case .full: return FRC_DATE_FULL
        case .short: return FRC_DATE_SHORT
        case .letters: return FRC_DATE_LETTERS
        case .shortLetters: return FRC_DATE_SHORT_LETTERS
        }
    }
}

extension Catalogue {
    /// The date at `instant` (`frc_date_at`).
    /// - Throws: ``FractonicaError/outOfRange`` outside the catalogue.
    public func date(at instant: Instant) throws -> FractonicaDate {
        FractonicaDate(try read(into: frc_date_t()) { frc_date_at($0, instant.microseconds, $1) })
    }

    /// The first microsecond of the Blink a date names (`frc_date_to_time`):
    /// the inverse of ``date(at:)`` down to the Blink.
    /// - Throws: ``FractonicaError/invalidArgument`` for a field outside its
    ///   fixed range; ``FractonicaError/outOfRange`` for a well-formed date
    ///   that is not in the catalogue.
    public func instant(of date: FractonicaDate) throws -> Instant {
        var raw = date.raw
        let time = try read(into: frc_time_t(0)) { frc_date_to_time($0, &raw, $1) }
        guard let instant = Instant(raw: time) else { throw FractonicaError.outOfRange }
        return instant
    }
}
