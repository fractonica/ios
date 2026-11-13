import Foundation
import FractonicaKit

/// When the screen next has to be redrawn (hard rule 5: scheduled from the
/// instants the core returns, never polled).
///
/// What is visible and changes on its own:
/// - the reading's finest term, the Blink count: the running Blink's end;
/// - the centre odometer of the focus and the odometer of the level under it
///   (the desktop's period pair): their `nextChange`;
/// - the Sun's three glyphs: the sync odometer's `nextChange`;
/// - the countdowns to the next thresholds (NOW, the lens, WAVE's list) and
///   to the Sun's next quarter: when each text next changes, from the core
///   (`frc_span_next_change`), for the levels around the focus that the
///   screens list;
/// - the signed spans that cross zero: the four thresholds of the moving
///   level's running cycle (the lens lists them, the past ones as elapsed
///   spans, `−20ι 21λ`) and the cursor's offset from now (the NOW mark,
///   `+3η 12ι`). Before its instant such a span shrinks
///   (`frc_span_next_change`); from it on it grows
///   (`frc_span_next_change_since`);
/// - the fill of the arcs and the point of now, which move continuously: a
///   modest cadence taken from the deepest arc drawn, a 48th of its cycle, so
///   the point advances in steps too small to see;
/// - in Earth mode only: the clock's second (the date line, the tumblers,
///   the durations under the countdowns), and, while a countdown is under
///   ten seconds, its hundredths (at the 30 frames a second floor).
///
/// Thresholds, beads and counters all change on a boundary of one of these.
enum ClockSchedule {
    /// The fastest the screen is ever redrawn for time alone (DESIGN.md §10:
    /// at most 30 frames a second while the focus is finer than ι).
    static let minimumInterval: Duration = .milliseconds(33)
    /// The longest the scheduler sleeps, so that a change of the device clock
    /// (or of the time zone) is picked up without a notification.
    static let maximumInterval: Duration = .seconds(1)

    /// The first instant strictly after `now` at which something on screen
    /// changes; `nil` when nothing will (outside the catalogue, or at its end).
    /// - Parameter cursor: the scrubbed moment, whose offset from now the
    ///   NOW mark shows; `nil` at the present.
    static func nextChange(
        in clock: Catalogue, after now: Instant, focus: Level, nestDepth: Int, earth: Bool = false,
        cursor: Instant? = nil
    ) -> Instant? {
        guard clock.contains(now) else {
            // Before the catalogue the clock starts at its first instant.
            return now < clock.first ? clock.first : nil
        }
        var candidates: [Instant?] = [
            try? clock.cycle(.blink, at: now).end,
            try? clock.odometer(focus, at: now).nextChange,
            try? clock.syncOdometer(at: now).nextChange,
        ]
        if let child = focus.child {
            candidates.append(try? clock.odometer(child, at: now).nextChange)
        }
        // The countdowns: the levels WAVE lists (two finer, the focus, four
        // coarser; NOW's are among them) and the Sun's next quarter.
        var boundaries: [Instant?] = [(try? clock.sync(at: now))?.next.instant]
        for step in -4 ... 2 {
            guard let level = focus.offset(by: step), level.isClockLevel else { continue }
            boundaries.append((try? clock.nextThreshold(level, after: now))?.instant)
        }
        for boundary in boundaries.compactMap({ $0 }) {
            candidates.append(clock.spanNextChange(from: now, to: boundary))
        }
        // The signed spans: shrinking before their instant, growing after it.
        var signed: [Instant] = []
        if focus.isClockLevel, let cycle = try? clock.cycle(focus, at: now),
           let points = try? clock.points(of: cycle) {
            signed += Quarter.allCases.compactMap { points[$0] }
        }
        if let cursor { signed.append(cursor) }
        for instant in signed {
            candidates.append(instant > now
                ? clock.spanNextChange(from: now, to: instant)
                : clock.spanNextChange(since: instant, at: now))
        }
        if let deepest = focus.offset(by: nestDepth), deepest.isClockLevel,
           let cycle = try? clock.cycle(deepest, at: now) {
            // Scheduling only: a length of real time, never shown.
            let step = max(cycle.end.microseconds(since: cycle.start) / 48, 1)
            candidates.append(now.advanced(byMicroseconds: step))
        }
        if earth {
            candidates.append(EarthText.nextEarthSecond(after: now))
            // An Earth duration under ten seconds is written to the hundredth.
            for level in [focus, focus.child].compactMap({ $0 }) where level.isClockLevel {
                if let threshold = try? clock.nextThreshold(level, after: now).instant,
                   threshold.microseconds(since: now) < 10_000_000 {
                    candidates.append(now.advanced(byMicroseconds: 10_000))
                }
            }
        }
        return candidates.compactMap { $0 }.filter { $0 > now }.min()
    }

    /// How long to sleep from `now` until `next`, kept between the two bounds.
    static func delay(from now: Instant, until next: Instant?) -> Duration {
        guard let next else { return maximumInterval }
        let wait = Duration.microseconds(next.microseconds(since: now))
        return min(max(wait, minimumInterval), maximumInterval)
    }
}
