import CFractonica
import Foundation

/// A moment: Unix time in **microseconds** (UTC, every day 86 400 s). This is
/// the core's `frc_time_t`, and the only time type the kit takes or returns.
///
/// The core's "no such instant" answer (`FRC_TIME_NONE`, a boundary beyond the
/// catalogue) never appears as an `Instant`: the kit returns `nil` instead.
public struct Instant: Hashable, Comparable, Sendable, CustomStringConvertible {
    /// Unix microseconds.
    public var microseconds: Int64

    public init(microseconds: Int64) {
        self.microseconds = microseconds
    }

    /// Unix milliseconds as an instant (`frc_time_from_ms`); `nil` when the
    /// value does not fit microseconds.
    public init?(unixMilliseconds: Int64) {
        self.init(raw: frc_time_from_ms(unixMilliseconds))
    }

    /// Unix seconds as an instant (`frc_time_from_s`); `nil` when the value
    /// does not fit microseconds.
    public init?(unixSeconds: Int64) {
        self.init(raw: frc_time_from_s(unixSeconds))
    }

    /// The instant of a Foundation `Date`, to the NEAREST microsecond.
    ///
    /// Rounded rather than cut: a `Date` is a `Double` of seconds since 2001,
    /// whose step is about 2 µs in the 17th century, so ``date`` cannot hold
    /// every instant there; rounding brings `Instant(i.date)` back within
    /// one microsecond of `i` (exactly back wherever the step is finer). A
    /// date beyond what microseconds can count (about ±292 000 years) is
    /// clamped to the first or last representable instant instead of
    /// trapping; such an instant is far outside any catalogue.
    public init(_ date: Date) {
        let value = (date.timeIntervalSince1970 * 1_000_000).rounded(.toNearestOrAwayFromZero)
        if let exact = Int64(exactly: value) {
            microseconds = exact
        } else if value.isNaN {
            microseconds = 0
        } else {
            microseconds = value > 0 ? .max : .min
        }
    }

    /// A value the core returned; `nil` for `FRC_TIME_NONE`.
    init?(raw: frc_time_t) {
        if frc_time_is_none(raw) != 0 { return nil }
        microseconds = raw
    }

    /// The device clock, now.
    public static var now: Instant { Instant(Date()) }

    /// The same moment for Foundation (timers, `TimeZone` look-ups).
    public var date: Date {
        Date(timeIntervalSince1970: Double(microseconds) / 1_000_000)
    }

    /// This instant moved by a signed number of microseconds.
    public func advanced(byMicroseconds delta: Int64) -> Instant {
        Instant(microseconds: microseconds + delta)
    }

    /// Microseconds from `other` to this instant (negative when earlier).
    /// For scheduling a redraw; a length to SHOW is a ``Span`` instead.
    public func microseconds(since other: Instant) -> Int64 {
        microseconds - other.microseconds
    }

    public static func < (lhs: Instant, rhs: Instant) -> Bool {
        lhs.microseconds < rhs.microseconds
    }

    /// Developer-facing (Unix microseconds). Never show it in pure mode.
    public var description: String { "Instant(\(microseconds) µs)" }
}
