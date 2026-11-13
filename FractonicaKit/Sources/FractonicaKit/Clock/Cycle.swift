import CFractonica

/// One cycle of one level, and where an instant sits in it (`frc_cycle_t`,
/// SPEC §3.2, §6.1).
///
/// `start ..< end` is half-open; the end of cycle `c` is the start of `c + 1`.
/// One exception: the catalogue's closing instant belongs to the last cycle,
/// so a reading taken exactly there has `instant == end`.
///
/// Levels 19...21 have cycles shorter than a microsecond; read the note on
/// `frc_cycle_t` in fractonica.h before relying on `start < end` there.
public struct Cycle: Hashable, Sendable {
    public let level: Level
    /// Global index of the cycle in the catalogue, 0-based.
    public let index: UInt64
    /// Index inside the parent cycle, 0-based. This is also the **sibling
    /// counter** of SPEC §6.1: light markers `0 ... local` of ``siblings``.
    /// For Alpha (no parent) it equals ``index``.
    public let local: Int
    /// Cycles per parent; for Alpha, the number of Alphas in the catalogue.
    public let siblings: Int
    /// The quarter the instant is in (`.peak` for a cycle asked for by index).
    public let quarter: Quarter
    /// Fraction of the cycle done, linear in position (zero for a cycle asked
    /// for by index). For lighting arcs; not for logic.
    public let phase: Fraction
    /// First microsecond of the cycle.
    public let start: Instant
    /// First microsecond after it; the closing instant when ``isClipped``.
    public let end: Instant
    /// Whether the catalogue ends inside this cycle.
    public let isClipped: Bool

    init(_ raw: frc_cycle_t) {
        level = Level(unchecked: Int(raw.level))
        index = raw.cycle
        local = Int(raw.local)
        siblings = Int(raw.siblings)
        quarter = Quarter(field: raw.quarter)
        phase = Fraction(raw: raw.phase)
        start = Instant(microseconds: raw.start)
        end = Instant(microseconds: raw.end)
        isClipped = raw.clipped != 0
    }

    // MARK: The header's navigation recipes (fractonica.h, "Navigating the tree")

    /// Global index of the parent cycle, one level coarser:
    /// `index / frc_siblings(level)`. `nil` for Alpha.
    public var parentIndex: UInt64? {
        let siblings = frc_siblings(level.raw)
        return siblings == 0 ? nil : index / UInt64(siblings)
    }

    /// Global index of the first child cycle, one level finer:
    /// `index * frc_factor(level)`. The children are the next
    /// ``Level/factor`` indices. `nil` if it does not fit 64 bits.
    public var firstChildIndex: UInt64? {
        let (product, overflow) = index.multipliedReportingOverflow(by: UInt64(frc_factor(level.raw)))
        return overflow ? nil : product
    }

    /// Global index of this cycle's first descendant at a finer `level`: the
    /// first-child recipe applied once per level on the way down. A running
    /// descendant's index minus this is how many of them are complete inside
    /// this cycle (at vector A: Preon index − the Helion's first Preon = 29,
    /// the `29ι` of the reading and the lit graduations of the bezel).
    /// `nil` for a coarser level or when the index does not fit 64 bits.
    public func firstDescendantIndex(at descendantLevel: Level) -> UInt64? {
        guard descendantLevel >= level else { return nil }
        var descendant = index
        for step in level.index ..< descendantLevel.index {
            let (product, overflow) = descendant.multipliedReportingOverflow(by: UInt64(frc_factor(UInt8(step))))
            if overflow { return nil }
            descendant = product
        }
        return descendant
    }

    /// Global index of the ancestor of this cycle at a coarser `level`: the
    /// parent recipe applied once per level on the way up. Two cycles belong
    /// to the same ancestor when these agree. `nil` for a finer level.
    public func ancestorIndex(at ancestorLevel: Level) -> UInt64? {
        guard ancestorLevel <= level else { return nil }
        var ancestor = index
        for step in stride(from: level.index, to: ancestorLevel.index, by: -1) {
            ancestor /= UInt64(frc_siblings(UInt8(step)))
        }
        return ancestor
    }

    // MARK: Half-cycles, the unit of the arc geometry (fractonica.h, same place)

    /// Whether the instant is in the second half of the cycle
    /// (`phase >= FRC_FRAC_HALF`).
    public var isInSecondHalf: Bool { phase >= .half }

    /// Global half-cycle index: `2 * index + (phase >= half)`. Its parity is
    /// the `odd` argument of ``Arc/child(m:local:odd:)``.
    public var halfIndex: UInt64 { 2 &* index &+ (isInSecondHalf ? 1 : 0) }

    /// The running half-cycle's place among the half-cycles of the parent
    /// cycle: `2 * local + (phase >= half)`, in `0 ..< 2 * siblings`. On a
    /// ring whose carrier is the parent cycle this is the slot being lit.
    public var localHalfIndex: Int { 2 * local + (isInSecondHalf ? 1 : 0) }

    /// The running half-cycle's place inside the parent's running HALF:
    /// ``localHalfIndex`` counted from the start of whichever half of the
    /// parent the instant is in, in `0 ..< siblings`. A half-cycle arc of the
    /// parent level carries `siblings` half-cycle arcs of this level (see
    /// ``Arc``); this is the one being lit on it. (The parent is in its
    /// second half exactly when `localHalfIndex >= siblings`.)
    public var halfIndexInParentHalf: Int {
        let half = localHalfIndex
        return half >= siblings ? half - siblings : half
    }

    /// How much of the running half-cycle is done: `phase << 1`.
    public var halfProgress: Fraction { Fraction(raw: phase.raw << 1) }

    // MARK: Name

    /// The cycle's name (SPEC §15.3, `frc_format_cycle_name`): `"Delta
    /// Trifracton"` for a major level, `"ε#2"` for a Nuclide, and for a finer
    /// cycle where it starts in its Nuclide, `"ε#2 5η 9ι"`.
    public var name: String {
        CoreText.infallible { frc_format_cycle_name(level.raw, index, 0, $0, $1) }
    }

    /// The short name: `"δ#3"`, `"ε#2"`, or the finest placing count alone (`"9ι"`).
    public var shortName: String {
        CoreText.infallible { frc_format_cycle_name(level.raw, index, 1, $0, $1) }
    }

    /// Which of its siblings the cycle is, counted from one
    /// (`frc_format_cycle_place`): `"8 of 9"` for ``local`` 7 of 9 siblings;
    /// an Alpha counts the Alphas of the catalogue (`"6 of 18"`).
    public var placeText: String {
        var raw = frc_cycle_t()
        raw.level = level.raw
        raw.local = UInt16(clamping: local)
        raw.siblings = UInt16(clamping: siblings)
        raw.cycle = index
        return CoreText.infallible { frc_format_cycle_place(&raw, $0, $1) }
    }
}

/// The five quarter points of a cycle (`frc_cycle_points`). A point beyond the
/// catalogue is `nil`.
public struct CyclePoints: Hashable, Sendable {
    public let start: Instant?
    public let peak: Instant?
    public let node: Instant?
    public let valley: Instant?
    public let end: Instant?

    /// The instant of the threshold that ends `quarter`.
    public subscript(quarter: Quarter) -> Instant? {
        switch quarter {
        case .peak: return peak
        case .node: return node
        case .valley: return valley
        case .end: return end
        }
    }
}

/// A threshold: which quarter boundary, and when (`frc_threshold_t`, SPEC §6.2).
public struct Threshold: Hashable, Sendable {
    /// The quarter this boundary ends (a `.node` threshold is the node).
    public let quarter: Quarter
    /// When; `nil` when it falls after the catalogue (asked at the closing
    /// instant) or does not apply (``Sync/next`` of a sync asked for by number).
    public let instant: Instant?

    init(_ raw: frc_threshold_t) {
        quarter = Quarter(field: raw.name)
        instant = Instant(raw: raw.time)
    }
}

// MARK: - Reading cycles

extension Catalogue {
    /// The cycle of `level` running at `instant` (`frc_cycle_at`).
    /// - Throws: ``FractonicaError/outOfRange`` outside the catalogue;
    ///   ``FractonicaError/invalidArgument`` for a level above ``Level/clockMax``.
    public func cycle(_ level: Level, at instant: Instant) throws -> Cycle {
        Cycle(try read(into: frc_cycle_t()) { frc_cycle_at($0, instant.microseconds, level.raw, $1) })
    }

    /// The cycle with global index `index` (`frc_cycle_by_index`); its phase
    /// is zero and its quarter `.peak`.
    /// - Throws: ``FractonicaError/outOfRange`` when `index >= cycleCount(level)`.
    public func cycle(_ level: Level, index: UInt64) throws -> Cycle {
        Cycle(try read(into: frc_cycle_t()) { frc_cycle_by_index($0, level.raw, index, $1) })
    }

    /// Number of cycles of `level` in the catalogue, the last partial one
    /// included (`frc_cycle_count`); 0 for a level the clock does not read.
    /// For Alpha on Saros 141 this is 18: the catalogue is α#1 – α#18.
    public func cycleCount(_ level: Level) -> UInt64 {
        withRaw { frc_cycle_count($0, level.raw) }
    }

    /// The five quarter points of a cycle (`frc_cycle_points`).
    public func points(of cycle: Cycle) throws -> CyclePoints {
        try points(cycle.level, index: cycle.index)
    }

    /// The five quarter points of cycle `index` of `level`.
    public func points(_ level: Level, index: UInt64) throws -> CyclePoints {
        var times = [frc_time_t](repeating: 0, count: 5)
        try check(withRaw { frc_cycle_points($0, level.raw, index, &times) })
        return CyclePoints(
            start: Instant(raw: times[0]), peak: Instant(raw: times[1]), node: Instant(raw: times[2]),
            valley: Instant(raw: times[3]), end: Instant(raw: times[4])
        )
    }

    /// The first quarter boundary of `level` strictly after `instant`
    /// (`frc_next_threshold`). Schedule the next redraw of a threshold mark
    /// at its instant; the reading taken there already shows the new quarter.
    public func nextThreshold(_ level: Level, after instant: Instant) throws -> Threshold {
        Threshold(try read(into: frc_threshold_t()) {
            frc_next_threshold($0, instant.microseconds, level.raw, $1)
        })
    }

    /// The instant at which cycle `index` of `level` reaches `phase`
    /// (`frc_time_at_phase`): the first microsecond at or after it, the
    /// phase being linear in position as ``Cycle/phase`` is. Phase zero is
    /// the cycle's start, ``Fraction/quarter`` its Peak, ``Fraction/half``
    /// its Node: the inverse of the phase, for a scrub.
    /// - Returns: `nil` for a level the clock does not read, an index beyond
    ///   the catalogue, or a phase of the last (clipped) cycle after the
    ///   closing instant.
    public func instant(_ level: Level, index: UInt64, atPhase phase: Fraction) -> Instant? {
        Instant(raw: withRaw { frc_time_at_phase($0, level.raw, index, phase.raw) })
    }

    // MARK: Walking the tree

    /// The parent cycle (one level coarser); `nil` for an Alpha.
    public func parent(of cycle: Cycle) throws -> Cycle? {
        guard let parentLevel = cycle.level.parent, let parentIndex = cycle.parentIndex else { return nil }
        return try self.cycle(parentLevel, index: parentIndex)
    }

    /// The child cycles (one level finer), in order: ``Level/factor`` of them,
    /// fewer when the catalogue ends inside this cycle. Empty for a cycle of
    /// the deepest clock level.
    public func children(of cycle: Cycle) throws -> [Cycle] {
        guard let childLevel = cycle.level.child, childLevel.isClockLevel,
              let first = cycle.firstChildIndex
        else { return [] }
        let total = cycleCount(childLevel)
        var children: [Cycle] = []
        for offset in 0 ..< UInt64(cycle.level.factor) {
            let (index, overflow) = first.addingReportingOverflow(offset)
            if overflow || index >= total { break }
            children.append(try self.cycle(childLevel, index: index))
        }
        return children
    }
}

// MARK: - Names without a catalogue

extension Level {
    /// The name of cycle `index` of this level (`frc_format_cycle_name`);
    /// see ``Cycle/name``. With `short`: `"δ#3"`, `"ε#2"`, `"9ι"`.
    /// - Throws: ``FractonicaError/invalidArgument`` for a level above ``Level/clockMax``.
    public func cycleName(index: UInt64, short: Bool = false) throws -> String {
        try CoreText.make { frc_format_cycle_name(raw, index, short ? 1 : 0, $0, $1) }
    }
}
