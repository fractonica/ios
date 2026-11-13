import SwiftUI

/// The ground every screen stands on (DESIGN.md §2): the void, a radial
/// vignette centred on the instrument, and the machining marks of a plate
/// that was turned on the same centre.
enum PlateRenderer {
    /// - Parameters:
    ///   - center: the centre the plate was "turned" on: the instrument's on
    ///     NOW, each screen's own elsewhere.
    ///   - firstRadius: the radius of the first machining mark (the marks
    ///     start outside the instrument).
    static func draw(center: CGPoint, firstRadius: CGFloat, in ink: inout Ink) {
        let palette = ink.palette
        let size = ink.layout.designSize
        let reach = max(size.width, size.height) * 0.7
        let disc = Path(ellipseIn: CGRect(x: center.x - reach, y: center.y - reach, width: 2 * reach, height: 2 * reach))
        ink.context.fill(disc, with: .radialGradient(
            Gradient(stops: [
                .init(color: palette.plate, location: 0),
                .init(color: palette.plate.opacity(0.55), location: 0.45),
                .init(color: palette.void.opacity(0), location: 1),
            ]),
            center: center, startRadius: 0, endRadius: reach
        ))
        // Concentric marks, spaced 19 / 26 / 33 and fading outwards.
        let limit = (size.width * size.width + size.height * size.height).squareRoot()
        var radius = firstRadius
        var index = 0
        while radius < limit {
            ink.circle(center, radius: radius, stroke: palette.etch1, width: ink.theme.line.hairline,
                       opacity: 0.9 - min(0.6, Double(index) * 0.03))
            radius += 19 + CGFloat(index % 3) * 7
            index += 1
        }
    }
}

/// The plate as a view: the first layer of every screen.
///
///     ZStack {
///         PlateView(center: metrics.center, firstRadius: 214)
///         …
///     }
struct PlateView: View {
    let center: CGPoint
    let firstRadius: CGFloat

    var body: some View {
        DesignCanvas { ink in
            PlateRenderer.draw(center: center, firstRadius: firstRadius, in: &ink)
        }
    }
}
