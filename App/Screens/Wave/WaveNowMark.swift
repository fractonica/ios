import SwiftUI
import FractonicaKit

/// The NOW mark at the right of the stamp (DESIGN.md §8, "Through time"):
/// lit while the moment shown is the present; away from it, it shows how far
/// away as a signed span (`+3η 12ι`) and a tap returns.
///
/// It is its own view so that it alone follows the running clock while the
/// cursor stands still. On this screen it replaces the floating return mark
/// of the other screens (`Chrome/ReturnMark.swift`).
struct WaveNowMark: View {
    let layout: WaveLayout

    @Environment(AppModel.self) private var model

    var body: some View {
        let right = layout.nowMarkRight, y = layout.captionY
        // The signed span from the present to the cursor, as the core
        // measures it; `nil` at the present.
        let offset: String? = model.cursor.flatMap { cursor in
            (try? model.clock.span(from: model.now, to: cursor))?.signedText()
        }
        let isAway = model.cursor != nil
        ZStack {
            DesignCanvas { ink in
                let palette = ink.palette, theme = ink.theme
                let word = Screen.now.word
                let style = theme.engraved(6.8, isAway ? palette.ash : palette.lumen)
                // Tracking trails the last letter: the word ends that much early.
                let wordWidth = ink.width(of: word, style) - style.tracking
                ink.text(word, at: CGPoint(x: right - wordWidth, y: y), style)
                let sign = CGPoint(x: right - wordWidth - 8.5, y: y - 2.5)
                ink.circle(sign, radius: 3.6, stroke: isAway ? palette.etch3 : palette.lumen, width: 0.9)
                if !isAway { ink.circle(sign, radius: 1.2, fill: palette.lumen) }
                if let offset {
                    ink.text(offset, at: CGPoint(x: sign.x - 9, y: y + 0.4), theme.value(11), anchor: .end)
                }
            }
            Button { model.returnToNow() } label: { Color.clear.contentShape(Rectangle()) }
                .buttonStyle(.plain)
                .disabled(!isAway)
                .accessibilityLabel(isAway ? "Return to now" : "Now")
                .accessibilityIdentifier("wave.now")
                .accessibilityValue(offset ?? "the present")
                .designFrame(layout.nowMarkFrame)
        }
    }
}
