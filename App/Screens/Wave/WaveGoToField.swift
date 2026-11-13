import SwiftUI
import FractonicaKit

/// "Go to": a small field on the WAVE screen that jumps to a typed moment.
/// It accepts everything the core reads as a date (`GoTo`), and in Earth
/// mode an Earth date as well.
///
/// At rest it is engraving on the canvas (two words and a rule) with a
/// ghosted example over the rule: the moment shown, written in the plain
/// ASCII shorthand the core reads (`a#6 b#4 g#9 d#3 e#5 34h 29i`), so the
/// field says what it takes and how to type the Greek letters. The text
/// field exists only while it is being typed in; the example stays until
/// the first character. An entry that cannot be
/// read stays in the field with a note under it; one that is outside the
/// catalogue goes to the nearest end of it and says so.
struct WaveGoToField: View {
    let layout: WaveLayout
    /// `OUT OF CATALOGUE · α#1 – α#18`, the note for an entry beyond it.
    let outOfCatalogue: String

    @Environment(AppModel.self) private var model
    @Environment(\.designSpace) private var space
    @Environment(\.theme) private var theme
    @State private var text = ""
    @State private var isEditing = false
    @State private var note: String?
    @FocusState private var hasKeyboard: Bool

    /// Where the typed text starts: after the engraved words.
    private var textX: CGFloat { layout.goToFrame.minX + 42 }

    var body: some View {
        let frame = layout.goToFrame, baseline = layout.goToBaseline, textX = textX
        let note = note, editing = isEditing
        let examples = text.isEmpty ? examples : []
        ZStack {
            DesignCanvas { ink in
                let palette = ink.palette, theme = ink.theme
                ink.text("Go to", at: CGPoint(x: frame.minX, y: baseline), theme.engraved(6.8, palette.etch3))
                ink.line(from: CGPoint(x: textX, y: baseline + 4.5), to: CGPoint(x: frame.maxX, y: baseline + 4.5),
                         editing ? palette.lumen : palette.etch2, width: editing ? 1 : theme.line.engraving)
                // The ghosted example: the longest wording that fits the rule.
                let ghost = theme.letter(9, palette.etch3, weight: .regular)
                if let example = examples.first(where: { ink.width(of: $0, ghost) <= frame.maxX - textX - 2 }) {
                    ink.text(example, at: CGPoint(x: textX + 1, y: baseline), ghost)
                }
                if let note {
                    ink.text(note, at: CGPoint(x: textX, y: baseline + 14), theme.engraved(6.2, palette.ash))
                }
            }
            if isEditing {
                field
                    .designFrame(CGRect(x: textX, y: baseline - 14, width: frame.maxX - textX, height: 20))
            } else {
                Button { begin() } label: { Color.clear.contentShape(Rectangle()) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Go to")
                    .accessibilityHint(model.mode == .earth ? "A stamp, a date, or an Earth date" : "A stamp or a date")
                    .designFrame(frame)
            }
        }
        .onChange(of: hasKeyboard) { _, has in
            model.isTyping = has
            if !has { isEditing = false }
        }
        .onDisappear { model.isTyping = false }
    }

    /// The moment shown as the core's ASCII shorthand, longest first: down
    /// to the Preon, then from the Delta. Empty outside the catalogue.
    private var examples: [String] {
        guard let date = try? model.clock.date(at: model.instant) else { return [] }
        return [date.text(.letters, finest: .preon), date.text(.shortLetters, finest: .preon)].map(Fractonica.ascii)
    }

    private var field: some View {
        TextField("", text: $text)
            .textFieldStyle(.plain)
            .font(theme.type.reading.font(size: 12.5 * space.scale, weight: theme.type.valueWeight))
            .foregroundStyle(theme.palette.bone)
            .tint(theme.palette.lumen)
            .autocorrectionDisabled()
            #if os(iOS)
            .textInputAutocapitalization(.never)
            .submitLabel(.go)
            #endif
            .focused($hasKeyboard)
            .onSubmit { go() }
            .onKeyPress(.escape) {
                hasKeyboard = false
                return .handled
            }
            .onAppear { hasKeyboard = true }
            .accessibilityLabel("Go to")
    }

    private func begin() {
        note = nil
        isEditing = true
    }

    /// Reads the entry and moves the cursor there.
    private func go() {
        let zone: TimeZone? = model.mode == .earth ? model.timeZone : nil
        switch GoTo.resolve(text, clock: model.clock, at: model.instant, earthZone: zone) {
        case .moment(let instant):
            model.scrub(to: instant)
            finish(note: nil)
        case .outOfCatalogue(let nearest):
            model.scrub(to: nearest)
            finish(note: outOfCatalogue)
        case .unreadable:
            note = "Not a moment"
        }
    }

    private func finish(note: String?) {
        text = ""
        self.note = note
        hasKeyboard = false
        isEditing = false
    }
}
