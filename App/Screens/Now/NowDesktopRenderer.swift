import SwiftUI
import FractonicaKit

/// The right column of the NOW screen on the desktop (DESIGN.md §7,
/// x 842 – 1224 of 1280 × 800): the Pentad line, the four major names with
/// their quarter words, the reading, the period pair (the focus and the
/// level under it: odometer, bead counter, countdown), the Sun, and the next
/// thresholds across the coarser levels.
enum NowDesktopRenderer {
    static let left: CGFloat = 842
    static let right: CGFloat = 1224

    static func draw(_ reading: NowReading, earthLines: NowEarth?, earth: Double, in ink: inout Ink) {
        let palette = ink.palette, theme = ink.theme
        let x0 = left, x1 = right
        let e = CGFloat(earth)

        // The Pentad line.
        if let pentad = reading.pentad {
            // The core's own wording: `Pentad II, 2nd Helion`.
            let words = pentad.text(.full, withHelion: true) ?? pentad.name
            NowPieces.pentadMark(reading, center: CGPoint(x: x0 + 10, y: 89), words: words,
                                 wordsX: x0 + 32, wordSize: 9, baseline: 92, in: &ink)
        }

        guard let live = reading.live else {
            ink.text(reading.outOfCatalogue, at: CGPoint(x: x0, y: 296),
                     theme.engraved(11, palette.ash, tracking: theme.type.dateTracking))
            return
        }

        // The four major periods with their quarter words.
        var y: CGFloat = 132
        for major in live.majors {
            let isFinest = major.level == live.majors.last?.level
            ink.text(major.level.name, at: CGPoint(x: x0, y: y), theme.letter(15, palette.ash))
            ink.text(major.name, at: CGPoint(x: x0 + 30, y: y - 1),
                     theme.engraved(11, isFinest ? palette.bone : palette.majorName, tracking: 0.26))
            ink.text(major.quarter.name, at: CGPoint(x: x1, y: y - 1), theme.engraved(9, palette.ash), anchor: .end)
            ink.line(from: CGPoint(x: x0, y: y + 11), to: CGPoint(x: x1, y: y + 11), palette.etch1, width: 1)
            y += 30
        }

        // The reading.
        y += 44
        NowPieces.readingLine(live.terms, at: CGPoint(x: x0, y: y), anchor: .start,
                              size: 50, trail: 24, gap: 14, trailGap: 8, in: &ink)
        if let earthLines, earth > 0 {
            ink.text(Ink.earth(earthLines.dateLine), at: CGPoint(x: x0, y: y + 26), theme.earthText(13), opacity: earth)
        }
        y += 26 * e

        // The period pair of the display model (SPEC §8).
        y += 62
        for (index, countdown) in live.countdowns.prefix(2).enumerated() {
            let x = x0 + CGFloat(index) * 196
            GlyphRenderer.drawRow(countdown.odometer.glyphs, center: CGPoint(x: x + 30, y: y + 28), unit: 5.2,
                                  color: palette.lumen, glow: theme.glow.glyph * 0.85, in: &ink)
            ink.text(countdown.level.name, at: CGPoint(x: x + 78, y: y + 8), theme.letter(20, palette.bone))
            ink.text(kindWord(countdown.level), at: CGPoint(x: x + 96, y: y + 7), theme.engraved(7.2, palette.ash))
            let count = countdown.cycle.siblings
            let pitch = min(9.5, 104 / CGFloat(max(count - 1, 1)))
            Marks.beads(center: CGPoint(x: x + 81 + CGFloat(count - 1) * pitch / 2, y: y + 22), count: count,
                        local: countdown.cycle.local, pitch: pitch, in: &ink)
            ink.text(NowPieces.countdownLabel(countdown, withLetter: false), at: CGPoint(x: x + 78, y: y + 44),
                     theme.engraved(7.2, palette.ash))
            ink.text(countdown.span, at: CGPoint(x: x + 78, y: y + 62), theme.value(17))
            if let earthLines, earth > 0, index < earthLines.countdownTimes.count {
                ink.text(Ink.earth(earthLines.countdownTimes[index]), at: CGPoint(x: x + 78, y: y + 77),
                         theme.earthText(10), opacity: earth)
            }
        }

        // The Sun.
        y += 132
        ink.line(from: CGPoint(x: x0, y: y - 30), to: CGPoint(x: x1, y: y - 30), palette.etch2, width: theme.line.engraving)
        NowPieces.sunBlock(
            live.sun, earth: earthLines, earthOpacity: earth,
            glyphCentre: CGPoint(x: x0 + 44, y: y + 22), glyphUnit: 4.6, columns: [x0 + 118, x0 + 208, x0 + 302],
            labelY: y + 8, valueY: y + 32, earthY: y + 48, valueSize: 19, earthSize: 10, in: &ink
        )

        // What comes next, across the levels (nothing at the closing instant:
        // then no heading either).
        y += 104
        guard !live.upcoming.isEmpty else { return }
        ink.line(from: CGPoint(x: x0, y: y - 28), to: CGPoint(x: x1, y: y - 28), palette.etch2, width: theme.line.engraving)
        ink.text("Next thresholds", at: CGPoint(x: x0, y: y - 8), theme.engraved(7.2, palette.ash))
        drawUpcoming(live.upcoming, earthLines: earthLines, earth: earth, firstBaseline: y + 16, in: &ink)
    }

    /// The rows of "next thresholds", soonest first: where on its ring the
    /// threshold sits, the level's letter (or the Sun's sign), the quarter
    /// word, a dotted leader, and the span until it.
    private static func drawUpcoming(
        _ rows: [NowReading.Upcoming], earthLines: NowEarth?, earth: Double, firstBaseline: CGFloat, in ink: inout Ink
    ) {
        let x0 = left, x1 = right, earthX = right - 100
        for (index, row) in rows.enumerated() {
            let earthLine = earthLines.flatMap { index < $0.upcoming.count ? $0.upcoming[index] : nil }
            NowPieces.upcomingRow(row, earthLine: earthLine, earth: earth, from: x0, to: x1, earthX: earthX,
                                  baseline: firstBaseline + CGFloat(index) * 27, in: &ink)
        }
    }

    /// What a level is, in the pair's heading: the unit's name, or "between"
    /// for a level between units (design/README.md ruling 4). A level finer
    /// than the Blink has no word.
    private static func kindWord(_ level: Level) -> String {
        if let unit = level.unit { return unit.name }
        return level.kind == .between ? level.kind.text : ""
    }
}
