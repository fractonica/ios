import FractonicaKit
import XCTest

/// The Gregorian translation (Earth mode): fields and ISO text for a UTC
/// offset, and the offset of a time zone taken per instant.
final class CivilTimeTests: XCTestCase {
    func testVectorAInUTC() {
        // A: 2026-10-08T12:00:00Z, a Thursday.
        let civil = CivilTime(Vector.a)
        XCTAssertEqual(civil.year, 2026)
        XCTAssertEqual(civil.month, 10)
        XCTAssertEqual(civil.day, 8)
        XCTAssertEqual(civil.hour, 12)
        XCTAssertEqual(civil.minute, 0)
        XCTAssertEqual(civil.second, 0)
        XCTAssertEqual(civil.microsecond, 0)
        XCTAssertEqual(civil.weekday, 3) // 0 = Monday
        XCTAssertEqual(civil.utcOffsetSeconds, 0)
        XCTAssertEqual(civil.isoText, "2026-10-08T12:00:00.000Z")
        XCTAssertEqual(civil.instant, Vector.a)
        XCTAssertEqual(CivilTime(Vector.b).isoText, "2000-01-01T00:00:00.000Z")
        XCTAssertEqual(CivilTime(Vector.b).weekday, 5) // a Saturday
        XCTAssertEqual(CivilTime(Vector.c).isoText, "2061-06-15T18:30:00.000Z")
    }

    func testFixedOffset() {
        let civil = CivilTime(Vector.a, utcOffsetSeconds: 2 * 3600)
        XCTAssertEqual(civil.hour, 14)
        XCTAssertEqual(civil.isoText, "2026-10-08T14:00:00.000+02:00")
        XCTAssertEqual(civil.instant, Vector.a)
        let west = CivilTime(Vector.b, utcOffsetSeconds: -5 * 3600)
        XCTAssertEqual(west.year, 1999)
        XCTAssertEqual(west.month, 12)
        XCTAssertEqual(west.day, 31)
        XCTAssertEqual(west.hour, 19)
        XCTAssertEqual(west.weekday, 4) // Friday
        XCTAssertEqual(west.isoText, "1999-12-31T19:00:00.000-05:00")
    }

    func testTimeZoneOffsetIsTakenPerInstant() throws {
        // Berlin: UTC+2 on 8 October 2026 (summer time), UTC+1 on 1 January 2000.
        let berlin = try XCTUnwrap(TimeZone(identifier: "Europe/Berlin"))
        let summer = CivilTime(Vector.a, timeZone: berlin)
        XCTAssertEqual(summer.utcOffsetSeconds, 7200)
        XCTAssertEqual(summer.hour, 14)
        XCTAssertEqual(summer.instant, Vector.a)
        let winter = CivilTime(Vector.b, timeZone: berlin)
        XCTAssertEqual(winter.utcOffsetSeconds, 3600)
        XCTAssertEqual(winter.hour, 1)
        XCTAssertEqual(winter.isoText, "2000-01-01T01:00:00.000+01:00")
        // The core's fields agree with Foundation's own calendar.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = berlin
        for instant in [Vector.a, Vector.b, Vector.c, Vector.anchorPlusOneSecond] {
            let civil = CivilTime(instant, timeZone: berlin)
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .weekday], from: instant.date)
            XCTAssertEqual(civil.year, parts.year)
            XCTAssertEqual(civil.month, parts.month)
            XCTAssertEqual(civil.day, parts.day)
            XCTAssertEqual(civil.hour, parts.hour)
            XCTAssertEqual(civil.minute, parts.minute)
            XCTAssertEqual(civil.second, parts.second)
            // Foundation: 1 = Sunday … 7 = Saturday; the core: 0 = Monday … 6 = Sunday.
            XCTAssertEqual(civil.weekday, (try XCTUnwrap(parts.weekday) + 5) % 7)
        }
    }

    func testFieldsToInstant() {
        // The sync end of vector A, as SPEC prints it: 2026-10-11T01:33:59.745Z.
        let fields = CivilTime(year: 2026, month: 10, day: 11, hour: 1, minute: 33, second: 59, microsecond: 745_000)
        XCTAssertEqual(fields.isoText, "2026-10-11T01:33:59.745Z")
        XCTAssertEqual(fields.instant.map(nearestMillisecond), 1_791_682_439_745)
        // Fields may overflow: month 13 is next January, day 0 the day before the 1st.
        XCTAssertEqual(
            CivilTime(year: 2026, month: 13, day: 1).instant,
            CivilTime(year: 2027, month: 1, day: 1).instant
        )
        XCTAssertEqual(
            CivilTime(year: 2026, month: 3, day: 0).instant,
            CivilTime(year: 2026, month: 2, day: 28).instant
        )
        // But an overflowing field is not a date to write, and a year too far has no instant.
        XCTAssertNil(CivilTime(year: 2026, month: 13, day: 1).isoText)
        XCTAssertNil(CivilTime(year: 400_000, month: 1, day: 1).instant)
        XCTAssertEqual(CivilTime(year: 1970, month: 1, day: 1).instant, Instant(microseconds: 0))
    }

    func testWallClockFieldsInATimeZone() throws {
        // Vector A is 14:00 in Paris (summer time, +2) and 12:00 in UTC.
        let paris = try XCTUnwrap(TimeZone(identifier: "Europe/Paris"))
        let utc = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let a = Instant(unixSeconds: 1_791_460_800)!
        XCTAssertEqual(CivilTime(year: 2026, month: 10, day: 8, hour: 14).instant(in: paris), a)
        XCTAssertEqual(CivilTime(year: 2026, month: 10, day: 8, hour: 12).instant(in: utc), a)
        // The offset already in the fields is ignored: the zone decides.
        XCTAssertEqual(CivilTime(year: 2026, month: 10, day: 8, hour: 14, utcOffsetSeconds: -3600).instant(in: paris), a)
        // Winter time (+1): the round trip holds on both sides of the change.
        for seconds: Int64 in [1_791_460_800, 1_798_761_600, 1_774_000_000] {
            let instant = Instant(unixSeconds: seconds)!
            XCTAssertEqual(CivilTime(instant, timeZone: paris).instant(in: paris), instant)
        }
        XCTAssertNil(CivilTime(year: 400_000, month: 1, day: 1).instant(in: paris))
    }

    /// The wall clock right beside a daylight-saving change, on both sides
    /// and at both changes of the year: the fields read as UTC fall on the
    /// other side of the change from the answer, so the zone's offset must
    /// be asked again at the first guess (the second look-up of
    /// `instant(in:)`).
    func testWallClockAcrossDaylightSavingChanges() throws {
        let paris = try XCTUnwrap(TimeZone(identifier: "Europe/Paris"))
        func wall(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Instant? {
            CivilTime(year: 2026, month: month, day: day, hour: hour, minute: minute).instant(in: paris)
        }
        // Spring, 29 March 2026: at 01:00 UTC the clock jumps 02:00 -> 03:00.
        XCTAssertEqual(wall(3, 29, 1, 30)?.date, try date("2026-03-29T00:30:00Z")) // winter time, +1
        XCTAssertEqual(wall(3, 29, 3, 30)?.date, try date("2026-03-29T01:30:00Z")) // summer time, +2
        // Autumn, 25 October 2026: at 01:00 UTC the clock goes back 03:00 -> 02:00.
        XCTAssertEqual(wall(10, 25, 1, 30)?.date, try date("2026-10-24T23:30:00Z")) // summer time, +2
        XCTAssertEqual(wall(10, 25, 3, 30)?.date, try date("2026-10-25T02:30:00Z")) // winter time, +1
        // And back: each of those instants reads as the wall clock it came from.
        for (month, day, hour) in [(3, 29, 1), (3, 29, 3), (10, 25, 1), (10, 25, 3)] {
            let fields = CivilTime(try XCTUnwrap(wall(month, day, hour, 30)), timeZone: paris)
            XCTAssertEqual([fields.month, fields.day, fields.hour, fields.minute], [month, day, hour, 30])
        }
    }

    /// Fields the core's struct cannot hold are refused, never clamped into
    /// another value; overflow upwards within it stays linear.
    func testFieldsOutsideTheStructAreRefused() {
        XCTAssertEqual(CivilTime(year: 2026, month: 3, day: 0).instant?.date, try date("2026-02-28T00:00:00Z"))
        XCTAssertEqual(CivilTime(year: 2026, month: 13, day: 1).instant?.date, try date("2027-01-01T00:00:00Z"))
        XCTAssertEqual(CivilTime(year: 2026, month: 3, day: 1, hour: 24).instant?.date, try date("2026-03-02T00:00:00Z"))
        XCTAssertNil(CivilTime(year: 2026, month: 3, day: -1).instant)
        XCTAssertNil(CivilTime(year: 2026, month: 3, day: 1, hour: -1).instant)
        XCTAssertNil(CivilTime(year: 2026, month: 300, day: 1).instant)
        XCTAssertNil(CivilTime(year: 2026, month: 3, day: 1, minute: 256).instant)
        XCTAssertNil(CivilTime(year: 2026, month: 3, day: -1).isoText)
    }

    private func date(_ iso: String) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: iso))
    }

    func testJulianRepair() {
        // SPEC §2.3: the reform. 1582-10-15 Gregorian is the day after 1582-10-04 Julian.
        let reform = Catalogue.gregorianReformUnixMilliseconds
        XCTAssertEqual(reform, -12_219_292_800_000)
        XCTAssertEqual(CivilTime(Instant(unixMilliseconds: reform)!).isoText, "1582-10-15T00:00:00.000Z")
        let julianOct5 = CivilTime(year: 1582, month: 10, day: 5).instant!
        // Fields "1582-10-05" read as a Julian date are the Gregorian 1582-10-15.
        XCTAssertEqual(Catalogue.julianFieldsToUnixMilliseconds(julianOct5.microseconds / 1000), reform)
    }
}
