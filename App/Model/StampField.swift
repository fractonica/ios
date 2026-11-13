import FractonicaKit

/// One term of the moment that can be stepped by itself on the WAVE screen:
/// a term of the stamp (`34η`), or, in Earth mode, a field of the Earth
/// date-time under it.
enum StampField: Hashable, Sendable {
    case unit(Unit)
    /// EARTH MODE ONLY.
    case earth(EarthField)
}

/// The fields of the Earth date-time row, in the order it is written
/// (`8 OCT 2026 12:00:00`). EARTH MODE ONLY: none of these words may reach a
/// label in pure mode.
enum EarthField: String, CaseIterable, Sendable {
    case day, month, year, hour, minute, second

    /// What the field is called aloud.
    var word: String { rawValue }
}
