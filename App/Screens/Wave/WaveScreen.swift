import SwiftUI
import FractonicaKit

/// WAVE: the timeline. Time moves under a fixed hairline (DESIGN.md §7
/// "Timeline", §8 "Through time", §9, §10; design/astrolabe/screen5.png and
/// screen5_greg.png).
///
/// From the top: the **stamp** (nine tumblers; in Earth mode the Earth
/// date-time under them, six tumblers more) with the NOW mark and the "go
/// to" field; the **Sun's lane** (one solar sync, its Pentads and quarters);
/// the **wave** of the focused level with its threshold rule; the straight
/// **limb** that changes the focus (the wave re-scales to it); the **list**
/// of next thresholds.
///
/// - **State**: the moment is `model.instant`. Everything here that moves it
///   goes through `model.scrub(to:)`, so the scrubbing is global: the
///   instrument, the lens and the ladder show the scrubbed moment until NOW
///   is tapped. The focus is `model.focus`, the selected tumbler
///   `model.activeStampField`.
/// - **Gestures** (§8, §10): drag the wave to scrub (inertia, then a snap
///   to a threshold or to the present within 6 pt); drag the Sun's lane for
///   coarse moves (one sync per width), or tap it to go there; drag a
///   tumbler up or down to step its term. On the Mac ↑ ↓ step the selected
///   tumbler; scrolling up and down steps the tumbler under the pointer and
///   turns the limb elsewhere; a sideways two-finger swipe over the wave or
///   the Sun's lane moves through time as a drag there does; ← → turn the
///   limb. The coast after a flick is the model's (`AppModel.glide`): any
///   other move through time stops it.
/// - **Drawing**: `WaveStampRenderer`, `WaveSunRenderer`, `WaveRenderer`,
///   `WaveListRenderer`, placed by `WaveLayout`, from one `WaveReading` per
///   redraw (and one `WaveEarth`, in Earth mode only).
/// - **Redraw**: with the model's clock; the scheduler paces it by the focus.
struct WaveScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.designSpace) private var space
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The tumbler in the hand.
    @State private var pull: TumblerPull?
    /// A drag of the wave or of the Sun's lane: where it began.
    @State private var drag: DragStart?

    private struct TumblerPull {
        var field: StampField
        var startY: CGFloat
        /// Steps already applied to the moment during this drag.
        var applied = 0
        /// How far the column sits from rest, in points.
        var offset: CGFloat = 0
    }

    private struct DragStart {
        var instant: Instant
        var point: CGPoint
        var moved = false
    }

    /// How far a pointer may wander and still be a tap.
    private static let slop: CGFloat = 4

    var body: some View {
        let layout = WaveLayout.standard(space.layout)
        let clock = model.clock, instant = model.instant, focus = model.focus, zone = model.timeZone
        let isEarth = model.mode == .earth
        let reading = WaveReading.read(clock, at: instant, focus: focus, reach: layout.reach, depth: layout.depth)
        let selected = model.activeStampField
        let ghosts = StampGhosts.read(clock, at: instant, field: selected, zone: isEarth ? zone : nil)
        let pulled = pull.map { WaveStampRenderer.Pull(field: $0.field, offset: $0.offset) }
        // Where the present is on the wave while the cursor is away from it.
        let present: Double? = model.isAtNow
            ? nil : WaveTrack.cycles(in: clock, level: focus, from: instant, to: model.now)
        let window = sunWindow(reading, layout: layout)
        let earthTarget: CGFloat = isEarth ? 1 : 0

        ZStack {
            PlateView(center: CGPoint(x: layout.hairlineX, y: layout.waveY), firstRadius: 0)
            MotionCanvas(value: Double(earthTarget)) { ink, earth in
                // The Earth texts exist only while Earth mode is on screen.
                let earthLines = earth > 0 ? WaveEarth.read(reading, clock: clock, at: instant, zone: zone) : nil
                let shift = layout.shift(CGFloat(earth))
                ink.text(Screen.wave.word, at: layout.title, ink.theme.engraved(8.5, ink.palette.ash))
                WaveStampRenderer.draw(reading, layout: layout, selected: selected, ghosts: ghosts, pull: pulled,
                                       earthFields: earthLines?.fields, earth: earth, in: &ink)
                WaveSunRenderer.draw(reading.live?.sun, layout: layout, y: layout.sunY + shift, window: window,
                                     quarterDates: earthLines?.sunQuarters, earth: earth, in: &ink)
                WaveRenderer.draw(reading, layout: layout, y: layout.waveY + shift,
                                  quarterTimes: earthLines?.waveQuarters, earth: earth, present: present, in: &ink)
                WaveListRenderer.draw(reading.live?.upcoming ?? [], layout: layout,
                                      earthLines: earthLines?.upcoming, earth: earth, in: &ink)
            }
            .animation(Motion.mode.animation(reduceMotion: reduceMotion), value: model.mode)

            hitAreas(reading, layout: layout, earth: earthTarget)
            // Over the hit areas: the mark's own frame reaches into the stamp's.
            WaveNowMark(layout: layout)
            WaveGoToField(layout: layout, outOfCatalogue: reading.outOfCatalogue)

            // The limb slides with the rest of the lower screen in Earth mode.
            LimbControl(level: model.focusBinding, selectable: AppModel.focusRange,
                        shape: .straight(center: layout.limb, span: layout.limbSpan))
                .offset(y: layout.lowerShift(earthTarget) * space.scale)
                .animation(Motion.mode.animation(reduceMotion: reduceMotion), value: model.mode)

            spokenElements(reading, layout: layout, earth: earthTarget)
        }
        .onScrollWheel { input in scrolled(input, layout: layout) }
        .onDisappear { model.stopGlide() }
    }

    /// Where the wave's window falls on the Sun's lane: its two edges, in
    /// Helions from the start of the sync.
    private func sunWindow(_ reading: WaveReading, layout: WaveLayout) -> ClosedRange<Double>? {
        guard let sun = reading.live?.sun else { return nil }
        let clock = model.clock, instant = model.instant
        let before = Double((layout.waveLeft - layout.hairlineX) / layout.cycleWidth)
        let after = Double((layout.waveRight - layout.hairlineX) / layout.cycleWidth)
        let first = WaveTrack.instant(in: clock, level: model.focus, from: instant, movedBy: before)
        let last = WaveTrack.instant(in: clock, level: model.focus, from: instant, movedBy: after)
        guard let from = WaveTrack.cycles(in: clock, level: Sync.level, from: sun.sync.start, to: first),
              let to = WaveTrack.cycles(in: clock, level: Sync.level, from: sun.sync.start, to: last), from <= to
        else { return nil }
        return from ... to
    }

    // MARK: Hit areas

    private func hitAreas(_ reading: WaveReading, layout: WaveLayout, earth: CGFloat) -> some View {
        ZStack {
            Color.clear
                .contentShape(Path(layout.stampRowFrame).applying(space.transform))
                .gesture(pulling(layout: layout) { point in
                    let index = Int((point.x - layout.stampLeft) / layout.columnWidth)
                    let units = Unit.allCases
                    return .unit(units[min(max(index, 0), units.count - 1)])
                })
            if earth > 0 {
                Color.clear
                    .contentShape(Path(layout.earthRowFrame).applying(space.transform))
                    .gesture(pulling(layout: layout) { point in
                        let index = Int((point.x - layout.stampLeft) / layout.columnWidth) - 1
                        let fields = EarthField.allCases
                        return .earth(fields[min(max(index, 0), fields.count - 1)])
                    })
            }
            Color.clear
                .contentShape(Path(layout.sunFrame(earth: earth)).applying(space.transform))
                .gesture(draggingSun(reading, layout: layout))
            Color.clear
                .contentShape(Path(layout.waveFrame(earth: earth)).applying(space.transform))
                .gesture(scrubbing(layout: layout))
        }
        .accessibilityHidden(true)
    }

    // MARK: Tumblers

    /// Drag a tumbler up or down: one step of its term per pitch of travel.
    /// Pulling up brings the later value from below, as on a wheel.
    private func pulling(layout: WaveLayout, field: @escaping (CGPoint) -> StampField) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let point = space.designPoint(value.location)
                var current = pull ?? TumblerPull(field: field(space.designPoint(value.startLocation)), startY: point.y)
                if pull == nil {
                    model.stopGlide()
                    model.stampField = current.field
                }
                let pitch: CGFloat
                if case .earth = current.field { pitch = layout.earthPitch } else { pitch = layout.tumblerPitch }
                let travel = point.y - current.startY
                let steps = Int((-travel / pitch).rounded())
                // Only a step the moment took counts: a refused one (the
                // catalogue's edge) leaves nothing to undo on the way back.
                if steps != current.applied, model.step(current.field, by: steps - current.applied) {
                    current.applied = steps
                }
                current.offset = travel + CGFloat(steps) * pitch
                pull = current
            }
            .onEnded { _ in pull = nil }
    }

    // MARK: The wave

    /// Drag the wave: the moment under the hairline follows the finger.
    private func scrubbing(layout: WaveLayout) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                model.stopGlide()
                let point = space.designPoint(value.location)
                var start = drag ?? DragStart(instant: model.instant, point: point)
                if abs(point.x - start.point.x) > WaveScreen.slop { start.moved = true }
                drag = start
                guard start.moved else { return }
                // Pulling the wave to the right brings the past under the hairline.
                model.scrub(alongWaveOf: model.focus, from: start.instant,
                            cycles: Double((start.point.x - point.x) / layout.cycleWidth))
            }
            .onEnded { value in
                let moved = drag?.moved ?? false
                drag = nil
                guard moved else { return }
                coast(velocity: value.velocity.width / space.scale, layout: layout)
            }
    }

    /// After a flick the wave keeps moving and slows (the model's
    /// `glide`, which any other move through time stops); then, or at once
    /// with Reduce Motion, it settles on a threshold or on the present if
    /// one is within 6 pt.
    private func coast(velocity: CGFloat, layout: WaveLayout) {
        let width = layout.cycleWidth
        guard !reduceMotion, abs(velocity) > 60 else {
            model.settleOnWave(cycleWidth: width)
            return
        }
        model.glide(alongWaveOf: model.focus, velocity: velocity, cycleWidth: width)
    }

    // MARK: The Sun's lane

    /// Drag along the lane for coarse moves: the point of now follows the
    /// finger, one sync per width. A tap goes to the place tapped.
    private func draggingSun(_ reading: WaveReading, layout: WaveLayout) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                model.stopGlide()
                let point = space.designPoint(value.location)
                var start = drag ?? DragStart(instant: model.instant, point: point)
                if abs(point.x - start.point.x) > WaveScreen.slop { start.moved = true }
                drag = start
                guard start.moved else { return }
                model.scrub(alongWaveOf: Sync.level, from: start.instant,
                            cycles: Double((point.x - start.point.x) / layout.helionWidth))
            }
            .onEnded { value in
                let start = drag
                drag = nil
                guard let start, !start.moved, let sun = reading.live?.sun else { return }
                let helions = Double((space.designPoint(value.location).x - layout.sunLeft) / layout.helionWidth)
                model.scrub(alongWaveOf: Sync.level, from: sun.sync.start,
                            cycles: min(max(helions, 0), Double(Sync.helions)))
            }
    }

    // MARK: The scroll wheel and trackpad (Mac)

    /// Up and down: over the stamp the wheel steps the tumbler under the
    /// pointer (wheel up: the value above); anywhere else it turns the limb.
    /// Sideways (a two-finger swipe): over the wave or the Sun's lane it
    /// moves through time as a drag there would, the content following the
    /// fingers; elsewhere it does nothing.
    private func scrolled(_ input: ScrollInput, layout: WaveLayout) {
        let point = input.location.map(space.designPoint)
        let earth: CGFloat = model.mode == .earth ? 1 : 0
        if input.pan != 0 {
            guard let point else { return }
            let pan = input.pan / space.scale
            if layout.waveFrame(earth: earth).contains(point) {
                model.scrub(alongWaveOf: model.focus, from: model.instant, cycles: Double(-pan / layout.cycleWidth))
            } else if layout.sunFrame(earth: earth).contains(point) {
                model.scrub(alongWaveOf: Sync.level, from: model.instant, cycles: Double(pan / layout.helionWidth))
            }
            return
        }
        let steps = input.steps
        if let point {
            if layout.stampRowFrame.contains(point) {
                let units = Unit.allCases
                let index = Int((point.x - layout.stampLeft) / layout.columnWidth)
                let field = StampField.unit(units[min(max(index, 0), units.count - 1)])
                model.stampField = field
                model.step(field, by: -steps)
                return
            }
            if model.mode == .earth, layout.earthRowFrame.contains(point) {
                let fields = EarthField.allCases
                let index = Int((point.x - layout.stampLeft) / layout.columnWidth) - 1
                let field = StampField.earth(fields[min(max(index, 0), fields.count - 1)])
                model.stampField = field
                model.step(field, by: -steps)
                return
            }
        }
        model.stepFocus(by: steps)
    }

    // MARK: Accessibility

    /// One element per tumbler, one for the Sun's lane, one for the wave and
    /// one per row of the list. Pure mode is given no Earth text to speak.
    private func spokenElements(_ reading: WaveReading, layout: WaveLayout, earth: CGFloat) -> some View {
        let earthLines: WaveEarth? = model.mode == .earth
            ? WaveEarth.read(reading, clock: model.clock, at: model.instant, zone: model.timeZone) : nil
        let terms = Array((reading.live?.terms ?? []).enumerated())
        let rows = Array((reading.live?.upcoming ?? []).prefix(layout.maxRows).enumerated())
        return ZStack {
            Color.clear
                .accessibilityElement()
                .accessibilityLabel(Screen.wave.word.capitalized)
                .accessibilityIdentifier("wave.moment")
                .accessibilityValue(WaveSpeech.moment(reading, earth: earthLines))
                .accessibilityAddTraits(.isHeader)
                .designFrame(layout.titleFrame)
            ForEach(terms, id: \.offset) { index, term in
                Color.clear
                    .accessibilityElement()
                    .accessibilityLabel(term.unit.name)
                    .accessibilityValue(term.text)
                    .accessibilityAdjustableAction { direction in
                        adjust(.unit(term.unit), direction)
                    }
                    .designFrame(layout.stampFrame(index))
            }
            if let fields = earthLines?.fields {
                ForEach(EarthField.allCases, id: \.self) { field in
                    Color.clear
                        .accessibilityElement()
                        .accessibilityLabel("Earth \(field.word)")
                        .accessibilityValue(fields[field])
                        .accessibilityAdjustableAction { direction in
                            adjust(.earth(field), direction)
                        }
                        .designFrame(layout.earthFrame(field))
                }
            }
            Color.clear
                .accessibilityElement()
                .accessibilityLabel("Sun")
                .accessibilityValue(WaveSpeech.sun(reading, earth: earthLines))
                .accessibilityAdjustableAction { direction in
                    // A coarse move: one Helion.
                    adjust(.unit(.helion), direction)
                }
                .designFrame(layout.sunFrame(earth: earth))
            Color.clear
                .accessibilityElement()
                .accessibilityLabel(reading.title)
                .accessibilityIdentifier("wave.track")
                .accessibilityValue(WaveSpeech.wave(reading, earth: earthLines))
                .accessibilityAdjustableAction { direction in
                    // From threshold to threshold of the focused level.
                    switch direction {
                    case .increment: model.stepThreshold(by: 1)
                    case .decrement: model.stepThreshold(by: -1)
                    @unknown default: break
                    }
                }
                .designFrame(layout.waveFrame(earth: earth))
            ForEach(rows, id: \.offset) { index, row in
                let earthLine = earthLines.flatMap { index < $0.upcoming.count ? $0.upcoming[index] : nil }
                Color.clear
                    .accessibilityElement()
                    .accessibilityLabel(WaveSpeech.rowLabel(row))
                    .accessibilityValue(WaveSpeech.rowValue(row, earthLine: earthLine))
                    .designFrame(layout.rowFrame(index, earth: earth))
            }
        }
        .allowsHitTesting(false)
    }

    private func adjust(_ field: StampField, _ direction: AccessibilityAdjustmentDirection) {
        switch direction {
        case .increment: model.step(field, by: 1)
        case .decrement: model.step(field, by: -1)
        @unknown default: break
        }
    }
}
