import CoreGraphics
import FractonicaKit

/// Where everything on the WAVE screen is (DESIGN.md §7, "Timeline").
///
/// Phone, as designed: stamp y 136, Sun lane axis y 232, wave axis y 380
/// (half-cycle radius 52, so one cycle is 208 pt), threshold rule y 468,
/// straight limb y 522, list from y 583 at pitch 22.4. In Earth mode the
/// row of Earth tumblers needs room under the stamp, so everything below
/// the stamp slides down by ``earthShift`` and the list closes up a little.
///
/// The desktop arrangement is this app's own (the design draws none): the
/// stamp top left with the Sun's lane beside it, the wave across the whole
/// width under one hairline, the limb under it and the list in two columns.
/// Nothing moves there when the mode changes.
///
/// `earth` in the functions below is 0 in pure mode, 1 in Earth mode, and
/// in between while the mode cross-fades.
struct WaveLayout: Equatable, Sendable {
    let layout: LayoutClass

    /// Left and right margins of the text.
    let left: CGFloat
    let right: CGFloat
    /// Baseline of the screen's title.
    let title: CGPoint

    // The "go to" field: its whole frame and the text's baseline.
    let goToFrame: CGRect
    let goToBaseline: CGFloat

    // The stamp: nine columns from `stampLeft` to `stampRight`.
    let stampLeft: CGFloat
    let stampRight: CGFloat
    /// Baselines of the caption row (MOMENT … NOW) and of the terms.
    let captionY: CGFloat
    let stampY: CGFloat
    let stampSize: CGFloat
    /// A ghosted neighbour: its size, and how far apart the values of a
    /// tumbler sit (one step of a drag).
    let ghostSize: CGFloat
    let tumblerPitch: CGFloat
    /// The Earth row under the stamp, on the same nine columns.
    let earthRowY: CGFloat
    let earthSize: CGFloat
    let earthGhostSize: CGFloat
    let earthPitch: CGFloat
    /// Where the NOW mark ends (its right edge), on the caption row.
    let nowMarkRight: CGFloat

    // The Sun's lane: one sync from `sunLeft` to `sunRight` on the axis `sunY`.
    let sunLeft: CGFloat
    let sunRight: CGFloat
    let sunY: CGFloat

    // The wave: the window it is seen through, the fixed hairline, the axis,
    // the radius of one half-cycle.
    let waveLeft: CGFloat
    let waveRight: CGFloat
    let hairlineX: CGFloat
    let waveY: CGFloat
    let halfRadius: CGFloat
    /// Nested levels wanted on the wave, and cycles read each side of the hairline.
    let depth: Int
    let reach: Int

    // The straight limb.
    let limb: CGPoint
    let limbSpan: Int

    // The list of next thresholds: its title, its columns, its rows.
    let listTitle: CGPoint
    let listColumns: [ClosedRange<CGFloat>]
    let listY: CGFloat
    let listPitch: CGFloat
    /// The pitch in Earth mode (the phone closes the rows up to make room).
    let listEarthPitch: CGFloat
    let rowsPerColumn: Int
    /// How far inside a column's right edge the Earth text ends.
    let listEarthInset: CGFloat

    /// How far everything below the stamp slides down in Earth mode.
    let earthShift: CGFloat
    /// How much further the limb and the list slide: the clock times under
    /// the wave's thresholds need the room the limb's ticks stand in.
    let earthLimbDrop: CGFloat

    static let phone = WaveLayout(
        layout: .phone, left: 20, right: 373, title: CGPoint(x: 20, y: 85),
        goToFrame: CGRect(x: 96, y: 68, width: 190, height: 30), goToBaseline: 85,
        stampLeft: 20, stampRight: 373, captionY: 103, stampY: 136, stampSize: 15,
        ghostSize: 12, tumblerPitch: 23,
        earthRowY: 183, earthSize: 10.5, earthGhostSize: 9, earthPitch: 17,
        nowMarkRight: 373,
        sunLeft: 22, sunRight: 371, sunY: 232,
        waveLeft: 0, waveRight: 393, hairlineX: 196.5, waveY: 380, halfRadius: 52, depth: 2, reach: 1,
        limb: CGPoint(x: 196.5, y: 522), limbSpan: 4,
        listTitle: CGPoint(x: 20, y: 560), listColumns: [20 ... 373], listY: 583,
        listPitch: 22.4, listEarthPitch: 19, rowsPerColumn: 8, listEarthInset: 105,
        earthShift: 27, earthLimbDrop: 8
    )

    static let desktop = WaveLayout(
        layout: .desktop, left: 132, right: 1224, title: CGPoint(x: 132, y: 58),
        goToFrame: CGRect(x: 212, y: 40, width: 300, height: 32), goToBaseline: 58,
        stampLeft: 132, stampRight: 636, captionY: 92, stampY: 130, stampSize: 18,
        ghostSize: 13.5, tumblerPitch: 26,
        earthRowY: 186, earthSize: 12, earthGhostSize: 10, earthPitch: 19,
        nowMarkRight: 636,
        sunLeft: 716, sunRight: 1224, sunY: 126,
        waveLeft: 89, waveRight: 1280, hairlineX: 684, waveY: 400, halfRadius: 70, depth: 3, reach: 3,
        limb: CGPoint(x: 684, y: 596), limbSpan: 7,
        listTitle: CGPoint(x: 132, y: 652), listColumns: [132 ... 640, 716 ... 1224], listY: 678,
        listPitch: 24, listEarthPitch: 24, rowsPerColumn: 4, listEarthInset: 110,
        earthShift: 0, earthLimbDrop: 0
    )

    static func standard(_ layout: LayoutClass) -> WaveLayout {
        layout == .desktop ? .desktop : .phone
    }

    // MARK: Derived measures

    /// The wave's own scale against the design's half-cycle radius of 52:
    /// the heights around the axis grow with it.
    var waveScale: CGFloat { halfRadius / 52 }
    /// Points per cycle of the focused level: two half-cycle diameters.
    var cycleWidth: CGFloat { 4 * halfRadius }
    /// Width of one of the nine stamp columns.
    var columnWidth: CGFloat { (stampRight - stampLeft) / CGFloat(Unit.allCases.count) }
    /// Points per Helion on the Sun's lane.
    var helionWidth: CGFloat { (sunRight - sunLeft) / CGFloat(Sync.helions) }

    /// How far the lower part of the screen has slid for the Earth row.
    func shift(_ earth: CGFloat) -> CGFloat { earthShift * earth }
    /// The same for the limb and the list under it.
    func lowerShift(_ earth: CGFloat) -> CGFloat { (earthShift + earthLimbDrop) * earth }

    /// Centre of stamp column `index` (0 is the Alpha).
    func columnX(_ index: Int) -> CGFloat {
        stampLeft + columnWidth * (CGFloat(index) + 0.5)
    }

    /// The column an Earth field stands in: the weekday leads in column 0,
    /// the six fields follow in the order they are written.
    func earthColumn(_ field: EarthField) -> Int {
        (EarthField.allCases.firstIndex(of: field) ?? 0) + 1
    }

    /// Baseline of list row `index` (soonest first, down the first column).
    func rowBaseline(_ index: Int, earth: CGFloat) -> CGFloat {
        let pitch = listPitch + (listEarthPitch - listPitch) * earth
        return listY + lowerShift(earth) + CGFloat(index % rowsPerColumn) * pitch
    }

    func rowColumn(_ index: Int) -> ClosedRange<CGFloat> {
        listColumns[min(index / rowsPerColumn, listColumns.count - 1)]
    }

    /// Rows that fit.
    var maxRows: Int { rowsPerColumn * listColumns.count }

    // MARK: Frames (hit areas, accessibility elements)

    /// One tumbler of the stamp.
    func stampFrame(_ index: Int) -> CGRect {
        CGRect(x: stampLeft + columnWidth * CGFloat(index), y: stampY - 28, width: columnWidth, height: 54)
    }

    /// The whole stamp row (a drag starts on the column under the finger).
    var stampRowFrame: CGRect {
        CGRect(x: stampLeft, y: stampY - 28, width: stampRight - stampLeft, height: 54)
    }

    /// One Earth tumbler.
    func earthFrame(_ field: EarthField) -> CGRect {
        CGRect(x: stampLeft + columnWidth * CGFloat(earthColumn(field)), y: earthRowY - 18,
               width: columnWidth, height: 32)
    }

    var earthRowFrame: CGRect {
        CGRect(x: stampLeft + columnWidth, y: earthRowY - 18,
               width: columnWidth * CGFloat(EarthField.allCases.count), height: 32)
    }

    var nowMarkFrame: CGRect {
        // Below the mode toggle's own area, down into the ghost row.
        CGRect(x: nowMarkRight - 110, y: captionY - 8, width: 116, height: 22)
    }

    func sunFrame(earth: CGFloat) -> CGRect {
        CGRect(x: sunLeft - 8, y: sunY + shift(earth) - 24, width: sunRight - sunLeft + 16, height: 54)
    }

    /// The band the wave is dragged in: from above the cycle names down to
    /// the threshold words.
    func waveFrame(earth: CGFloat) -> CGRect {
        let k = waveScale, y = waveY + shift(earth)
        return CGRect(x: waveLeft, y: y - 90 * k, width: waveRight - waveLeft, height: 190 * k)
    }

    func rowFrame(_ index: Int, earth: CGFloat) -> CGRect {
        let column = rowColumn(index)
        return CGRect(x: column.lowerBound, y: rowBaseline(index, earth: earth) - 15,
                      width: column.upperBound - column.lowerBound, height: 20)
    }

    var titleFrame: CGRect {
        CGRect(x: title.x, y: title.y - 12, width: 70, height: 18)
    }
}
