import FractonicaKit

/// The words and numbers of the NOW screen around the instrument, read from
/// the core at one instant. Every string here is the core's text; the Earth
/// translations are made separately, from the instants kept beside them
/// (`Screens/Now/NowEarth.swift`), and only in Earth mode.
struct NowReading: Equatable, Sendable {
    /// The Pentad leads the date as a weekday leads a civil one. `nil` only
    /// outside the catalogue.
    let pentad: Pentad?
    /// `nil` outside the catalogue; then ``outOfCatalogue`` is shown instead.
    let live: Live?
    /// `OUT OF CATALOGUE · α#1 – α#18` (design/README.md ruling 7).
    let outOfCatalogue: String

    struct Live: Equatable, Sendable {
        /// The date; `date.text(.full)` is what a screen reader says.
        let date: FractonicaDate
        /// The four major periods, Alpha first.
        let majors: [Major]
        /// The minor terms of the stamp: `ε#5`, `34η`, `29ι`, `21λ`, `3ν`.
        let terms: [String]
        /// The next thresholds of the focus and of the level under it.
        let countdowns: [Countdown]
        /// The Sun's numbers; `nil` in a partial sync at the catalogue's edges.
        let sun: SunFigures?
        /// What comes next across the coarser levels and the Sun, soonest first.
        let upcoming: [Upcoming]
    }

    /// A major period as the date says it: `Delta Trifracton`, `End`.
    struct Major: Equatable, Sendable {
        let level: Level
        let name: String
        let quarter: Quarter
    }

    /// The next threshold of one level, with its sibling counter.
    struct Countdown: Equatable, Sendable {
        let level: Level
        let cycle: Cycle
        let odometer: Odometer
        let threshold: Threshold
        /// `6ι 43λ`.
        let span: String
    }

    struct SunFigures: Equatable, Sendable {
        let sync: Sync
        let odometer: Odometer
        /// The sync's number in digit groups: `4 820`.
        let number: String
        /// The drift against civil days in whole Flavons, cut: `−6 235λ`
        /// (the design's `−6 236λ` is rounded).
        let drift: String
        /// The span to the sync's next quarter: `2η 24ι`.
        let nextSpan: String
    }

    /// One row of "next thresholds".
    struct Upcoming: Equatable, Sendable {
        /// `nil` is the Sun.
        let level: Level?
        let threshold: Threshold
        let span: String
    }

    /// The numeral inside the Pentad mark (`II`), the core's numeral form.
    /// Empty for the Hypopentad, whose sign is the square alone.
    var pentadNumeral: String { pentad?.numeral ?? "" }

    // MARK: Reading

    static func read(_ clock: Catalogue, at instant: Instant, focus: Level) -> NowReading {
        let pentad = try? clock.pentad(at: instant)
        let live = try? readLive(clock, at: instant, focus: focus)
        return NowReading(pentad: pentad, live: live, outOfCatalogue: outOfCatalogueText(clock))
    }

    private static func readLive(_ clock: Catalogue, at instant: Instant, focus: Level) throws -> Live {
        let date = try clock.date(at: instant)
        let majors = try [Level.alpha, .beta, .gamma, .delta].map { level -> Major in
            let cycle = try clock.cycle(level, at: instant)
            return Major(level: level, name: cycle.name, quarter: cycle.quarter)
        }
        // The stamp is nine terms, Alpha first; the reading is the minor five.
        let terms = Array(date.terms.dropFirst(majors.count))

        // A threshold the core has no instant for (nothing comes later: the
        // catalogue's closing instant) is not listed: a label with no value
        // would announce something that does not exist.
        var countdowns: [Countdown] = []
        for level in [focus, focus.child].compactMap({ $0 }) where level.isClockLevel {
            let threshold = try clock.nextThreshold(level, after: instant)
            guard threshold.instant != nil else { continue }
            countdowns.append(Countdown(
                level: level,
                cycle: try clock.cycle(level, at: instant),
                odometer: try clock.odometer(level, at: instant),
                threshold: threshold,
                span: try spanText(clock, from: instant, to: threshold.instant)
            ))
        }

        var sun: SunFigures?
        var upcoming: [Upcoming] = []
        if let sync = try? clock.sync(at: instant), let odometer = try? clock.syncOdometer(at: instant) {
            let nextSpan = try spanText(clock, from: instant, to: sync.next.instant)
            sun = SunFigures(
                sync: sync,
                odometer: odometer,
                number: Fractonica.count(signed: Int64(sync.number)),
                drift: (try? clock.span(from: sync.nominal, to: sync.start).text(in: .flavon)) ?? "",
                nextSpan: nextSpan
            )
            if sync.next.instant != nil {
                upcoming.append(Upcoming(level: nil, threshold: sync.next, span: nextSpan))
            }
        }
        // The four levels just coarser than the focus (fewer near Alpha).
        var coarser = focus.parent
        while let level = coarser, upcoming.count < 5, focus.index - level.index <= 4 {
            let threshold = try clock.nextThreshold(level, after: instant)
            coarser = level.parent
            guard threshold.instant != nil else { continue }
            upcoming.append(Upcoming(
                level: level, threshold: threshold, span: try spanText(clock, from: instant, to: threshold.instant)
            ))
        }
        upcoming.sort { ($0.threshold.instant ?? clock.last) < ($1.threshold.instant ?? clock.last) }

        return Live(date: date, majors: majors, terms: terms, countdowns: countdowns, sun: sun, upcoming: upcoming)
    }

    /// The span to a boundary the core returned; empty at the catalogue's end.
    private static func spanText(_ clock: Catalogue, from instant: Instant, to boundary: Instant?) throws -> String {
        guard let boundary else { return "" }
        return try clock.span(from: instant, to: boundary).text()
    }

    private static func outOfCatalogueText(_ clock: Catalogue) -> String {
        let first = (try? Level.alpha.cycleName(index: 0, short: true)) ?? ""
        let lastIndex = clock.cycleCount(.alpha)
        let last = lastIndex > 0 ? ((try? Level.alpha.cycleName(index: lastIndex - 1, short: true)) ?? "") : ""
        return "OUT OF CATALOGUE · \(first) – \(last)"
    }
}
