import SwiftUI
import FractonicaKit

/// Draws the LENS (DESIGN.md §7, §9; design/astrolabe/screen4.png and
/// screen4_pure.png): the title block, the ring (`LensRing`), the lineage
/// strip of seals, the data rows and the seven media. The straight limb at
/// the bottom is a `LimbControl` laid over this by `LensScreen`.
///
/// `earth` is 0 in pure mode and 1 in Earth mode. An Earth value never
/// replaces a Fractonica one here (DESIGN.md §1, principle 5): it is set
/// beside it, in the Earth colour, led by the Earth sign; a column that is
/// wholly Earth carries the sign once, in its heading.
enum LensRenderer {
    static func draw(
        _ reading: LensReading, layout: LensLayout, outOfCatalogue: String?, earth: Double, in ink: inout Ink
    ) {
        drawTitle(reading, layout: layout, outOfCatalogue: outOfCatalogue, in: &ink)
        if let ring = reading.ring {
            LensRing.draw(ring, layout: layout, earth: earth, in: &ink)
        } else {
            LensRing.drawSeal(reading.rung, layout: layout, in: &ink)
        }
        drawLineage(reading, layout: layout, in: &ink)
        drawRows(reading.rows, layout: layout, earth: earth, in: &ink)
        drawMedia(reading, layout: layout, earth: earth, in: &ink)
    }

    // MARK: Title

    private static func drawTitle(
        _ reading: LensReading, layout l: LensLayout, outOfCatalogue: String?, in ink: inout Ink
    ) {
        let palette = ink.palette, theme = ink.theme
        let rung = reading.rung
        ink.text(Screen.lens.word, at: CGPoint(x: l.titleX, y: l.titleY), theme.engraved(8.5, palette.ash))
        ink.text(reading.ordinalLine, at: CGPoint(x: l.titleX, y: l.titleY + 14), theme.engraved(6.5, palette.etch3))
        if let outOfCatalogue {
            // design/README.md ruling 7: said once, where the screen begins.
            ink.text(outOfCatalogue, at: CGPoint(x: l.titleX, y: l.titleY + 27), theme.engraved(6.5, palette.ash))
        }
        ink.text(rung.name, at: l.letter, theme.letter(l.letterSize, palette.bone, weight: .ultraLight))
        ink.text(rung.level.title, at: CGPoint(x: l.titleX, y: l.nameY),
                 theme.engraved(l.nameSize, palette.bone, tracking: 0.34))
        ink.text(reading.kindLine, at: CGPoint(x: l.titleX, y: l.kindY), theme.engraved(6.6, palette.ash, tracking: 0.2))
        if let epithet = reading.epithet {
            let color: Color
            switch epithet.tone {
            case .sun: color = palette.solLabel
            case .visibleLight: color = palette.hAlpha
            case .plain: color = palette.etch3
            }
            ink.text(epithet.text, at: CGPoint(x: l.titleX, y: l.epithetY), theme.engraved(6.6, color, tracking: 0.2))
        }
    }

    // MARK: Lineage

    /// The exact prefix, then the factors that lead from the Alpha down to
    /// this rung, each level as its seal. A deep rung shows the last few
    /// levels of its lineage; the dots say that it goes on upwards.
    private static func drawLineage(_ reading: LensReading, layout l: LensLayout, in ink: inout Ink) {
        let palette = ink.palette, theme = ink.theme
        let labelStyle = theme.engraved(7, palette.ash)
        ink.text(reading.prefixLabel, at: CGPoint(x: l.lineageLeft, y: l.prefixY), labelStyle)
        let room = l.lineageRight - l.lineageLeft - ink.width(of: reading.prefixLabel, labelStyle) - 14
        // The exact digits of a deep rung are long: they are set smaller
        // rather than cut.
        var prefix = reading.prefix.last ?? ""
        var prefixStyle = theme.value(12.5)
        for size in [12.5, 10.5, 9, 7.5] as [CGFloat] {
            let style = theme.value(size)
            if let fitting = reading.prefix.first(where: { ink.width(of: $0, style) <= room }) {
                prefix = fitting
                prefixStyle = style
                break
            }
            prefixStyle = style
        }
        ink.text(prefix, at: CGPoint(x: l.lineageRight, y: l.prefixY + 1), prefixStyle, anchor: .end)

        let shown = Array(reading.lineage.suffix(l.sealCount))
        let isCut = shown.count < reading.lineage.count
        let y = l.lineageY
        for (slot, level) in shown.enumerated() {
            let x = l.sealX + CGFloat(slot) * l.sealPitch
            let isSelf = level == reading.rung.level
            if slot == 0, isCut {
                // The lineage goes on upwards.
                for dot in -1 ... 1 {
                    ink.circle(CGPoint(x: x + CGFloat(dot) * 5, y: y), radius: 0.9, fill: palette.etch3)
                }
            } else {
                let isLight = isSelf && reading.rung.isVisibleLight
                let color = isLight ? palette.hAlpha : (isSelf ? palette.lumen : palette.seal)
                SealRenderer.draw(level, center: CGPoint(x: x, y: y), extent: 11, color: color,
                                  width: isSelf ? 1 : 0.8, glow: isSelf && theme.glow.arc > 0 ? 0.5 : nil, in: &ink)
                ink.text(level.name, at: CGPoint(x: x, y: y + 26),
                         theme.letter(12, isSelf ? palette.bone : palette.ash), anchor: .middle)
            }
            guard !isSelf else { continue }
            // The connector to the next level carries this level's factor.
            ink.line(from: CGPoint(x: x + 15, y: y), to: CGPoint(x: x + l.sealPitch - 15, y: y),
                     palette.etch2, width: theme.line.engraving)
            if !(slot == 0 && isCut) {
                ink.text("\(level.factor)", at: CGPoint(x: x + l.sealPitch / 2, y: y - 6),
                         theme.letter(9.5, palette.ash, weight: .regular), anchor: .middle)
            }
        }
    }

    // MARK: Data rows

    private static func drawRows(_ rows: [LensReading.Row], layout l: LensLayout, earth: Double, in ink: inout Ink) {
        let palette = ink.palette, theme = ink.theme
        let labelStyle = theme.engraved(7, palette.ash)
        let valueStyle = theme.value(12.5)
        let earthStyle = theme.earthText(10.5)
        let gap: CGFloat = 14
        for (index, row) in rows.prefix(l.maxRows).enumerated() {
            let y = l.rowsY + CGFloat(index) * l.rowPitch
            ink.text(row.label, at: CGPoint(x: l.rowsLeft, y: y), labelStyle)
            ink.line(from: CGPoint(x: l.rowsLeft, y: y + 9.5), to: CGPoint(x: l.rowsRight, y: y + 9.5),
                     palette.etch1, width: 1)
            let room = l.rowsRight - l.rowsLeft - ink.width(of: row.label, labelStyle) - 16
            let translations = earth > 0 ? row.earth.map(Ink.earth) : []
            let choice = fit(pure: row.pure, earth: translations, room: room, gap: gap,
                             pureStyle: valueStyle, earthStyle: earthStyle, ink: ink)
            var right = l.rowsRight
            if let pure = choice.pure {
                ink.text(pure, at: CGPoint(x: right, y: y + 1), valueStyle, anchor: .end)
                right -= ink.width(of: pure, valueStyle) + gap
            }
            if let translation = choice.earth {
                ink.text(translation, at: CGPoint(x: right, y: y + 0.5), earthStyle, anchor: .end, opacity: earth)
            }
        }
    }

    /// The most detailed wordings of a value and of its translation that fit
    /// the row together: the translation is kept whole while some wording of
    /// the value still fits beside it.
    private static func fit(
        pure: [String], earth: [String], room: CGFloat, gap: CGFloat,
        pureStyle: InkTextStyle, earthStyle: InkTextStyle, ink: Ink
    ) -> (pure: String?, earth: String?) {
        guard !earth.isEmpty else {
            return (pure.first { ink.width(of: $0, pureStyle) <= room } ?? pure.last, nil)
        }
        guard !pure.isEmpty else {
            return (nil, earth.first { ink.width(of: $0, earthStyle) <= room } ?? earth.last)
        }
        for translation in earth {
            let left = room - ink.width(of: translation, earthStyle) - gap
            if let value = pure.first(where: { ink.width(of: $0, pureStyle) <= left }) {
                return (value, translation)
            }
        }
        return (pure.last, earth.last)
    }

    // MARK: Media

    /// One cycle of travel in the seven media of SPEC §16.3, on a logarithmic
    /// rule: pure as spans of light, Earth adds the metres in a column of
    /// their own.
    private static func drawMedia(_ reading: LensReading, layout l: LensLayout, earth: Double, in ink: inout Ink) {
        let palette = ink.palette, theme = ink.theme
        let headStyle = theme.engraved(7, palette.ash)
        let columnStyle = theme.engraved(7, palette.etch3)
        let spanStyle = theme.value(12)
        let wordStyle = theme.letter(9, palette.ash, weight: .regular)
        let earthStyle = theme.earthText(11)
        let wordGap: CGFloat = 3.5

        // Column widths: the spans of light at the right edge, the metres to
        // their left, and the rule gives way to both.
        func spanWidth(_ row: LensReading.MediumRow) -> CGFloat {
            ink.width(of: row.span, spanStyle) + (row.word.isEmpty ? 0 : wordGap + ink.width(of: row.word, wordStyle))
        }
        let pureWidth = reading.media.map(spanWidth).max() ?? 0
        let earthWidth = reading.media.compactMap { $0.earth.map { ink.width(of: $0, earthStyle) } }.max() ?? 0
        let earthRight = l.rowsRight - pureWidth - 16
        let ruleEndPure = min(l.ruleEnd, l.rowsRight - pureWidth - 12)
        let ruleEndEarth = min(l.ruleEnd, earthRight - earthWidth - 12)
        let e = CGFloat(earth)
        let ruleEnd = ruleEndPure + (ruleEndEarth - ruleEndPure) * (earthWidth > 0 ? e : 0)

        ink.text(reading.travelTitle, at: CGPoint(x: l.rowsLeft, y: l.mediaY), headStyle)
        ink.text("length", at: CGPoint(x: l.rowsRight, y: l.mediaY), columnStyle, anchor: .end)
        if earth > 0, earthWidth > 0 {
            // A column wholly in Earth units: one Earth sign, in its heading.
            ink.text("length", at: CGPoint(x: earthRight, y: l.mediaY), columnStyle, anchor: .end, opacity: earth)
            Marks.earthSign(center: CGPoint(x: earthRight - ink.width(of: "length", columnStyle) - 7, y: l.mediaY - 2.6),
                            opacity: earth, in: &ink)
        }

        for (index, row) in reading.media.enumerated() {
            let y = l.mediaRowsY + CGFloat(index) * l.mediaPitch
            let leads = index == 0
            ink.text(row.name, at: CGPoint(x: l.rowsLeft, y: y), theme.letter(11.5, leads ? palette.bone : palette.listText))
            if ruleEnd - l.ruleStart >= 24 {
                let color = leads ? palette.lumen : palette.lumenMid
                let mark = l.ruleStart + (ruleEnd - l.ruleStart) * CGFloat(row.place)
                ink.line(from: CGPoint(x: l.ruleStart, y: y - 3.5), to: CGPoint(x: ruleEnd, y: y - 3.5), palette.etch1, width: 1)
                ink.line(from: CGPoint(x: l.ruleStart, y: y - 3.5), to: CGPoint(x: mark, y: y - 3.5), color, width: leads ? 1.3 : 1)
                ink.circle(CGPoint(x: mark, y: y - 3.5), radius: 1.6, fill: color)
            }
            var right = l.rowsRight
            if !row.word.isEmpty {
                ink.text(row.word, at: CGPoint(x: right, y: y), wordStyle, anchor: .end)
                right -= ink.width(of: row.word, wordStyle) + wordGap
            }
            ink.text(row.span, at: CGPoint(x: right, y: y), spanStyle, anchor: .end)
            if let translation = row.earth, earth > 0 {
                ink.text(translation, at: CGPoint(x: earthRight, y: y), earthStyle, anchor: .end, opacity: earth)
            }
        }
    }
}
