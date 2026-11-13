import CFractonica

/// A Pentad: about a day, one of the four runs of Helions of a solar sync
/// (`frc_pentad_t`, SPEC §7.5). A sync is Pentad I, II, III (5 Helions each)
/// and the Hypopentad (4). A date on screen leads with its Pentad, as a civil
/// date leads with its weekday.
///
/// The Hypopentad is drawn as a square wherever a Pentad is drawn as a
/// pentagon (design/README.md, ruling 10): ask ``isHypopentad``.
public struct Pentad: Hashable, Sendable {
    /// Number of the sync it belongs to.
    public let sync: Int
    /// 0 Pentad I, 1 Pentad II, 2 Pentad III, 3 Hypopentad.
    public let index: Int
    /// The running Helion's place in the Pentad, 1...5 (1...4 in the
    /// Hypopentad). 0 for a Pentad asked for by number.
    public let helion: Int
    /// Helions in this Pentad: 5, or 4 for the Hypopentad.
    public let helions: Int
    /// The place in the sync of its first Helion, 0, 5, 10 or 15
    /// (`frc_pentad_t.first`): where the Pentad starts on the Sun's ring
    /// and lane. The same for a Pentad cut at the catalogue's edge.
    public let first: Int
    /// Start and end, cut at the catalogue's edges.
    public let start: Instant
    public let end: Instant

    /// Pentads per sync, the Hypopentad included: ``index`` runs 0...3
    /// (fractonica.h documents the four; it has no macro for the count).
    public static let perSync = 4

    init(_ raw: frc_pentad_t) {
        sync = Int(raw.sync)
        index = Int(raw.index)
        helion = Int(raw.helion)
        helions = Int(raw.helions)
        first = Int(raw.first)
        start = Instant(microseconds: raw.start)
        end = Instant(microseconds: raw.end)
    }

    /// The Pentad as the core takes it.
    private var raw: frc_pentad_t {
        frc_pentad_t(
            sync: Int32(clamping: sync), index: UInt8(clamping: index), helion: UInt8(clamping: helion),
            helions: UInt8(clamping: helions), first: UInt8(clamping: first), start: start.microseconds, end: end.microseconds
        )
    }

    /// Whether this is the fourth, shorter run (fractonica.h: index 3).
    public var isHypopentad: Bool { index == 3 }

    /// The Pentad in words or signs (`frc_format_pentad`).
    ///
    /// | form | name | with the Helion |
    /// |---|---|---|
    /// | `.full` | `Pentad II` | `Pentad II, 3rd Helion` |
    /// | `.short` | `⬠II` (Hypopentad `◻`) | `⬠II·3` |
    /// | `.ascii` | `P2` (Hypopentad `H`) | `P2.3` |
    /// | `.numeral` | `II` (Hypopentad: empty) | the same: never the Helion |
    ///
    /// - Returns: `nil` when `withHelion` is asked of a Pentad that has no
    ///   running Helion (one from ``Catalogue/pentad(sync:index:)``).
    public func text(_ form: PentadForm = .full, withHelion: Bool = false) -> String? {
        var raw = self.raw
        return try? CoreText.make { frc_format_pentad(&raw, form.raw, withHelion ? 1 : 0, $0, $1) }
    }

    /// `"Pentad II"`, `"Hypopentad"`.
    public var name: String { text(.full) ?? "" }
    /// `"⬠II"`, `"◻"`.
    public var mark: String { text(.short) ?? "" }
    /// The numeral inside a drawn Pentad mark, `"I"`, `"II"`, `"III"`, and
    /// `""` for the Hypopentad, whose drawn square is the whole mark
    /// (`frc_format_pentad`, `FRC_PENTAD_NUMERAL`).
    public var numeral: String { text(.numeral) ?? "" }
}

/// How a Pentad is written (`frc_pentad_form_t`).
public enum PentadForm: Hashable, Sendable, CaseIterable {
    /// `Pentad II`
    case full
    /// `⬠II`
    case short
    /// `P2`
    case ascii
    /// `II` alone (empty for the Hypopentad): the numeral of a drawn mark
    case numeral

    var raw: frc_pentad_form_t {
        switch self {
        case .full: return FRC_PENTAD_FULL
        case .short: return FRC_PENTAD_SHORT
        case .ascii: return FRC_PENTAD_ASCII
        case .numeral: return FRC_PENTAD_NUMERAL
        }
    }
}

extension Catalogue {
    /// The Pentad running at `instant` (`frc_pentad_at`). Defined in the
    /// partial syncs at the catalogue's edges too.
    public func pentad(at instant: Instant) throws -> Pentad {
        Pentad(try read(into: frc_pentad_t()) { frc_pentad_at($0, instant.microseconds, $1) })
    }

    /// Pentad `index` (0...3) of sync `sync` (`frc_pentad_by_number`); its
    /// ``Pentad/helion`` is 0.
    /// - Throws: ``FractonicaError/outOfRange`` when wholly outside the
    ///   catalogue; ``FractonicaError/invalidArgument`` for an index above 3.
    public func pentad(sync: Int, index: Int) throws -> Pentad {
        guard let sync = Int32(exactly: sync) else { throw FractonicaError.outOfRange }
        guard let index = UInt8(exactly: index) else { throw FractonicaError.invalidArgument }
        return Pentad(try read(into: frc_pentad_t()) { frc_pentad_by_number($0, sync, index, $1) })
    }
}
