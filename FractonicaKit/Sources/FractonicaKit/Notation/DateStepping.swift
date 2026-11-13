import CFractonica

// Stepping one term of the stamp (design/astrolabe/DESIGN.md §8, "Through
// time": the nine tumblers). Kept apart from FractonicaDate.swift because it
// is a composition of core calls, not a wrapper of one.

extension Catalogue {
    /// The instant reached by moving `instant` a whole number of cycles of
    /// `unit` while keeping every finer term of the stamp as it is: stepping
    /// the Helion of `ε#5 34η 29ι 21λ 3ν` by +1 gives `ε#5 35η 29ι 21λ 3ν`,
    /// and stepping it from `77η` rolls into the next Nuclide.
    ///
    /// No arithmetic happens here. The neighbouring cycle is found by its
    /// global index (``cycle(_:index:)``), its date is read at its start, the
    /// finer fields are copied over from the date at `instant`, and the core
    /// turns the result back into an instant (the first microsecond of that
    /// Blink).
    ///
    /// - Throws: ``FractonicaError/outOfRange`` when the step leaves the
    ///   catalogue (clamp with ``clamped(_:)`` or keep the old instant).
    public func instant(byStepping unit: Unit, by cycles: Int, from instant: Instant) throws -> Instant {
        let level = unit.level
        let here = try cycle(level, at: instant)
        let target: UInt64
        if cycles >= 0 {
            let (sum, overflow) = here.index.addingReportingOverflow(UInt64(cycles))
            guard !overflow else { throw FractonicaError.outOfRange }
            target = sum
        } else {
            let back = UInt64(cycles.magnitude)
            guard back <= here.index else { throw FractonicaError.outOfRange }
            target = here.index - back
        }
        let current = try date(at: instant)
        var stepped = try date(at: try cycle(level, index: target).start)
        var finer = unit.finer
        while let field = finer {
            stepped[field] = current[field]
            finer = field.finer
        }
        return try self.instant(of: stepped)
    }
}
