import SwiftUI
import FractonicaKit

/// The nested alternating arcs of a ring (DESIGN.md §5): the half-cycles of
/// level F+1 standing on the carrier, those of F+2 standing on each of them,
/// and so on, split into what has elapsed, what is to come, and the path of
/// arcs that leads to now.
///
/// All geometry is the core's (`Arc.child`, `Arc.cgPoint`); which arc is being
/// lit and how far comes from the running cycles the core returned
/// (`Cycle.localHalfIndex`, `.halfIndexInParentHalf`, `.halfProgress`): never
/// from a multiplied phase.
enum NestRenderer {
    /// The arcs of one nesting depth, grouped by how they are painted.
    struct Layer {
        /// Fully elapsed / still to come.
        var elapsed = CGMutablePath()
        var toCome = CGMutablePath()
        /// In the child cycle that contains now, but not on the path itself.
        var nearElapsed = CGMutablePath()
        var nearToCome = CGMutablePath()
        /// The arc on the path to now, split at now.
        var pathElapsed = CGMutablePath()
        var pathToCome = CGMutablePath()
    }

    /// A built nest: one ``Layer`` per depth (children first) and the point
    /// of now on the deepest arc drawn.
    struct Nest {
        var layers: [Layer] = []
        var nowPoint: CGPoint?
        /// The arcs that hold now, one per depth at most, with how far each
        /// is lit: the only part of a nest that changes from frame to frame.
        fileprivate var current: [(depth: Int, arc: Arc, progress: CGFloat)] = []
    }

    /// Nesting stops when the arcs of a depth fall under this radius (ruling 9).
    static let minimumRadius: CGFloat = 3

    // MARK: Building

    /// Builds the nest on `carrier` for the focus level.
    /// - Parameters:
    ///   - focus: the level of the carrier's cycle.
    ///   - running: the running cycles of F+1, F+2 … (as many as were read);
    ///     `nil` draws everything as "to come" (outside the catalogue, seals).
    ///   - depth: how many nested levels are wanted; fewer are drawn when an
    ///     arc's radius would fall under ``minimumRadius``.
    static func build(carrier: Arc, focus: Level, running: [Cycle]?, depth: Int) -> Nest {
        // A whole cycle closed into a ring carries twice its factor of
        // half-cycles; the path to now starts on the ring itself.
        build(carrier: carrier, level: focus, rootSlots: 2 * focus.factor, secondHalf: false,
              stage: running == nil ? .toCome : .current, running: running, depth: depth)
    }

    /// Where a carrier stands against the moment shown.
    enum Stage {
        /// Wholly in the past: everything on it is lit.
        case elapsed
        /// Wholly ahead: everything on it is engraved.
        case toCome
        /// The moment shown is on it: lit up to there.
        case current
    }

    /// Builds the nest standing on ONE HALF-CYCLE of `level` laid as an arc:
    /// the unit of the wave (WAVE screen), where the cycles of the focused
    /// level follow one another along a line, each half a semicircle from
    /// `Arc.waveRoot`.
    /// - Parameters:
    ///   - carrier: the half-cycle's arc.
    ///   - secondHalf: whether it is the second half of its cycle (its
    ///     children then continue the count and the alternation of the first).
    ///   - stage: where the half stands against the moment shown.
    ///   - running: the running cycles of L+1, L+2 …; used for the cycle that
    ///     holds the moment (both of its halves, so that the child cycle that
    ///     straddles the middle is lit as one), `nil` for any other cycle.
    static func buildHalf(
        carrier: Arc, level: Level, secondHalf: Bool, stage: Stage, running: [Cycle]?, depth: Int
    ) -> Nest {
        build(carrier: carrier, level: level, rootSlots: level.factor, secondHalf: secondHalf,
              stage: stage, running: running, depth: depth)
    }

    /// The nest from the cache when only the lit part of the arcs on the
    /// path to now has moved since it was built (DESIGN.md: precompute per
    /// focus, redraw only the arcs whose fill changed). Everything else (the
    /// hundreds of elapsed and engraved arcs) is built once per state of the
    /// running cycles' indices, and only the path's arcs are split at now
    /// each frame.
    private static func build(
        carrier: Arc, level: Level, rootSlots: Int, secondHalf: Bool, stage: Stage, running: [Cycle]?, depth: Int
    ) -> Nest {
        let key = NestKey(carrier: carrier, level: level, rootSlots: rootSlots, secondHalf: secondHalf,
                          stage: stage, running: running, depth: depth)
        var nest = NestCache.shared.nest(for: key) ?? {
            let built = buildStatic(carrier: carrier, level: level, rootSlots: rootSlots, secondHalf: secondHalf,
                                    stage: stage, running: running, depth: depth)
            NestCache.shared.store(built, for: key)
            return built
        }()
        // The path to now, split at the progress the core gave this frame
        // (the cached arcs carry the progress they were built with; take
        // the live one from the running cycles).
        for layer in nest.layers.indices {
            nest.layers[layer].pathElapsed = CGMutablePath()
            nest.layers[layer].pathToCome = CGMutablePath()
        }
        nest.nowPoint = nil
        for entry in nest.current {
            let progress = running.flatMap { entry.depth < $0.count ? CGFloat($0[entry.depth].halfProgress.value) : nil }
                ?? entry.progress
            entry.arc.addPath(to: nest.layers[entry.depth].pathElapsed, from: 0, to: progress)
            entry.arc.addPath(to: nest.layers[entry.depth].pathToCome, from: progress, to: 1)
            nest.nowPoint = entry.arc.cgPoint(at: progress)
        }
        return nest
    }

    private static func buildStatic(
        carrier: Arc, level: Level, rootSlots: Int, secondHalf: Bool, stage: Stage, running: [Cycle]?, depth: Int
    ) -> Nest {
        // Slots per carrier at each depth: the root's own count, then each
        // level's factor on a half-cycle arc.
        var slots: [Int] = []
        var level = level
        while slots.count < depth, let child = level.child, child.isClockLevel {
            slots.append(slots.isEmpty ? rootSlots : level.factor)
            level = child
        }
        if let running { slots = Array(slots.prefix(running.count)) }
        slots = Array(slots.prefix(fittingDepth(carrier: carrier, slots: slots)))

        var nest = Nest(layers: slots.map { _ in Layer() })
        guard !slots.isEmpty else { return nest }
        descend(arc: carrier, depth: 0, parentOdd: secondHalf, stage: stage, near: false,
                nearChild: running?.first?.local, slots: slots, running: running ?? [], into: &nest)
        return nest
    }

    private static func descend(
        arc: Arc, depth: Int, parentOdd: Bool, stage: Stage, near: Bool, nearChild: Int?,
        slots: [Int], running: [Cycle], into nest: inout Nest
    ) {
        let m = slots[depth]
        // On the second half of a cycle the slots continue the first half's.
        let base = parentOdd ? m : 0
        // The slot being lit on this arc, when now is on it.
        var currentSlot = -1
        var progress: CGFloat = 0
        if stage == .current, depth < running.count {
            let cycle = running[depth]
            // Depth 0 counts in the root's cycle (the ring: all of it; a
            // half-cycle of the wave: from the half's own first slot).
            currentSlot = depth == 0 ? cycle.localHalfIndex - base : cycle.halfIndexInParentHalf
            progress = CGFloat(cycle.halfProgress.value)
        }
        for slot in 0 ..< m {
            // Parity of the child's global half-cycle index: even bulges outward.
            let odd = (base + slot) % 2 == 1
            let child = arc.child(m: m, local: slot, odd: odd)
            guard !child.isEmpty else { continue }

            let childStage: Stage
            switch stage {
            case .elapsed: childStage = .elapsed
            case .toCome: childStage = .toCome
            case .current: childStage = slot < currentSlot ? .elapsed : (slot == currentSlot ? .current : .toCome)
            }
            // "Near": the two half-arcs of the child cycle that contains now,
            // and everything nested on them.
            let isNear = depth == 0 ? nearChild.map { (base + slot) / 2 == $0 } ?? false : near

            switch childStage {
            case .current:
                // Split at now by `build`, every frame.
                nest.current.append((depth, child, progress))
            case .elapsed:
                child.addPath(to: isNear && depth > 0 ? nest.layers[depth].nearElapsed : nest.layers[depth].elapsed)
            case .toCome:
                child.addPath(to: isNear && depth > 0 ? nest.layers[depth].nearToCome : nest.layers[depth].toCome)
            }

            if depth + 1 < slots.count {
                descend(arc: child, depth: depth + 1, parentOdd: odd, stage: childStage, near: isNear,
                        nearChild: nil, slots: slots, running: running, into: &nest)
            }
        }
    }

    /// How many of the wanted depths are drawn: a depth is kept while its
    /// arcs are, on average, at least ``minimumRadius``. A child's radius
    /// depends on its carrier's radius and sweep only, and a carrier's sweep
    /// on its parity, so one arc of each parity per depth tells the radii of
    /// the whole depth.
    ///
    /// The average, not the smallest: the design's own desktop Helion
    /// (R 172, three levels) has one family of great-grandchildren at 2.7 pt
    /// among others of 3.3 to 6 pt, and draws them all (desktop1.png).
    /// Dropping a depth for its smallest family would drop that lace.
    private static func fittingDepth(carrier: Arc, slots: [Int]) -> Int {
        var carriers: [(arc: Arc, odd: Bool)] = [(carrier, false)]
        for (depth, m) in slots.enumerated() {
            var next: [(arc: Arc, odd: Bool)] = []
            for parent in carriers {
                for slot in 0 ..< min(2, m) {
                    let odd = ((parent.odd ? m : 0) + slot) % 2 == 1
                    next.append((parent.arc.child(m: m, local: slot, odd: odd), odd))
                }
            }
            let mean = next.reduce(0) { $0 + CGFloat($1.arc.radius) } / CGFloat(max(next.count, 1))
            if mean < minimumRadius { return depth }
            carriers = next
        }
        return slots.count
    }

    // MARK: Painting

    /// Paints a nest with the styles of the table in DESIGN.md §5, deepest
    /// layer first so that the hero line lies on top.
    /// - Parameter heroWidth: the first-level line (1.4 phone, 1.7 desktop).
    static func paint(_ nest: Nest, heroWidth: CGFloat, in ink: inout Ink) {
        let palette = ink.palette, line = ink.theme.line, glow = ink.theme.glow
        for depth in nest.layers.indices.reversed() {
            let layer = nest.layers[depth]
            let isHero = depth == 0
            let tier = min(depth - 1, line.nested.count - 1)
            let width = isHero ? heroWidth : line.nested[tier]
            let restOpacity = isHero ? 1 : line.nestedOpacity[tier]

            // To come: engraving.
            let toCome = CGMutablePath()
            toCome.addPath(layer.toCome)
            toCome.addPath(layer.nearToCome)
            toCome.addPath(layer.pathToCome)
            ink.stroke(toCome, isHero ? palette.etch3 : palette.etch2, width: isHero ? line.heroToCome : width)
            // Elapsed: the cold light, at rest below the hero.
            ink.stroke(layer.elapsed, isHero ? palette.lumen : palette.lumenMid, width: width,
                       opacity: restOpacity, glow: isHero ? glow.arc : nil)
            // Elapsed inside the child cycle that holds now: brighter.
            ink.stroke(layer.nearElapsed, depth == 1 ? palette.lumen : palette.lumenMid, width: width,
                       opacity: min(1, restOpacity + 0.25))
            // The path to now.
            ink.stroke(layer.pathElapsed, palette.lumen, width: isHero ? width : width * 1.2, glow: glow.arc)
        }
    }
}

// MARK: - The cache of built nests

/// What a nest's static part depends on: the carrier, the level and slots,
/// and, for each running cycle, which cycle it is and which half-cycle slots
/// are lit (never how far: that is split in per frame).
private struct NestKey: Hashable {
    let carrierX: Float, carrierY: Float, radius: Float, start: Float, sweep: Float
    let level: Int, rootSlots: Int, secondHalf: Bool, stage: Int, depth: Int
    let running: [Int64]?

    init(carrier: Arc, level: Level, rootSlots: Int, secondHalf: Bool,
         stage: NestRenderer.Stage, running: [Cycle]?, depth: Int) {
        carrierX = carrier.cx
        carrierY = carrier.cy
        radius = carrier.radius
        start = carrier.start
        sweep = carrier.sweep
        self.level = level.index
        self.rootSlots = rootSlots
        self.secondHalf = secondHalf
        switch stage {
        case .elapsed: self.stage = 0
        case .toCome: self.stage = 1
        case .current: self.stage = 2
        }
        self.depth = depth
        self.running = running?.flatMap { cycle in
            [Int64(cycle.level.index), Int64(bitPattern: cycle.index), Int64(cycle.local),
             Int64(cycle.localHalfIndex), Int64(cycle.halfIndexInParentHalf)]
        }
    }
}

/// A small store of built nests, most recently used kept. The instrument
/// asks for one nest a frame and WAVE for about a dozen (its laps' halves);
/// a few dozen entries hold every nest on screen.
private final class NestCache: @unchecked Sendable {
    static let shared = NestCache()
    private let lock = NSLock()
    private var entries: [NestKey: NestRenderer.Nest] = [:]
    private var order: [NestKey] = []
    private let capacity = 48

    func nest(for key: NestKey) -> NestRenderer.Nest? {
        lock.lock()
        defer { lock.unlock() }
        return entries[key]
    }

    func store(_ nest: NestRenderer.Nest, for key: NestKey) {
        lock.lock()
        defer { lock.unlock() }
        if entries.updateValue(nest, forKey: key) == nil {
            order.append(key)
            if order.count > capacity {
                entries[order.removeFirst()] = nil
            }
        }
    }
}
