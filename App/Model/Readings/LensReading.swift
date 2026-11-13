import Foundation
import FractonicaKit

/// Everything the lens shows about one rung (DESIGN.md §9, "Lens"): its
/// static facts for all 63 levels, and, for a level the instrument can show
/// (0...13) inside the catalogue, its running cycle with the four thresholds.
///
/// No arithmetic of its own. Counts, spans, rates, light-spans, `9 θ`,
/// `+6ι 43λ`, `8 of 9`, the factor chain and the glyph of a threshold are
/// the core's; what the core does not have yet goes through `ShimCoreGaps`
/// (whether a period is legible, a device's wording). Earth texts are built
/// only when `zone` is given, that is, in Earth mode.
struct LensReading: Equatable, Sendable {
    let rung: RungReading
    /// `rung 7 of 63`.
    let ordinalLine: String
    /// `depth 7 · level 6 · unit` (the kind in the core's word, `frc_format_level_kind`).
    let kindLine: String
    /// One more line under the name, for the rungs that have something to
    /// say for themselves.
    let epithet: Epithet?
    /// The levels from the Alpha down to this rung: the lineage strip.
    let lineage: [Level]
    /// `Exact P(6)` and its value, longest wording first:
    /// `125 125 = 5 · 13 · 5 · 5 · 7 · 11`, then `125 125`.
    let prefixLabel: String
    let prefix: [String]
    /// The data rows, top to bottom.
    let rows: [Row]
    /// `One Helion of travel`, and the seven media.
    let travelTitle: String
    let media: [MediumRow]
    /// The live ring; `nil` for a rung the instrument cannot show.
    let ring: Ring?

    struct Epithet: Equatable, Sendable {
        enum Tone: Sendable {
            /// The Helion: the Sun's colour.
            case sun
            /// ζ1: the one red.
            case visibleLight
            case plain
        }

        let text: String
        let tone: Tone
    }

    /// One labelled row. A value is a list of wordings, the most detailed
    /// first: the renderer takes the first that fits its width.
    struct Row: Equatable, Sendable {
        let label: String
        /// Fractonica wordings; empty for a row that is wholly Earth.
        let pure: [String]
        /// EARTH MODE ONLY: the translation set beside the value.
        var earth: [String] = []
    }

    /// One medium of SPEC §16.3: how far something travels in one cycle.
    struct MediumRow: Equatable, Sendable {
        let name: String
        /// Where the length falls between the slowest and the fastest medium,
        /// 0...1 on a logarithmic rule (a drawing position, unitless).
        let place: Double
        /// The length as a span of light, `24ι 1λ`, and the word that
        /// follows it, `light` (design/README.md ruling 2).
        let span: String
        let word: String
        /// EARTH MODE ONLY: the length in metres.
        let earth: String?
    }

    /// The live ring of a rung the instrument can show.
    struct Ring: Equatable, Sendable {
        /// The rung as the instrument reads it (engraved outside the catalogue).
        let instrument: InstrumentReading
        /// Peak, node, valley, end of the running cycle.
        let thresholds: [ThresholdRow]
    }

    struct ThresholdRow: Equatable, Sendable {
        let quarter: Quarter
        /// The glyph state the cycle reaches there (SPEC §4).
        let glyph: Glyph?
        /// How far it is from the moment shown, signed: `−20ι 21λ`, `+6ι 43λ`.
        /// `nil` outside the catalogue.
        let span: String?
        /// Whether it is the next one to come.
        let isNext: Bool
        /// EARTH MODE ONLY: when it falls.
        let earth: String?
    }

    // MARK: Reading

    /// Reads the lens for `level` at `instant`.
    /// - Parameter zone: Earth mode's time zone; `nil` in pure mode, and then
    ///   no Earth text is built.
    static func read(_ clock: Catalogue, at instant: Instant, level: Level, zone: TimeZone?) -> LensReading {
        let earth = zone != nil
        let interval = LadderReading.interval(clock, at: instant)
        let rung = RungReading.read(level, interval: interval, earth: earth)
        let lineage = Array(Level.all[...level.index])
        let ring = AppModel.focusRange.contains(level.index)
            ? readRing(clock, at: instant, level: level, zone: zone) : nil

        return LensReading(
            rung: rung,
            ordinalLine: "rung \(level.depth) of \(Level.count)",
            kindLine: "depth \(level.depth) · level \(level.index) · \(level.kind.text)",
            epithet: epithet(of: rung),
            lineage: lineage,
            prefixLabel: "Exact P(\(level.index))",
            prefix: prefixWordings(level),
            rows: rows(rung, interval: interval, running: ring?.instrument.live?.cycle),
            travelTitle: "One \(level.unit?.name ?? level.name) of travel",
            media: media(level, interval: interval, earth: earth),
            ring: ring
        )
    }

    private static func epithet(of rung: RungReading) -> Epithet? {
        if rung.level == Sync.level {
            return Epithet(text: "the unit that locks to the Sun", tone: .sun)
        }
        if rung.isVisibleLight {
            return Epithet(text: "\(rung.band.name) \(Fractonica.lightWord)", tone: .visibleLight)
        }
        return rung.band == .noBand ? nil : Epithet(text: rung.band.name, tone: .plain)
    }

    /// `P(level)` with the factors that make it (the core writes every
    /// level in full), then the value alone in digit groups (the core groups
    /// what fits 64 bits; beyond that it writes the exact digits). The Alpha's
    /// is `1` alone.
    private static func prefixWordings(_ level: Level) -> [String] {
        let value = level.prefix.map(Fractonica.count) ?? level.prefixText
        let withFactors = level.prefixFactorsText
        return withFactors == value ? [value] : [withFactors, value]
    }

    // MARK: Rows

    private static func rows(_ rung: RungReading, interval: SarosInterval, running: Cycle?) -> [Row] {
        let level = rung.level
        var rows: [Row] = []

        // Made of: its children, and the same counted in the next finer unit.
        if let child = level.child {
            let direct = child.unit.flatMap { level.countText(in: $0) } ?? level.childrenText ?? ""
            let inUnit = level.finerUnit.flatMap { $0.level == child ? nil : level.countText(in: $0) }
            rows.append(Row(label: "Made of", pure: wordings([inUnit, direct].compactMap { $0 }, keeping: 1)))
        }

        // Siblings: in the parent, in the next coarser unit, and which one is running.
        var siblings: [String] = []
        if let inParent = rung.inParent { siblings.append(inParent) }
        if let unit = level.unit, let coarser = unit.coarser, coarser.level != level.parent,
           let inUnit = unit.inParentText {
            siblings.append(inUnit)
        }
        if let running {
            siblings.append("now \(running.placeText)")
        }
        if !siblings.isEmpty {
            // The running one is said last and kept longest after the parent.
            var candidates = [siblings]
            if siblings.count == 3 { candidates.append([siblings[0], siblings[2]]) }
            if siblings.count >= 2 { candidates.append([siblings[0]]) }
            rows.append(Row(label: "Siblings", pure: candidates.map { $0.joined(separator: " · ") }))
        }

        // Period: counted in each finer unit; under the Blink, as a part of one
        // while the core's span still shows it.
        var periods = Unit.allCases.filter { $0.level > level }.compactMap { level.countText(in: $0) }
        if periods.isEmpty, let length = rung.length { periods = [length] }
        if periods.isEmpty, ShimCoreGaps.spanIsLegible(level.span) { periods = [level.span.text()] }
        let earth = rung.earth
        if !periods.isEmpty {
            rows.append(Row(label: "Period", pure: wordings(periods, keeping: 1), earth: earth.map { [$0.period] } ?? []))
        }

        rows.append(Row(label: "Rate", pure: [rung.rate, rung.rateRounded],
                        earth: earth.map { periods.isEmpty ? ["\($0.period) · \($0.frequency)", $0.frequency] : [$0.frequency] } ?? []))

        var band = Row(label: "Band", pure: [rung.band.name])
        if earth != nil, let edges = rung.band.edgeTexts {
            band.earth = ["\(edges.low) – \(edges.high)"]
        }
        rows.append(band)

        // A device that makes the rung (SPEC §16.4): Earth mode, under the Blink.
        if earth != nil, level > .blink {
            let ticks = ShimCoreGaps.timerTicks(level, interval: interval)
            let step = ShimCoreGaps.oscillatorStep(level, interval: interval)
            let parts = [ticks, step].compactMap { $0 }
            if !parts.isEmpty {
                rows.append(Row(label: "Device", pure: [], earth: wordings(parts, keeping: 1)))
            }
        }
        return rows
    }

    /// The parts joined, then with fewer and fewer of the trailing ones: the
    /// wordings a row offers when it is short of room.
    private static func wordings(_ parts: [String], keeping minimum: Int) -> [String] {
        guard !parts.isEmpty else { return [] }
        return stride(from: parts.count, through: min(minimum, parts.count), by: -1).map {
            parts.prefix($0).joined(separator: " · ")
        }
    }

    // MARK: Media

    private static func media(_ level: Level, interval: SarosInterval, earth: Bool) -> [MediumRow] {
        // The rule is logarithmic in speed: the same for every rung, since a
        // length is a speed times the one period.
        let speeds = Medium.allCases.map { Double($0.speed.numerator) / Double(max($0.speed.denominator, 1)) }
        let slowest = speeds.min() ?? 1, fastest = speeds.max() ?? 1
        let range = log(fastest / slowest)
        return zip(Medium.allCases, speeds).map { medium, speed in
            return MediumRow(
                name: medium.name,
                place: range > 0 ? max(0.02, log(speed / slowest) / range) : 1,
                span: level.lightSpanText(medium, withWord: false),
                word: Fractonica.lightWord,
                earth: earth ? level.lengthText(interval, speed: medium.speed) : nil
            )
        }
    }

    // MARK: The live ring

    private static func readRing(_ clock: Catalogue, at instant: Instant, level: Level, zone: TimeZone?) -> Ring {
        let instrument = InstrumentReading.read(clock, at: instant, focus: level, depth: 2)
        let next = instrument.live?.nextThreshold.quarter
        let thresholds = Quarter.allCases.map { quarter -> ThresholdRow in
            let at = instrument.live?.points[quarter]
            let span = at.flatMap { try? clock.span(from: instant, to: $0) }?.signedText()
            var earth: String?
            if let zone, let at { earth = EarthText.when(at, from: instant, zone: zone) }
            return ThresholdRow(
                quarter: quarter, glyph: try? Glyph(at: quarter),
                span: span, isNext: quarter == next, earth: earth
            )
        }
        return Ring(instrument: instrument, thresholds: thresholds)
    }
}
