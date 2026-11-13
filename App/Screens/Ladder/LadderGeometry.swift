import CoreGraphics
import FractonicaKit

/// Where everything on the LADDER screen is (DESIGN.md §7, "Ladder"): the rim
/// of the great wheel, the rows on it, the columns of values, the spine.
///
/// The ladder is the limb at full length. The 63 rungs sit on the rim of a
/// wheel whose centre is far to the right; the rung at the wheel's fixed
/// middle is enlarged, its neighbours follow at a regular pitch and fade
/// towards the ends. `position` is the scale position at the middle, as a
/// level index that is fractional while the wheel is turning.
///
/// Phone numbers are the design's own (wheel radius 1150, rows at pitch 47,
/// the focused row 2 × 92 tall at y 452, values right-aligned at x 342, the
/// spine at x 375 from y 128 to 742). The desktop arrangement is the same
/// wheel with more rows and one column per value.
struct LadderGeometry: Equatable, Sendable {
    let layout: LayoutClass
    /// Radius of the wheel, and the x of its rim at the middle row.
    let wheelRadius: CGFloat
    let rimX: CGFloat
    /// The y of the focused row.
    let focusY: CGFloat
    /// Distance from the focused row to its neighbours, and between the others.
    let focusGap: CGFloat
    let pitch: CGFloat
    /// Rows drawn on each side of the focused one.
    let span: Int
    /// Half the height of the rim that is drawn.
    let rimReach: CGFloat
    /// Left margin of the title, and the title's baseline.
    let titleX: CGFloat
    let titleY: CGFloat
    /// Baselines of the two lines of column headings.
    let headingY: CGFloat
    /// The spine: its x, and the y of the first and the last rung.
    let spineX: CGFloat
    let spineTop: CGFloat
    let spineBottom: CGFloat
    /// Right edges of the value columns.
    var columns: Columns

    /// The right edge of each column of values. On the phone one column
    /// carries either the pure or the Earth values (`primary`); the desktop
    /// has one column per value and shows both in Earth mode.
    struct Columns: Equatable, Sendable {
        /// Phone: the one value column. Desktop: unused.
        var primary: CGFloat = 0
        /// Phone: the widest a list row's size may be (screen3.png: an exact
        /// rate up to ε1's, `20 290 520 250 000 pB`; finer rungs take the
        /// core's four-digit form, `1.562 × 10¹⁵ pB`).
        var listValueWidth: CGFloat = .infinity
        /// Desktop, pure: length, rate, made of.
        var length: CGFloat = 0
        var rate: CGFloat = 0
        var madeOf: CGFloat = 0
        /// Desktop, Earth: period, frequency, light in vacuum.
        var period: CGFloat = 0
        var frequency: CGFloat = 0
        var light: CGFloat = 0
        /// Where the focused row's band rule ends.
        var ruleEnd: CGFloat = 0
        /// Desktop: where the three pure columns and the rule's end stand in
        /// pure mode, when the Earth columns are absent. They spread over the
        /// whole width instead of leaving its right half bare, and slide back
        /// to their Earth places as the Earth columns fade in.
        var pureLength: CGFloat?
        var pureRate: CGFloat?
        var pureMadeOf: CGFloat?
        var pureRuleEnd: CGFloat?

        /// The columns at a blend of the modes (0 pure ... 1 Earth).
        func blended(earth: Double) -> Columns {
            let e = CGFloat(min(max(earth, 0), 1))
            func mix(_ pure: CGFloat?, _ earthPlace: CGFloat) -> CGFloat {
                guard let pure else { return earthPlace }
                return pure + (earthPlace - pure) * e
            }
            var columns = self
            columns.length = mix(pureLength, length)
            columns.rate = mix(pureRate, rate)
            columns.madeOf = mix(pureMadeOf, madeOf)
            columns.ruleEnd = mix(pureRuleEnd, ruleEnd)
            return columns
        }
    }

    /// The geometry with its columns at a blend of the modes.
    func blended(earth: Double) -> LadderGeometry {
        var geometry = self
        geometry.columns = columns.blended(earth: earth)
        return geometry
    }

    static let phone = LadderGeometry(
        layout: .phone, wheelRadius: 1150, rimX: 46, focusY: 452, focusGap: 92, pitch: 47, span: 5,
        rimReach: 360, titleX: 20, titleY: 85, headingY: 127,
        spineX: 375, spineTop: 128, spineBottom: 742,
        columns: Columns(primary: 342, listValueWidth: 140, ruleEnd: 342)
    )

    static let desktop = LadderGeometry(
        layout: .desktop, wheelRadius: 1500, rimX: 156, focusY: 420, focusGap: 88, pitch: 45, span: 6,
        rimReach: 372, titleX: 132, titleY: 58, headingY: 66,
        spineX: 1240, spineTop: 110, spineBottom: 730,
        columns: Columns(length: 520, rate: 730, madeOf: 822, period: 950, frequency: 1066, light: 1190, ruleEnd: 822,
                         pureLength: 700, pureRate: 1010, pureMadeOf: 1190, pureRuleEnd: 1190)
    )

    static func standard(_ layout: LayoutClass) -> LadderGeometry {
        layout == .desktop ? .desktop : .phone
    }

    // MARK: The wheel

    /// Centre of the wheel.
    var wheelCenter: CGPoint { CGPoint(x: rimX + wheelRadius, y: focusY) }

    /// The x of the rim at height `y`.
    func rimX(atY y: CGFloat) -> CGFloat {
        let dy = min(abs(y - focusY), wheelRadius)
        return wheelCenter.x - (wheelRadius * wheelRadius - dy * dy).squareRoot()
    }

    /// The y of a row `offset` rungs from the middle (fractional while turning).
    func rowY(offset: CGFloat) -> CGFloat {
        let distance = abs(offset)
        let dy = distance <= 1 ? distance * focusGap : focusGap + (distance - 1) * pitch
        return focusY + (offset < 0 ? -dy : dy)
    }

    /// The inverse of ``rowY(offset:)``: how many rungs from the middle the
    /// height `y` is (a tap on a row).
    func offset(atY y: CGFloat) -> CGFloat {
        let dy = abs(y - focusY)
        let distance = dy <= focusGap ? dy / focusGap : 1 + (dy - focusGap) / pitch
        return y < focusY ? -distance : distance
    }

    /// How much a row `offset` rungs away is the focused one: 1 at the
    /// middle, 0 from one rung away.
    func focus(offset: CGFloat) -> CGFloat {
        max(0, 1 - abs(offset))
    }

    /// Half the height a row takes on the band rail: 17 for a list row, 62
    /// for the focused one.
    func halfHeight(offset: CGFloat) -> CGFloat {
        17 + 45 * focus(offset: offset)
    }

    /// Opacity of a list row: the rows dim towards the ends of the window
    /// and leave it within the last half rung.
    func rowOpacity(offset: CGFloat) -> Double {
        let distance = Double(abs(offset))
        let dim = 1 - min(0.62, max(0, distance - 1) * 0.15)
        let leaving = min(max((Double(span) + 0.6 - distance) / 0.6, 0), 1)
        return dim * leaving
    }

    /// The rungs in the window at `position`, nearest the top first.
    func visibleLevels(at position: Double) -> [Level] {
        let nearest = Int(position.rounded())
        return ((nearest - span - 1) ... (nearest + span + 1)).compactMap { index in
            guard let level = Level(index), abs(Double(index) - position) < Double(span) + 0.6 else { return nil }
            return level
        }
    }

    /// The level whose row is at height `y`, at `position`.
    func level(atY y: CGFloat, position: Double) -> Level? {
        Level(Int((position + Double(offset(atY: y))).rounded()))
    }

    // MARK: The spine

    /// The y of a rung on the spine (fractional positions lie between ticks).
    func spineY(_ level: Double) -> CGFloat {
        spineTop + (spineBottom - spineTop) * CGFloat(level) / CGFloat(Level.count - 1)
    }

    /// The scale position at height `y` of the spine, kept on the ladder.
    func spinePosition(atY y: CGFloat) -> Double {
        let position = Double((y - spineTop) / (spineBottom - spineTop)) * Double(Level.count - 1)
        return min(max(position, 0), Double(Level.count - 1))
    }

    /// The strip that scrubs: the spine with its letters and its bracket.
    var spineHitFrame: CGRect {
        CGRect(x: spineX - 30, y: spineTop - 12, width: 48, height: spineBottom - spineTop + 24)
    }

    /// The part of the screen that turns the wheel: the rows, left of the spine.
    var wheelHitFrame: CGRect {
        let top = rowY(offset: -CGFloat(span)) - 24
        let bottom = rowY(offset: CGFloat(span)) + 24
        let left: CGFloat = layout == .desktop ? 100 : 0
        return CGRect(x: left, y: top, width: spineHitFrame.minX - left, height: bottom - top)
    }

    /// The focused row, for its accessibility element.
    var focusFrame: CGRect {
        CGRect(x: rimX - 24, y: focusY - 62, width: columns.ruleEnd - rimX + 30, height: 136)
    }
}
