import SwiftUI
import FractonicaKit

/// The limb (DESIGN.md §8): the scale of level letters. Curved under the
/// instrument on NOW, laid straight on the other screens; the level under the
/// fixed index is the selection. This file only draws; the control that binds
/// it to a level and takes the gestures is `Instrument/LimbControl.swift`.
enum LimbRenderer {
    /// Draws the curved limb, concentric with the instrument.
    /// - Parameters:
    ///   - position: the scale position under the index, as a level index
    ///     that may be fractional while the limb is turning.
    ///   - selectable: the levels the control can stop on; letters outside
    ///     are engraved but dark.
    static func drawCurved(
        metrics: InstrumentMetrics, position: Double, selectable: ClosedRange<Int>, in ink: inout Ink
    ) {
        let palette = ink.palette, center = metrics.center
        let step = metrics.limbStepDegrees, span = metrics.limbSpan
        let ruleRadius = metrics.limbRadius - metrics.limbRuleInset

        // The scale line, fading out towards both ends.
        let halfSweep = CGFloat(span) * step + 5
        let rule = Arc(
            cx: Float(center.x), cy: Float(center.y), radius: Float(ruleRadius),
            start: Float((90 + halfSweep).radians), sweep: Float((-2 * halfSweep).radians)
        )
        let left = center.polar(ruleRadius, (90 + halfSweep).radians).x
        let right = center.polar(ruleRadius, (90 - halfSweep).radians).x
        ink.stroke(rule.cgPath(), fading: fade(palette.etch3, shoulder: 0.3),
                   from: CGPoint(x: left, y: 0), to: CGPoint(x: right, y: 0), width: ink.theme.line.engraving)

        let nearest = Int(position.rounded())
        for index in (nearest - span - 1) ... (nearest + span + 1) {
            guard let level = Level(index) else { continue }
            let offset = CGFloat(Double(index) - position)
            guard abs(offset) <= CGFloat(span) + 0.5 else { continue }
            let angle = (90 - offset * step).radians
            let style = letterStyle(level, offset: offset, selectable: selectable, metrics: metrics, span: CGFloat(span), ink: ink)
            let letterRadius = metrics.limbRadius + 2 * style.focus
            let at = center.polar(letterRadius, angle)
            ink.text(
                level.name, at: CGPoint(x: at.x, y: at.y + style.size * 0.3),
                ink.theme.letter(style.size, style.color), anchor: .middle,
                rotation: angle - .pi / 2, opacity: style.opacity
            )
            let isUnit = level.unit != nil
            ink.line(
                from: center.polar(ruleRadius, angle), to: center.polar(ruleRadius + (isUnit ? 5 : 2.5), angle),
                style.focus > 0.5 ? palette.lumen : (isUnit ? palette.etch3 : palette.etch2),
                width: style.focus > 0.5 ? 1.2 : ink.theme.line.tick
            )
        }
        // The fixed index notch under 6 o'clock.
        notch(at: CGPoint(x: center.x, y: center.y + metrics.limbRadius + metrics.limbNotchOffset), in: &ink)
    }

    /// Draws the limb laid straight, centred on `center` (the baseline of
    /// its letters), `pitch` points per letter.
    static func drawStraight(
        center: CGPoint, position: Double, selectable: ClosedRange<Int>,
        span: Int = 4, pitch: CGFloat = 34, in ink: inout Ink
    ) {
        let palette = ink.palette
        let nearest = Int(position.rounded())
        for index in (nearest - span - 1) ... (nearest + span + 1) {
            guard let level = Level(index) else { continue }
            let offset = CGFloat(Double(index) - position)
            guard abs(offset) <= CGFloat(span) + 0.5 else { continue }
            let x = center.x + offset * pitch
            let focus = max(0, 1 - abs(offset))
            let isUnit = level.unit != nil
            let canSelect = selectable.contains(index)
            let color = focus > 0.5 ? palette.bone : (!canSelect ? palette.etch3 : (isUnit ? palette.ash : palette.between))
            ink.text(
                level.name, at: CGPoint(x: x, y: center.y + 2 * focus),
                ink.theme.letter(13 + 7 * focus, color), anchor: .middle,
                opacity: focus > 0.5 ? 1 : max(0, 1 - abs(offset) * 0.14)
            )
            ink.line(
                from: CGPoint(x: x, y: center.y - 20), to: CGPoint(x: x, y: center.y - (isUnit ? 25 : 22.5)),
                focus > 0.5 ? palette.lumen : (isUnit ? palette.etch3 : palette.etch2),
                width: focus > 0.5 ? 1.2 : ink.theme.line.tick
            )
        }
        Marks.fadingRule(
            from: CGPoint(x: center.x - 160, y: center.y - 20), to: CGPoint(x: center.x + 160, y: center.y - 20), in: &ink
        )
        notch(at: CGPoint(x: center.x, y: center.y + 10), in: &ink)
    }

    // MARK: Pieces

    /// The index: a small caret pointing up at the selected letter.
    private static func notch(at tip: CGPoint, in ink: inout Ink) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: tip.x - 4.5, y: tip.y + 5))
        path.addLine(to: tip)
        path.addLine(to: CGPoint(x: tip.x + 4.5, y: tip.y + 5))
        ink.stroke(path, ink.palette.lumen, width: 1.1)
    }

    private struct LetterStyle {
        var size: CGFloat
        var color: Color
        var opacity: Double
        /// 1 under the index, falling to 0 one letter away.
        var focus: CGFloat
    }

    /// Unit levels are ash, levels between units darker, the letter under the
    /// index bone and larger; letters fade towards the ends of the scale.
    private static func letterStyle(
        _ level: Level, offset: CGFloat, selectable: ClosedRange<Int>, metrics: InstrumentMetrics,
        span: CGFloat, ink: Ink
    ) -> LetterStyle {
        let palette = ink.palette
        let focus = max(0, 1 - abs(offset))
        let size = metrics.limbLetterSize + (metrics.limbFocusLetterSize - metrics.limbLetterSize) * focus
        let canSelect = selectable.contains(level.index)
        let rest = !canSelect ? palette.etch3 : (level.unit != nil ? palette.ash : palette.between)
        let fade = max(0.4, 1 - Double(abs(offset)) / Double(span + 3.5))
        return LetterStyle(size: size, color: focus > 0.5 ? palette.bone : rest,
                           opacity: focus > 0.5 ? 1 : fade, focus: focus)
    }

    private static func fade(_ color: Color, shoulder: CGFloat) -> [Gradient.Stop] {
        [
            .init(color: color.opacity(0), location: 0), .init(color: color, location: shoulder),
            .init(color: color, location: 1 - shoulder), .init(color: color.opacity(0), location: 1),
        ]
    }
}
