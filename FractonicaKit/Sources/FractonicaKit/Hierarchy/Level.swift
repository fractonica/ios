import CFractonica

/// A rung of the harmonic hierarchy, **zero-based**: level 0 is Alpha, level 6
/// the Helion, level 62 the last rung of the spectral ladder (SPEC §3, §16.1).
///
/// The API always takes levels. The user-facing number is ``depth``
/// (`level + 1`): "depth 7" is level 6 (SPEC pitfall 6).
///
/// Two limits matter:
/// - static facts (name, factor, period, length) exist for all 63 levels;
/// - a reading at an instant (cycle, glyph, odometer) exists for
///   ``isClockLevel`` levels only, 0...21.
///
/// Related: ``Unit`` (the nine named levels), `Ladder/Level+Ladder.swift`
/// (period, frequency, length, band), `Notation/Span.swift` (``span``).
public struct Level: Hashable, Comparable, Sendable, CustomStringConvertible {
    /// 0...62.
    public let index: Int

    /// `nil` unless `index` is 0...62.
    public init?(_ index: Int) {
        guard (0 ..< Level.count).contains(index) else { return nil }
        self.index = index
    }

    /// For values that come from the core or from the constants below.
    init(unchecked index: Int) {
        self.index = index
    }

    /// The level as the core takes it.
    var raw: UInt8 { UInt8(index) }

    // MARK: The set of levels

    /// Number of rungs, 63 (`FRC_LEVEL_COUNT`).
    public static let count = Int(FRC_LEVEL_COUNT)
    /// Every rung, coarsest first.
    public static let all: [Level] = (0 ..< count).map(Level.init(unchecked:))
    /// The deepest level the clock reads at an instant, 21 (`FRC_CLOCK_MAX_LEVEL`).
    public static let clockMax = Level(unchecked: Int(FRC_CLOCK_MAX_LEVEL))
    /// Levels 0...21, the ones with cycles, glyphs and odometers.
    public static let clockLevels: [Level] = Array(all[0 ... clockMax.index])

    public static let alpha = Unit.alpha.level
    public static let beta = Unit.beta.level
    public static let gamma = Unit.gamma.level
    public static let delta = Unit.delta.level
    /// ε, level 4.
    public static let nuclide = Unit.nuclide.level
    /// η, level 6: the basic reading and the solar-sync level.
    public static let helion = Unit.helion.level
    /// ι, level 8.
    public static let preon = Unit.preon.level
    /// λ, level 10.
    public static let flavon = Unit.flavon.level
    /// ν, level 12: the finest unit.
    public static let blink = Unit.blink.level

    // MARK: Neighbours

    /// The user-facing number of the rung: `index + 1` (SPEC §3).
    public var depth: Int { index + 1 }
    /// The next coarser level; `nil` for Alpha.
    public var parent: Level? { Level(index - 1) }
    /// The next finer level; `nil` for the last rung.
    public var child: Level? { Level(index + 1) }
    /// The level `distance` rungs finer (negative: coarser); `nil` off the ladder.
    public func offset(by distance: Int) -> Level? { Level(index + distance) }

    /// Whether the clock reads this level at an instant (levels 0...21).
    public var isClockLevel: Bool { index <= Level.clockMax.index }

    // MARK: Facts from the core

    /// Greek name (SPEC §3.4): `"α"` ... `"ω"`, then `"α1"` ... `"ο2"`.
    public var name: String {
        CoreText.infallible { frc_format_level_name(raw, $0, $1) }
    }

    /// The letter's English word: `"Alpha"` ... `"Omega"`, then `"Alpha1"` ...
    public var word: String {
        CoreText.infallible { frc_format_level_word(raw, $0, $1) }
    }

    /// What the level is in the notation: major, unit, between or sub-Blink.
    public var kind: LevelKind {
        LevelKind(raw: frc_level_kind(raw))
    }

    /// How many cycles of the next finer level one cycle of this level
    /// contains (`frc_factor`): 5, 13, 5, 5, 7, 11, 9, 4, repeating.
    public var factor: Int { Int(frc_factor(raw)) }

    /// How many cycles of this level one cycle of its parent contains
    /// (`frc_siblings`); 0 for Alpha, which has no parent.
    public var siblings: Int { Int(frc_siblings(raw)) }

    /// P(level): cycles of this level per 4 Saros (`frc_prefix`). `nil` when
    /// the value does not fit 64 bits (levels above 22): use ``prefixText``.
    public var prefix: UInt64? {
        let value = frc_prefix(raw)
        return value == 0 ? nil : value
    }

    /// P(level) as an exact decimal string, any level (`frc_format_prefix`).
    public var prefixText: String {
        CoreText.infallible { frc_format_prefix(raw, $0, $1) }
    }

    /// The named unit that sits on this level; `nil` for a level that is not a
    /// unit (ζ θ κ μ and everything finer than the Blink).
    public var unit: Unit? {
        let value = frc_unit_of_level(raw)
        guard value >= 0 else { return nil }
        return Unit(raw: frc_unit_t(UInt32(value)))
    }

    public static func < (lhs: Level, rhs: Level) -> Bool { lhs.index < rhs.index }

    /// Developer-facing, e.g. `"Level 6 (η)"`.
    public var description: String { "Level \(index) (\(name))" }
}

/// What a level is in the notation of SPEC §15 (`frc_level_kind_t`).
public enum LevelKind: Hashable, Sendable, CaseIterable {
    /// α β γ δ: said in words, with a fracton ordinal and a quarter word.
    case major
    /// ε η ι λ ν: the minor units, said in letters and counts.
    case unit
    /// ζ θ κ μ: levels of the hierarchy that are not units ("between").
    case between
    /// ξ and finer: shorter than a Blink.
    case subBlink

    /// The kind in the words of design ruling 4 (`frc_format_level_kind`):
    /// `"major"`, `"unit"`, `"between"`, `"sub-Blink"`.
    public var text: String {
        CoreText.infallible { frc_format_level_kind(raw, $0, $1) }
    }

    var raw: frc_level_kind_t {
        switch self {
        case .major: return FRC_KIND_MAJOR
        case .unit: return FRC_KIND_UNIT
        case .between: return FRC_KIND_BETWEEN
        case .subBlink: return FRC_KIND_SUB
        }
    }

    init(raw: frc_level_kind_t) {
        switch raw {
        case FRC_KIND_MAJOR: self = .major
        case FRC_KIND_UNIT: self = .unit
        case FRC_KIND_BETWEEN: self = .between
        default: self = .subBlink
        }
    }
}
