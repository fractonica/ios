import FractonicaKit

/// What assistive technology says on the LADDER. Pure mode speaks only
/// Fractonica: the Earth translation is appended only when the rung carries
/// one, and it carries one only in Earth mode.
enum LadderSpeech {
    /// `Rung 30 of 63`.
    static func label(_ rung: RungReading) -> String {
        "Rung \(rung.level.depth) of \(Level.count)"
    }

    /// `Zeta1, sub, visible, 7 in ε1, made of 11 η1, 142 033 641 750 000 pB`.
    static func value(_ rung: RungReading) -> String {
        var parts: [String] = [rung.level.word]
        if let unit = rung.unitName { parts.append(unit) }
        parts.append(rung.kind.text)
        parts.append(rung.band.name)
        if let inParent = rung.inParent { parts.append(inParent) }
        if let madeOf = rung.madeOf { parts.append("made of \(madeOf)") }
        if let length = rung.length { parts.append(length) }
        parts.append(rung.rate)
        if let earth = rung.earth {
            parts.append("Earth \(earth.period), \(earth.frequency), \(earth.length)")
        }
        return parts.joined(separator: ", ")
    }
}
