import FractonicaKit

/// The static facts of one rung, as the ladder lists them and the lens
/// repeats them (DESIGN.md §9, "Ladder"). Every text is the core's: names,
/// spans, rates and counts from `Notation/PureWording`, Earth quantities from
/// `Ladder/Level+Ladder`. Nothing here depends on the instant except the
/// Saros interval the Earth values and the band are laid from.
struct RungReading: Equatable, Sendable {
    let level: Level
    /// `ζ1`.
    let name: String
    /// `Helion` for a unit, else `nil`.
    let unitName: String?
    let kind: LevelKind
    let band: Band
    /// `7 in ε1`: its cycles per parent cycle. `nil` for the Alpha.
    let inParent: String?
    /// `36ι` (in the next finer unit) or, from the Blink down, `11 η1`
    /// (cycles of the next rung). `nil` for the last rung.
    let madeOf: String?
    /// Its length as a span, down to the Blink: `1η`, `11η`. `nil` finer.
    let length: String?
    /// Its exact rate: `1 per 58 500 Blinks`, `142 033 641 750 000 pB`.
    let rate: String
    /// The same to four digits where it is long: `1.420 × 10¹⁴ pB`.
    let rateRounded: String
    /// The Earth translation; `nil` in pure mode (it is not even built).
    let earth: Earth?

    /// EARTH MODE ONLY: period, frequency and light-in-vacuum length for the
    /// Saros interval at the cursor (`frc_format_period` …).
    struct Earth: Equatable, Sendable {
        let period: String
        let frequency: String
        let length: String
    }

    /// The one rung that is visible light: ζ1, 656 nm (DESIGN.md §2, `h-alpha`).
    var isVisibleLight: Bool { band == .visible }

    /// Whether the instrument can be focused on it (design/README.md ruling 9).
    var isFocusable: Bool { AppModel.focusRange.contains(level.index) }

    /// What a list sets as the rung's size (design/README.md ruling 3), as
    /// wordings longest first: its span down to the Blink; below it, its
    /// exact rate, then the core's rate to four digits. The renderer sets
    /// the first that fits its column (no wording is chosen by picking the
    /// core's text apart).
    var sizeWordings: [String] {
        if let length { return [length] }
        return rate == rateRounded ? [rate] : [rate, rateRounded]
    }

    /// The rate alone, the same way: exact, then to four digits.
    var rateWordings: [String] {
        rate == rateRounded ? [rate] : [rate, rateRounded]
    }

    /// `unit · no band · 11 in ζ`: the line under a rung's letter.
    var caption: String {
        [kind.text, band.name, inParent].compactMap { $0 }.joined(separator: " · ")
    }

    static func read(_ level: Level, interval: SarosInterval, earth: Bool) -> RungReading {
        let madeOf: String?
        if let unit = level.finerUnit, let counted = level.countText(in: unit) {
            madeOf = counted
        } else {
            madeOf = level.childrenText
        }
        return RungReading(
            level: level,
            name: level.name,
            unitName: level.unit?.name,
            kind: level.kind,
            band: level.band(interval),
            inParent: level.inParentText,
            madeOf: madeOf,
            length: level <= .blink ? level.span.text() : nil,
            rate: level.rateText(),
            rateRounded: level.rateText(digits: 4),
            earth: earth ? Earth(
                period: level.periodText(interval),
                frequency: level.frequencyText(interval),
                length: level.lengthText(interval)
            ) : nil
        )
    }
}

/// The whole spectral ladder: 63 rungs for one Saros interval.
struct LadderReading: Equatable, Sendable {
    let interval: SarosInterval
    let rungs: [RungReading]

    /// The ladder for the Saros interval that holds `instant` (the reference
    /// interval of SPEC §16 outside the catalogue).
    /// - Parameter earth: build the Earth translations (Earth mode only).
    static func read(_ clock: Catalogue, at instant: Instant, earth: Bool) -> LadderReading {
        read(interval: LadderReading.interval(clock, at: instant), earth: earth)
    }

    static func read(interval: SarosInterval, earth: Bool) -> LadderReading {
        LadderReading(interval: interval, rungs: Level.all.map { RungReading.read($0, interval: interval, earth: earth) })
    }

    /// The Saros interval the ladder is laid from at `instant`.
    static func interval(_ clock: Catalogue, at instant: Instant) -> SarosInterval {
        (try? clock.interval(at: instant)) ?? .reference
    }

    subscript(level: Level) -> RungReading { rungs[level.index] }
}
