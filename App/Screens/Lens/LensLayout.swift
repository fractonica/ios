import CoreGraphics

/// Where everything on the LENS is (DESIGN.md §7, "Lens").
///
/// Phone, as designed: title block left (x 20), ring centre (268, 188) R 54,
/// lineage strip y 356, data rows from y 414 at pitch 25, media rows from
/// y 573 at pitch 21.5, straight limb y 742. The desktop arrangement puts the
/// title, a larger ring, the lineage and the limb in the left half and the
/// rows and the media in a column on the right.
struct LensLayout: Equatable, Sendable {
    let layout: LayoutClass

    // The title block.
    let titleX: CGFloat
    let titleY: CGFloat
    /// Baseline and size of the level's letter.
    let letter: CGPoint
    let letterSize: CGFloat
    /// Baselines of the name, the kind line and the epithet.
    let nameY: CGFloat
    let nameSize: CGFloat
    let kindY: CGFloat
    let epithetY: CGFloat

    // The ring.
    let ringCenter: CGPoint
    let ringRadius: CGFloat
    /// Sizes around the ring: the threshold glyphs' unit, the words, the values.
    let thresholdGlyphUnit: CGFloat
    let thresholdWordSize: CGFloat
    let thresholdValueSize: CGFloat

    // The lineage: the row of the exact prefix, then the strip of seals.
    let lineageLeft: CGFloat
    let lineageRight: CGFloat
    let prefixY: CGFloat
    let lineageY: CGFloat
    /// x of the first seal, distance between seals, how many fit.
    let sealX: CGFloat
    let sealPitch: CGFloat
    let sealCount: Int

    // The data rows and the media.
    let rowsLeft: CGFloat
    let rowsRight: CGFloat
    let rowsY: CGFloat
    let rowPitch: CGFloat
    /// Rows that fit above the media.
    let maxRows: Int
    let mediaY: CGFloat
    let mediaRowsY: CGFloat
    let mediaPitch: CGFloat
    /// The logarithmic rule of the media: from x to x.
    let ruleStart: CGFloat
    let ruleEnd: CGFloat

    // The straight limb.
    let limb: CGPoint
    let limbSpan: Int
    /// The first machining mark of the plate, outside the ring's labels.
    let plateRadius: CGFloat

    static let phone = LensLayout(
        layout: .phone,
        titleX: 20, titleY: 85, letter: CGPoint(x: 17, y: 180), letterSize: 78,
        nameY: 214, nameSize: 15, kindY: 232, epithetY: 244,
        ringCenter: CGPoint(x: 268, y: 188), ringRadius: 54,
        thresholdGlyphUnit: 2.3, thresholdWordSize: 6.8, thresholdValueSize: 9.5,
        lineageLeft: 20, lineageRight: 373, prefixY: 322, lineageY: 356,
        sealX: 34, sealPitch: 325.0 / 6, sealCount: 7,
        rowsLeft: 20, rowsRight: 373, rowsY: 414, rowPitch: 25, maxRows: 5,
        mediaY: 551, mediaRowsY: 573, mediaPitch: 21.5, ruleStart: 176, ruleEnd: 284,
        limb: CGPoint(x: 196.5, y: 742), limbSpan: 4, plateRadius: 112
    )

    static let desktop = LensLayout(
        layout: .desktop,
        titleX: 132, titleY: 58, letter: CGPoint(x: 128, y: 198), letterSize: 104,
        nameY: 238, nameSize: 17, kindY: 258, epithetY: 271,
        ringCenter: CGPoint(x: 476, y: 232), ringRadius: 78,
        thresholdGlyphUnit: 3.1, thresholdWordSize: 7.5, thresholdValueSize: 11,
        lineageLeft: 132, lineageRight: 650, prefixY: 432, lineageY: 474,
        sealX: 148, sealPitch: 54, sealCount: 10,
        rowsLeft: 720, rowsRight: 1210, rowsY: 150, rowPitch: 29, maxRows: 7,
        mediaY: 400, mediaRowsY: 428, mediaPitch: 26, ruleStart: 906, ruleEnd: 1036,
        limb: CGPoint(x: 391, y: 690), limbSpan: 5, plateRadius: 160
    )

    static func standard(_ layout: LayoutClass) -> LensLayout {
        layout == .desktop ? .desktop : .phone
    }

    /// The ring's scale against the design's R 54: its offsets grow with it.
    var ringScale: CGFloat { ringRadius / 54 }

    // MARK: Frames (accessibility elements, the swipe-down area)

    var titleFrame: CGRect {
        CGRect(x: titleX, y: titleY - 12, width: layout == .desktop ? 230 : 150, height: epithetY - titleY + 22)
    }

    var ringFrame: CGRect {
        let reach = ringRadius * 2
        return CGRect(x: ringCenter.x - reach, y: ringCenter.y - reach, width: 2 * reach, height: 2 * reach)
    }

    var lineageFrame: CGRect {
        CGRect(x: lineageLeft, y: prefixY - 12, width: lineageRight - lineageLeft, height: lineageY - prefixY + 44)
    }

    func rowFrame(_ index: Int) -> CGRect {
        CGRect(x: rowsLeft, y: rowsY + CGFloat(index) * rowPitch - rowPitch + 10, width: rowsRight - rowsLeft, height: rowPitch)
    }

    var mediaFrame: CGRect {
        CGRect(x: rowsLeft, y: mediaY - 12, width: rowsRight - rowsLeft, height: mediaRowsY - mediaY + 7 * mediaPitch)
    }

    /// Everything above the limb: a swipe down anywhere here closes the lens.
    var swipeFrame: CGRect {
        let size = layout.designSize
        let left: CGFloat = layout == .desktop ? 100 : 0
        return CGRect(x: left, y: 110, width: size.width - left, height: limb.y - 150)
    }
}
