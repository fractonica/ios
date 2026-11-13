import SwiftUI
import FractonicaKit

/// The lens's ring (DESIGN.md §7 "Lens", §6): the inspected rung's running
/// cycle at R 54 with two nested levels, its beads, the point of now and its
/// two glyphs, and around it the four thresholds, each with the glyph state
/// the cycle reaches there and how far away it is.
///
/// Only a rung the instrument can show has a live ring (levels 0...13,
/// design/README.md ruling 9). A deeper rung gets its seal in the same
/// place, engraved: a static fact, nothing lit.
enum LensRing {
    // MARK: The live ring

    static func draw(_ ring: LensReading.Ring, layout: LensLayout, earth: Double, in ink: inout Ink) {
        let palette = ink.palette, theme = ink.theme, line = theme.line
        let center = layout.ringCenter, scale = layout.ringScale
        let reading = ring.instrument
        // The thresholds stand where the first counter ring of the
        // instrument would be: 1.37 R. A level of few children has arcs that
        // reach further out than that, so its ring is drawn smaller to stay
        // inside them.
        let tickRadius = layout.ringRadius * 1.37
        let wanted = InstrumentGeometry(metrics: .inspector(center: center, radius: layout.ringRadius), focus: reading.focus)
        let radius = layout.ringRadius * min(1, tickRadius / wanted.firstRingRadius)
        let geometry = InstrumentGeometry(metrics: .inspector(center: center, radius: radius), focus: reading.focus)

        // The carrier and the arcs nested on it.
        let carrier = Arc.fullCircle(center: center, radius: radius)
        let phase = CGFloat(reading.live?.cycle.phase.value ?? 0)
        ink.stroke(carrier.cgPath(from: phase, to: 1), palette.etch2, width: line.engraving)
        ink.stroke(carrier.cgPath(from: 0, to: phase), palette.lumenDim, width: line.carrierLit)
        let nest = NestRenderer.build(carrier: carrier, focus: reading.focus, running: reading.live?.nested, depth: 2)
        NestRenderer.paint(nest, heroWidth: line.heroPhone * (layout.layout == .desktop ? 1.1 : 0.93), in: &ink)

        // Beads: the children's sibling counter.
        for bead in 0 ..< reading.beadCount {
            let at = center.polar(radius, -CGFloat.pi / 2 + CGFloat(bead) * 2 * .pi / CGFloat(reading.beadCount))
            let lit = bead < reading.beadsLit
            ink.circle(at, radius: 1.5 * scale, fill: lit ? palette.bone : palette.void,
                       stroke: lit ? palette.bone : palette.etch3, width: 0.7)
        }
        if reading.live != nil, let point = nest.nowPoint {
            Marks.nowPoint(at: point, radius: 2.2 * scale, in: &ink)
        }
        if let odometer = reading.live?.odometer {
            // The design sets these glyphs at 3.5 pt per unit in a ring of 54.
            GlyphRenderer.drawRow(odometer.glyphs, center: CGPoint(x: center.x, y: center.y + 1),
                                  unit: geometry.glyphUnit * 0.754, color: palette.lumen,
                                  glow: theme.glow.glyph * 0.85, in: &ink)
        }

        for row in ring.thresholds {
            drawThreshold(row, layout: layout, tickRadius: tickRadius, earth: earth, in: &ink)
        }
    }

    /// One threshold: its tick, the glyph state reached there, its name and
    /// its distance from the moment shown (Earth mode adds when it falls).
    private static func drawThreshold(
        _ row: LensReading.ThresholdRow, layout: LensLayout, tickRadius: CGFloat, earth: Double, in ink: inout Ink
    ) {
        let palette = ink.palette, theme = ink.theme
        let center = layout.ringCenter, k = layout.ringScale
        let angle = Marks.angle(of: row.quarter)
        let color = row.isNext ? palette.now : palette.ash
        ink.line(from: center.polar(tickRadius, angle), to: center.polar(tickRadius + 6 * k, angle),
                 row.isNext ? palette.now : palette.etch3, width: 1)

        // End and node sit above and below the ring, with their words beside
        // the glyph; peak and valley sit either side, with their words under it.
        let vertical = row.quarter == .end || row.quarter == .node
        // Earth mode hangs a third line under peak and valley: they move up
        // a little to keep clear of the title block (and no further, or
        // their words would meet the ticks).
        let side = center.y - (8 + 4 * CGFloat(earth)) * k
        let glyphCentre: CGPoint
        switch row.quarter {
        case .peak: glyphCentre = CGPoint(x: center.x + tickRadius + 22 * k, y: side)
        case .valley: glyphCentre = CGPoint(x: center.x - tickRadius - 22 * k, y: side)
        case .end: glyphCentre = CGPoint(x: center.x - 24 * k, y: center.y - tickRadius - 18 * k)
        case .node: glyphCentre = CGPoint(x: center.x - 24 * k, y: center.y + tickRadius + 22 * k)
        }
        if let glyph = row.glyph {
            GlyphRenderer.draw(glyph, center: glyphCentre, unit: layout.thresholdGlyphUnit, color: color, in: &ink)
        }

        let wordStyle = theme.engraved(layout.thresholdWordSize, color)
        let valueStyle = theme.value(layout.thresholdValueSize, weight: .regular,
                                     digits: row.isNext ? palette.bone : palette.ash)
        let earthStyle = theme.earthText(layout.thresholdValueSize - 1)
        let span = row.span ?? ""
        let translation = earth > 0 ? row.earth.map(Ink.earth) : nil
        let lineHeight = layout.thresholdValueSize + 2.5

        if vertical {
            let x = glyphCentre.x + 14 * k, y = glyphCentre.y - 2
            ink.text(row.quarter.name, at: CGPoint(x: x, y: y), wordStyle)
            ink.text(span, at: CGPoint(x: x, y: y + lineHeight), valueStyle)
            if let translation {
                // Beside the span: the line below would run into the ring.
                ink.text(translation, at: CGPoint(x: x + ink.width(of: span, valueStyle) + 8, y: y + lineHeight),
                         earthStyle, opacity: earth)
            }
        } else {
            // Centred under the glyph, but never off the edge of the design.
            // A translation with a date in it (`31 DEC 23:33`) is wider than
            // the room between the ring and the edge: keeping it on one line
            // would push it into the ring, so it is set on two.
            let size = layout.layout.designSize
            let room = 2 * (min(glyphCentre.x, size.width - glyphCentre.x) - 6)
            var lines = translation.map { [$0] } ?? []
            if let whole = lines.first, ink.width(of: whole, earthStyle) > room + 12,
               let cut = whole.lastIndex(of: " "), whole[..<cut].contains(where: \.isNumber) {
                lines = [String(whole[..<cut]), String(whole[whole.index(after: cut)...])]
            }
            let widest = max(ink.width(of: span, valueStyle), lines.map { ink.width(of: $0, earthStyle) }.max() ?? 0,
                             ink.width(of: row.quarter.name, wordStyle))
            let x = min(max(glyphCentre.x, widest / 2 + 6), size.width - widest / 2 - 6)
            let y = glyphCentre.y + 22 * k
            ink.text(row.quarter.name, at: CGPoint(x: x, y: y), wordStyle, anchor: .middle)
            ink.text(span, at: CGPoint(x: x, y: y + lineHeight), valueStyle, anchor: .middle)
            for (index, line) in lines.enumerated() {
                ink.text(line, at: CGPoint(x: x, y: y + (2 + CGFloat(index)) * lineHeight - 1), earthStyle,
                         anchor: .middle, opacity: earth)
            }
        }
    }

    // MARK: A rung with no live ring

    /// The seal of a rung the instrument cannot show, where the ring would
    /// be: engraved, and in the one red for the rung that is visible light.
    static func drawSeal(_ rung: RungReading, layout: LensLayout, in ink: inout Ink) {
        let palette = ink.palette, theme = ink.theme
        let center = layout.ringCenter
        let extent = layout.ringRadius * 1.19
        if rung.isVisibleLight {
            SealRenderer.draw(rung.level, center: center, extent: extent, color: palette.hAlpha, width: 1.3,
                              glow: theme.glow.arc > 0 ? 0.7 : nil, in: &ink)
        } else {
            SealRenderer.draw(rung.level, center: center, extent: extent, color: palette.etch3, width: theme.line.heroToCome, in: &ink)
        }
        ink.text("\(rung.level.depth)", at: CGPoint(x: center.x, y: center.y + 5.5 * layout.ringScale),
                 theme.letter(16 * layout.ringScale, rung.isVisibleLight ? palette.bone : palette.ash, weight: .light), anchor: .middle)
        ink.text("finer than the instrument reads",
                 at: CGPoint(x: center.x, y: center.y + extent + 22 * layout.ringScale),
                 theme.engraved(6.5, palette.etch3), anchor: .middle)
    }
}
