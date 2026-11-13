import SwiftUI
import FractonicaKit

/// Draws THE INSTRUMENT (DESIGN.md §5): the focused cycle as a ring of nested
/// alternating arcs, its ancestors as counter rings outside it (an orrery:
/// one planet per ring), the Sun's ring, the inner bezel with its graduations
/// and the four thresholds, the alidade, the point of now, and the focus
/// level's phase glyphs at the centre.
///
/// A pure function of a reading: `draw` takes what the core said
/// (``InstrumentReading``), where things are (``InstrumentGeometry``) and
/// draws. It works for any focus level 0...13 and for the engraved,
/// out-of-catalogue state (`reading.live == nil`: nothing lit).
enum InstrumentRenderer {
    /// The in-between states of DESIGN.md §10. `.settled` is a still picture.
    struct Blend: Equatable, Sendable {
        /// The glyphs shown before the last change, and how far the new ones
        /// have faded in (0...1).
        var previousDigits: [Int]?
        var glyph: Double = 1
        /// The threshold that was next before the last crossing, and how far
        /// the light has moved to the new one.
        var previousQuarter: Quarter?
        var threshold: Double = 1
        /// How far the newest bead has turned from hollow to lit.
        var bead: Double = 1
        /// Opacity of the Earth additions (0 pure ... 1 Earth).
        var earth: Double = 0

        static let settled = Blend()
    }

    static func draw(
        _ reading: InstrumentReading, geometry: InstrumentGeometry,
        earth: EarthLayer? = nil, blend: Blend = .settled, in ink: inout Ink
    ) {
        let metrics = geometry.metrics
        if metrics.showsOrrery {
            drawOrrery(reading, geometry: geometry, earth: earth, blend: blend, in: &ink)
        }
        let nest = drawHero(reading, geometry: geometry, in: &ink)
        drawBeads(reading, geometry: geometry, blend: blend, in: &ink)
        drawBezel(reading, geometry: geometry, earth: earth, blend: blend, in: &ink)
        if let live = reading.live {
            if metrics.showsOrrery {
                // The alidade: one hairline through now, from the bezel to
                // just beyond the outermost ring. It is the hand.
                let angle = -CGFloat.pi / 2 + CGFloat(live.cycle.phase.value) * 2 * .pi
                ink.line(
                    from: metrics.center.polar(geometry.bezelRadius, angle),
                    to: metrics.center.polar(geometry.outerRadius + 5, angle),
                    ink.palette.bone, width: ink.theme.line.hairline, opacity: 0.42
                )
            }
            if let point = nest.nowPoint {
                Marks.nowPoint(at: point, radius: metrics.nowPointRadius, in: &ink)
            }
        }
        drawCentre(reading, geometry: geometry, blend: blend, in: &ink)
    }

    // MARK: The orrery

    /// The counter rings of the ancestors and the Sun's ring.
    private static func drawOrrery(
        _ reading: InstrumentReading, geometry: InstrumentGeometry, earth: EarthLayer?, blend: Blend, in ink: inout Ink
    ) {
        let metrics = geometry.metrics
        for counter in reading.counters {
            guard let radius = geometry.ringRadii[counter.level.index] else { continue }
            CounterRingRenderer.draw(
                center: metrics.center, radius: radius, slots: counter.slots,
                currentSlot: counter.live?.child.local,
                slotFill: counter.live?.child.phase.value ?? 0,
                planetPhase: counter.live?.cycle.phase.value ?? 0,
                letter: metrics.showsWords ? counter.level.name : nil,
                style: CounterRingRenderer.style(major: counter.isMajor, metrics: metrics, theme: ink.theme),
                in: &ink
            )
        }
        guard reading.showsSunRing, let radius = geometry.sunRadius else { return }
        let sun = reading.live?.sun
        CounterRingRenderer.draw(
            center: metrics.center, radius: radius, slots: sun?.slots ?? Sync.helions,
            currentSlot: sun?.currentSlot, slotFill: sun?.slotFill ?? 0,
            planetPhase: sun?.sync.phase.value ?? 0, groupStarts: sun?.pentadStarts ?? [],
            letter: nil, style: CounterRingRenderer.sunStyle(metrics: metrics, theme: ink.theme), in: &ink
        )
        if let earth, blend.earth > 0 {
            drawEarthDays(earth.sunTicks, radius: radius, metrics: metrics, opacity: blend.earth, in: &ink)
        }
    }

    /// Earth mode: the civil days of this sync, hung on the Sun's ring.
    private static func drawEarthDays(
        _ ticks: [EarthLayer.SunTick], radius: CGFloat, metrics: InstrumentMetrics, opacity: Double, in ink: inout Ink
    ) {
        let large = metrics.isLarge, center = metrics.center
        let base = radius + 2.2
        let hours = CGMutablePath(), days = CGMutablePath()
        for tick in ticks {
            let angle = -CGFloat.pi / 2 + CGFloat(tick.fraction) * 2 * .pi
            let length: CGFloat
            switch tick.kind {
            case .midnight: length = large ? 9 : 6.5
            case .sixHours: length = large ? 5 : 3.6
            case .hour: length = large ? 2.6 : 1.8
            }
            let path = tick.kind == .midnight ? days : hours
            path.move(to: center.polar(base, angle))
            path.addLine(to: center.polar(base + length, angle))
        }
        ink.stroke(hours, ink.palette.etch3, width: 0.7, opacity: opacity)
        ink.stroke(days, ink.palette.earth, width: 1, opacity: opacity)
        for tick in ticks {
            guard let label = tick.label else { continue }
            let angle = -CGFloat.pi / 2 + CGFloat(tick.fraction) * 2 * .pi + (large ? 9 : 7.5) / radius
            let at = center.polar(base + (large ? 7 : 5), angle)
            ink.text(label, at: CGPoint(x: at.x, y: at.y + 2.4), ink.theme.earthText(large ? 9 : 7),
                     anchor: .middle, knockout: 3, opacity: opacity)
        }
    }

    // MARK: The hero ring

    /// The carrier and the nested arcs on it. Returns the nest for the point
    /// of now.
    private static func drawHero(
        _ reading: InstrumentReading, geometry: InstrumentGeometry, in ink: inout Ink
    ) -> NestRenderer.Nest {
        let palette = ink.palette, line = ink.theme.line, metrics = geometry.metrics
        let carrier = Arc.fullCircle(center: metrics.center, radius: geometry.heroRadius)
        let phase = CGFloat(reading.live?.cycle.phase.value ?? 0)
        // The cycle itself: its elapsed part in resting light.
        ink.stroke(carrier.cgPath(from: phase, to: 1), palette.etch2, width: line.engraving)
        ink.stroke(carrier.cgPath(from: 0, to: phase), palette.lumenDim, width: line.carrierLit)
        let nest = NestRenderer.build(
            carrier: carrier, focus: reading.focus, running: reading.live?.nested, depth: metrics.nestDepth
        )
        NestRenderer.paint(nest, heroWidth: metrics.isLarge ? line.heroDesktop : line.heroPhone, in: &ink)
        return nest
    }

    /// One bead on the carrier at the start of each whole child cycle, lit
    /// through the current one: the children's sibling counter.
    private static func drawBeads(
        _ reading: InstrumentReading, geometry: InstrumentGeometry, blend: Blend, in ink: inout Ink
    ) {
        let palette = ink.palette, count = reading.beadCount, metrics = geometry.metrics
        for bead in 0 ..< count {
            let angle = -CGFloat.pi / 2 + CGFloat(bead) * 2 * .pi / CGFloat(count)
            let at = metrics.center.polar(geometry.heroRadius, angle)
            let lit: Double = bead < reading.beadsLit - 1 ? 1 : (bead == reading.beadsLit - 1 ? blend.bead : 0)
            if lit < 1 {
                ink.circle(at, radius: metrics.beadRadius, fill: palette.void, stroke: palette.etch3, width: 0.8)
            }
            if lit > 0 {
                ink.circle(at, radius: metrics.beadRadius, fill: palette.bone, stroke: palette.bone, width: 0.8, opacity: lit)
            }
        }
    }

    // MARK: The inner bezel

    /// The bezel circle, its graduations (one per grandchild cycle, a long
    /// one per child cycle), and the four thresholds with their words.
    private static func drawBezel(
        _ reading: InstrumentReading, geometry: InstrumentGeometry, earth: EarthLayer?, blend: Blend, in ink: inout Ink
    ) {
        let metrics = geometry.metrics
        let palette = ink.palette, center = metrics.center, bezel = geometry.bezelRadius
        ink.circle(center, radius: bezel, stroke: palette.etch2, width: ink.theme.line.engraving)

        let count = reading.graduationCount
        if count > 0, count <= 400 {
            let lit = CGMutablePath(), unlit = CGMutablePath()
            let litThrough = reading.live.map(\.graduationsLit) ?? -1
            for index in 0 ..< count {
                let angle = -CGFloat.pi / 2 + CGFloat(index) * 2 * .pi / CGFloat(count)
                let length = index % reading.graduationsPerBead == 0 ? metrics.longGraduationLength : metrics.graduationLength
                let path = index <= litThrough ? lit : unlit
                path.move(to: center.polar(bezel, angle))
                path.addLine(to: center.polar(bezel + length, angle))
            }
            ink.stroke(unlit, palette.etch3, width: 0.8)
            ink.stroke(lit, palette.lumenMid, width: 0.9)
        }

        // Thresholds: end at 12, peak at 3, node at 6, valley at 9 o'clock.
        let next = reading.live?.cycle.quarter
        for quarter in Quarter.allCases {
            // How lit this word is: 1 for the next threshold, fading from the
            // previous one during a crossing.
            var light: Double = quarter == next ? blend.threshold : 0
            if quarter == blend.previousQuarter, quarter != next { light = 1 - blend.threshold }
            let angle = Marks.angle(of: quarter)
            let tickStart = center.polar(bezel - metrics.thresholdTickLength, angle)
            let tickEnd = center.polar(bezel, angle)
            ink.line(from: tickStart, to: tickEnd, palette.etch3, width: 0.9, opacity: 1 - light)
            ink.line(from: tickStart, to: tickEnd, palette.now, width: 1.3, opacity: light)
            guard metrics.showsWords else { continue }

            let word = quarter.name
            let size = metrics.bezelWordSize
            let at = center.polar(bezel - metrics.bezelWordInset, angle)
            // Words run along the bezel; the bottom one stays upright.
            let upright = quarter == .node
            let position = CGPoint(x: at.x, y: at.y + (upright ? size * 0.75 : 0))
            let rotation: CGFloat? = upright ? nil : angle + .pi / 2
            if let time = earth?.bezelTimes[quarter], blend.earth > 0 {
                // Earth mode appends the threshold's clock time (`END 12:56`).
                // While the mode is changing the bare word leaves as the
                // translated one arrives.
                drawBezelWord(word, at: position, size: size, rotation: rotation,
                              light: light, opacity: 1 - blend.earth, in: &ink)
                drawBezelWord("\(word) \(time)", at: position, size: size, rotation: rotation,
                              light: light, opacity: blend.earth, in: &ink)
            } else {
                drawBezelWord(word, at: position, size: size, rotation: rotation, light: light, opacity: 1, in: &ink)
            }
        }
    }

    private static func drawBezelWord(
        _ word: String, at position: CGPoint, size: CGFloat, rotation: CGFloat?,
        light: Double, opacity: Double, in ink: inout Ink
    ) {
        let palette = ink.palette
        let tracking: CGFloat = 0.2
        ink.text(word, at: position, ink.theme.engraved(size, palette.etch3, tracking: tracking),
                 anchor: .middle, rotation: rotation, opacity: (1 - light) * opacity)
        ink.text(word, at: position, ink.theme.engraved(size, palette.now, tracking: tracking),
                 anchor: .middle, rotation: rotation, opacity: light * opacity)
    }

    // MARK: The centre

    /// The focused level's odometer: two 2-stroke glyphs, with the cycle's
    /// own name above them.
    private static func drawCentre(
        _ reading: InstrumentReading, geometry: InstrumentGeometry, blend: Blend, in ink: inout Ink
    ) {
        let metrics = geometry.metrics
        let unit = geometry.glyphUnit, center = metrics.center
        let glyphCentre = CGPoint(x: center.x, y: center.y + (metrics.showsWords ? unit * 0.4 : 0))
        if let odometer = reading.live?.odometer {
            let glow = ink.theme.glow.glyph
            if let previous = blend.previousDigits, blend.glyph < 1 {
                let old = previous.compactMap { try? Glyph(index: $0, strokes: odometer.strokes) }
                GlyphRenderer.drawRow(old, center: glyphCentre, unit: unit, color: ink.palette.lumen,
                                      glow: glow, opacity: 1 - blend.glyph, snap: true, in: &ink)
            }
            GlyphRenderer.drawRow(odometer.glyphs, center: glyphCentre, unit: unit, color: ink.palette.lumen,
                                  glow: glow, opacity: blend.glyph, snap: true, in: &ink)
        }
        if metrics.showsWords {
            ink.text(reading.title, at: CGPoint(x: center.x, y: center.y - unit * 5.05),
                     ink.theme.value(metrics.titleSize), anchor: .middle)
        }
    }
}
