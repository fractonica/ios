import SwiftUI
import FractonicaKit

/// The limb: the one control that moves across the scales (DESIGN.md §8). A
/// scale of level letters under a fixed index; the letter under the index is
/// the selection. Curved under the instrument on NOW, laid straight on the
/// lens and the wave: the same control, bound to the same level.
///
///     LimbControl(level: model.focusBinding, selectable: AppModel.focusRange,
///                 shape: .curved(.standard(space.layout)))
///     LimbControl(level: model.focusBinding, selectable: AppModel.focusRange,
///                 shape: .straight(center: CGPoint(x: 196.5, y: 742)))
///
/// Drag along it to turn it (one letter per 8.2° on the phone, per 34 pt when
/// straight); tap a letter to go straight there. The selection changes as the
/// letters pass the index; on release the limb settles on the selected letter.
/// To assistive technology it is one adjustable element.
struct LimbControl: View {
    enum Shape: Equatable {
        /// Concentric with the instrument described by the metrics.
        case curved(InstrumentMetrics)
        /// Laid straight: `center` is the middle of the letters' baseline.
        case straight(center: CGPoint, span: Int = 4, pitch: CGFloat = 34)
    }

    @Binding var level: Level
    /// The levels the limb can stop on (the instrument: 0...13).
    let selectable: ClosedRange<Int>
    let shape: Shape

    @Environment(\.designSpace) private var space
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The scale position under the index while it differs from the selection
    /// (turning, settling); `nil` at rest.
    @State private var position: Double?
    @State private var drag: DragStart?

    private struct DragStart {
        var position: Double
        var point: CGPoint
    }

    var body: some View {
        let selectable = selectable, shape = shape
        ZStack {
            MotionCanvas(value: position ?? Double(level.index)) { ink, position in
                switch shape {
                case .curved(let metrics):
                    LimbRenderer.drawCurved(metrics: metrics, position: position, selectable: selectable, in: &ink)
                case .straight(let center, let span, let pitch):
                    LimbRenderer.drawStraight(center: center, position: position, selectable: selectable,
                                              span: span, pitch: pitch, in: &ink)
                }
            }
            Color.clear
                .contentShape(hitShape)
                .gesture(turning)
                .accessibilityHidden(true)
            // Accessibility before `.designFrame`: a placed view fills its parent.
            Color.clear
                .accessibilityElement()
                .accessibilityLabel("Limb")
                .accessibilityIdentifier("limb")
                .accessibilityValue(spokenLevel)
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: select(level.index + 1)
                    case .decrement: select(level.index - 1)
                    @unknown default: break
                    }
                }
                .designFrame(spokenFrame)
                .allowsHitTesting(false)
        }
        .onChange(of: level) { _, new in
            // Moved from elsewhere (a key, a tap on a ring): turn to it.
            guard drag == nil else { return }
            withAnimation(Motion.zoom.animation(reduceMotion: reduceMotion)) { position = Double(new.index) }
        }
    }

    /// `Eta, Helion`: the letter's word and, for a unit, its name.
    private var spokenLevel: String {
        [level.word, level.unit?.name].compactMap { $0 }.joined(separator: ", ")
    }

    // MARK: Turning

    private var turning: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let point = space.designPoint(value.location)
                let start = drag ?? DragStart(position: position ?? Double(level.index), point: point)
                if drag == nil { drag = start }
                let moved = lettersBetween(start.point, point)
                let low = Double(selectable.lowerBound) - 0.3, high = Double(selectable.upperBound) + 0.3
                let turned = min(max(start.position + moved, low), high)
                position = turned
                select(Int(turned.rounded()), settle: false)
            }
            .onEnded { value in
                let point = space.designPoint(value.location)
                let start = drag
                drag = nil
                if let start, hypot(point.x - start.point.x, point.y - start.point.y) < 6 {
                    // A tap: go to the letter under the finger.
                    select(Int((start.position + lettersFromIndex(point)).rounded()))
                }
                withAnimation(Motion.zoom.animation(reduceMotion: reduceMotion)) { position = Double(level.index) }
            }
    }

    /// Selects a level by index, kept inside the selectable range.
    private func select(_ index: Int, settle: Bool = true) {
        let clamped = min(max(index, selectable.lowerBound), selectable.upperBound)
        guard clamped != level.index, let target = Level(clamped) else { return }
        level = target
        if settle, drag == nil {
            withAnimation(Motion.zoom.animation(reduceMotion: reduceMotion)) { position = Double(clamped) }
        }
    }

    /// How many letters the scale turned when the finger went from `a` to `b`.
    /// Dragging towards the left brings finer levels under the index.
    private func lettersBetween(_ a: CGPoint, _ b: CGPoint) -> Double {
        switch shape {
        case .curved(let metrics):
            var degrees = (angle(of: b, about: metrics.center) - angle(of: a, about: metrics.center)) * 180 / .pi
            if degrees > 180 { degrees -= 360 }
            if degrees < -180 { degrees += 360 }
            return Double(degrees / metrics.limbStepDegrees)
        case .straight(_, _, let pitch):
            return Double((a.x - b.x) / pitch)
        }
    }

    /// How many letters from the index the point `p` is (positive: finer).
    private func lettersFromIndex(_ p: CGPoint) -> Double {
        switch shape {
        case .curved(let metrics):
            let degrees = 90 - angle(of: p, about: metrics.center) * 180 / .pi
            return Double(degrees / metrics.limbStepDegrees)
        case .straight(let center, _, let pitch):
            return Double((p.x - center.x) / pitch)
        }
    }

    private func angle(of point: CGPoint, about center: CGPoint) -> CGFloat {
        atan2(point.y - center.y, point.x - center.x)
    }

    // MARK: Hit area

    /// Where assistive technology finds the limb: around the index.
    private var spokenFrame: CGRect {
        switch shape {
        case .curved(let metrics):
            return CGRect(x: metrics.center.x - 60, y: metrics.center.y + metrics.limbRadius - 26, width: 120, height: 52)
        case .straight(let center, _, _):
            return CGRect(x: center.x - 60, y: center.y - 30, width: 120, height: 52)
        }
    }

    /// The band the letters live in, in the view's own coordinates: an
    /// annular sector for the curved limb (so that it does not cover the
    /// instrument above it), a strip for the straight one.
    private var hitShape: Path {
        var path = Path()
        switch shape {
        case .curved(let metrics):
            let half = (CGFloat(metrics.limbSpan) + 0.8) * metrics.limbStepDegrees
            let inner = metrics.limbRadius - metrics.limbRuleInset - 6
            let outer = metrics.limbRadius + metrics.limbNotchOffset + 10
            path.addArc(center: metrics.center, radius: outer, startAngle: .degrees(90 - half),
                        endAngle: .degrees(90 + half), clockwise: false)
            path.addArc(center: metrics.center, radius: inner, startAngle: .degrees(90 + half),
                        endAngle: .degrees(90 - half), clockwise: true)
            path.closeSubpath()
        case .straight(let center, let span, let pitch):
            let half = (CGFloat(span) + 0.6) * pitch
            path.addRect(CGRect(x: center.x - half, y: center.y - 34, width: 2 * half, height: 56))
        }
        return path.applying(space.transform)
    }
}
