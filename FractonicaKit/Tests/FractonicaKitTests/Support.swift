import FractonicaKit
import XCTest

// Shared by every test file: the instants of SPEC §12 and the way SPEC's
// rounded figures are compared with the core's exact ones.

/// The catalogue every vector is given on.
let clock = Catalogue.saros141

/// The instants of SPEC.md §12, typed in as the SPEC prints them.
enum Vector {
    /// A: 2026-10-08T12:00:00Z.
    static let a = Instant(unixSeconds: 1_791_460_800)!
    /// B: 2000-01-01T00:00:00Z.
    static let b = Instant(unixSeconds: 946_684_800)!
    /// C: 2061-06-15T18:30:00Z.
    static let c = Instant(unixSeconds: 2_886_085_800)!
    /// "Anchor": Unix 125593320.816, one second after the anchor eclipse.
    static let anchorPlusOneSecond = Instant(unixMilliseconds: 125_593_320_816)!
}

/// Microseconds rounded to the nearest millisecond, a half away from zero.
///
/// SPEC prints instants to the millisecond; the core returns the first
/// microsecond at or after the exact instant. An instant matches SPEC's when
/// it rounds to SPEC's millisecond (the rule of core/tests/test_spec.c).
func nearestMillisecond(_ instant: Instant) -> Int64 {
    let us = instant.microseconds
    return us >= 0 ? (us + 500) / 1000 : -((-us + 500) / 1000)
}

/// Asserts that `instant` is the instant SPEC prints as `seconds.milliseconds`.
func XCTAssertInstant(
    _ instant: Instant?, unixMilliseconds expected: Int64,
    file: StaticString = #filePath, line: UInt = #line
) {
    guard let instant else {
        return XCTFail("no instant; expected \(expected) ms", file: file, line: line)
    }
    XCTAssertEqual(nearestMillisecond(instant), expected, file: file, line: line)
}

/// The ISO 8601 text (UTC) of an instant rounded to the millisecond, the way
/// SPEC prints one: `"2026-10-07T01:34:09.826Z"`.
func isoUTC(_ instant: Instant) -> String? {
    Instant(unixMilliseconds: nearestMillisecond(instant)).flatMap { CivilTime($0).isoText }
}

/// Asserts that `body` throws exactly `expected`.
func XCTAssertThrows<T>(
    _ expected: FractonicaError, _ body: @autoclosure () throws -> T,
    file: StaticString = #filePath, line: UInt = #line
) {
    XCTAssertThrowsError(try body(), file: file, line: line) { error in
        XCTAssertEqual(error as? FractonicaError, expected, file: file, line: line)
    }
}
