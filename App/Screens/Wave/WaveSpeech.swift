import FractonicaKit

/// What assistive technology says for each block of the WAVE screen. Built
/// from the core's own texts; the Earth translation is appended only when
/// one is passed, and one is made only in Earth mode, so pure mode has
/// nothing Earthly to say. The translation is introduced by the WORD
/// `Earth`, as on every other screen; the drawn sign `⊕` (``Ink/earth(_:)``)
/// is for the eye only.
enum WaveSpeech {
    /// `Earth 12:56:12`: an Earth text as it is spoken.
    static func earth(_ text: String) -> String {
        "Earth \(text)"
    }

    /// The wave: `34η, End in 6ι 43λ` (+ `, Earth 12:56:12`).
    static func wave(_ reading: WaveReading, earth: WaveEarth?) -> String {
        guard let live = reading.live else { return reading.outOfCatalogue }
        // At the catalogue's closing instant nothing comes next.
        guard live.next.instant != nil else { return live.cycle.name }
        var parts = [live.cycle.name, "\(live.next.quarter.name) in \(live.nextSpan)"]
        if let earth, let index = Quarter.allCases.firstIndex(of: live.next.quarter), index < earth.waveQuarters.count {
            parts.append(WaveSpeech.earth(earth.waveQuarters[index]))
        }
        return parts.joined(separator: ", ")
    }

    /// The Sun's lane: `Solar sync 4 820, drift −2η 23ι, Pentad II, Node in 2η 24ι`.
    static func sun(_ reading: WaveReading, earth: WaveEarth?) -> String {
        guard let sun = reading.live?.sun else { return reading.live == nil ? reading.outOfCatalogue : "" }
        var parts = ["Solar sync \(sun.number)", "drift \(sun.drift)"]
        if let index = sun.currentPentad, index < sun.pentads.count { parts.append(sun.pentads[index].name) }
        guard sun.sync.next.instant != nil else { return parts.joined(separator: ", ") }
        parts.append("\(sun.sync.next.quarter.name) in \(sun.nextSpan)")
        if let earth, let index = Quarter.allCases.firstIndex(of: sun.sync.next.quarter), index < earth.sunQuarters.count {
            parts.append(WaveSpeech.earth(earth.sunQuarters[index]))
        }
        return parts.joined(separator: ", ")
    }

    /// The label of a row of the list: `Preon Node`, `Sun Node`.
    static func rowLabel(_ row: NowReading.Upcoming) -> String {
        "\(row.level?.title ?? "Sun") \(row.threshold.quarter.name)"
    }

    /// Its value: the span, and in Earth mode when it falls.
    static func rowValue(_ row: NowReading.Upcoming, earthLine: String?) -> String {
        guard let earthLine, !earthLine.isEmpty else { return row.span }
        return "\(row.span), \(WaveSpeech.earth(earthLine))"
    }

    /// The whole moment: the date in words, and in Earth mode the date line.
    static func moment(_ reading: WaveReading, earth: WaveEarth?) -> String {
        guard let live = reading.live else { return reading.outOfCatalogue }
        guard let earth, !earth.dateLine.isEmpty else { return live.date.text(.full) }
        return "\(live.date.text(.full)), \(WaveSpeech.earth(earth.dateLine))"
    }
}
