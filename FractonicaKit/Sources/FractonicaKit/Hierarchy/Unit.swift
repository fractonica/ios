import CFractonica

/// The nine named units, longest first (SPEC §15.1, `frc_unit_t`).
///
/// Alpha, Beta, Gamma, Delta are the major periods (said in words); Nuclide,
/// Helion, Preon, Flavon, Blink the minor units (said in letters and counts).
/// Dates and spans are written over this ladder.
public enum Unit: Hashable, Sendable, CaseIterable, Comparable {
    case alpha, beta, gamma, delta, nuclide, helion, preon, flavon, blink

    /// The unit as the core takes it.
    var raw: frc_unit_t {
        switch self {
        case .alpha: return FRC_UNIT_ALPHA
        case .beta: return FRC_UNIT_BETA
        case .gamma: return FRC_UNIT_GAMMA
        case .delta: return FRC_UNIT_DELTA
        case .nuclide: return FRC_UNIT_NUCLIDE
        case .helion: return FRC_UNIT_HELION
        case .preon: return FRC_UNIT_PREON
        case .flavon: return FRC_UNIT_FLAVON
        case .blink: return FRC_UNIT_BLINK
        }
    }

    /// `nil` for a value that is not one of the nine units.
    init?(raw: frc_unit_t) {
        guard let unit = Unit.allCases.first(where: { $0.raw == raw }) else { return nil }
        self = unit
    }

    /// The level the unit sits on: 0 1 2 3 4 6 8 10 12 (`frc_unit_level`).
    public var level: Level { Level(unchecked: Int(frc_unit_level(raw))) }

    /// Exact length in Blinks: 1 for the Blink, 25 for the Flavon, 58 500 for
    /// the Helion ... (`frc_unit_blinks`).
    public var blinks: UInt64 { frc_unit_blinks(raw) }

    /// How many of the next finer unit make one of this unit: 36 Preons in a
    /// Helion; 0 for the Blink (`frc_unit_parts`).
    public var parts: Int { Int(frc_unit_parts(raw)) }

    /// The next finer unit; `nil` for the Blink.
    public var finer: Unit? {
        let all = Unit.allCases
        let next = all.index(after: all.firstIndex(of: self)!)
        return next < all.endIndex ? all[next] : nil
    }

    /// The next coarser unit; `nil` for Alpha.
    public var coarser: Unit? {
        let all = Unit.allCases
        let index = all.firstIndex(of: self)!
        return index > all.startIndex ? all[all.index(before: index)] : nil
    }

    /// The Greek letter, e.g. `"η"` (`frc_format_unit_symbol`).
    public var symbol: String {
        CoreText.infallible { frc_format_unit_symbol(raw, $0, $1) }
    }

    /// The word, e.g. `"Helion"` (`frc_format_unit_name`).
    public var name: String { name(plural: false) }

    /// `"Helion"` or `"Helions"`.
    public func name(plural: Bool) -> String {
        CoreText.infallible { frc_format_unit_name(raw, plural ? 1 : 0, $0, $1) }
    }
}
