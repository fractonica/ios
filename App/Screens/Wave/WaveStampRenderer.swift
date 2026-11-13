import SwiftUI
import FractonicaKit

/// The stamp of the WAVE screen (DESIGN.md §8, "Through time"): the moment
/// as a row of nine tumblers, `α#6 β#4 γ#9 δ#3 ε#5 34η 29ι 21λ 3ν`, each on
/// its own rule; the selected one shows its neighbours ghosted above and
/// below. In Earth mode a second row stands under it on the same columns:
/// the Earth date-time, whose six fields are tumblers too.
///
/// This file only draws. The gestures are in `WaveScreen.swift`, the
/// stepping in `Model/AppModel+TimeTravel.swift`.
enum WaveStampRenderer {
    /// A tumbler in the hand: which one, and how far its column has been
    /// pulled from rest, in points (positive: downwards).
    struct Pull: Equatable, Sendable {
        var field: StampField
        var offset: CGFloat
    }

    /// - Parameters:
    ///   - selected: the tumbler whose neighbours are shown.
    ///   - ghosts: its neighbours' texts.
    ///   - pull: the drag in progress, if any.
    ///   - earth: the Earth row's texts and its opacity (0: pure mode).
    static func draw(
        _ reading: WaveReading, layout: WaveLayout, selected: StampField, ghosts: StampGhosts,
        pull: Pull?, earthFields: EarthText.EarthFields?, earth: Double, in ink: inout Ink
    ) {
        let palette = ink.palette, theme = ink.theme
        ink.text("Moment", at: CGPoint(x: layout.stampLeft, y: layout.captionY), theme.engraved(6.8, palette.etch3))

        guard let live = reading.live else {
            // Outside the catalogue the stamp is replaced by one line.
            ink.text(reading.outOfCatalogue, at: CGPoint(x: layout.stampLeft, y: layout.stampY - 2),
                     theme.engraved(9.5, palette.ash, tracking: theme.type.dateTracking))
            return
        }

        let half = layout.columnWidth / 2 - 5
        let ruleY = layout.stampY + layout.stampSize * 0.6
        for (index, term) in live.terms.enumerated() {
            let x = layout.columnX(index)
            let isSelected = selected == .unit(term.unit)
            let offset = pull?.field == .unit(term.unit) ? pull?.offset ?? 0 : 0
            tumbler(
                term.text, ghosts: isSelected ? ghosts : nil, at: CGPoint(x: x, y: layout.stampY), offset: offset,
                pitch: layout.tumblerPitch, lift: 4,
                style: theme.value(layout.stampSize),
                ghostStyle: theme.value(layout.ghostSize, digits: palette.etch3, letters: palette.etch3), in: &ink
            )
            ink.line(from: CGPoint(x: x - half, y: ruleY), to: CGPoint(x: x + half, y: ruleY),
                     isSelected ? palette.lumen : palette.etch2, width: isSelected ? 1.2 : theme.line.engraving)
        }

        guard let earthFields, earth > 0 else { return }
        drawEarthRow(earthFields, layout: layout, selected: selected, ghosts: ghosts, pull: pull,
                     opacity: earth, in: &ink)
    }

    /// The Earth date-time on the stamp's columns: the weekday led by the
    /// Earth sign, then day, month, year, hour, minute and second, each a
    /// tumbler on its own rule, then the zone, shown here and nowhere else.
    private static func drawEarthRow(
        _ fields: EarthText.EarthFields, layout: WaveLayout, selected: StampField, ghosts: StampGhosts,
        pull: Pull?, opacity: Double, in ink: inout Ink
    ) {
        let palette = ink.palette, theme = ink.theme
        let y = layout.earthRowY
        let style = theme.earthText(layout.earthSize)
        var ghostStyle = theme.earthText(layout.earthGhostSize)
        ghostStyle.color = palette.etch3

        ink.layer(opacity: opacity) { ink in
            ink.text(Ink.earth(fields.weekday), at: CGPoint(x: layout.columnX(0), y: y), style, anchor: .middle)
            let half = layout.columnWidth / 2 - 7
            let ruleY = y + layout.earthSize * 0.6
            for field in EarthField.allCases {
                let x = layout.columnX(layout.earthColumn(field))
                let isSelected = selected == .earth(field)
                let offset = pull?.field == .earth(field) ? pull?.offset ?? 0 : 0
                tumbler(fields[field], ghosts: isSelected ? ghosts : nil, at: CGPoint(x: x, y: y), offset: offset,
                        pitch: layout.earthPitch, lift: 2, style: style, ghostStyle: ghostStyle, in: &ink)
                ink.line(from: CGPoint(x: x - half, y: ruleY), to: CGPoint(x: x + half, y: ruleY),
                         isSelected ? palette.lumen : palette.etch2, width: isSelected ? 1.2 : theme.line.engraving)
            }
            // The marks between the fields, as the date line writes them.
            var mark = theme.earthText(layout.earthSize)
            mark.color = palette.etch3
            let boundary = { (column: Int) in layout.stampLeft + layout.columnWidth * CGFloat(column) }
            ink.text("·", at: CGPoint(x: boundary(layout.earthColumn(.hour)), y: y), mark, anchor: .middle)
            ink.text(":", at: CGPoint(x: boundary(layout.earthColumn(.minute)), y: y - 0.6), mark, anchor: .middle)
            ink.text(":", at: CGPoint(x: boundary(layout.earthColumn(.second)), y: y - 0.6), mark, anchor: .middle)
            ink.text(fields.zone, at: CGPoint(x: layout.columnX(layout.earthColumn(.second) + 1), y: y), style,
                     anchor: .middle)
        }
    }

    /// One tumbler: the value on its baseline and, when selected, the value
    /// one step earlier above it and one step later below it. Pulled by
    /// `offset`, the column slides and the value nearest the baseline is the
    /// bright one.
    /// - Parameters:
    ///   - pitch: the distance between neighbouring values.
    ///   - lift: how much lower than `pitch` the ghosts sit (the design sets
    ///     them 19 above and 27 below a 15 pt term: clear of its rule).
    private static func tumbler(
        _ text: String, ghosts: StampGhosts?, at point: CGPoint, offset: CGFloat, pitch: CGFloat, lift: CGFloat,
        style: InkTextStyle, ghostStyle: InkTextStyle, in ink: inout Ink
    ) {
        guard let ghosts else {
            ink.text(text, at: point, style, anchor: .middle)
            return
        }
        let column: [(String?, CGFloat)] = [(ghosts.above, -1), (text, 0), (ghosts.below, 1)]
        for (value, step) in column {
            guard let value else { continue }
            // Distance from the baseline in steps: 0 is the value read.
            let distance = step + offset / pitch
            let away = min(abs(distance), 1)
            let y = point.y + distance * pitch + lift * away
            ink.text(value, at: CGPoint(x: point.x, y: y), style, anchor: .middle, opacity: Double(1 - away))
            ink.text(value, at: CGPoint(x: point.x, y: y), ghostStyle, anchor: .middle,
                     opacity: Double(away) * Double(max(0, 1.6 - abs(distance)) / 0.6).clamped(to: 0 ... 1))
        }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
