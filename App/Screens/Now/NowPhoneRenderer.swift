import SwiftUI
import FractonicaKit

/// The words and numbers of the NOW screen on the phone (DESIGN.md §7,
/// 393 × 852): Pentad mark, date words, the reading, two countdown columns
/// with bead counters, and the Sun. The instrument and the limb are drawn by
/// their own views above this.
///
/// `earth` is 0 in pure mode and 1 in Earth mode; in between the Earth lines
/// fade in and the blocks slide the few points the design moves them
/// (date words 534 → 528, reading 580 → 570 …).
enum NowPhoneRenderer {
    static func draw(_ reading: NowReading, earthLines: NowEarth?, earth: Double, in ink: inout Ink) {
        let palette = ink.palette, theme = ink.theme
        let centreX: CGFloat = 196.5
        let e = CGFloat(earth)

        NowPieces.pentadMark(reading, center: CGPoint(x: 31, y: 82), words: reading.pentad?.name ?? "",
                             wordsX: 50, wordSize: 8, baseline: 84.6, in: &ink)

        let wordsY = 534 - 6 * e
        let readingY = wordsY + 46 - 4 * e
        let countY = readingY + 34 + 16 * e
        let sunY = 708 + 6 * e

        guard let live = reading.live else {
            // Outside the catalogue the reading is replaced by one line.
            ink.text(reading.outOfCatalogue, at: CGPoint(x: centreX, y: readingY - 12),
                     theme.engraved(9.5, palette.ash, tracking: theme.type.dateTracking), anchor: .middle)
            Marks.fadingRule(from: CGPoint(x: 20, y: sunY - 34), to: CGPoint(x: 373, y: sunY - 34), in: &ink)
            return
        }

        // The date: words for the finest major period, counts for the minors.
        if let delta = live.majors.last {
            ink.text("\(delta.name) · \(delta.quarter.name)", at: CGPoint(x: centreX, y: wordsY),
                     theme.engraved(9.5, palette.ash, tracking: theme.type.dateTracking), anchor: .middle)
        }
        NowPieces.readingLine(live.terms, at: CGPoint(x: centreX, y: readingY), anchor: .middle,
                              size: 38, trail: 19, gap: 12, trailGap: 6, in: &ink)
        if let earthLines, earth > 0 {
            ink.text(Ink.earth(earthLines.dateLine), at: CGPoint(x: centreX, y: readingY + 22),
                     theme.earthText(11.5, tracking: 0.04), anchor: .middle, opacity: earth)
        }

        // The next thresholds of the two periods on the instrument.
        for (index, countdown) in live.countdowns.prefix(2).enumerated() {
            let x = centreX + (index == 0 ? -90 : 90)
            let count = countdown.cycle.siblings
            Marks.beads(center: CGPoint(x: x, y: countY), count: count, local: countdown.cycle.local,
                        pitch: min(8.2, 150 / CGFloat(max(count - 1, 1))), in: &ink)
            ink.text(NowPieces.countdownLabel(countdown, withLetter: true), at: CGPoint(x: x, y: countY + 17),
                     theme.engraved(7.5, palette.ash), anchor: .middle)
            ink.text(countdown.span, at: CGPoint(x: x, y: countY + 39), theme.value(19), anchor: .middle)
            if let earthLines, earth > 0, index < earthLines.countdownTimes.count {
                let line = "\(earthLines.countdownTimes[index]) · \(earthLines.countdownDurations[index])"
                ink.text(Ink.earth(line), at: CGPoint(x: x, y: countY + 54), theme.earthText(9.5),
                         anchor: .middle, opacity: earth)
            }
        }
        // The rule between the two columns, when there are two (at the
        // catalogue's closing instant nothing comes later and none is listed).
        if live.countdowns.count > 1 {
            ink.line(from: CGPoint(x: centreX, y: countY - 2), to: CGPoint(x: centreX, y: countY + 42 + 14 * e),
                     palette.etch2, width: theme.line.engraving)
        }

        // The Sun.
        Marks.fadingRule(from: CGPoint(x: 20, y: sunY - 34), to: CGPoint(x: 373, y: sunY - 34), in: &ink)
        NowPieces.sunBlock(
            live.sun, earth: earthLines, earthOpacity: earth,
            glyphCentre: CGPoint(x: 58, y: sunY + 1), glyphUnit: 3.7, columns: [118, 200, 292],
            labelY: sunY - 10, valueY: sunY + 12, earthY: sunY + 27, valueSize: 18, earthSize: 9, in: &ink
        )
    }
}
