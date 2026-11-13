import SwiftUI

/// The four sigils of the navigation (DESIGN.md §8), drawn with the same 1 pt
/// line as everything else: ring-with-planet (NOW), rungs (LADDER), reticle
/// (LENS), two half-arcs (WAVE). No bar, no background, no badge.
enum SigilRenderer {
    static func draw(_ screen: Screen, center: CGPoint, color: Color, in ink: inout Ink) {
        let width = ink.theme.line.sigil
        let x = center.x, y = center.y
        switch screen {
        case .now:
            ink.circle(center, radius: 7, stroke: color, width: width)
            ink.circle(center.polar(7, CGFloat(-50).radians), radius: 1.9, fill: color)
        case .ladder:
            for (rung, length) in [14, 11, 8, 5].enumerated() {
                let rungY = y - 6 + CGFloat(rung) * 4
                ink.line(from: CGPoint(x: x - 7, y: rungY), to: CGPoint(x: x - 7 + CGFloat(length), y: rungY), color, width: width)
            }
        case .lens:
            ink.circle(center, radius: 4.5, stroke: color, width: width)
            for quarter in 0 ..< 4 {
                let angle = CGFloat(quarter) * .pi / 2
                ink.line(from: center.polar(6.5, angle), to: center.polar(9, angle), color, width: width)
            }
        case .wave:
            // Two half-arcs: one half-cycle over the axis, the next under it.
            let path = CGMutablePath()
            path.move(to: CGPoint(x: x - 9, y: y))
            path.addArc(center: CGPoint(x: x - 4.5, y: y), radius: 4.5, startAngle: .pi, endAngle: 0, clockwise: false)
            path.addArc(center: CGPoint(x: x + 4.5, y: y), radius: 4.5, startAngle: .pi, endAngle: 0, clockwise: true)
            ink.stroke(path, color, width: width)
        }
    }
}
