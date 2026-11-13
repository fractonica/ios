import FractonicaKit

// The app's own words for facts the core gives as values, not as text
// (design/README.md ruling 4), and the order of the bands. They are labels of
// the interface, the same in both modes, and none of them names an Earth
// unit. Everything that is notation (letters, counts, spans, rates) and the
// words of ruling 4 (a level's kind, `major` `unit` `between` `sub-Blink`:
// `LevelKind.text`; `no band`: `Band.name`) come from the core and are used
// as it writes them, capitals only where the app engraves capitals.

extension Band {
    /// The bands on either side of this one, in the order of `frc_band_t`
    /// (`noBand` beyond the first and the last): the names at the two ends
    /// of the band rule. `nil` for ``noBand``.
    var neighbours: (below: Band, above: Band)? {
        let bands = Band.allCases.filter { $0 != .noBand }
        guard let index = bands.firstIndex(of: self) else { return nil }
        return (index > 0 ? bands[index - 1] : .noBand, index + 1 < bands.count ? bands[index + 1] : .noBand)
    }

    /// EARTH MODE ONLY: `400 THz`, `790 THz`, the band's edges
    /// (`frc_band_edges`) written by the core's quantity formatter with the
    /// two digits SPEC §16.2 prints. `nil` for ``noBand``.
    var edgeTexts: (low: String, high: String)? {
        edges.map { ($0.low.text(.frequency, digits: 2), $0.high.text(.frequency, digits: 2)) }
    }
}

extension Level {
    /// The first unit finer than this level: what its cycle is counted in
    /// ("made of 36ι"). `nil` from the Blink down.
    var finerUnit: Unit? {
        Unit.allCases.first { $0.level > self }
    }

    /// What the rung is called in a title and aloud: the unit's name where
    /// it is one (`Helion`), else the letter's word (`Zeta1`).
    var title: String {
        unit?.name ?? word
    }

    /// The last rung of the ladder.
    static var last: Level { Level.all[Level.count - 1] }
}
