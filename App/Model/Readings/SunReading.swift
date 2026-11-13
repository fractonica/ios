import FractonicaKit

/// The Sun at an instant: the solar sync (19 Helions, about four civil days),
/// its three glyphs, and where the running Helion sits in it (SPEC §7).
///
/// Exists only inside a whole sync: in the first and last partial sync of the
/// catalogue the core has no sync reading (the Pentad still answers; see
/// ``NowReading``).
struct SunReading: Equatable, Sendable {
    let sync: Sync
    /// The sync's phase as three 2-stroke glyphs.
    let odometer: Odometer
    /// Slots of the Sun's ring: the Helions of one sync, 19.
    let slots: Int
    /// The slots a Pentad starts at (0, 5, 10, 15): the ring's wider gaps.
    let pentadStarts: [Int]
    /// The slot of the running Helion, 0-based, and how much of it is done.
    let currentSlot: Int
    let slotFill: Double

    static func read(_ clock: Catalogue, at instant: Instant) -> SunReading? {
        guard let sync = try? clock.sync(at: instant),
              let odometer = try? clock.syncOdometer(at: instant),
              let helion = try? clock.cycle(Sync.level, at: instant)
        else { return nil }
        // Where each Pentad starts and which Helion runs: the core's places
        // (`frc_pentad_t.first`, `frc_sync_t.helion`).
        let pentads = (0 ..< Pentad.perSync).compactMap { try? clock.pentad(sync: sync.number, index: $0) }
        return SunReading(
            sync: sync,
            odometer: odometer,
            slots: Sync.helions,
            pentadStarts: pentads.map(\.first),
            currentSlot: sync.helion,
            slotFill: helion.phase.value
        )
    }
}
