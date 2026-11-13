import SwiftUI

/// The mapping between the design's coordinates and the view's.
///
/// Every screen is drawn in the fixed coordinates of DESIGN.md §7 (393 × 852
/// for the phone, 1280 × 800 for the desktop) and the whole drawing is scaled
/// uniformly to fit the view and centred. `RootView` computes one of these
/// from its size and puts it in the environment; nothing else measures the
/// screen.
///
/// - Drawing: `DesignCanvas { ink in … }` hands you an ``Ink`` already in
///   design coordinates.
/// - Hit areas and accessibility elements: `.designFrame(rect)` places any
///   view on a rectangle given in design coordinates.
/// - Gestures: ``designPoint(_:)`` converts a location in the full-size view
///   back to design coordinates.
struct DesignSpace: Equatable, Sendable {
    let layout: LayoutClass
    /// The size of the view the design is fitted into.
    let viewSize: CGSize
    /// View points per design point.
    let scale: CGFloat
    /// Where the design's (0, 0) falls in the view.
    let origin: CGPoint

    /// The design's own size (393 × 852 or 1280 × 800).
    var designSize: CGSize { layout.designSize }

    /// The smallest engraved word on a phone, in view points (DESIGN.md §3:
    /// "never smaller than 6.2 pt on phone").
    static let phoneEngravedMinimum: CGFloat = 6.2

    /// The engraved size, in design points, under which no engraved word is
    /// set: where the phone design is drawn smaller than designed (a 375 ×
    /// 667 iPhone SE), its smallest words grow back to 6.2 view points
    /// instead of shrinking with it. 0 where nothing needs it.
    var engravedFloor: CGFloat {
        layout == .phone && scale < 1 ? DesignSpace.phoneEngravedMinimum / scale : 0
    }

    /// Fits the design of `layout` (or of the class that suits `viewSize`)
    /// into a view.
    ///
    /// The desktop design is scaled uniformly to fit and centred. The phone
    /// design carries its own safe bands (59 pt at the top, 34 at the
    /// bottom: an iPhone 16 Pro's), with nothing drawn in them. When the whole
    /// design fits the view at the scale its content needs, it is centred
    /// whole, as before; when it does not (a 375 × 667 iPhone SE: a 20 pt
    /// status bar, no home indicator), the bands the device does not need are
    /// given back: the content between them is fitted into the view's own
    /// safe area and the bands run off its edges.
    /// - Parameter safeArea: the view's safe-area insets (zero in a snapshot).
    init(viewSize: CGSize, layout: LayoutClass? = nil, safeArea: EdgeInsets = EdgeInsets()) {
        let layout = layout ?? .fitting(viewSize)
        let design = layout.designSize
        let bands = layout.safeBands
        let content = design.height - bands.top - bands.bottom
        let available = viewSize.height - safeArea.top - safeArea.bottom
        let whole = min(viewSize.width / design.width, viewSize.height / design.height)
        let byContent = min(viewSize.width / design.width, available / content)
        var scale = layout == .phone ? max(whole, byContent) : whole
        if !scale.isFinite || scale <= 0 { scale = 1 }
        self.layout = layout
        self.viewSize = viewSize
        self.scale = scale
        let x = (viewSize.width - design.width * scale) / 2
        if design.height * scale <= viewSize.height + 0.5 {
            origin = CGPoint(x: x, y: (viewSize.height - design.height * scale) / 2)
        } else {
            // The content centred in the safe area; the bands overflow.
            let top = safeArea.top + (available - content * scale) / 2
            origin = CGPoint(x: x, y: top - bands.top * scale)
        }
    }

    /// A design rectangle in view coordinates.
    func viewRect(_ rect: CGRect) -> CGRect {
        CGRect(
            x: origin.x + rect.minX * scale, y: origin.y + rect.minY * scale,
            width: rect.width * scale, height: rect.height * scale
        )
    }

    /// A view location in design coordinates.
    func designPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: (point.x - origin.x) / scale, y: (point.y - origin.y) / scale)
    }

    /// The transform that takes design coordinates to view coordinates.
    var transform: CGAffineTransform {
        CGAffineTransform(translationX: origin.x, y: origin.y).scaledBy(x: scale, y: scale)
    }
}

private struct DesignSpaceKey: EnvironmentKey {
    static let defaultValue = DesignSpace(viewSize: LayoutClass.phone.designSize, layout: .phone)
}

extension EnvironmentValues {
    /// The design-to-view mapping of the screen being shown.
    var designSpace: DesignSpace {
        get { self[DesignSpaceKey.self] }
        set { self[DesignSpaceKey.self] = newValue }
    }
}

// MARK: - Placing views in design coordinates

private struct DesignFrame: ViewModifier {
    @Environment(\.designSpace) private var space
    let rect: CGRect

    func body(content: Content) -> some View {
        let frame = space.viewRect(rect)
        content
            .frame(width: max(frame.width, 0), height: max(frame.height, 0))
            .position(x: frame.midX, y: frame.midY)
    }
}

extension View {
    /// Places the view on a rectangle given in design coordinates. Use it for
    /// hit areas and accessibility elements laid over a drawing; the parent
    /// must fill the screen (a `ZStack` inside `RootView`).
    ///
    /// **Order matters**: the placed view fills its parent, so accessibility
    /// modifiers and a `Button`'s label must come BEFORE this modifier, and a
    /// gesture attached after it reports locations of the whole screen
    /// (convert them with ``DesignSpace/designPoint(_:)``).
    func designFrame(_ rect: CGRect) -> some View {
        modifier(DesignFrame(rect: rect))
    }

    /// The same for a square of side `2 × radius` centred on a design point.
    func designFrame(center: CGPoint, radius: CGFloat) -> some View {
        designFrame(CGRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius))
    }
}
