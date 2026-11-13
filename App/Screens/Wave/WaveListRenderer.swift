import SwiftUI
import FractonicaKit

/// The list under the wave (DESIGN.md §7, §9): the next thresholds of the
/// levels around the focus and of the Sun, soonest first, each with the span
/// from the moment shown. Earth mode adds when it falls, led by the Earth
/// sign. The row itself is the one the NOW screen draws (`NowPieces`).
enum WaveListRenderer {
    static func draw(
        _ rows: [NowReading.Upcoming], layout: WaveLayout, earthLines: [String]?, earth: Double, in ink: inout Ink
    ) {
        let e = CGFloat(earth)
        // Outside the catalogue there is nothing to come: no heading over nothing.
        guard !rows.isEmpty else { return }
        ink.text("Next thresholds", at: CGPoint(x: layout.listTitle.x, y: layout.listTitle.y + layout.lowerShift(e)),
                 ink.theme.engraved(6.8, ink.palette.ash))
        for (index, row) in rows.prefix(layout.maxRows).enumerated() {
            let column = layout.rowColumn(index)
            let earthLine = earthLines.flatMap { index < $0.count ? $0[index] : nil }
            NowPieces.upcomingRow(
                row, earthLine: earthLine, earth: earth, from: column.lowerBound, to: column.upperBound,
                earthX: column.upperBound - layout.listEarthInset, baseline: layout.rowBaseline(index, earth: e), in: &ink
            )
        }
    }
}
