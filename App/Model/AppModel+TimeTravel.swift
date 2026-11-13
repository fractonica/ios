import CoreGraphics
// Not all of Foundation: its own `Unit` would hide the kit's.
import struct Foundation.TimeZone
import FractonicaKit

// Time travel (DESIGN.md §8, "Through time"): the ways the cursor moves.
// All of them end in `scrub(to:)`, which clamps to the catalogue, so the
// instrument, the lens and the ladder show the scrubbed moment too.

extension AppModel {
    /// The tumbler the keys step: the one last touched, else the unit just
    /// finer than the focus (the wave's own grain: the Preon for a Helion
    /// wave). An Earth field counts only in Earth mode.
    var activeStampField: StampField {
        if let stampField {
            if case .earth = stampField, mode == .pure { return defaultStampField }
            return stampField
        }
        return defaultStampField
    }

    private var defaultStampField: StampField {
        .unit(focus.finerUnit ?? .blink)
    }

    /// Selects the tumbler beside the active one (⌥← ⌥→): the nine terms of
    /// the stamp, then, in Earth mode, the six Earth fields.
    func selectStampField(by steps: Int) {
        var fields = Unit.allCases.map(StampField.unit)
        if mode == .earth { fields += EarthField.allCases.map(StampField.earth) }
        guard let index = fields.firstIndex(of: activeStampField) else { return }
        stampField = fields[min(max(index + steps, 0), fields.count - 1)]
    }

    /// Steps one term of the moment by whole units (a tumbler, ↑ ↓). Does
    /// nothing when the step would leave the catalogue. An Earth field is
    /// stepped only in Earth mode.
    /// - Returns: whether the moment moved (a tumbler being pulled counts
    ///   only the steps that were taken, so pulling it back undoes exactly
    ///   those).
    @discardableResult
    func step(_ field: StampField, by steps: Int) -> Bool {
        guard steps != 0 else { return false }
        let zone: TimeZone? = mode == .earth ? timeZone : nil
        guard let stepped = WaveStepping.instant(clock, from: instant, field: field, by: steps, zone: zone) else {
            return false
        }
        scrub(to: stepped)
        return true
    }

    /// Steps the active tumbler: the arrow keys on the WAVE screen.
    func stepStamp(by steps: Int) {
        step(activeStampField, by: steps)
    }

    /// Moves the cursor along the wave of `level` by a number of its cycles,
    /// counted from `origin` (a drag is measured from where it began).
    func scrub(alongWaveOf level: Level, from origin: Instant, cycles: Double) {
        scrub(to: WaveTrack.instant(in: clock, level: level, from: origin, movedBy: cycles))
    }

    /// After a flick the wave keeps moving and slows by 0.92 a frame
    /// (DESIGN.md §10), then settles (``settleOnWave(cycleWidth:within:)``).
    /// - Parameters:
    ///   - velocity: points per second along the wave, positive to the right
    ///     (the past comes under the hairline).
    ///   - cycleWidth: the wave's points per cycle.
    /// The coast is the model's: any other move through time
    /// (``scrub(to:)``, ``returnToNow()``) stops it.
    func glide(alongWaveOf level: Level, velocity: CGFloat, cycleWidth: CGFloat) {
        stopGlide()
        coastTask = Task { @MainActor [weak self] in
            var speed = velocity
            let frame = 1.0 / 60
            while abs(speed) > 14 {
                try? await Task.sleep(for: .seconds(frame))
                guard let self, !Task.isCancelled else { return }
                let moved = WaveTrack.instant(in: self.clock, level: level, from: self.instant,
                                              movedBy: Double(-speed * frame / cycleWidth))
                self.moveCursorWhileGliding(to: moved)
                speed *= 0.92
            }
            guard let self, !Task.isCancelled else { return }
            self.coastTask = nil
            self.settleOnWave(cycleWidth: cycleWidth)
        }
    }

    /// Where a released drag settles (DESIGN.md §10: "snap within 6 pt"):
    /// on the present when it is that close, else on the nearest threshold
    /// of the focused cycle that is. `cycleWidth` is the wave's points per
    /// cycle.
    func settleOnWave(cycleWidth: CGFloat, within reach: CGFloat = 6) {
        guard let cursor else { return }
        switch WaveSnap.target(in: clock, level: focus, at: cursor, now: now, cycleWidth: cycleWidth, within: reach) {
        case .present: returnToNow()
        case .threshold(let instant): scrub(to: instant)
        case nil: break
        }
    }

    /// The threshold of the focused level before (−1) or after (+1) the
    /// moment shown: how assistive technology walks the wave.
    func stepThreshold(by direction: Int) {
        guard let cycle = try? clock.cycle(focus, at: instant) else { return }
        if direction > 0 {
            if let next = try? clock.nextThreshold(focus, after: instant).instant { scrub(to: next) }
            return
        }
        // The latest boundary strictly before the moment: one of this
        // cycle's, else the last quarter boundary of the cycle before it.
        let here = (try? clock.points(of: cycle)).map { [$0.start, $0.peak, $0.node, $0.valley] } ?? []
        if let earlier = here.compactMap({ $0 }).filter({ $0 < instant }).max() {
            scrub(to: earlier)
        } else if cycle.index > 0, let before = try? clock.points(focus, index: cycle.index - 1).valley {
            scrub(to: before)
        }
    }
}

/// Snapping a released drag of the wave.
enum WaveSnap {
    enum Target: Equatable {
        /// The present: the cursor is dropped.
        case present
        case threshold(Instant)
    }

    /// What lies within `reach` points of the hairline at `instant`, on a
    /// wave drawn `cycleWidth` points per cycle: the present first, else the
    /// nearest of the five quarter points of the cycle under the hairline.
    /// Distances are measured along the wave (``WaveTrack``); the instants
    /// snapped to are the core's.
    static func target(
        in clock: Catalogue, level: Level, at instant: Instant, now: Instant, cycleWidth: CGFloat, within reach: CGFloat
    ) -> Target? {
        func distance(to other: Instant) -> CGFloat? {
            WaveTrack.cycles(in: clock, level: level, from: instant, to: other).map { abs(CGFloat($0)) * cycleWidth }
        }
        if let toNow = distance(to: now), toNow < reach { return .present }
        guard let cycle = try? clock.cycle(level, at: instant), let points = try? clock.points(of: cycle) else {
            return nil
        }
        let candidates = [points.start, points.peak, points.node, points.valley, points.end].compactMap { $0 }
        let nearest = candidates
            .compactMap { point in distance(to: point).map { (point, $0) } }
            .min { $0.1 < $1.1 }
        guard let nearest, nearest.1 < reach, nearest.0 != instant else { return nil }
        return .threshold(nearest.0)
    }
}
