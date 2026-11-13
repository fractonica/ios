import CFractonica

/// One solar sync and where an instant sits in it (`frc_sync_t`, SPEC §7):
/// 19 Helions, about 4 civil days, counted from the catalogue's anchor
/// eclipse. It is the unit that locks the clock to the Sun.
///
/// Do not derive the digits or the quarter from ``phase``, ``start`` or
/// ``end``: use ``Catalogue/syncOdometer(at:strokes:digits:)`` and ``quarter``
/// (core/AGENTS.md, "Common mistakes").
public struct Sync: Hashable, Sendable {
    /// The sync's number: 0 at the anchor, negative before it.
    public let number: Int
    /// The quarter of the sync the instant is in (`.peak` when asked by number).
    public let quarter: Quarter
    /// The running Helion's place in the sync, 0...18 (`frc_sync_t.helion`):
    /// its slot on the Sun's ring and lane. 0 for a sync asked for by number.
    public let helion: Int
    /// Fraction of the sync done, linear in **time** (zero when asked by number).
    public let phase: Fraction
    public let start: Instant
    public let end: Instant
    /// Where the sync would start if a sync were exactly four days:
    /// anchor eclipse + `number` × 4 days.
    public let nominal: Instant
    /// `start − nominal` in microseconds: the drift against civil days.
    /// To SAY it in Fractonica terms measure ``Catalogue/span(from:to:)``
    /// from ``nominal`` to ``start``.
    public let driftMicroseconds: Int64
    /// The next quarter boundary of the sync, about a day away. Its instant
    /// is `nil` for a sync asked for by number.
    public let next: Threshold

    /// The level a sync is counted in: 6, the Helion (`FRC_SYNC_LEVEL`).
    public static let level = Level(unchecked: Int(FRC_SYNC_LEVEL))
    /// Helions per sync, 19 (`FRC_SYNC_CYCLES`).
    public static let helions = Int(FRC_SYNC_CYCLES)
    /// Civil days a sync nominally lasts, 4 (`FRC_SYNC_DAYS`).
    public static let nominalDays = Int(FRC_SYNC_DAYS)

    init(_ raw: frc_sync_t) {
        number = Int(raw.sync)
        quarter = Quarter(field: raw.quarter)
        helion = Int(raw.helion)
        phase = Fraction(raw: raw.phase)
        start = Instant(microseconds: raw.start)
        end = Instant(microseconds: raw.end)
        nominal = Instant(microseconds: raw.nominal)
        driftMicroseconds = raw.drift_us
        next = Threshold(raw.next)
    }
}

extension Catalogue {
    /// The solar sync running at `instant` (`frc_sync_at`).
    /// - Throws: ``FractonicaError/outOfRange`` outside the catalogue **and
    ///   inside its first and last partial sync** (``pentad(at:)`` still
    ///   answers there).
    public func sync(at instant: Instant) throws -> Sync {
        Sync(try read(into: frc_sync_t()) { frc_sync_at($0, instant.microseconds, $1) })
    }

    /// Sync number `number` (`frc_sync_by_number`).
    /// - Throws: ``FractonicaError/outOfRange`` if it is not whole in the catalogue.
    public func sync(number: Int) throws -> Sync {
        guard let number = Int32(exactly: number) else { throw FractonicaError.outOfRange }
        return Sync(try read(into: frc_sync_t()) { frc_sync_by_number($0, number, $1) })
    }

    /// The sync's phase as an odometer (`frc_sync_odometer`, SPEC §7.3). The
    /// reference display is 3 glyphs of 2 strokes; the alternative 2 of 3.
    public func syncOdometer(at instant: Instant, strokes: Int = 2, digits: Int = 3) throws -> Odometer {
        guard let strokes = UInt8(exactly: strokes), let digits = UInt8(exactly: digits) else {
            throw FractonicaError.invalidArgument
        }
        return Odometer(try read(into: frc_odometer_t()) {
            frc_sync_odometer($0, instant.microseconds, strokes, digits, $1)
        })
    }

    /// The instant at which sync `number` reaches `phase`
    /// (`frc_time_at_sync_phase`): the first microsecond at or after it, on
    /// the exact start and end (a sync's phase is linear in time). Phase
    /// zero is the sync's start, ``Fraction/quarter`` the end of its first
    /// quarter, ``Fraction/half`` its Node. A place on the Sun's ring as an
    /// instant.
    /// - Returns: `nil` for a sync that is not whole in the catalogue.
    public func instant(sync number: Int, atPhase phase: Fraction) -> Instant? {
        guard let number = Int32(exactly: number) else { return nil }
        return Instant(raw: withRaw { frc_time_at_sync_phase($0, number, phase.raw) })
    }
}
