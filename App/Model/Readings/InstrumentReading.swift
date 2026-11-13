import FractonicaKit

/// Everything the instrument draws for one focus level at one instant, read
/// from the core once per redraw.
///
/// No arithmetic of its own: cycles, phases, counters and odometer states are
/// the core's; the only operations here are the header's navigation recipes
/// (a descendant's index minus the first descendant's, a count of children).
struct InstrumentReading: Equatable, Sendable {
    let focus: Level
    /// `nil` outside the catalogue: the instrument is then drawn engraved,
    /// nothing lit (design/README.md ruling 7).
    let live: Live?
    /// One ring per ancestor of the focus, nearest first (ζ, ε, δ … for a
    /// Helion). Present, unlit, outside the catalogue too.
    let counters: [CounterReading]
    /// Whether the Sun's ring belongs on the instrument: the focus is the
    /// Helion or finer (DESIGN.md §5).
    var showsSunRing: Bool { focus >= Sync.level }

    struct Live: Equatable, Sendable {
        /// The focused cycle: the carrier of the hero ring.
        let cycle: Cycle
        /// The running cycles of the levels nested on it, coarsest first:
        /// child (F+1), grandchild (F+2), great-grandchild (F+3).
        let nested: [Cycle]
        /// The centre: the focus level's two glyphs.
        let odometer: Odometer
        /// Start, peak, node, valley, end of the focused cycle (Earth mode
        /// writes their clock times on the bezel).
        let points: CyclePoints
        /// The next threshold of the focused cycle and how far it is.
        let nextThreshold: Threshold
        let nextSpan: String
        /// Completed grandchild cycles in the focused cycle: `29` of `29ι`.
        /// The bezel lights graduations `0 ... graduationsLit`.
        let graduationsLit: Int
        /// The Sun, when the instant is inside a whole solar sync.
        let sun: SunReading?
    }

    // MARK: Reading

    /// Reads the instrument for `focus` at `instant`.
    /// - Parameter depth: how many nested levels to read (2 phone, 3 desktop).
    static func read(_ clock: Catalogue, at instant: Instant, focus: Level, depth: Int = 3) -> InstrumentReading {
        let ancestors = Array(Level.all[..<focus.index].reversed())
        guard let live = try? readLive(clock, at: instant, focus: focus, depth: depth),
              let counters = try? ancestors.map({ try CounterReading.read(clock, at: instant, level: $0) })
        else {
            return InstrumentReading(focus: focus, live: nil, counters: ancestors.map(CounterReading.engraved))
        }
        return InstrumentReading(focus: focus, live: live, counters: counters)
    }

    private static func readLive(_ clock: Catalogue, at instant: Instant, focus: Level, depth: Int) throws -> Live {
        let cycle = try clock.cycle(focus, at: instant)
        var nested: [Cycle] = []
        var level = focus
        while nested.count < depth, let child = level.child, child.isClockLevel {
            nested.append(try clock.cycle(child, at: instant))
            level = child
        }
        var graduationsLit = 0
        if nested.count >= 2, let first = cycle.firstDescendantIndex(at: nested[1].level) {
            graduationsLit = Int(nested[1].index - first)
        }
        let next = try clock.nextThreshold(focus, after: instant)
        let nextSpan = try next.instant.map { try clock.span(from: instant, to: $0).text() } ?? ""
        return Live(
            cycle: cycle,
            nested: nested,
            odometer: try clock.odometer(focus, at: instant),
            points: try clock.points(of: cycle),
            nextThreshold: next,
            nextSpan: nextSpan,
            graduationsLit: graduationsLit,
            sun: focus >= Sync.level ? SunReading.read(clock, at: instant) : nil
        )
    }

    // MARK: What the drawing asks

    /// Half-cycle slots on the carrier: two per child cycle.
    var slotCount: Int { 2 * focus.factor }
    /// Beads on the carrier: one per whole child cycle.
    var beadCount: Int { focus.factor }
    /// Beads lit: through the running child (its sibling counter, SPEC §6.1).
    var beadsLit: Int { live?.nested.first.map { $0.local + 1 } ?? 0 }
    /// Grandchild cycles per child cycle: every such graduation is a long one.
    var graduationsPerBead: Int { focus.child?.factor ?? 1 }
    /// Graduations of the inner bezel: one per grandchild cycle.
    var graduationCount: Int { beadCount * graduationsPerBead }

    /// The words above the centre glyphs: the cycle's own short name for a
    /// unit or a major period (`34η`, `δ#3`); for a level between units,
    /// whose name only says where it starts, the level's letter.
    var title: String {
        guard let live else { return focus.name }
        switch focus.kind {
        case .major, .unit: return live.cycle.shortName
        case .between, .subBlink: return focus.name
        }
    }

    /// What the ring is called aloud: the unit's word, or the letter's.
    var spokenName: String { focus.unit?.name ?? focus.word }
}

/// One counter ring of the orrery: an ancestor level, its children as slots,
/// its phase as a planet (DESIGN.md §5, "Counter rings").
struct CounterReading: Equatable, Sendable {
    let level: Level
    /// Slots: the level's children per cycle.
    let slots: Int
    let live: Live?

    struct Live: Equatable, Sendable {
        /// The running cycle of the ring's own level: its phase places the planet.
        let cycle: Cycle
        /// The running child cycle: `local` is the slot being lit (slots
        /// before it are complete), `phase` how far it is lit.
        let child: Cycle
    }

    /// The four major periods are engraved more faintly (DESIGN.md §13).
    var isMajor: Bool { level.kind == .major }

    static func read(_ clock: Catalogue, at instant: Instant, level: Level) throws -> CounterReading {
        guard let childLevel = level.child else { throw FractonicaError.invalidArgument }
        return CounterReading(
            level: level,
            slots: level.factor,
            live: Live(cycle: try clock.cycle(level, at: instant), child: try clock.cycle(childLevel, at: instant))
        )
    }

    /// The ring with nothing lit: outside the catalogue.
    static func engraved(_ level: Level) -> CounterReading {
        CounterReading(level: level, slots: level.factor, live: nil)
    }
}
