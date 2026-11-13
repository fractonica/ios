import SwiftUI
import FractonicaKit

/// Phase glyphs (DESIGN.md §6), drawn from the core's own outlines
/// (`Glyph.outline`, i.e. `frc_glyph_path`): a stem of 3 units per stroke,
/// ink 0.3 units, round caps and joins, the dot above a falling glyph.
enum GlyphRenderer {
    /// Draws one glyph with the centre of its ink box at `center`.
    /// - Parameters:
    ///   - unit: points per design unit (8.8 for the phone's centre odometer).
    ///   - snap: for the big odometer: the ink is rounded to whole device
    ///     pixels and the stem placed on the pixel grid, so that it is crisp.
    static func draw(
        _ glyph: Glyph, center: CGPoint, unit: CGFloat, color: Color,
        glow: Double? = nil, opacity: Double = 1, snap: Bool = false, in ink: inout Ink
    ) {
        var unit = unit
        var x = center.x
        if snap {
            let width = unit * CGFloat(Glyph.inkThickness) / CGFloat(Glyph.unitsPerDesignUnit)
            let snapped = ink.snappedWidth(width)
            unit *= snapped / width
            x = ink.snappedStem(x: x, width: snapped)
        }
        // The ink box of any glyph with this stroke count, from the core:
        // the glyph's origin (the top of its stem) sits this far above its centre.
        let box = Glyph.inkBounds(strokes: glyph.strokes, unit: unit)
        let outline = glyph.outline(unit: unit, origin: CGPoint(x: x, y: center.y - box.midY))
        ink.stroke(outline.strokes, color, width: outline.lineWidth, opacity: opacity, glow: glow)
        ink.fill(outline.dots, color, opacity: opacity)
    }

    /// Draws glyphs side by side, the row centred on `center`: an odometer.
    /// - Parameter pitch: distance between stems in design units (5.6; the
    ///   Sun's three glyphs use 6.4).
    static func drawRow(
        _ glyphs: [Glyph], center: CGPoint, unit: CGFloat, pitch: CGFloat = 5.6, color: Color,
        glow: Double? = nil, opacity: Double = 1, snap: Bool = false, in ink: inout Ink
    ) {
        let step = pitch * unit
        let first = center.x - step * CGFloat(glyphs.count - 1) / 2
        for (index, glyph) in glyphs.enumerated() {
            draw(glyph, center: CGPoint(x: first + CGFloat(index) * step, y: center.y), unit: unit,
                 color: color, glow: glow, opacity: opacity, snap: snap, in: &ink)
        }
    }
}
