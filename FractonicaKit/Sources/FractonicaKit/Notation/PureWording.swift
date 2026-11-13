import CFractonica

// PURE WORDING: the static facts of a level said without an Earth unit
// (fractonica.h, "Pure wording"; design/README.md, rulings 2 and 3).
//
// Pure mode shows no second, no hertz and no metre. These core functions are
// the texts it shows instead. They need no catalogue and no Saros
// interval. The app shows each text as it comes and never composes its own.
//
//   a count                       Fractonica.count(58500)          "58 500"
//   a cycle counted in a unit     Level.helion.countText(in: .blink)  "58 500ν"
//   a rate in cycles per Blink    level.rateText(digits: 4)        "1.420 × 10¹⁴ pB"
//   a length as a span of light   level.lightSpanText(.bounded)    "24ι 1λ light"
//   the word "light" alone        Fractonica.lightWord             "light"
//   a signed count                Fractonica.count(signed: -3)     "−3"
//   what a cycle is made of       Level.helion.childrenText        "9 θ"
//   how many in the parent        Level.helion.inParentText        "11 in ζ"
//   a unit in the next unit       Unit.helion.inParentText         "77 in ε"
//   P with its factors            Level.helion.prefixFactorsText   "125 125 = 5 · 13 · 5 · 5 · 7 · 11"
//   a cycle among its siblings    cycle.placeText (Clock/Cycle.swift)  "8 of 9"
//   what a level is               LevelKind.text (Hierarchy/Level.swift)  "between"

extension Fractonica {
    /// A whole number with its digits in groups of three, separated by
    /// U+202F NARROW NO-BREAK SPACE, as every grouped number of the core is
    /// written (`frc_format_count`): `"999"`, `"1 000"`, `"58 500"`.
    /// Use it for every bare count on screen (the sync number `4 820`).
    public static func count(_ n: UInt64) -> String {
        CoreText.infallible { frc_format_count(n, $0, $1) }
    }

    /// A signed whole number grouped the same way, U+2212 before a negative
    /// one (`frc_format_count_signed`): `"4 820"`, `"−3"`, `"0"` (never
    /// `"−0"`). Sync numbers before the anchor are negative.
    public static func count(signed n: Int64) -> String {
        CoreText.infallible { frc_format_count_signed(n, $0, $1) }
    }

    /// The word `"light"` alone (`frc_format_light_word`): what
    /// ``Level/lightSpanText(_:withWord:)`` appends after a space, for a
    /// view that sets it in a style of its own (design/README.md ruling 2).
    public static var lightWord: String {
        CoreText.infallible { frc_format_light_word($0, $1) }
    }
}

extension Level {
    /// How many of `unit` one cycle of this level holds, with the unit's
    /// symbol (`frc_format_level_in_unit`): the Helion is `"58 500ν"`,
    /// `"2 340λ"`, `"36ι"` and `"1η"`; ζ is `"11η"`.
    /// - Returns: `nil` when the level is finer than the Blink (it holds no
    ///   whole unit) or `unit` is coarser than the level.
    public func countText(in unit: Unit) -> String? {
        try? CoreText.make { frc_format_level_in_unit(raw, unit.raw, $0, $1) }
    }

    /// What one cycle of this level is made of, counted in LEVELS
    /// (`frc_format_level_children`): `"9 θ"` for the Helion, `"5 β"` for
    /// Alpha, `"11 η1"` for ζ1. ``countText(in:)`` counts in units.
    /// `nil` for the last rung, which has no level below it.
    public var childrenText: String? {
        try? CoreText.make { frc_format_level_children(raw, $0, $1) }
    }

    /// How many cycles of this level its parent holds, with the parent's
    /// name (`frc_format_level_in_parent`): `"11 in ζ"` for the Helion,
    /// `"5 in α"` for Beta. `nil` for Alpha, which has no parent.
    public var inParentText: String? {
        try? CoreText.make { frc_format_level_in_parent(raw, $0, $1) }
    }

    /// P(level) and the factors that make it (`frc_format_prefix_factors`):
    /// `"125 125 = 5 · 13 · 5 · 5 · 7 · 11"` for the Helion, `"5 = 5"` for
    /// Beta, `"1"` for Alpha. Every level is written in full (level 62 is a
    /// 52-digit prefix and 62 factors: `FRC_PREFIX_FACTORS_SIZE` bytes).
    public var prefixFactorsText: String {
        CoreText.infallible(minimumCapacity: Int(FRC_PREFIX_FACTORS_SIZE)) { frc_format_prefix_factors(raw, $0, $1) }
    }

    /// The rate of this rung in cycles per Blink, from the exact ratio, for
    /// every level (`frc_format_level_rate`).
    ///
    /// - Down to the Blink it is the text of ``BlinkRate/text``: `"1 pB"`,
    ///   `"1 per 5 Blinks"` (μ), `"1 per 25 Blinks"` (the Flavon),
    ///   `"1 per 58 500 Blinks"` (the Helion; design ruling 3).
    /// - Finer than the Blink the rate is a whole number: `"7 pB"`,
    ///   `"2 772 pB"`, and in full for ζ1 `"142 033 641 750 000 pB"`.
    ///
    /// - Parameter digits: `nil` writes the number in full. 2...9 writes a
    ///   rate of a million or more as a power of ten with that many
    ///   significant digits, `"1.420 × 10¹⁴ pB"`. Other values are brought
    ///   into 2...9.
    public func rateText(digits: Int? = nil) -> String {
        let digitCount = digits.map { UInt8(min(max($0, 2), 9)) } ?? 0
        return CoreText.infallible { frc_format_level_rate(raw, digitCount, $0, $1) }
    }

    /// A LENGTH said without metres: the span light in vacuum needs to cover
    /// the distance a wave in `medium` covers in one period of this level
    /// (`frc_format_light_span`). One Helion in the seven media reads `"1η"`,
    /// `"24ι 1λ"`, `"3.5ν"`, `"2.05ξ"`, `"5.15ο"`, `"1.80ο"`, `"6.15χ"`.
    /// From one Blink up it is a span; below, a count of the largest rung
    /// that fits with three significant digits.
    /// - Parameter withWord: appends `" light"`: `"1η light"`.
    public func lightSpanText(_ medium: Medium = .vacuum, withWord: Bool = true) -> String {
        CoreText.infallible { frc_format_light_span(raw, medium.speed.raw, withWord ? 1 : 0, $0, $1) }
    }

    /// The same for a speed of the caller's own.
    /// - Throws: ``FractonicaError/invalidArgument`` for a speed with a zero
    ///   part; ``FractonicaError/overflow`` for a span no ``Span`` can hold.
    public func lightSpanText(speed: Speed, withWord: Bool = true) throws -> String {
        try CoreText.make { frc_format_light_span(raw, speed.raw, withWord ? 1 : 0, $0, $1) }
    }
}

extension Unit {
    /// How many of this unit make the next coarser unit, with that unit's
    /// symbol (`frc_format_unit_in_parent`): the Helion is `"77 in ε"`
    /// (where its parent LEVEL ζ holds 11), the Blink `"25 in λ"`. `nil` for
    /// Alpha, which has no coarser unit.
    public var inParentText: String? {
        try? CoreText.make { frc_format_unit_in_parent(raw, $0, $1) }
    }
}
