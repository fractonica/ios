import SwiftUI
import FractonicaKit

/// The NOW return mark (DESIGN.md §8, "Through time"): visible on every
/// screen while the cursor is away from the present. It shows how far away
/// as a span and a tap returns. While the present is shown it is absent, and
/// on the WAVE screen too: there the stamp carries its own NOW mark
/// (`Screens/Wave/WaveNowMark.swift`).
struct ReturnMark: View {
    @Environment(AppModel.self) private var model
    @Environment(\.designSpace) private var space

    var body: some View {
        if let cursor = model.cursor, model.screen != .wave {
            let at = ChromePlaces(layout: space.layout).returnMark
            // How far the cursor is from now, as a signed span (`+3η 12ι`).
            let offset = (try? model.clock.span(from: model.now, to: cursor))?.signedText() ?? ""
            ZStack {
                DesignCanvas { ink in
                    let palette = ink.palette, theme = ink.theme
                    let word = Screen.now.word
                    let wordWidth = ink.width(of: word, theme.engraved(7.5, palette.lumen))
                    let spanWidth = ink.width(of: offset, theme.value(12.5))
                    let total = 14 + wordWidth + 6 + spanWidth
                    var x = at.x - total / 2
                    // A small point of now leads the word.
                    ink.circle(CGPoint(x: x + 4, y: at.y - 2.6), radius: 4, stroke: palette.lumen, width: 0.8)
                    ink.circle(CGPoint(x: x + 4, y: at.y - 2.6), radius: 1.5, fill: palette.lumen)
                    x += 14
                    ink.text(word, at: CGPoint(x: x, y: at.y), theme.engraved(7.5, palette.lumen))
                    x += wordWidth + 6
                    ink.text(offset, at: CGPoint(x: x, y: at.y + 0.6), theme.value(12.5))
                }
                Button { model.returnToNow() } label: { Color.clear.contentShape(Rectangle()) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Return to now")
                    .accessibilityIdentifier("return.now")
                    .accessibilityValue(offset)
                    .designFrame(CGRect(x: at.x - 90, y: at.y - 20, width: 180, height: 32))
            }
        }
    }
}
