import CoreGraphics
import FractonicaKit

/// Where the rings of the instrument are for one focus level: the counter
/// rings of the ancestors, the Sun's ring, the outermost radius (DESIGN.md §5,
/// "Counter rings").
///
///     first ring at 1.37 R, then +g per ring; the Sun's ring sits after ζ at
///     +g and is followed by +1.16 g; the rings from ε outwards step by gM.
///
/// A Helion has seven rings and they fit as designed. A deeper focus has more
/// ancestors than the design has room for: the gaps are then compressed
/// evenly so that the outermost ring stays at ``InstrumentMetrics/maxOuterRadius``.
struct InstrumentGeometry: Equatable, Sendable {
    let metrics: InstrumentMetrics
    let focus: Level
    /// Radius of each ancestor's ring, by level index.
    let ringRadii: [Int: CGFloat]
    /// Radius of the Sun's ring; `nil` when the focus is coarser than the Helion.
    let sunRadius: CGFloat?
    /// Radius of the outermost ring (the hero's reach when there is none).
    let outerRadius: CGFloat
    /// Radius of the hero ring's carrier: R, or less for a level of few
    /// children on an instrument that has no room to move its counter rings
    /// out of the way of such large arcs (see ``init(metrics:focus:)``).
    let heroRadius: CGFloat
    /// Radius of the inner bezel: 0.71 R, or less when the hero's inward arcs
    /// come further in than that (levels of few children have large arcs).
    let bezelRadius: CGFloat
    /// Radius of the first counter ring: 1.37 R, or more when the hero's
    /// outward arcs, with everything nested on them, reach further out.
    let firstRingRadius: CGFloat
    /// Points per design unit of the centre glyphs: the metrics' unit, shrunk
    /// with the bezel so that the pair always fits inside it.
    let glyphUnit: CGFloat

    /// The counter rings are never pressed closer together than this share
    /// of the design's gaps to make room for a hero of large arcs; beyond
    /// that the hero ring itself is drawn smaller.
    static let tightestSqueeze: CGFloat = 0.45

    init(metrics: InstrumentMetrics, focus: Level) {
        self.metrics = metrics
        self.focus = focus
        // How far the hero reaches inwards and outwards, in units of its
        // carrier's radius, measured on the core's own construction
        // (``HeroReach``). For a Helion (18 slots) the arcs stay between
        // 0.84 R and 1.23 R and the design's 0.71 R and 1.37 R hold. A level
        // of 4 or 5 children has arcs that would cross both.
        let reach = HeroReach.of(focus, depth: metrics.nestDepth)
        let margin = metrics.radius * 0.03

        let hasSun = focus >= Sync.level
        let sunAfter = Sync.level.parent          // ζ: the Sun's ring follows it
        let majorFrom = Level.nuclide             // ε and coarser step by gM

        // Offsets from the first ring, in the design's own gaps.
        var offsets: [Int: CGFloat] = [:]
        var sunOffset: CGFloat?
        var offset: CGFloat = 0
        var last: CGFloat = 0
        var level = focus.parent
        while let ring = level {
            offsets[ring.index] = offset
            last = offset
            if hasSun, ring == sunAfter {
                offset += metrics.ringGap
                sunOffset = offset
                last = offset
                offset += metrics.ringGap * 1.16
            } else {
                offset += ring <= majorFrom ? metrics.majorRingGap : metrics.ringGap
            }
            level = ring.parent
        }
        // The first ring stands clear of the hero's outward reach. When
        // that would press the rings closer than `tightestSqueeze` (or than
        // the design's own gaps already are for this many ancestors), the
        // rings stay there and the hero ring is drawn smaller instead.
        var heroRadius = metrics.radius
        var firstRingRadius = max(metrics.firstRingRadius, reach.outer * heroRadius + margin)
        if last > 0 {
            let designSqueeze = min(1, max(metrics.maxOuterRadius - metrics.firstRingRadius, 0) / last)
            let furthest = max(metrics.firstRingRadius,
                               metrics.maxOuterRadius - last * min(designSqueeze, Self.tightestSqueeze))
            if firstRingRadius > furthest {
                firstRingRadius = furthest
                heroRadius = (furthest - margin) / reach.outer
            }
        }
        self.heroRadius = heroRadius
        self.firstRingRadius = firstRingRadius
        // The bezel stays inside the first-level arcs (what is nested on
        // them is engraving fine enough to cross its graduations).
        let bezelRadius = min(metrics.bezelRadius, reach.innerHero * heroRadius - margin)
        self.bezelRadius = bezelRadius
        glyphUnit = metrics.glyphUnit * bezelRadius / metrics.bezelRadius

        // Compress when the ancestors do not fit.
        let room = max(metrics.maxOuterRadius - firstRingRadius, 0)
        let squeeze = last > room && last > 0 ? room / last : 1
        ringRadii = offsets.mapValues { firstRingRadius + $0 * squeeze }
        sunRadius = sunOffset.map { firstRingRadius + $0 * squeeze }
        outerRadius = offsets.isEmpty ? reach.outer * heroRadius : firstRingRadius + last * squeeze
    }

    /// The ancestor whose ring is nearest to `radius` (a tap on the orrery),
    /// if the tap is on the rings at all.
    func ring(atRadius radius: CGFloat) -> Level? {
        guard radius > firstRingRadius - 6, radius < outerRadius + 10 else { return nil }
        return ringRadii.min { abs($0.value - radius) < abs($1.value - radius) }.flatMap { Level($0.key) }
    }
}

/// How far the hero ring reaches from the instrument's centre, in units of
/// its carrier's radius: the first-level arcs alone, and with the levels
/// nested on them.
///
/// Measured, not derived: the arcs are built with the core's construction
/// (`Arc.child`, in the order and parity `NestRenderer` uses) on a carrier of
/// radius 1 000 and sampled along their length (`Arc.point`). The table is
/// built once, for the levels the instrument can focus and the depths it draws.
struct HeroReach: Equatable, Sendable {
    /// Furthest point of the nest from the centre.
    var outer: CGFloat
    /// Nearest point of the first-level arcs to the centre.
    var innerHero: CGFloat

    static func of(_ focus: Level, depth: Int) -> HeroReach {
        let depths = table[min(max(focus.index, 0), table.count - 1)]
        return depths[min(max(depth, 1), depths.count) - 1]
    }

    /// `table[level][depth - 1]`, levels 0...13, depths 1...3.
    private static let table: [[HeroReach]] = Level.all.prefix(14).map { level in
        (1 ... 3).map { measure(level, depth: $0) }
    }

    private static func measure(_ focus: Level, depth: Int) -> HeroReach {
        let unit: Float = 1_000
        let carrier = Arc.fullCircle(cx: 0, cy: 0, radius: unit)
        // Slots per carrier at each depth, as in `NestRenderer`.
        var slots: [Int] = []
        var level = focus
        while slots.count < depth, let child = level.child, child.isClockLevel {
            slots.append(slots.isEmpty ? 2 * level.factor : level.factor)
            level = child
        }
        var reach = HeroReach(outer: 1, innerHero: 1)
        func distance(_ arc: Arc, at t: Float) -> CGFloat {
            let point = arc.point(at: t)
            return CGFloat((point.x * point.x + point.y * point.y).squareRoot() / unit)
        }
        func descend(_ arc: Arc, depth: Int, parentOdd: Bool) {
            let m = slots[depth]
            // The ring repeats every two slots: one arc of each parity is enough.
            for slot in 0 ..< (depth == 0 ? min(2, m) : m) {
                let odd = ((parentOdd ? m : 0) + slot) % 2 == 1
                let child = arc.child(m: m, local: slot, odd: odd)
                guard !child.isEmpty else { continue }
                for step in 0 ... 8 {
                    let d = distance(child, at: Float(step) / 8)
                    reach.outer = max(reach.outer, d)
                    if depth == 0 { reach.innerHero = min(reach.innerHero, d) }
                }
                if depth + 1 < slots.count { descend(child, depth: depth + 1, parentOdd: odd) }
            }
        }
        if !slots.isEmpty { descend(carrier, depth: 0, parentOdd: false) }
        return reach
    }
}
