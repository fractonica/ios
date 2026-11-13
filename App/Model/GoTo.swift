import Foundation
import FractonicaKit

/// Reading a typed moment (the WAVE screen's "go to" field).
///
/// A Fractonica date is read by the core (`frc_parse_date`): everything it
/// writes, and the ASCII shorthand `a#6 b#4 g#9 d#3 e#5 34h 29i`. A short
/// form (`34η 29ι`, `δ#3 ε#5`) takes its coarser parts from the moment
/// shown. In Earth mode only, text the core does not read is tried as an
/// Earth date in the device's zone.
enum GoTo {
    enum Outcome: Equatable, Sendable {
        /// A moment inside the catalogue.
        case moment(Instant)
        /// A readable moment outside the catalogue: the nearest end of it
        /// (time travel clamps, design/README.md ruling 7).
        case outOfCatalogue(Instant)
        case unreadable
    }

    /// - Parameters:
    ///   - instant: the moment shown, the context of a short form.
    ///   - earthZone: Earth mode's zone; `nil` in pure mode, where an Earth
    ///     date is not read at all.
    static func resolve(_ text: String, clock: Catalogue, at instant: Instant, earthZone: TimeZone?) -> Outcome {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .unreadable }
        let context = try? clock.date(at: instant)
        if let date = try? FractonicaDate(parsing: text, context: context) {
            if let moment = try? clock.instant(of: date) { return .moment(moment) }
            // A well-formed date the catalogue does not hold: before its
            // first Alpha, or after its last instant.
            return .outOfCatalogue(date.alpha < 1 ? clock.first : clock.last)
        }
        if let earthZone, let moment = EarthText.instant(parsing: text, zone: earthZone) {
            return clock.contains(moment) ? .moment(moment) : .outOfCatalogue(clock.clamped(moment))
        }
        return .unreadable
    }
}
