import SwiftUI
import FractonicaKit

/// LADDER: the spectral catalogue. All 63 rungs on the rim of a great wheel,
/// the rung at its middle enlarged (DESIGN.md §7 "Ladder", §8, §9;
/// design/astrolabe/screen3.png and screen3_pure.png).
///
/// - **State**: the rung at the middle is `model.lensLevel`, the rung of
///   interest that the lens inspects too. Turning the wheel never changes the
///   instrument's focus; a long press does.
/// - **Gestures** (§8): drag vertically to turn the wheel (it settles on a
///   rung); tap the focused row to open the LENS on it, tap another row to
///   bring it to the middle; long-press a row to focus the instrument on it
///   when it is focusable (levels 0...13). The spine at the right edge is a
///   scrubber over the whole ladder. On the Mac the scroll wheel and ↑ ↓ turn
///   the wheel and Return opens the lens.
/// - **Drawing**: `LadderRenderer` (rows, rim, headings) and `LadderSpine`,
///   placed by `LadderGeometry`, on one `MotionCanvas`.
/// - **Redraw**: nothing here moves with time; only the Saros interval at the
///   cursor is read from the clock (Earth values and bands are laid from it).
struct LadderScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.designSpace) private var space

    var body: some View {
        // Read here, so that the wheel below is redrawn when the interval
        // changes (an eclipse) and not at every tick of the clock.
        LadderWheel(interval: LadderReading.interval(model.clock, at: model.instant),
                    geometry: .standard(space.layout))
    }
}

/// The wheel with its gestures and its accessibility element.
private struct LadderWheel: View {
    let interval: SarosInterval
    let geometry: LadderGeometry

    @Environment(AppModel.self) private var model
    @Environment(\.designSpace) private var space
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The scale position at the wheel's middle; `nil` until the view has
    /// appeared (then the model's rung is shown as it is).
    @State private var position: Double?
    @State private var drag: DragStart?
    /// The pending long press, and whether it fired during this touch.
    @State private var press: Task<Void, Never>?
    @State private var pressFired = false
    /// A rung a long press could not focus (finer than the instrument
    /// reads): its row says so for a moment.
    @State private var refused: Level?
    @State private var refusalClear: Task<Void, Never>?

    private struct DragStart {
        var position: Double
        var point: CGPoint
        var moved = false
    }

    /// How far a finger may wander and still be a tap or a long press.
    private static let slop: CGFloat = 6

    var body: some View {
        let geometry = geometry, interval = interval
        let level = model.lensLevel, focus = model.focus
        let marks = LadderSpine.Mark.read(interval: interval)
        let shown = LadderMotion(position: position ?? Double(level.index), earth: model.mode == .earth ? 1 : 0,
                                 refusal: refused == nil ? 0 : 1)
        let refused = refused
        ZStack {
            // The plate was turned on the wheel's own centre.
            PlateView(center: geometry.wheelCenter, firstRadius: 6)
            MotionCanvas(value: shown) { ink, motion in
                LadderRenderer.draw(geometry: geometry, interval: interval, position: motion.position,
                                    earth: motion.earth,
                                    refusal: refused.map { ($0, motion.refusal) }, in: &ink)
                LadderSpine.draw(marks, geometry: geometry, position: motion.position, focus: focus, in: &ink)
            }
            .animation(Motion.mode.animation(reduceMotion: reduceMotion), value: model.mode)
            .animation(Motion.mode.animation(reduceMotion: reduceMotion), value: refused)

            Color.clear
                .contentShape(Path(geometry.wheelHitFrame).applying(space.transform))
                .gesture(turning)
                .accessibilityHidden(true)
            Color.clear
                .contentShape(Path(geometry.spineHitFrame).applying(space.transform))
                .gesture(scrubbing)
                .accessibilityHidden(true)

            spokenRung(level)
        }
        .onAppear { if position == nil { position = Double(model.lensLevel.index) } }
        .onChange(of: level) { _, new in
            // Moved from elsewhere (a key, the scroll wheel, a long press): turn to it.
            guard drag == nil else { return }
            settle(on: new)
        }
        .onScrollWheelStep { model.step(by: $0) }
    }

    // MARK: Turning the wheel

    private var turning: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let point = space.designPoint(value.location)
                var start = drag ?? DragStart(position: position ?? Double(model.lensLevel.index), point: point)
                if drag == nil { beginPress(at: point, position: start.position) }
                if abs(point.y - start.point.y) > LadderWheel.slop || abs(point.x - start.point.x) > LadderWheel.slop {
                    start.moved = true
                    cancelPress()
                }
                drag = start
                guard start.moved, !pressFired else { return }
                // Dragging up brings the finer rungs to the middle.
                turn(to: start.position + Double((start.point.y - point.y) / geometry.pitch))
            }
            .onEnded { value in
                let point = space.designPoint(value.location)
                let start = drag
                drag = nil
                cancelPress()
                defer { pressFired = false }
                guard let start, !pressFired else { return settle(on: model.lensLevel) }
                if start.moved {
                    // A flick carries the wheel on to where it would have stopped.
                    let predicted = space.designPoint(value.predictedEndLocation)
                    let carried = start.position + Double((start.point.y - predicted.y) / geometry.pitch)
                    settle(on: rung(nearest: carried))
                } else if abs(point.y - geometry.focusY) <= geometry.halfHeight(offset: 0) {
                    // A tap on the focused row opens the lens on it.
                    model.openLens(on: model.lensLevel)
                } else if let tapped = geometry.level(atY: point.y, position: start.position) {
                    settle(on: tapped)
                }
            }
    }

    /// The spine scrubs: the rung under the finger comes to the middle.
    private var scrubbing: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let point = space.designPoint(value.location)
                if drag == nil { drag = DragStart(position: position ?? Double(model.lensLevel.index), point: point) }
                turn(to: geometry.spinePosition(atY: point.y))
            }
            .onEnded { _ in
                drag = nil
                settle(on: model.lensLevel)
            }
    }

    /// Follows the finger: the wheel is between rungs, the rung of interest
    /// is the nearest one.
    private func turn(to target: Double) {
        let turned = min(max(target, -0.3), Double(Level.count - 1) + 0.3)
        position = turned
        let nearest = rung(nearest: turned)
        if nearest != model.lensLevel { model.inspect(nearest) }
    }

    private func rung(nearest position: Double) -> Level {
        Level(min(max(Int(position.rounded()), 0), Level.count - 1)) ?? model.lensLevel
    }

    /// Brings `level` to the middle and lets the wheel come to rest there.
    private func settle(on level: Level) {
        if level != model.lensLevel { model.inspect(level) }
        withAnimation(Motion.zoom.animation(reduceMotion: reduceMotion)) { position = Double(level.index) }
    }

    // MARK: Long press

    /// A finger resting on a row for half a second focuses the instrument on
    /// that rung, if the instrument can show it (design/README.md ruling 9).
    /// A rung finer than that comes to the middle and its row says, for a
    /// moment, that it is finer than the instrument reads: the press is
    /// answered, never silently dropped.
    private func beginPress(at point: CGPoint, position: Double) {
        pressFired = false
        press?.cancel()
        let onFocusedRow = abs(point.y - geometry.focusY) <= geometry.halfHeight(offset: 0)
        guard let pressed = onFocusedRow ? rung(nearest: position) : geometry.level(atY: point.y, position: position)
        else { return }
        press = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            pressFired = true
            guard AppModel.focusRange.contains(pressed.index) else {
                settle(on: pressed)
                refuse(pressed)
                return
            }
            // The focus brings the rung of interest with it: the wheel turns to it.
            model.setFocus(pressed)
            settle(on: pressed)
        }
    }

    /// Shows the refusal on `level`'s row, then lets it fade.
    private func refuse(_ level: Level) {
        refused = level
        refusalClear?.cancel()
        refusalClear = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1800))
            guard !Task.isCancelled else { return }
            refused = nil
        }
    }

    private func cancelPress() {
        press?.cancel()
        press = nil
    }

    // MARK: Accessibility

    /// The rung at the middle is one adjustable element: swipe up or down to
    /// turn the wheel, activate to open the lens. In pure mode the rung is
    /// read without its Earth translation, so none is spoken.
    private func spokenRung(_ level: Level) -> some View {
        let rung = RungReading.read(level, interval: interval, earth: model.mode == .earth)
        return Color.clear
            .accessibilityElement()
            .accessibilityLabel(LadderSpeech.label(rung))
            .accessibilityIdentifier("ladder.rung")
            .accessibilityValue(LadderSpeech.value(rung))
            .accessibilityHint("Opens the lens")
            .accessibilityAddTraits(.isButton)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: model.step(by: 1)
                case .decrement: model.step(by: -1)
                @unknown default: break
                }
            }
            .accessibilityAction { model.openLens(on: level) }
            .accessibilityAction(named: "Focus the instrument") {
                if rung.isFocusable { model.setFocus(level) }
            }
            .designFrame(geometry.focusFrame)
            .allowsHitTesting(false)
    }
}

/// What the ladder's canvas animates: where the wheel is, and how far the
/// Earth values have faded in.
struct LadderMotion: VectorArithmetic, Sendable {
    var position: Double
    /// 0 pure ... 1 Earth.
    var earth: Double
    /// 0 ... 1: how far the refusal of a long press is shown.
    var refusal: Double = 0

    static let zero = LadderMotion(position: 0, earth: 0)

    static func + (lhs: LadderMotion, rhs: LadderMotion) -> LadderMotion {
        LadderMotion(position: lhs.position + rhs.position, earth: lhs.earth + rhs.earth,
                     refusal: lhs.refusal + rhs.refusal)
    }

    static func - (lhs: LadderMotion, rhs: LadderMotion) -> LadderMotion {
        LadderMotion(position: lhs.position - rhs.position, earth: lhs.earth - rhs.earth,
                     refusal: lhs.refusal - rhs.refusal)
    }

    mutating func scale(by rhs: Double) {
        position *= rhs
        earth *= rhs
        refusal *= rhs
    }

    var magnitudeSquared: Double { position * position + earth * earth + refusal * refusal }
}
