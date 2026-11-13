import SwiftUI
import FractonicaKit

/// The blocks both arrangements of the NOW screen share: the Pentad mark,
/// the reading line, the Sun's three values. Positions are the caller's.
enum NowPieces {
    /// The Pentad mark: the polygon with its vertices lit through the running
    /// Helion, the numeral inside it, and the words beside it.
    static func pentadMark(
        _ reading: NowReading, center: CGPoint, words: String, wordsX: CGFloat, wordSize: CGFloat,
        baseline: CGFloat, in ink: inout Ink
    ) {
        guard let pentad = reading.pentad else { return }
        let sol = ink.palette.sol
        Marks.pentad(center: center, radius: 10, sides: pentad.helions, lit: pentad.helion, in: &ink)
        ink.text(reading.pentadNumeral, at: CGPoint(x: center.x, y: center.y + 3.2),
                 ink.theme.engraved(8, sol, tracking: 0.05), anchor: .middle)
        ink.text(words, at: CGPoint(x: wordsX, y: baseline), ink.theme.engraved(wordSize, sol))
    }

    /// The reading: `ε#5 34η 29ι` large, `21λ 3ν` at half size in ash.
    /// - Parameters:
    ///   - size: the large size (38 phone, 50 desktop); the small is `trail`.
    ///   - gap: the space between large terms; `trailGap` between small ones.
    static func readingLine(
        _ terms: [String], at point: CGPoint, anchor: TextAnchor, size: CGFloat, trail: CGFloat,
        gap: CGFloat, trailGap: CGFloat, in ink: inout Ink
    ) {
        let theme = ink.theme
        let large = theme.value(size, weight: theme.type.readingWeight)
        let small = theme.value(trail, weight: theme.type.valueWeight, digits: ink.palette.ash)
        // The Nuclide, the Helion and the Preon are the reading proper; the
        // Flavon and the Blink trail it.
        let pieces = terms.enumerated().map { index, term in
            index < 3
                ? TextPiece(text: term, style: large, gapBefore: index == 0 ? 0 : gap)
                : TextPiece(text: term, style: small, gapBefore: index == 3 ? gap : trailGap)
        }
        ink.line(pieces, at: point, anchor: anchor)
    }

    /// The Sun's block: its three glyphs, then SOLAR SYNC, DRIFT and the
    /// countdown to the sync's next quarter, with their Earth lines.
    /// - Parameters:
    ///   - glyphCentre / glyphUnit: the three-glyph sync odometer.
    ///   - columns: the x of the three value columns.
    ///   - labelY / valueY / earthY: the three baselines.
    static func sunBlock(
        _ sun: NowReading.SunFigures?, earth: NowEarth?, earthOpacity: Double,
        glyphCentre: CGPoint, glyphUnit: CGFloat, columns: [CGFloat],
        labelY: CGFloat, valueY: CGFloat, earthY: CGFloat, valueSize: CGFloat, earthSize: CGFloat,
        in ink: inout Ink
    ) {
        // In the partial syncs at the catalogue's ends the core has no sync
        // reading: the block is left out whole, never labels over nothing.
        guard let sun else { return }
        let palette = ink.palette, theme = ink.theme
        GlyphRenderer.drawRow(sun.odometer.glyphs, center: glyphCentre, unit: glyphUnit, pitch: 6.4,
                              color: palette.sol, glow: theme.glow.glyph * 0.85, in: &ink)
        // The last label names the quarter the core says comes next; with
        // nothing later (the closing instant) that column is left out.
        var labels = ["Solar sync", "Drift"]
        var values: [String?] = [sun.number, sun.drift]
        if sun.sync.next.instant != nil {
            labels.append("\(sun.sync.next.quarter.name) in")
            values.append(sun.nextSpan)
        }
        let earthLines = [earth?.syncStart, earth?.driftSeconds, earth?.syncNext]
        for (index, x) in columns.prefix(labels.count).enumerated() {
            ink.text(labels[index], at: CGPoint(x: x, y: labelY), theme.engraved(7.2, palette.solLabel))
            if let value = values[index] {
                ink.text(value, at: CGPoint(x: x, y: valueY), theme.value(valueSize))
            }
            if let line = earthLines[index], !line.isEmpty, earthOpacity > 0 {
                ink.text(Ink.earth(line), at: CGPoint(x: x, y: earthY), theme.earthText(earthSize), opacity: earthOpacity)
            }
        }
    }

    /// One row of "next thresholds" (the desktop NOW column, the WAVE list):
    /// where on its ring the threshold sits, the level's letter (or the
    /// Sun's sign), the quarter word, a dotted leader, the Earth time when
    /// there is one, and the span until it.
    /// - Parameters:
    ///   - earthLine / earth: the Earth text and its opacity (0: pure mode).
    ///   - x0 / x1: the row's left and right edges; `earthX`: where the Earth
    ///     text ends.
    static func upcomingRow(
        _ row: NowReading.Upcoming, earthLine: String?, earth: Double, from x0: CGFloat, to x1: CGFloat,
        earthX: CGFloat, baseline y: CGFloat, in ink: inout Ink
    ) {
        let palette = ink.palette, theme = ink.theme
        let isSun = row.level == nil
        Marks.quarter(row.threshold.quarter, center: CGPoint(x: x0 + 6, y: y - 4),
                      color: isSun ? palette.sol : palette.lumen, in: &ink)
        if let level = row.level {
            ink.text(level.name, at: CGPoint(x: x0 + 31, y: y), theme.letter(15, palette.bone), anchor: .middle)
        } else {
            // The Sun's sign: a ring with its centre.
            ink.circle(CGPoint(x: x0 + 31, y: y - 4.5), radius: 4.6, stroke: palette.sol, width: 1)
            ink.circle(CGPoint(x: x0 + 31, y: y - 4.5), radius: 1.1, fill: palette.sol)
        }
        ink.text(row.threshold.quarter.name, at: CGPoint(x: x0 + 50, y: y - 1.5),
                 theme.engraved(7.5, isSun ? palette.solLabel : palette.ash))
        if let earthLine, !earthLine.isEmpty, earth > 0 {
            ink.text(Ink.earth(earthLine), at: CGPoint(x: earthX, y: y - 1),
                     theme.earthText(10), anchor: .end, opacity: earth)
        }
        ink.text(row.span, at: CGPoint(x: x1, y: y), theme.value(15), anchor: .end)
        // The leader stops short of whatever stands to its right.
        let leaderEnd = (x1 - 74) + ((earthX - 92) - (x1 - 74)) * CGFloat(earth)
        ink.line(from: CGPoint(x: x0 + 88, y: y - 4), to: CGPoint(x: leaderEnd, y: y - 4),
                 palette.etch1, width: 1, dash: [1, 4])
    }

    /// The label of a countdown: `η  END  IN`.
    static func countdownLabel(_ countdown: NowReading.Countdown, withLetter: Bool) -> String {
        let words = "\(countdown.threshold.quarter.name) in"
        return withLetter ? "\(countdown.level.name) \(words)" : words
    }
}
