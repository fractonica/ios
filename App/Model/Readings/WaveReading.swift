// Not all of Foundation: its own `Unit` would hide the kit's.
import struct Foundation.TimeZone
import FractonicaKit

/// Everything the WAVE screen shows at one instant for one focus level, read
/// from the core: the nine terms of the stamp, the cycles of the focused
/// level around the moment (the wave), the Sun's lane, and the next
/// thresholds. Every string is the core's text. The Earth translations are
/// made separately, and only in Earth mode (``WaveEarth``).
struct WaveReading: Equatable, Sendable {
    let focus: Level
    /// `Helion wave`: the unit's name, or the letter's word for a level
    /// that is not a unit.
    let title: String
    /// `9 θ · 36ι`: what one cycle of the focus is made of (its children,
    /// and their count in the next finer unit when that is a different level).
    let madeOf: String
    /// `nil` outside the catalogue: the wave is then engraved, nothing lit,
    /// and ``outOfCatalogue`` replaces the stamp (design/README.md ruling 7).
    let live: Live?
    /// `OUT OF CATALOGUE · α#1 – α#18`.
    let outOfCatalogue: String

    struct Live: Equatable, Sendable {
        /// The date, for speech (`date.text(.full)`).
        let date: FractonicaDate
        /// The nine terms of the stamp, Alpha first.
        let terms: [Term]
        /// The cycle of the focus under the hairline.
        let cycle: Cycle
        /// The cycles drawn, earliest first: the one under the hairline
        /// (`offset` 0) and its neighbours as far as the catalogue has them.
        let laps: [Lap]
        /// The running cycles of the levels nested on the wave, coarsest first.
        let nested: [Cycle]
        /// The thresholds of the cycle under the hairline.
        let points: CyclePoints
        let next: Threshold
        /// The span to it: `6ι 43λ`.
        let nextSpan: String
        /// `nil` in the partial syncs at the catalogue's edges.
        let sun: SunLane?
        /// What comes next across the levels around the focus and the Sun,
        /// soonest first.
        let upcoming: [NowReading.Upcoming]
    }

    /// One term of the stamp: `34η` of the Helion.
    struct Term: Equatable, Sendable {
        let unit: Unit
        let text: String
    }

    /// One cycle of the focus on the wave.
    struct Lap: Equatable, Sendable {
        /// Cycles from the one under the hairline: −1 is the one before it.
        let offset: Int
        let cycle: Cycle
        /// What is written where it starts: `34η`, `δ#3`.
        var name: String { cycle.shortName }
    }

    /// The Sun's lane: one solar sync as its 19 Helions, in four Pentads.
    struct SunLane: Equatable, Sendable {
        let sync: Sync
        /// `4 820`.
        let number: String
        /// The drift against civil days in whole Flavons: `−6 235λ`.
        let drift: String
        /// The Pentads of the sync, in order.
        let pentads: [PentadMark]
        /// The Pentad that is running: an index into ``pentads``.
        let currentPentad: Int?
        /// The running Helion: its slot in the sync and the cycle itself
        /// (which half it is in, and how far).
        let slot: Int
        let helion: Cycle
        /// The span to the sync's next quarter: `2η 24ι`.
        let nextSpan: String
    }

    struct PentadMark: Equatable, Sendable {
        /// The Helion slot it starts at, and how many it has (5, or 4).
        let start: Int
        let helions: Int
        /// `I`, `II`, `III`; empty for the Hypopentad, whose sign is the square.
        let numeral: String
        /// `Pentad II`, for speech.
        let name: String
    }

    // MARK: Reading

    /// - Parameter reach: how many cycles to read on each side of the one
    ///   under the hairline (what fits the window: 2 on the phone).
    /// - Parameter depth: how many nested levels to read.
    static func read(_ clock: Catalogue, at instant: Instant, focus: Level, reach: Int, depth: Int) -> WaveReading {
        WaveReading(
            focus: focus,
            title: "\(focus.title) wave",
            madeOf: madeOf(focus),
            live: try? readLive(clock, at: instant, focus: focus, reach: reach, depth: depth),
            outOfCatalogue: NowReading.read(clock, at: instant, focus: focus).outOfCatalogue
        )
    }

    private static func madeOf(_ focus: Level) -> String {
        guard let child = focus.child, let children = focus.childrenText else { return "" }
        guard let unit = focus.finerUnit, unit.level != child, let counted = focus.countText(in: unit) else {
            return children
        }
        return "\(children) · \(counted)"
    }

    private static func readLive(
        _ clock: Catalogue, at instant: Instant, focus: Level, reach: Int, depth: Int
    ) throws -> Live {
        let date = try clock.date(at: instant)
        let terms = Unit.allCases.map { Term(unit: $0, text: date.term($0)) }
        let cycle = try clock.cycle(focus, at: instant)

        // The neighbours by index (the header's recipe: the next cycle is index + 1).
        var laps: [Lap] = []
        let count = clock.cycleCount(focus)
        for offset in -reach ... reach {
            let index: UInt64
            if offset < 0 {
                guard UInt64(-offset) <= cycle.index else { continue }
                index = cycle.index - UInt64(-offset)
            } else {
                let (sum, overflow) = cycle.index.addingReportingOverflow(UInt64(offset))
                guard !overflow, sum < count else { continue }
                index = sum
            }
            laps.append(Lap(offset: offset, cycle: offset == 0 ? cycle : try clock.cycle(focus, index: index)))
        }

        var nested: [Cycle] = []
        var level = focus
        while nested.count < depth, let child = level.child, child.isClockLevel {
            nested.append(try clock.cycle(child, at: instant))
            level = child
        }

        let next = try clock.nextThreshold(focus, after: instant)
        let sun = readSun(clock, at: instant)
        return Live(
            date: date, terms: terms, cycle: cycle, laps: laps, nested: nested,
            points: try clock.points(of: cycle), next: next,
            nextSpan: try spanText(clock, from: instant, to: next.instant),
            sun: sun, upcoming: try readUpcoming(clock, at: instant, focus: focus, sun: sun)
        )
    }

    private static func readSun(_ clock: Catalogue, at instant: Instant) -> SunLane? {
        guard let sync = try? clock.sync(at: instant), let helion = try? clock.cycle(Sync.level, at: instant) else {
            return nil
        }
        let pentads = (0 ..< Pentad.perSync).compactMap { try? clock.pentad(sync: sync.number, index: $0) }.map {
            PentadMark(start: $0.first, helions: $0.helions, numeral: $0.numeral, name: $0.name)
        }
        return SunLane(
            sync: sync,
            number: Fractonica.count(signed: Int64(sync.number)),
            drift: (try? clock.span(from: sync.nominal, to: sync.start).text(in: .flavon)) ?? "",
            pentads: pentads,
            currentPentad: (try? clock.pentad(at: instant))?.index,
            slot: sync.helion,
            helion: helion,
            nextSpan: (try? spanText(clock, from: instant, to: sync.next.instant)) ?? ""
        )
    }

    /// The next thresholds of the two levels finer than the focus, of the
    /// focus, of the four coarser ones, and of the Sun, soonest first.
    private static func readUpcoming(
        _ clock: Catalogue, at instant: Instant, focus: Level, sun: SunLane?
    ) throws -> [NowReading.Upcoming] {
        var rows: [NowReading.Upcoming] = []
        for step in stride(from: 2, through: -4, by: -1) {
            guard let level = focus.offset(by: step), level.isClockLevel else { continue }
            let threshold = try clock.nextThreshold(level, after: instant)
            // Nothing comes later (the catalogue's closing instant): no row.
            guard threshold.instant != nil else { continue }
            rows.append(NowReading.Upcoming(
                level: level, threshold: threshold, span: try spanText(clock, from: instant, to: threshold.instant)
            ))
        }
        if let sun, sun.sync.next.instant != nil {
            rows.append(NowReading.Upcoming(level: nil, threshold: sun.sync.next, span: sun.nextSpan))
        }
        return rows.sorted { ($0.threshold.instant ?? clock.last) < ($1.threshold.instant ?? clock.last) }
    }

    /// The span to a boundary the core returned; empty at the catalogue's end.
    private static func spanText(_ clock: Catalogue, from instant: Instant, to boundary: Instant?) throws -> String {
        guard let boundary else { return "" }
        return try clock.span(from: instant, to: boundary).text()
    }
}

// MARK: - The tumblers' neighbours

/// The values a tumbler shows ghosted above and below the one it is on: the
/// term as it would read one step earlier and one step later.
struct StampGhosts: Equatable, Sendable {
    var above: String?
    var below: String?

    /// - Parameter zone: Earth mode's zone. An Earth field is read only when
    ///   it is given, so pure mode builds no Earth text.
    static func read(_ clock: Catalogue, at instant: Instant, field: StampField, zone: TimeZone?) -> StampGhosts {
        StampGhosts(above: text(clock, at: instant, field: field, steps: -1, zone: zone),
                    below: text(clock, at: instant, field: field, steps: 1, zone: zone))
    }

    private static func text(
        _ clock: Catalogue, at instant: Instant, field: StampField, steps: Int, zone: TimeZone?
    ) -> String? {
        guard let stepped = WaveStepping.instant(clock, from: instant, field: field, by: steps, zone: zone) else {
            return nil
        }
        switch field {
        case .unit(let unit):
            return (try? clock.date(at: stepped))?.term(unit)
        case .earth(let earth):
            return zone.map { EarthText.earthFields(stepped, zone: $0)[earth] }
        }
    }
}

/// Stepping one term of the moment by whole units (the tumblers, the keys).
enum WaveStepping {
    /// The instant `steps` units of `field` from `instant`; `nil` when the
    /// step would leave the catalogue (the tumbler then stays where it is:
    /// time travel never leaves the catalogue, design/README.md ruling 7).
    /// A term of the stamp is stepped by the core (`frc_date_at` /
    /// `frc_date_to_time` through `Catalogue.instant(byStepping:)`), an Earth
    /// field by the calendar, and only when a zone is given.
    static func instant(
        _ clock: Catalogue, from instant: Instant, field: StampField, by steps: Int, zone: TimeZone?
    ) -> Instant? {
        switch field {
        case .unit(let unit):
            return try? clock.instant(byStepping: unit, by: steps, from: instant)
        case .earth(let earth):
            guard let zone, let stepped = ShimCoreGaps.step(instant, field: earth, by: steps, zone: zone),
                  clock.contains(stepped)
            else { return nil }
            return stepped
        }
    }
}
