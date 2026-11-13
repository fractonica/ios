import SwiftUI
import FractonicaKit

/// Draws the LADDER (DESIGN.md §7–§9; design/astrolabe/screen3.png and
/// screen3_pure.png): the title, the rim of the great wheel with its band
/// rail, the rows in the window and the column headings. The spine is drawn
/// by `LadderSpine`.
///
/// A pure function of the wheel's position: a row is read from the core
/// (`RungReading`) only while it is in the window, so turning the wheel
/// costs a dozen rungs a frame, not sixty-three.
///
/// `earth` is 0 in pure mode and 1 in Earth mode; in between the Earth
/// values fade in. On the phone they take the place of the pure values in
/// the one value column (as the design draws it); on the desktop they are
/// three more columns under one Earth-sign heading.
enum LadderRenderer {
    /// - Parameter refusal: a rung a long press could not focus, and how far
    ///   its refusal is shown (0...1).
    static func draw(
        geometry: LadderGeometry, interval: SarosInterval, position: Double, earth: Double,
        refusal: (level: Level, opacity: Double)? = nil, in ink: inout Ink
    ) {
        // The desktop's pure columns spread out where the Earth ones are absent.
        let geometry = geometry.blended(earth: earth)
        drawTitle(geometry: geometry, in: &ink)
        drawHeadings(geometry: geometry, earth: earth, in: &ink)
        drawRim(geometry: geometry, in: &ink)

        let rows = geometry.visibleLevels(at: position).map { level -> Row in
            let offset = CGFloat(Double(level.index) - position)
            return Row(rung: RungReading.read(level, interval: interval, earth: earth > 0),
                       offset: offset, y: geometry.rowY(offset: offset))
        }
        drawBandRail(rows, geometry: geometry, in: &ink)
        for row in rows {
            let focus = Double(smooth(geometry.focus(offset: row.offset)))
            let x = geometry.rimX(atY: row.y)
            // A row is a list row, the focused row, or on its way between the two.
            ink.layer(opacity: geometry.rowOpacity(offset: row.offset) * (1 - focus)) { layer in
                drawListRow(row.rung, x: x, y: row.y, geometry: geometry, earth: earth, in: &layer)
            }
            ink.layer(opacity: focus) { layer in
                let refused = refusal.flatMap { $0.level == row.rung.level ? $0.opacity : nil } ?? 0
                drawFocusedRow(row.rung, x: x, y: row.y, geometry: geometry, interval: interval, earth: earth,
                               refused: refused, in: &layer)
            }
        }
    }

    /// One row of the window: the rung, how far it is from the middle, where it is.
    private struct Row {
        let rung: RungReading
        let offset: CGFloat
        let y: CGFloat
    }

    /// Eases the hand-over between a list row and the focused row, so that
    /// two half-enlarged rows are on screen only for the middle of a step.
    private static func smooth(_ t: CGFloat) -> CGFloat {
        let x = min(max((t - 0.25) / 0.5, 0), 1)
        return x * x * (3 - 2 * x)
    }

    // MARK: Furniture

    private static func drawTitle(geometry g: LadderGeometry, in ink: inout Ink) {
        let palette = ink.palette, theme = ink.theme
        ink.text("Spectral ladder", at: CGPoint(x: g.titleX, y: g.titleY), theme.engraved(8.5, palette.ash))
        ink.text("\(Level.count) rungs · \(Level.alpha.title) to the Planck edge",
                 at: CGPoint(x: g.titleX, y: g.titleY + 14), theme.engraved(6.5, palette.etch3))
    }

    /// The column headings. A column that is wholly Earth units carries one
    /// Earth sign in its heading (DESIGN.md §9).
    private static func drawHeadings(geometry g: LadderGeometry, earth: Double, in ink: inout Ink) {
        let palette = ink.palette
        let style = ink.theme.engraved(6.3, palette.etch3)
        let c = g.columns, y = g.headingY
        switch g.layout {
        case .phone:
            let x = c.primary
            ink.text("length · rate", at: CGPoint(x: x, y: y), style, anchor: .end, opacity: 1 - earth)
            ink.text("made of", at: CGPoint(x: x, y: y + 11), style, anchor: .end, opacity: 1 - earth)
            ink.text("period", at: CGPoint(x: x, y: y), style, anchor: .end, opacity: earth)
            ink.text("frequency · light in vacuum", at: CGPoint(x: x, y: y + 11), style, anchor: .end, opacity: earth)
            let sign = CGPoint(x: x - ink.width(of: "period", style) - 7, y: y - 2.4)
            Marks.earthSign(center: sign, opacity: earth, in: &ink)
        case .desktop:
            ink.text("length", at: CGPoint(x: c.length, y: y + 11), style, anchor: .end)
            ink.text("rate", at: CGPoint(x: c.rate, y: y + 11), style, anchor: .end)
            ink.text("made of", at: CGPoint(x: c.madeOf, y: y + 11), style, anchor: .end)
            guard earth > 0 else { return }
            ink.text("period", at: CGPoint(x: c.period, y: y + 11), style, anchor: .end, opacity: earth)
            ink.text("frequency", at: CGPoint(x: c.frequency, y: y + 11), style, anchor: .end, opacity: earth)
            ink.text("light in vacuum", at: CGPoint(x: c.light, y: y + 11), style, anchor: .end, opacity: earth)
            // One sign over the three Earth columns, and the rule that gathers them.
            let left = c.period - 58
            Marks.earthSign(center: CGPoint(x: left + 3.4, y: y - 2.4), opacity: earth, in: &ink)
            ink.line(from: CGPoint(x: left + 12, y: y - 2.4), to: CGPoint(x: c.light, y: y - 2.4),
                     palette.etch2, width: ink.theme.line.engraving, opacity: earth)
        }
    }

    /// The rim of the wheel, fading out towards the top and the bottom.
    private static func drawRim(geometry g: LadderGeometry, in ink: inout Ink) {
        let color = ink.palette.etch3
        let top = g.focusY - g.rimReach, bottom = g.focusY + g.rimReach
        ink.stroke(
            rimArc(geometry: g, radius: g.wheelRadius, from: top, to: bottom),
            fading: [
                .init(color: color.opacity(0), location: 0), .init(color: color, location: 0.2),
                .init(color: color, location: 0.8), .init(color: color.opacity(0), location: 1),
            ],
            from: CGPoint(x: 0, y: top), to: CGPoint(x: 0, y: bottom), width: ink.theme.line.heroToCome
        )
    }

    /// The piece of a circle concentric with the wheel between two heights.
    private static func rimArc(geometry g: LadderGeometry, radius: CGFloat, from y0: CGFloat, to y1: CGFloat) -> CGPath {
        let center = g.wheelCenter
        func angle(_ y: CGFloat) -> CGFloat { .pi - asin(min(max((y - center.y) / radius, -1), 1)) }
        let path = CGMutablePath()
        path.addArc(center: center, radius: radius, startAngle: angle(y0), endAngle: angle(y1), clockwise: true)
        return path
    }

    /// The band rail: the bands as broken arcs just outside the rim, one arc
    /// per run of rows in the same band. Visible light is the one red; rungs
    /// outside every band have no rail.
    private static func drawBandRail(_ rows: [Row], geometry g: LadderGeometry, in ink: inout Ink) {
        let palette = ink.palette
        var start = 0
        while start < rows.count {
            var end = start
            while end + 1 < rows.count, rows[end + 1].rung.band == rows[start].rung.band { end += 1 }
            let first = rows[start], last = rows[end]
            defer { start = end + 1 }
            guard first.rung.band != .noBand else { continue }
            let y0 = first.y - g.halfHeight(offset: first.offset)
            let y1 = last.y + g.halfHeight(offset: last.offset)
            let isLight = first.rung.isVisibleLight
            // A run at the end of the window leaves with its last row.
            let leaving = min(1, 2.5 * max(g.rowOpacity(offset: first.offset), g.rowOpacity(offset: last.offset)))
            ink.stroke(rimArc(geometry: g, radius: g.wheelRadius + 9, from: y0, to: y1),
                       isLight ? palette.hAlpha : palette.etch3, width: isLight ? 1.2 : 0.9,
                       opacity: (isLight ? 1 : 0.8) * leaving)
        }
    }

    // MARK: A list row

    private static func drawListRow(
        _ rung: RungReading, x: CGFloat, y: CGFloat, geometry g: LadderGeometry, earth: Double, in ink: inout Ink
    ) {
        let palette = ink.palette, theme = ink.theme
        SealRenderer.draw(rung.level, center: CGPoint(x: x, y: y), extent: 11,
                          color: rung.isVisibleLight ? palette.hAlpha : palette.seal, in: &ink)
        ink.circle(CGPoint(x: x, y: y), radius: 2.6, fill: palette.void)
        ink.text("\(rung.level.depth)", at: CGPoint(x: x - 17, y: y + 3),
                 theme.letter(9, palette.etch3, weight: .regular), anchor: .end)

        let nameStyle = theme.letter(19, palette.bone)
        ink.text(rung.name, at: CGPoint(x: x + 22, y: y + 2), nameStyle)
        // Where the name (and its unit word) ends: the size must stop short of it.
        var nameEnd = x + 22 + ink.width(of: rung.name, nameStyle)
        if let unit = rung.unitName {
            let unitStyle = theme.engraved(6.3, palette.ash, tracking: 0.2)
            ink.text(unit, at: CGPoint(x: nameEnd + 8, y: y + 2), unitStyle)
            nameEnd += 8 + ink.width(of: unit, unitStyle)
        }
        let captionStyle = theme.engraved(6.3, palette.ash, tracking: 0.2)
        ink.text(rung.caption, at: CGPoint(x: x + 22, y: y + 15), captionStyle)

        let c = g.columns
        switch g.layout {
        case .phone:
            // One column: the pure values, or their Earth translation.
            let sizeStyle = theme.value(12.5)
            let size = ink.fitting(rung.sizeWordings, sizeStyle, width: min(c.primary - nameEnd - 12, c.listValueWidth))
            ink.text(size, at: CGPoint(x: c.primary, y: y + 1), sizeStyle, anchor: .end, opacity: 1 - earth)
            if let madeOf = rung.madeOf {
                ink.text(madeOf, at: CGPoint(x: c.primary, y: y + 15), theme.letter(9, palette.ash, weight: .regular),
                         anchor: .end, opacity: 1 - earth)
            }
            if let translation = rung.earth, earth > 0 {
                ink.text(translation.period, at: CGPoint(x: c.primary, y: y + 1), theme.letter(12.5, palette.bone),
                         anchor: .end, opacity: earth)
                // The second line shares its baseline with the caption: where
                // the deepest rungs' powers of ten would run into it, the
                // frequency stands alone.
                let style = theme.earthText(9)
                let room = c.primary - (x + 22 + ink.width(of: rung.caption, captionStyle) + 8)
                let both = "\(translation.frequency) · \(translation.length)"
                ink.text(ink.width(of: both, style) <= room ? both : translation.frequency,
                         at: CGPoint(x: c.primary, y: y + 15), style, anchor: .end, opacity: earth)
            }
        case .desktop:
            let baseline = y + 4
            if let length = rung.length {
                ink.text(length, at: CGPoint(x: c.length, y: baseline), theme.value(12.5), anchor: .end)
            }
            let rateStyle = theme.value(12.5)
            let rate = ink.fitting(rung.rateWordings, rateStyle, width: c.rate - c.length - 16)
            ink.text(rate, at: CGPoint(x: c.rate, y: baseline), rateStyle, anchor: .end)
            if let madeOf = rung.madeOf {
                ink.text(madeOf, at: CGPoint(x: c.madeOf, y: baseline), theme.value(11, digits: palette.ash), anchor: .end)
            }
            if let translation = rung.earth, earth > 0 {
                let style = theme.earthText(11)
                ink.text(translation.period, at: CGPoint(x: c.period, y: baseline), style, anchor: .end, opacity: earth)
                ink.text(translation.frequency, at: CGPoint(x: c.frequency, y: baseline), style, anchor: .end, opacity: earth)
                ink.text(translation.length, at: CGPoint(x: c.light, y: baseline), style, anchor: .end, opacity: earth)
            }
        }
    }

    // MARK: The focused row

    /// The measures of the enlarged row in one arrangement.
    private struct FocusMetrics {
        var sealExtent: CGFloat, sealX: CGFloat, depthSize: CGFloat
        var textX: CGFloat, nameSize: CGFloat, nameY: CGFloat
        var titleSize: CGFloat, titleY: CGFloat, noteSize: CGFloat, noteY: CGFloat
        var valueSize: CGFloat, valueY: CGFloat, captionY: CGFloat
        var ruleY: CGFloat

        static let phone = FocusMetrics(
            sealExtent: 30, sealX: 16, depthSize: 12, textX: 62, nameSize: 46, nameY: -14,
            titleSize: 8, titleY: -36, noteSize: 6.5, noteY: -23, valueSize: 19, valueY: 18, captionY: 33, ruleY: 55
        )
        static let desktop = FocusMetrics(
            sealExtent: 34, sealX: 18, depthSize: 13, textX: 68, nameSize: 50, nameY: -12,
            titleSize: 8.5, titleY: -36, noteSize: 7, noteY: -22, valueSize: 21, valueY: 21, captionY: 36, ruleY: 55
        )
    }

    private static func drawFocusedRow(
        _ rung: RungReading, x: CGFloat, y: CGFloat, geometry g: LadderGeometry,
        interval: SarosInterval, earth: Double, refused: Double = 0, in ink: inout Ink
    ) {
        let palette = ink.palette, theme = ink.theme
        let m = g.layout == .desktop ? FocusMetrics.desktop : FocusMetrics.phone
        let isLight = rung.isVisibleLight
        // The rung that is visible light is drawn in its own colour, once.
        let accent = isLight ? palette.hAlpha : palette.lumen
        let phone = g.layout == .phone

        if isLight {
            let reach: CGFloat = 120
            let disc = Path(ellipseIn: CGRect(x: x - reach, y: y - reach, width: 2 * reach, height: 2 * reach))
            ink.context.fill(disc, with: .radialGradient(
                Gradient(colors: [accent.opacity(0.13), accent.opacity(0)]),
                center: CGPoint(x: x, y: y), startRadius: 0, endRadius: reach
            ))
        }
        let sealCentre = CGPoint(x: x + m.sealX, y: y)
        SealRenderer.draw(rung.level, center: sealCentre, extent: m.sealExtent, color: accent, width: 1.3,
                          glow: theme.glow.arc > 0 ? 0.7 : nil, in: &ink)
        ink.text("\(rung.level.depth)", at: CGPoint(x: sealCentre.x, y: y + m.depthSize * 0.35),
                 theme.letter(m.depthSize, palette.bone, weight: .regular), anchor: .middle)

        // The letter, and what the rung is.
        let left = x + m.textX
        let nameStyle = theme.letter(m.nameSize, palette.bone, weight: theme.type.readingWeight)
        ink.text(rung.name, at: CGPoint(x: left, y: y + m.nameY), nameStyle)
        let noteX = left + ink.width(of: rung.name, nameStyle) + 16
        ink.text(title(of: rung), at: CGPoint(x: noteX, y: y + m.titleY),
                 theme.engraved(m.titleSize, isLight ? accent : palette.bone, tracking: 0.26))
        let note = [rung.inParent, rung.madeOf.map { "made of \($0)" }].compactMap { $0 }.joined(separator: " · ")
        // A long press on a rung the instrument cannot show is answered here,
        // in the note's place (clear of the Earth lines), for a moment.
        ink.text(note, at: CGPoint(x: noteX, y: y + m.noteY), theme.engraved(m.noteSize, palette.ash, tracking: 0.2),
                 opacity: 1 - refused)
        if refused > 0 {
            ink.text("finer than the instrument reads", at: CGPoint(x: noteX, y: y + m.noteY),
                     theme.engraved(m.noteSize, palette.lumen, tracking: 0.2), opacity: refused)
        }

        // Its size: a span down to the Blink, then the exact rate.
        let valueStyle = theme.value(m.valueSize, weight: theme.type.readingWeight)
        let room = g.columns.ruleEnd - left
        let size = rung.length ?? (ink.width(of: rung.rate, valueStyle) <= room ? rung.rate : rung.rateRounded)
        let caption = rung.length == nil ? "cycles per \(Unit.blink.name)" : rung.rate
        let pureOpacity = phone ? 1 - earth : 1
        ink.text(size, at: CGPoint(x: left, y: y + m.valueY), valueStyle, opacity: pureOpacity)
        ink.text(caption, at: CGPoint(x: left, y: y + m.captionY), theme.engraved(6.5, palette.ash), opacity: pureOpacity)

        // Earth: visible light leads with its wavelength, any other rung
        // with its period.
        if let translation = rung.earth, earth > 0 {
            let lead = isLight ? translation.length : translation.period
            let rest = isLight
                ? "\(translation.period) · \(translation.frequency)"
                : "\(translation.frequency) · \(translation.length)"
            let leadStyle = theme.letter(25, palette.bone, weight: theme.type.readingWeight)
            if phone {
                ink.text(Ink.earth(lead), at: CGPoint(x: left, y: y + 20), leadStyle, opacity: earth)
                ink.text(rest, at: CGPoint(x: left, y: y + 40), theme.earthText(11), opacity: earth)
            } else {
                ink.text(Ink.earth(lead), at: CGPoint(x: g.columns.light, y: y + 2), leadStyle, anchor: .end, opacity: earth)
                ink.text(rest, at: CGPoint(x: g.columns.light, y: y + 22), theme.earthText(11), anchor: .end, opacity: earth)
            }
        }

        drawBandRule(rung, from: left, to: g.columns.ruleEnd, y: y + m.ruleY, accent: accent,
                     interval: interval, earth: earth, in: &ink)
    }

    /// What the focused rung is, in a word or two.
    private static func title(of rung: RungReading) -> String {
        if rung.isVisibleLight { return "\(rung.band.name) \(Fractonica.lightWord)" }
        if let unit = rung.unitName { return "\(unit) · \(rung.kind.text)" }
        return rung.band == .noBand ? rung.kind.text : "\(rung.kind.text) · \(rung.band.name)"
    }

    /// Where the rung sits in its band: a rule from one edge of the band to
    /// the other with the rung marked on it (logarithmic, so unitless). The
    /// ends name the bands beyond; Earth mode adds the edges.
    private static func drawBandRule(
        _ rung: RungReading, from x0: CGFloat, to x1: CGFloat, y: CGFloat, accent: Color,
        interval: SarosInterval, earth: Double, in ink: inout Ink
    ) {
        guard let neighbours = rung.band.neighbours,
              let place = ShimCoreGaps.placeInBand(rung.level, interval: interval)
        else { return }
        let palette = ink.palette, theme = ink.theme
        ink.line(from: CGPoint(x: x0, y: y), to: CGPoint(x: x1, y: y), palette.etch3, width: theme.line.engraving)
        for x in [x0, x1] {
            ink.line(from: CGPoint(x: x, y: y - 3), to: CGPoint(x: x, y: y + 3), palette.etch3, width: theme.line.engraving)
        }
        let mark = CGMutablePath()
        let at = x0 + (x1 - x0) * CGFloat(place)
        mark.move(to: CGPoint(x: at, y: y - 6))
        mark.addLine(to: CGPoint(x: at, y: y + 6))
        ink.stroke(mark, accent, width: 1.4, glow: theme.glow.arc > 0 ? 0.8 : nil)

        let style = theme.engraved(6.2, palette.etch3, tracking: 0.16)
        let below = neighbours.below.name, above = neighbours.above.name
        ink.text(below, at: CGPoint(x: x0, y: y + 13), style, opacity: 1 - earth)
        ink.text(above, at: CGPoint(x: x1, y: y + 13), style, anchor: .end, opacity: 1 - earth)
        if earth > 0, let edges = rung.band.edgeTexts {
            ink.text("\(below) · \(edges.low)", at: CGPoint(x: x0, y: y + 13), style, opacity: earth)
            ink.text("\(edges.high) · \(above)", at: CGPoint(x: x1, y: y + 13), style, anchor: .end, opacity: earth)
        }
    }
}
