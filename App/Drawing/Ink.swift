import SwiftUI

/// The pen every renderer draws with: a `GraphicsContext` already in design
/// coordinates, plus the theme. It offers the few strokes the design uses
/// (a path, a line, a disc, a glow, a line of text) so that renderers read
/// like the design's own description and never touch a colour or font
/// literal.
///
/// You get one from `DesignCanvas { ink in … }`. Renderers take it `inout`
/// only so that they can be composed; drawing does not change it.
struct Ink {
    var context: GraphicsContext
    let theme: Theme
    let layout: LayoutClass
    /// Device pixels per design point (view scale × display scale); 0 when
    /// unknown. Used to snap glyph stems to the pixel grid (DESIGN.md §6).
    let pixelsPerPoint: CGFloat
    /// The design origin in device pixels.
    let pixelOrigin: CGPoint

    var palette: Palette { theme.palette }

    /// Blur sigma of the glow for this arrangement.
    var glowRadius: CGFloat {
        layout == .desktop ? theme.glow.radiusDesktop : theme.glow.radiusPhone
    }

    // MARK: Strokes and fills

    /// Strokes a path with round caps and joins. `glow` is the opacity of a
    /// blurred copy drawn under the crisp stroke (`nil` or 0: none).
    func stroke(
        _ path: CGPath, _ color: Color, width: CGFloat,
        opacity: Double = 1, glow: Double? = nil, dash: [CGFloat] = []
    ) {
        guard !path.isEmpty, opacity > 0 else { return }
        let shape = Path(path)
        let style = StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round, dash: dash)
        if let glow, glow > 0 {
            var halo = context
            halo.opacity = glow * opacity
            halo.addFilter(.blur(radius: glowRadius))
            halo.stroke(shape, with: .color(color), style: style)
        }
        var pen = context
        pen.opacity = opacity
        pen.stroke(shape, with: .color(color), style: style)
    }

    /// Strokes a path with a colour that fades in and out along a straight
    /// line (the limb's scale, the rules that die away at the margins).
    func stroke(_ path: CGPath, fading stops: [Gradient.Stop], from start: CGPoint, to end: CGPoint, width: CGFloat) {
        context.stroke(
            Path(path), with: .linearGradient(Gradient(stops: stops), startPoint: start, endPoint: end),
            style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
        )
    }

    /// Fills a path.
    func fill(_ path: CGPath, _ color: Color, opacity: Double = 1, glow: Double? = nil) {
        guard !path.isEmpty, opacity > 0 else { return }
        let shape = Path(path)
        if let glow, glow > 0 {
            var halo = context
            halo.opacity = glow * opacity
            halo.addFilter(.blur(radius: glowRadius))
            halo.fill(shape, with: .color(color))
        }
        var pen = context
        pen.opacity = opacity
        pen.fill(shape, with: .color(color))
    }

    /// A straight line.
    func line(from start: CGPoint, to end: CGPoint, _ color: Color, width: CGFloat, opacity: Double = 1, dash: [CGFloat] = []) {
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)
        stroke(path, color, width: width, opacity: opacity, dash: dash)
    }

    /// A circle: filled, outlined, or both.
    func circle(
        _ center: CGPoint, radius: CGFloat, fill: Color? = nil, stroke: Color? = nil,
        width: CGFloat = 1, opacity: Double = 1, glow: Double? = nil
    ) {
        let path = CGPath(
            ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius),
            transform: nil
        )
        if let fill { self.fill(path, fill, opacity: opacity, glow: glow) }
        if let stroke { self.stroke(path, stroke, width: width, opacity: opacity, glow: fill == nil ? glow : nil) }
    }

    // MARK: Layers

    /// Draws `body` as one layer with its own opacity, scaled about a point:
    /// the zoom between focus levels.
    func layer(opacity: Double, scale: CGFloat = 1, about anchor: CGPoint = .zero, _ body: (inout Ink) -> Void) {
        guard opacity > 0.001 else { return }
        var outer = context
        outer.opacity = opacity
        outer.drawLayer { inner in
            if scale != 1 {
                inner.translateBy(x: anchor.x, y: anchor.y)
                inner.scaleBy(x: scale, y: scale)
                inner.translateBy(x: -anchor.x, y: -anchor.y)
            }
            var ink = Ink(
                context: inner, theme: theme, layout: layout,
                // A scaled layer is in motion: no pixel snapping.
                pixelsPerPoint: scale == 1 ? pixelsPerPoint : 0, pixelOrigin: pixelOrigin
            )
            body(&ink)
        }
    }

    // MARK: Pixel grid

    /// `x` moved to the nearest place where a vertical stroke `width` wide
    /// has crisp edges: a pixel centre for an odd width in pixels, a pixel
    /// boundary for an even one. Unchanged when the pixel scale is unknown.
    func snappedStem(x: CGFloat, width: CGFloat) -> CGFloat {
        guard pixelsPerPoint > 0 else { return x }
        let pixels = (width * pixelsPerPoint).rounded()
        let position = x * pixelsPerPoint + pixelOrigin.x
        let snapped = Int(pixels) % 2 == 1 ? position.rounded(.down) + 0.5 : position.rounded()
        return (snapped - pixelOrigin.x) / pixelsPerPoint
    }

    /// A stroke width rounded to whole device pixels (at least one).
    func snappedWidth(_ width: CGFloat) -> CGFloat {
        guard pixelsPerPoint > 0 else { return width }
        return max((width * pixelsPerPoint).rounded(), 1) / pixelsPerPoint
    }
}

// MARK: - Geometry helpers shared by the renderers

extension CGPoint {
    /// The point at `radius` from this one in direction `angle` (radians,
    /// y down: 0 is 3 o'clock, positive is clockwise).
    func polar(_ radius: CGFloat, _ angle: CGFloat) -> CGPoint {
        CGPoint(x: x + radius * cos(angle), y: y + radius * sin(angle))
    }
}

extension CGFloat {
    /// Degrees to radians.
    var radians: CGFloat { self * .pi / 180 }
}
