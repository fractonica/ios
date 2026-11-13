import CFractonica

/// The eclipse catalogue of one Saros series: the time base of the clock
/// (SPEC §2.2, §14). Wraps `frc_catalogue_t`.
///
/// **Everything that is read at an instant is a method of a catalogue**, in
/// extensions next to the type they return:
///
///     let clock = Catalogue.saros141
///     let helion = try clock.cycle(.helion, at: .now)       // Clock/Cycle.swift
///     let pair   = try clock.odometer(.helion, at: .now)    // Clock/Odometer.swift
///     let date   = try clock.date(at: .now)                 // Notation/FractonicaDate.swift
///
/// The clock is defined on `first ... last` only. Outside it every reading
/// throws ``FractonicaError/outOfRange``; nothing is extrapolated.
public struct Catalogue: Equatable, @unchecked Sendable {
    // @unchecked Sendable: `raw` holds a pointer to a table of eclipse instants
    // that is immutable for the life of the value (the core's constant table,
    // or `storage`, which is never written after init).

    /// The descriptor the core functions take.
    let raw: frc_catalogue_t
    /// Keeps the table of a catalogue built from a Swift array alive.
    private let storage: TableStorage?

    /// Solar Saros 141: 70 eclipses, the series every client runs on
    /// (design/README.md, ruling 8).
    public static let saros141 = Catalogue(raw: FRC_SAROS_141, storage: nil)

    private init(raw: frc_catalogue_t, storage: TableStorage?) {
        self.raw = raw
        self.storage = storage
    }

    /// A catalogue for another series (`frc_catalogue_init`, which validates
    /// the table and chooses the solar-sync anchor by SPEC §7.2).
    /// - Parameters:
    ///   - series: the Saros series number, 0 if unnamed.
    ///   - eclipseUnixMilliseconds: the greatest-eclipse instants in Unix
    ///     **milliseconds** (the published precision), strictly increasing,
    ///     at least two.
    /// - Throws: ``FractonicaError/invalidArgument`` for a table the core refuses.
    public init(series: Int, eclipseUnixMilliseconds: [Int64]) throws {
        guard let seriesNumber = UInt16(exactly: series),
              let count = UInt16(exactly: eclipseUnixMilliseconds.count)
        else { throw FractonicaError.invalidArgument }
        let storage = TableStorage(eclipseUnixMilliseconds)
        var raw = frc_catalogue_t()
        try check(frc_catalogue_init(&raw, storage.table, count, seriesNumber))
        self.init(raw: raw, storage: storage)
    }

    /// The Saros series number (141), 0 if unnamed.
    public var series: Int { Int(raw.series) }
    /// Number of eclipses in the table.
    public var eclipseCount: Int { Int(raw.count) }
    /// Ordinal of the eclipse the solar sync is counted from (20 for Saros 141).
    public var anchorOrdinal: Int { Int(raw.anchor) }

    /// First instant of the clock's domain.
    public var first: Instant { Instant(microseconds: withRaw { frc_catalogue_first($0) }) }
    /// The closing instant (it belongs to the last cycle, sync and Pentad).
    public var last: Instant { Instant(microseconds: withRaw { frc_catalogue_last($0) }) }
    /// The domain of the clock, `first ... last`.
    public var range: ClosedRange<Instant> { first ... last }

    /// Whether the clock is defined at `instant`.
    public func contains(_ instant: Instant) -> Bool {
        withRaw { frc_catalogue_contains($0, instant.microseconds) } != 0
    }

    /// `instant` if the clock is defined there, otherwise the nearer end of
    /// the catalogue: "time travel clamps to the catalogue" (ruling 7).
    public func clamped(_ instant: Instant) -> Instant {
        min(max(instant, first), last)
    }

    /// Instant of eclipse `ordinal` (0-based); `nil` beyond the table.
    public func eclipse(_ ordinal: Int) -> Instant? {
        guard let ordinal = UInt16(exactly: ordinal) else { return nil }
        return Instant(raw: withRaw { frc_catalogue_instant($0, ordinal) })
    }

    /// Two catalogues are equal when they are the same table (identity, not
    /// contents) with the same series number and anchor.
    public static func == (lhs: Catalogue, rhs: Catalogue) -> Bool {
        lhs.raw.instants_ms == rhs.raw.instants_ms
            && lhs.raw.count == rhs.raw.count
            && lhs.raw.series == rhs.raw.series
            && lhs.raw.anchor == rhs.raw.anchor
    }

    // MARK: Calling the core

    /// Runs `body` with the descriptor pointer the core functions take.
    func withRaw<Result>(_ body: (UnsafePointer<frc_catalogue_t>) throws -> Result) rethrows -> Result {
        try withUnsafePointer(to: raw, body)
    }

    /// The shape of nearly every clock function:
    /// `frc_status_t f(catalogue, ..., T *out)`. Returns the filled `T`.
    /// - Throws: the ``FractonicaError`` of a status other than `FRC_OK`.
    func read<Value>(
        into initial: Value,
        _ body: (UnsafePointer<frc_catalogue_t>, UnsafeMutablePointer<Value>) -> frc_status_t
    ) throws -> Value {
        var value = initial
        let status = withUnsafePointer(to: raw) { catalogue in
            withUnsafeMutablePointer(to: &value) { body(catalogue, $0) }
        }
        try check(status)
        return value
    }
}

/// Owns the copy of a Swift array of eclipse instants for as long as a
/// ``Catalogue`` built from it lives (the core keeps a pointer, not a copy).
private final class TableStorage {
    let table: UnsafeMutablePointer<Int64>
    private let count: Int

    init(_ instants: [Int64]) {
        count = instants.count
        table = UnsafeMutablePointer<Int64>.allocate(capacity: max(count, 1))
        table.initialize(from: instants, count: count)
    }

    deinit {
        table.deinitialize(count: count)
        table.deallocate()
    }
}

// MARK: - Table building

extension Catalogue {
    /// SPEC §2.3, for building a table only: reinterpret the proleptic
    /// Gregorian fields of a Unix-millisecond value as a Julian-calendar date
    /// (`frc_julian_fields_to_unix_ms`). Apply it to values before
    /// ``gregorianReformUnixMilliseconds`` from a source that lists Julian dates.
    public static func julianFieldsToUnixMilliseconds(_ unixMilliseconds: Int64) -> Int64 {
        frc_julian_fields_to_unix_ms(unixMilliseconds)
    }

    /// 1582-10-15T00:00:00Z in Unix milliseconds (`FRC_GREGORIAN_REFORM_MS`).
    public static var gregorianReformUnixMilliseconds: Int64 { FRC_GREGORIAN_REFORM_MS }
}
