#if canImport(CoreGraphics)
import CoreGraphics

/// A glyph ready for Core Graphics / SwiftUI, in points.
///
///     let outline = glyph.outline(unit: 8.8, origin: stemTop)
///     context.stroke(Path(outline.strokes), with: .color(lumen),
///                    style: StrokeStyle(lineWidth: outline.lineWidth, lineCap: .round, lineJoin: .round))
///     context.fill(Path(outline.dots), with: .color(lumen))
public struct GlyphOutline {
    /// The stem and the strokes: **stroke** it with ``lineWidth``, round caps
    /// and round joins (SPEC §9.1).
    public let strokes: CGPath
    /// The dot, if the glyph has one: **fill** it. Empty otherwise.
    public let dots: CGPath
    /// The ink thickness, 0.3 design units, in points.
    public let lineWidth: CGFloat
    /// The ink bounds of any glyph with this stroke count, in points: lay
    /// glyphs out by this box so that a row does not jump as values change.
    public let bounds: CGRect
}

extension Glyph {
    /// The outline in points.
    /// - Parameters:
    ///   - unit: points per design unit (DESIGN.md §6: 8.8 for the phone's
    ///     centre odometer). The stem is 3 units per stroke.
    ///   - origin: where the top of the stem (the glyph's own origin) goes.
    ///     The dot sits above it, the stem runs down from it.
    public func outline(unit: CGFloat, origin: CGPoint = .zero) -> GlyphOutline {
        // The only numbers made here are the same coordinates in another
        // scale: points = origin + core coordinate × unit / FRC_GLYPH_UNIT.
        let scale = unit / CGFloat(Glyph.unitsPerDesignUnit)
        func point(_ p: GlyphPoint) -> CGPoint {
            CGPoint(x: origin.x + CGFloat(p.x) * scale, y: origin.y + CGFloat(p.y) * scale)
        }

        let strokes = CGMutablePath()
        let dots = CGMutablePath()
        for element in path {
            switch element {
            case .move(let to):
                strokes.move(to: point(to))
            case .line(let to):
                strokes.addLine(to: point(to))
            case .cubic(let control1, let control2, let to):
                strokes.addCurve(to: point(to), control1: point(control1), control2: point(control2))
            case .dot(let center, let radius):
                let r = CGFloat(radius) * scale
                let c = point(center)
                dots.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
            }
        }
        return GlyphOutline(
            strokes: strokes,
            dots: dots,
            lineWidth: CGFloat(Glyph.inkThickness) * scale,
            bounds: Glyph.inkBounds(strokes: self.strokes, unit: unit, origin: origin)
        )
    }

    /// The ink bounds of any glyph of `strokes` strokes, in points
    /// (``bounds(strokes:)`` in another scale).
    public static func inkBounds(strokes: Int, unit: CGFloat, origin: CGPoint = .zero) -> CGRect {
        let scale = unit / CGFloat(Glyph.unitsPerDesignUnit)
        let box = Glyph.bounds(strokes: strokes)
        return CGRect(
            x: origin.x + CGFloat(box.minX) * scale,
            y: origin.y + CGFloat(box.minY) * scale,
            width: CGFloat(box.maxX - box.minX) * scale,
            height: CGFloat(box.maxY - box.minY) * scale
        )
    }
}
#endif
