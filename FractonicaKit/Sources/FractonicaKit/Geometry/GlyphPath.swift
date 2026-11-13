import CFractonica

// The outline of a phase glyph (SPEC §9.1), exactly as the core emits it:
// integer coordinates in HUNDREDTHS of a design unit, x right, y down, the
// stem starting at the origin and running down 3 units per stroke.
//
// For SwiftUI / Core Graphics use `Glyph.outline(unit:origin:)` in
// GlyphPath+CoreGraphics.swift; this file is the platform-free form.

/// A point of a glyph outline, in hundredths of a design unit (y down).
public struct GlyphPoint: Hashable, Sendable {
    public let x: Int
    public let y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    /// Point `index` of the coordinate list a path command carries.
    init(_ coordinates: UnsafePointer<Int16>, at index: Int) {
        x = Int(coordinates[2 * index])
        y = Int(coordinates[2 * index + 1])
    }
}

/// One command of a glyph outline (`frc_path_op_t`).
public enum GlyphPathElement: Hashable, Sendable {
    /// Start a new stroked line here.
    case move(to: GlyphPoint)
    /// A straight line from the current point.
    case line(to: GlyphPoint)
    /// A cubic Bézier from the current point.
    case cubic(control1: GlyphPoint, control2: GlyphPoint, to: GlyphPoint)
    /// A **filled** circle (the dot of the falling branch). Not part of the
    /// stroked line.
    case dot(center: GlyphPoint, radius: Int)
}

/// The ink bounds of a glyph, in hundredths of a design unit. They depend on
/// the stroke count only, never on the value, so a row of glyphs does not jump.
public struct GlyphBounds: Hashable, Sendable {
    public let minX: Int
    public let minY: Int
    public let maxX: Int
    public let maxY: Int

    public init(minX: Int, minY: Int, maxX: Int, maxY: Int) {
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
    }
}

/// One straight piece of a flattened glyph, in hundredths of a design unit.
public struct GlyphSegment: Hashable, Sendable {
    public let from: GlyphPoint
    public let to: GlyphPoint

    public init(from: GlyphPoint, to: GlyphPoint) {
        self.from = from
        self.to = to
    }
}

extension Glyph {
    /// Coordinate units per design unit, 100 (`FRC_GLYPH_UNIT`).
    public static let unitsPerDesignUnit = Int(FRC_GLYPH_UNIT)
    /// Stroke thickness in the same units, 30 = 0.3 u (`FRC_GLYPH_INK`).
    /// Round caps and joins.
    public static let inkThickness = Int(FRC_GLYPH_INK)
    /// Radius of the dot in the same units, 30 (`FRC_GLYPH_DOT_RADIUS`).
    public static let dotRadius = Int(FRC_GLYPH_DOT_RADIUS)

    /// The outline as the core lists it (`frc_glyph_path`): the stem, one
    /// stroke per trit, then the dot if the glyph has one.
    public var path: [GlyphPathElement] {
        var elements: [GlyphPathElement] = []
        var raw = self.raw
        withUnsafeMutablePointer(to: &elements) { context in
            frc_glyph_path(&raw, { context, operation, coordinates in
                guard let context, let coordinates else { return }
                let elements = context.assumingMemoryBound(to: [GlyphPathElement].self)
                switch operation {
                case FRC_PATH_MOVE:
                    elements.pointee.append(.move(to: GlyphPoint(coordinates, at: 0)))
                case FRC_PATH_LINE:
                    elements.pointee.append(.line(to: GlyphPoint(coordinates, at: 0)))
                case FRC_PATH_CUBIC:
                    elements.pointee.append(.cubic(
                        control1: GlyphPoint(coordinates, at: 0),
                        control2: GlyphPoint(coordinates, at: 1),
                        to: GlyphPoint(coordinates, at: 2)
                    ))
                case FRC_PATH_DOT:
                    elements.pointee.append(.dot(
                        center: GlyphPoint(coordinates, at: 0), radius: Int(coordinates[2])
                    ))
                default:
                    break
                }
            }, context)
        }
        return elements
    }

    /// The same glyph flattened to straight segments (`frc_glyph_segments`),
    /// each curve cut into `curveSteps` pieces (1...32). The dot is not
    /// included: draw it from ``path`` or at the core's dot position.
    public func segments(curveSteps: Int = 8) -> [GlyphSegment] {
        var segments: [GlyphSegment] = []
        var raw = self.raw
        withUnsafeMutablePointer(to: &segments) { context in
            frc_glyph_segments(&raw, UInt8(clamping: curveSteps), { context, x0, y0, x1, y1 in
                guard let context else { return }
                context.assumingMemoryBound(to: [GlyphSegment].self).pointee.append(GlyphSegment(
                    from: GlyphPoint(x: Int(x0), y: Int(y0)), to: GlyphPoint(x: Int(x1), y: Int(y1))
                ))
            }, context)
        }
        return segments
    }

    /// Ink bounds of any glyph of `strokes` strokes (`frc_glyph_bounds`):
    /// x −215...215, y −220...(300 × strokes + 15). All zero for an invalid
    /// stroke count.
    public static func bounds(strokes: Int) -> GlyphBounds {
        var minX: Int16 = 0, minY: Int16 = 0, maxX: Int16 = 0, maxY: Int16 = 0
        frc_glyph_bounds(UInt8(clamping: strokes), &minX, &minY, &maxX, &maxY)
        return GlyphBounds(minX: Int(minX), minY: Int(minY), maxX: Int(maxX), maxY: Int(maxY))
    }

    /// Ink bounds of this glyph.
    public var bounds: GlyphBounds { Glyph.bounds(strokes: strokes) }
}
