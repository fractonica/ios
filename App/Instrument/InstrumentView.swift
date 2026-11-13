import SwiftUI
import FractonicaKit

/// The hero: the instrument for the model's focus at the model's instant,
/// with its motion, its gestures and its accessibility elements.
///
///     InstrumentView(metrics: .standard(space.layout))
///
/// - **Drawing**: `InstrumentRenderer`, on a `MotionCanvas`.
/// - **Motion** (DESIGN.md §10): the zoom between focus levels, and the
///   cross-fades of glyphs, bezel words and beads, see ``InstrumentMotion``.
///   With Reduce Motion they are cuts.
/// - **Gestures** (§8): pinch or two-finger rotate to change the scale, tap a
///   counter ring to focus it, tap the centre to open the lens on the focus.
/// - **Accessibility**: the hero ring, each counter ring and the Sun's ring
///   are one element each, labelled with their reading in the current mode.
struct InstrumentView: View {
    let metrics: InstrumentMetrics

    @Environment(AppModel.self) private var model
    @Environment(\.designSpace) private var space
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Where the zoom is on the ladder of levels; `nil` until the focus first changes.
    @State private var zoom: Double?
    @State private var glyphFade = FadeClock()
    @State private var thresholdFade = FadeClock()
    @State private var beadFade = FadeClock()
    @State private var motion = InstrumentMotion()
    @State private var previous: InstrumentSteps?
    /// The focus when a pinch or a rotation began.
    @State private var gestureBase: Level?
    /// What the pinch or the twist has moved the focus by (one of the two).
    @State private var twoFingers = TwoFingerSteps()

    var body: some View {
        let clock = model.clock, instant = model.instant, focus = model.focus
        let zone = model.timeZone, metrics = metrics
        let reading = InstrumentReading.read(clock, at: instant, focus: focus, depth: metrics.nestDepth)
        let geometry = InstrumentGeometry(metrics: metrics, focus: focus)
        let steps = InstrumentSteps(reading)
        let previous = previous
        let fades = (glyph: glyphFade, threshold: thresholdFade, bead: beadFade)

        var target = motion
        target.zoom = zoom ?? Double(focus.index)
        target.earth = model.mode == .earth ? 1 : 0

        return ZStack {
            MotionCanvas(value: target) { ink, motion in
                let low = Int(motion.zoom.rounded(.down))
                let part = motion.zoom - Double(low)
                if part < 0.002 || part > 0.998 || Level(low) == nil {
                    // Settled on one level: the still instrument with its cross-fades.
                    var blend = InstrumentRenderer.Blend.settled
                    blend.earth = motion.earth
                    if let previous, previous.focus == focus {
                        blend.previousDigits = previous.digits
                        blend.glyph = fades.glyph.progress(at: motion.glyph)
                        blend.previousQuarter = previous.quarter
                        blend.threshold = fades.threshold.progress(at: motion.threshold)
                        blend.bead = fades.bead.progress(at: motion.bead)
                    }
                    let earth = motion.earth > 0 ? EarthLayer.read(reading, clock: clock, at: instant, zone: zone) : nil
                    InstrumentRenderer.draw(reading, geometry: geometry, earth: earth, blend: blend, in: &ink)
                } else {
                    // Between two levels: the coarser one swells past 1.37 R to
                    // become the innermost counter ring of the finer one.
                    InstrumentView.drawZoom(
                        clock: clock, instant: instant, low: low, part: part,
                        metrics: metrics, earth: motion.earth, in: &ink
                    )
                }
            }
            .animation(Motion.mode.animation(reduceMotion: reduceMotion), value: model.mode)

            touchLayer(geometry: geometry)
            spokenElements(reading: reading, geometry: geometry)
        }
        .onChange(of: focus) { _, new in
            withAnimation(Motion.zoom.animation(reduceMotion: reduceMotion)) { zoom = Double(new.index) }
        }
        .onChange(of: steps) { old, new in
            stepped(from: old, to: new)
        }
    }

    // MARK: Motion

    /// The instrument half way between two focus levels: both drawn, scaled
    /// about the centre so that the coarser one's hero ring and the finer
    /// one's first counter ring coincide, and cross-faded.
    private static func drawZoom(
        clock: Catalogue, instant: Instant, low: Int, part: Double,
        metrics: InstrumentMetrics, earth: Double, in ink: inout Ink
    ) {
        let ratio = Double(metrics.firstRingRadius / metrics.radius)
        for (index, opacity, exponent) in [(low, 1 - part, part), (low + 1, part, part - 1)] {
            guard let level = Level(index) else { continue }
            let reading = InstrumentReading.read(clock, at: instant, focus: level, depth: metrics.nestDepth)
            let geometry = InstrumentGeometry(metrics: metrics, focus: level)
            ink.layer(opacity: opacity, scale: CGFloat(pow(ratio, exponent)), about: metrics.center) { layer in
                InstrumentRenderer.draw(reading, geometry: geometry, in: &layer)
            }
        }
    }

    /// Something changed in a step: remember what was shown and start the
    /// matching cross-fade. A change of focus is the zoom's business, and a
    /// focus finer than ι changes state faster than a fade lasts.
    private func stepped(from old: InstrumentSteps, to new: InstrumentSteps) {
        guard old.focus == new.focus, new.focus <= .preon else {
            previous = nil
            return
        }
        previous = old
        if old.digits != new.digits {
            let to = glyphFade.advance()
            withAnimation(Motion.glyph.animation(reduceMotion: reduceMotion)) { motion.glyph = to }
        }
        if old.quarter != new.quarter {
            let to = thresholdFade.advance()
            withAnimation(Motion.threshold.animation(reduceMotion: reduceMotion)) { motion.threshold = to }
        }
        if new.beads == old.beads + 1 {
            let to = beadFade.advance()
            withAnimation(Motion.bead.animation(reduceMotion: reduceMotion)) { motion.bead = to }
        }
    }

    // MARK: Gestures

    /// One transparent disc over the instrument that takes the taps, the
    /// pinch and the rotation.
    private func touchLayer(geometry: InstrumentGeometry) -> some View {
        let reach = geometry.outerRadius + 8
        return Color.clear
            .contentShape(Circle())
            .designFrame(center: metrics.center, radius: reach)
            .onTapGesture(coordinateSpace: .local) { location in
                // A placed view fills its parent, so "local" is the screen.
                let point = space.designPoint(location)
                let radius = hypot(point.x - metrics.center.x, point.y - metrics.center.y)
                if radius < geometry.bezelRadius {
                    model.openLens()
                } else if let ring = geometry.ring(atRadius: radius) {
                    model.setFocus(ring)
                }
            }
            .gesture(SimultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in
                        // One level per factor of 1.37: the ratio between the
                        // hero ring and the first counter ring.
                        twoFingers.pinch(magnification: Double(value.magnification),
                                         ratio: Double(metrics.firstRingRadius / metrics.radius))
                        applyGesture()
                    }
                    .onEnded { _ in endGesture() },
                RotateGesture()
                    .onChanged { value in
                        // The limb turns with the fingers: one letter per step.
                        twoFingers.twist(degrees: value.rotation.degrees, step: Double(metrics.limbStepDegrees))
                        applyGesture()
                    }
                    .onEnded { _ in endGesture() }
            ))
            .accessibilityHidden(true)
    }

    private func applyGesture() {
        let base = gestureBase ?? model.focus
        if gestureBase == nil { gestureBase = base }
        if let level = Level(base.index + twoFingers.steps) {
            model.setFocus(level)
        } else {
            model.setFocus(twoFingers.steps > 0 ? Level.all[Level.count - 1] : .alpha)
        }
    }

    private func endGesture() {
        gestureBase = nil
        twoFingers = TwoFingerSteps()
    }

    // MARK: Accessibility

    /// One element per ring, placed where the ring's planet (or the hero's
    /// centre) is. Pure mode passes no zone, so nothing Earthly is spoken.
    private func spokenElements(reading: InstrumentReading, geometry: InstrumentGeometry) -> some View {
        let zone: TimeZone? = model.mode == .earth ? model.timeZone : nil
        let now = NowReading.read(model.clock, at: model.instant, focus: model.focus)
        // Accessibility modifiers come before `.designFrame`: a placed view
        // fills its parent, and the element must be the small rectangle.
        return ZStack {
            Color.clear
                .accessibilityElement()
                .accessibilityLabel(InstrumentSpeech.heroLabel(reading))
                .accessibilityValue(InstrumentSpeech.heroValue(reading, outOfCatalogue: now.outOfCatalogue, zone: zone))
                .accessibilityHint("Opens the lens")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { model.openLens() }
                .designFrame(center: metrics.center, radius: geometry.bezelRadius)

            ForEach(reading.counters, id: \.level) { counter in
                Color.clear
                    .accessibilityElement()
                    .accessibilityLabel(InstrumentSpeech.counterLabel(counter))
                    .accessibilityValue(InstrumentSpeech.counterValue(counter, outOfCatalogue: now.outOfCatalogue))
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { model.setFocus(counter.level) }
                    .designFrame(center: planet(counter.live?.cycle.phase.value, radius: geometry.ringRadii[counter.level.index]), radius: 14)
            }

            if reading.showsSunRing {
                Color.clear
                    .accessibilityElement()
                    .accessibilityLabel(InstrumentSpeech.sunLabel)
                    .accessibilityValue(InstrumentSpeech.sunValue(now, zone: zone))
                    .designFrame(center: planet(reading.live?.sun?.sync.phase.value, radius: geometry.sunRadius), radius: 14)
            }
        }
        .allowsHitTesting(false)
    }

    /// Where a ring's planet is (12 o'clock when the ring is engraved).
    private func planet(_ phase: Double?, radius: CGFloat?) -> CGPoint {
        metrics.center.polar(radius ?? metrics.firstRingRadius, -CGFloat.pi / 2 + CGFloat(phase ?? 0) * 2 * .pi)
    }
}
