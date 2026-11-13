import CFractonica
import Foundation

/// The Gregorian translation of an instant at a fixed UTC offset
/// (`frc_civil_t`): proleptic Gregorian, any year.
///
/// **EARTH MODE ONLY.** Nothing of this type may reach the screen, an
/// accessibility label, a tooltip, a menu or a window title in pure mode
/// (design/README.md, ruling 11).
///
/// The zone is the device's (ruling 6). Its offset changes with the instant
/// (daylight saving), so take it per instant: ``init(_:timeZone:)`` asks
/// Foundation for the offset and the core for the fields.
public struct CivilTime: Hashable, Sendable {
    public var year: Int
    /// 1...12.
    public var month: Int
    /// 1...31.
    public var day: Int
    /// 0...23.
    public var hour: Int
    public var minute: Int
    public var second: Int
    public var microsecond: Int
    /// 0 = Monday ... 6 = Sunday. Output only: ``instant``
    /// ignores it.
    public var weekday: Int
    /// The offset from UTC these fields are in, in seconds (0 = UTC).
    public var utcOffsetSeconds: Int

    public init(
        year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0, second: Int = 0,
        microsecond: Int = 0, utcOffsetSeconds: Int = 0
    ) {
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
        self.second = second
        self.microsecond = microsecond
        self.weekday = 0
        self.utcOffsetSeconds = utcOffsetSeconds
    }

    /// The civil fields of `instant` at a fixed offset (`frc_civil_from_time`).
    public init(_ instant: Instant, utcOffsetSeconds: Int = 0) {
        var raw = frc_civil_t()
        frc_civil_from_time(instant.microseconds, Int32(clamping: utcOffsetSeconds), &raw)
        year = Int(raw.year)
        month = Int(raw.month)
        day = Int(raw.day)
        hour = Int(raw.hour)
        minute = Int(raw.minute)
        second = Int(raw.second)
        microsecond = Int(raw.microsecond)
        weekday = Int(raw.weekday)
        self.utcOffsetSeconds = utcOffsetSeconds
    }

    /// The civil fields of `instant` in a time zone: the offset in force at
    /// that instant comes from Foundation, the fields from the core.
    public init(_ instant: Instant, timeZone: TimeZone) {
        self.init(instant, utcOffsetSeconds: timeZone.secondsFromGMT(for: instant.date))
    }

    /// The fields as the core's struct, or `nil` when one of them does not
    /// fit it: the struct holds a month, day, hour, minute and second of
    /// 0...255 (never negative) and a year of 32 bits. Nothing is clamped,
    /// so no field silently becomes another value.
    var exactRaw: frc_civil_t? {
        guard let year = Int32(exactly: year),
              let month = UInt8(exactly: month), let day = UInt8(exactly: day),
              let hour = UInt8(exactly: hour), let minute = UInt8(exactly: minute),
              let second = UInt8(exactly: second), let microsecond = UInt32(exactly: microsecond)
        else { return nil }
        return frc_civil_t(
            year: year, month: month, day: day, hour: hour, minute: minute, second: second,
            weekday: UInt8(clamping: weekday), microsecond: microsecond
        )
    }

    /// The instant these fields name at their offset (`frc_time_from_civil`).
    /// Fields may overflow upwards within what the core's struct holds
    /// (0...255: month 13 is next January, hour 24 the next midnight, day 0
    /// the day before the 1st). `nil` for a negative field, a field above
    /// 255, an offset beyond 32 bits or a year the core cannot hold.
    public var instant: Instant? {
        guard var raw = exactRaw, let offset = Int32(exactly: utcOffsetSeconds) else { return nil }
        return Instant(raw: frc_time_from_civil(&raw, offset))
    }

    /// The instant these fields name as **wall-clock time in a time zone**
    /// (a typed Earth date, an Earth tumbler): ``utcOffsetSeconds`` is
    /// ignored and the zone's offset is used instead. The offset in force
    /// depends on the instant that is being looked for, so it is asked of
    /// Foundation twice: once at the fields read as UTC, once at the instant
    /// that first guess gives. The fields become an instant in the core
    /// (`frc_time_from_civil`) both times. A wall-clock time that a
    /// daylight-saving change skips or repeats resolves to one of its
    /// neighbours. `nil` for a year the core cannot hold.
    public func instant(in timeZone: TimeZone) -> Instant? {
        var fields = self
        fields.utcOffsetSeconds = 0
        guard let asUTC = fields.instant else { return nil }
        fields.utcOffsetSeconds = timeZone.secondsFromGMT(for: asUTC.date)
        guard let guess = fields.instant else { return nil }
        fields.utcOffsetSeconds = timeZone.secondsFromGMT(for: guess.date)
        return fields.instant
    }

    /// ISO 8601 with milliseconds (`frc_format_civil`):
    /// `"2026-10-08T12:00:00.000Z"`, or `"…+02:00"` for a non-zero offset.
    /// `nil` unless the fields are a date and a time of day.
    public var isoText: String? {
        guard var raw = exactRaw, let offset = Int32(exactly: utcOffsetSeconds) else { return nil }
        return try? CoreText.make { frc_format_civil(&raw, offset, $0, $1) }
    }

    /// Whether the fields name a real moment (`frc_civil_validate`): `false`
    /// for a day the calendar does not have (`31 FEB`, 2026-02-29), a time
    /// of day that does not exist (hour 24, second 60), a year outside
    /// ±290 000, or a field the core's struct cannot hold. The weekday is not
    /// read.
    public var isValid: Bool {
        guard var raw = exactRaw else { return false }
        return frc_civil_validate(&raw) == FRC_OK
    }

    /// Reads an Earth date and time typed by a person, or written by the core
    /// (`frc_parse_civil`): `"2026-10-08"`, `"2026-10-08 12:00"`,
    /// `"2026-10-08T14:00:00+02:00"`, `"8 OCT 2026"`, `"THU 8 OCT 2026 ·
    /// 12:00:00"`, with an optional zone after a time (`Z`, `UTC`, `GMT`,
    /// `+02:00`, `+0200`, `+02`, `UTC+3`). Without a time: midnight.
    /// - Returns: the fields (``weekday`` computed from the date), with
    ///   ``utcOffsetSeconds`` the offset the text names (0 when it names
    ///   none), and whether it named one. Without one, the fields are a wall
    ///   clock: take their instant with ``instant(in:)``.
    /// - Throws: ``FractonicaError/unparsable`` for text of another shape (a
    ///   zone's name, a date without a year, a weekday that is not the
    ///   date's); ``FractonicaError/outOfRange`` for well-formed text that
    ///   names no real moment (`31 FEB 2026`, hour 24).
    public static func parse(_ text: String) throws -> (time: CivilTime, namesOffset: Bool) {
        var raw = frc_civil_t()
        var offset: Int32 = 0
        var hasOffset: Int32 = 0
        try check(frc_parse_civil(text, &raw, &offset, &hasOffset))
        var time = CivilTime(
            year: Int(raw.year), month: Int(raw.month), day: Int(raw.day), hour: Int(raw.hour),
            minute: Int(raw.minute), second: Int(raw.second), microsecond: Int(raw.microsecond),
            utcOffsetSeconds: Int(offset)
        )
        time.weekday = Int(raw.weekday)
        return (time, hasOffset != 0)
    }
}
