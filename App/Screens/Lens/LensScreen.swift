import SwiftUI
import FractonicaKit

/// LENS: one rung inspected, any of the 63 (DESIGN.md §7 "Lens", §8, §9;
/// design/astrolabe/screen4.png and screen4_pure.png).
///
/// - **State**: the rung is `model.lensLevel`. The straight limb at the
///   bottom changes it over all 63 rungs; the instrument's focus follows
///   while the rung is one it can show (levels 0...13).
/// - **Drawing**: `LensRenderer` (title, lineage, rows, media) and `LensRing`
///   (the live ring with its thresholds, or the seal of a deeper rung),
///   placed by `LensLayout`, from one `LensReading` per redraw.
/// - **Leaving**: swipe down, or Escape, returns to the screen the lens was
///   opened from (`model.closeLens()`).
/// - **Redraw**: the live ring moves with the model's clock; the scheduler
///   paces it by the lens's own rung (`AppModel.movingLevel`).
struct LensScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.designSpace) private var space
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let layout = LensLayout.standard(space.layout)
        let clock = model.clock, instant = model.instant, level = model.lensLevel, zone = model.timeZone
        let outOfCatalogue: String? = model.isInCatalogue
            ? nil : NowReading.read(clock, at: instant, focus: model.focus).outOfCatalogue
        ZStack {
            PlateView(center: layout.ringCenter, firstRadius: layout.plateRadius)
            ZStack {
                MotionCanvas(value: model.mode == .earth ? 1.0 : 0.0) { ink, earth in
                    // The Earth texts exist only while Earth mode is on screen.
                    let reading = LensReading.read(clock, at: instant, level: level, zone: earth > 0 ? zone : nil)
                    LensRenderer.draw(reading, layout: layout, outOfCatalogue: outOfCatalogue, earth: earth, in: &ink)
                }
                .animation(Motion.mode.animation(reduceMotion: reduceMotion), value: model.mode)
                // A change of rung is a short cross-fade of the whole drawing
                // (and of nothing else: the limb has its own motion).
                .id(level)
                .transition(.opacity)
            }
            .animation(Motion.screen.animation(reduceMotion: reduceMotion), value: level)

            Color.clear
                .contentShape(Path(layout.swipeFrame).applying(space.transform))
                .gesture(swipeDown)
                .accessibilityHidden(true)

            LimbControl(level: model.lensLevelBinding, selectable: 0 ... Level.count - 1,
                        shape: .straight(center: layout.limb, span: layout.limbSpan))

            spokenElements(layout: layout, outOfCatalogue: outOfCatalogue)
        }
        .onScrollWheelStep { model.step(by: $0) }
    }

    /// Swipe down → back (DESIGN.md §8).
    private var swipeDown: some Gesture {
        DragGesture(minimumDistance: 24, coordinateSpace: .local)
            .onEnded { value in
                let down = value.translation.height / space.scale
                if down > 70, down > 2 * abs(value.translation.width / space.scale) {
                    model.closeLens()
                }
            }
    }

    // MARK: Accessibility

    /// One element per block: the title, the ring, the lineage, each row and
    /// the media. Pure mode passes no zone, so the reading has no Earth text
    /// to speak.
    private func spokenElements(layout: LensLayout, outOfCatalogue: String?) -> some View {
        let zone: TimeZone? = model.mode == .earth ? model.timeZone : nil
        let reading = LensReading.read(model.clock, at: model.instant, level: model.lensLevel, zone: zone)
        let rows = Array(reading.rows.prefix(layout.maxRows).enumerated())
        return ZStack {
            Color.clear
                .accessibilityElement()
                .accessibilityLabel(Screen.lens.word.capitalized)
                .accessibilityIdentifier("lens.title")
                .accessibilityValue(LensSpeech.title(reading))
                .accessibilityAddTraits(.isHeader)
                .accessibilityAction(.escape) { model.closeLens() }
                .designFrame(layout.titleFrame)
            Color.clear
                .accessibilityElement()
                .accessibilityLabel("Ring")
                .accessibilityValue(reading.ring.map { LensSpeech.ring($0, outOfCatalogue: outOfCatalogue ?? "") }
                    ?? "finer than the instrument reads")
                .designFrame(layout.ringFrame)
            Color.clear
                .accessibilityElement()
                .accessibilityLabel(reading.prefixLabel)
                .accessibilityValue(LensSpeech.lineage(reading))
                .designFrame(layout.lineageFrame)
            ForEach(rows, id: \.offset) { index, row in
                Color.clear
                    .accessibilityElement()
                    .accessibilityLabel(row.label)
                    .accessibilityValue(LensSpeech.row(row))
                    .designFrame(layout.rowFrame(index))
            }
            Color.clear
                .accessibilityElement()
                .accessibilityLabel(reading.travelTitle)
                .accessibilityValue(LensSpeech.media(reading))
                .designFrame(layout.mediaFrame)
        }
        .allowsHitTesting(false)
    }
}
