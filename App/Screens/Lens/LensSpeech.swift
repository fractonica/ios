import FractonicaKit

/// What assistive technology says on the LENS. Every Earth text in a
/// ``LensReading`` exists only in Earth mode, so pure mode speaks none.
enum LensSpeech {
    /// `Eta, Helion, rung 7 of 63, depth 7 · level 6 · unit, …`.
    static func title(_ reading: LensReading) -> String {
        var parts = [reading.rung.level.word]
        if let unit = reading.rung.unitName { parts.append(unit) }
        parts.append(reading.ordinalLine)
        parts.append(reading.kindLine)
        if let epithet = reading.epithet { parts.append(epithet.text) }
        return parts.joined(separator: ", ")
    }

    /// `Alpha 5, Beta 13, …`: each ancestor with its factor, then the prefix.
    static func lineage(_ reading: LensReading) -> String {
        let steps = reading.lineage.dropLast().map { "\($0.word) \($0.factor)" }
        return (steps + [reading.prefix.last ?? ""]).joined(separator: ", ")
    }

    /// The four thresholds: `Peak −20ι 21λ, …, next End +6ι 43λ`.
    static func ring(_ ring: LensReading.Ring, outOfCatalogue: String) -> String {
        guard ring.instrument.live != nil else { return outOfCatalogue }
        return ring.thresholds.map { row in
            var text = "\(row.isNext ? "next " : "")\(row.quarter.name) \(row.span ?? "")"
            if let earth = row.earth { text += ", Earth \(earth)" }
            return text
        }.joined(separator: ", ")
    }

    static func row(_ row: LensReading.Row) -> String {
        var parts: [String] = []
        if let pure = row.pure.first { parts.append(pure) }
        if let earth = row.earth.first { parts.append("Earth \(earth)") }
        return parts.joined(separator: ", ")
    }

    static func media(_ reading: LensReading) -> String {
        reading.media.map { row in
            var text = "\(row.name) \(row.span) \(row.word)"
            if let earth = row.earth { text += ", Earth \(earth)" }
            return text
        }.joined(separator: "; ")
    }
}
