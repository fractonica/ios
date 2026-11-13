import SwiftUI

/// How a run of text is set: face, colour, tracking. Made by the theme
/// helpers below, never by hand, so no view names a font.
struct InkTextStyle {
    var font: Font
    var color: Color
    /// Colour of unit letters and `#` inside a reading; `nil` = same as ``color``.
    var letterColor: Color?
    /// Extra advance per character, in points.
    var tracking: CGFloat = 0
    /// Engraved words are capitals; Greek letters inside them stay lowercase
    /// because they are symbols (DESIGN.md §3).
    var uppercase = false
    /// The face for Greek letters when ``font`` has none.
    var greekFont: Font?
}

extension Theme {
    /// Engraved words: capitals in the engraved face, tracked (0.24 em unless
    /// told otherwise).
    /// Never under ``Theme/engravedFloor`` (DESIGN.md §3's minimum on a phone).
    func engraved(_ size: CGFloat, _ color: Color, tracking: CGFloat? = nil) -> InkTextStyle {
        let size = max(size, engravedFloor)
        return InkTextStyle(
            font: type.engraved.font(size: size), color: color,
            tracking: size * (tracking ?? type.engravedTracking), uppercase: true,
            greekFont: type.engravedHasGreek ? nil : type.reading.font(size: size * 1.15)
        )
    }

    /// A reading or a value: numerals in `digits`, unit letters and `#` in
    /// `letters` (bone and ash by default).
    func value(_ size: CGFloat, weight: Font.Weight? = nil, digits: Color? = nil, letters: Color? = nil) -> InkTextStyle {
        InkTextStyle(
            font: type.reading.font(size: size, weight: weight ?? type.valueWeight),
            color: digits ?? palette.bone, letterColor: letters ?? palette.ash
        )
    }

    /// A level letter or a plain word in the reading face, one colour.
    func letter(_ size: CGFloat, _ color: Color, weight: Font.Weight? = nil) -> InkTextStyle {
        InkTextStyle(font: type.reading.font(size: size, weight: weight ?? type.valueWeight), color: color)
    }

    /// An Earth translation: always the Earth colour, regular weight.
    func earthText(_ size: CGFloat, tracking: CGFloat = 0) -> InkTextStyle {
        InkTextStyle(
            font: type.earth.font(size: size, weight: type.earthWeight), color: palette.earth,
            tracking: size * tracking
        )
    }
}

/// Where the given x falls on a line of text.
enum TextAnchor {
    case start, middle, end
}

/// One piece of a line set in several styles (the reading: big terms, then
/// small ones), with the gap before it.
struct TextPiece {
    var text: String
    var style: InkTextStyle
    var gapBefore: CGFloat = 0
}

extension Ink {
    /// The Earth sign that leads every translation sharing a block with
    /// Fractonica notation (DESIGN.md §9).
    static let earthSign = "⊕"

    /// A translation led by the Earth sign.
    static func earth(_ text: String) -> String {
        "\(earthSign) \(text)"
    }

    /// Draws one line of text with its **baseline** at `point.y`, like an SVG
    /// `<text>`: the design's coordinates are baselines.
    /// - Parameters:
    ///   - rotation: radians, about `point`.
    ///   - knockout: clears a pad of the void colour this much larger than the
    ///     text behind it (letters standing on a ring).
    func text(
        _ string: String, at point: CGPoint, _ style: InkTextStyle,
        anchor: TextAnchor = .start, rotation: CGFloat? = nil, knockout: CGFloat? = nil, opacity: Double = 1
    ) {
        line([TextPiece(text: string, style: style)], at: point, anchor: anchor,
             rotation: rotation, knockout: knockout, opacity: opacity)
    }

    /// Draws several pieces on one baseline, anchored as a whole.
    func line(
        _ pieces: [TextPiece], at point: CGPoint, anchor: TextAnchor = .start,
        rotation: CGFloat? = nil, knockout: CGFloat? = nil, opacity: Double = 1
    ) {
        guard opacity > 0, !pieces.isEmpty else { return }
        var pen = context
        pen.opacity = opacity
        if let rotation, rotation != 0 {
            pen.translateBy(x: point.x, y: point.y)
            pen.rotate(by: .radians(rotation))
            pen.translateBy(x: -point.x, y: -point.y)
        }
        let unbounded = CGSize(width: CGFloat.infinity, height: CGFloat.infinity)
        let resolved = pieces.map { pen.resolve(Text(Ink.attributed($0.text, $0.style))) }
        let sizes = resolved.map { $0.measure(in: unbounded) }
        let width = zip(pieces, sizes).reduce(0) { $0 + $1.0.gapBefore + $1.1.width }
        // Tracking adds its space after the last character too. Like the
        // design's SVG, a centred line is centred on the inked letters.
        let trailing = pieces.last?.style.tracking ?? 0
        var x: CGFloat
        switch anchor {
        case .start: x = point.x
        case .middle: x = point.x - width / 2 + trailing / 2
        case .end: x = point.x - width
        }
        if let knockout {
            let height = sizes.map(\.height).max() ?? 0
            let ascent = zip(resolved, sizes).map { $0.firstBaseline(in: $1) }.max() ?? 0
            // The pad hugs the letters' x-height band, not the whole line box.
            let pad = CGRect(x: x, y: point.y - ascent * 0.72, width: width - trailing, height: min(height, ascent * 0.86))
                .insetBy(dx: -knockout / 2, dy: -knockout / 2)
            pen.fill(Path(roundedRect: pad, cornerRadius: pad.height / 2), with: .color(palette.void))
        }
        for (index, text) in resolved.enumerated() {
            x += pieces[index].gapBefore
            let baseline = text.firstBaseline(in: sizes[index])
            pen.draw(text, at: CGPoint(x: x, y: point.y - baseline), anchor: .topLeading)
            x += sizes[index].width
        }
    }

    /// The width a line would take, for laying out by hand.
    func width(of string: String, _ style: InkTextStyle) -> CGFloat {
        context.resolve(Text(Ink.attributed(string, style)))
            .measure(in: CGSize(width: CGFloat.infinity, height: CGFloat.infinity)).width
    }

    // MARK: Attributed text

    /// The string in its style: capitals where engraved (ASCII only, so that
    /// Greek symbols stay lowercase), unit letters and `#` in their own colour.
    static func attributed(_ string: String, _ style: InkTextStyle) -> AttributedString {
        var result = AttributedString()
        var run = ""
        var runIsLetter = false

        func flush() {
            guard !run.isEmpty else { return }
            var piece = AttributedString(run)
            piece.font = runIsLetter ? (style.greekFont ?? style.font) : style.font
            piece.foregroundColor = runIsLetter ? (style.letterColor ?? style.color) : style.color
            if style.tracking != 0 { piece.tracking = style.tracking }
            result.append(piece)
            run = ""
        }

        for character in string {
            let isLetter = Ink.isUnitLetter(character)
            if isLetter != runIsLetter { flush() }
            runIsLetter = isLetter
            if style.uppercase, character.isASCII {
                run.append(contentsOf: character.uppercased())
            } else {
                run.append(character)
            }
        }
        flush()
        return result
    }

    /// Greek letters and `#`: the symbols of the notation, set in ash inside
    /// a reading while the numerals are bone.
    static func isUnitLetter(_ character: Character) -> Bool {
        if character == "#" { return true }
        guard let scalar = character.unicodeScalars.first else { return false }
        return (0x0370 ... 0x03FF).contains(scalar.value)
    }
}

extension Ink {
    /// The first of `wordings` (longest first) that is no wider than
    /// `width` in `style`; the last, shortest one when none is. How a value
    /// with several wordings fits its column.
    func fitting(_ wordings: [String], _ style: InkTextStyle, width: CGFloat) -> String {
        wordings.first { self.width(of: $0, style) <= width } ?? wordings.last ?? ""
    }
}
