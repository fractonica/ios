import SwiftUI
import FractonicaKit

/// The app icon, drawn by the instrument itself: `--icon <directory>` writes
/// the two master pictures there and exits (Tools/icon.sh then cuts the sizes
/// of `App/Resources/Assets.xcassets/AppIcon.appiconset` from them).
///
///     icon-ios.png   1024 × 1024, full bleed, no alpha (iOS masks it itself)
///     icon-mac.png   1024 × 1024, the plate as a rounded square inside the
///                    margins a Mac icon keeps, on a transparent ground
///
/// The picture is the hero ring of a Helion on the plate: the same
/// `InstrumentRenderer`, bare (no orrery, no words), reading SPEC vector A
/// from the core unless `--t` says otherwise. Nothing in it is invented: the
/// arcs lit, the beads and the two glyphs are that instant's.
@MainActor
enum IconRenderer {
    /// The icon's side in pixels.
    static let side: CGFloat = 1024

    static func run(_ arguments: LaunchArguments, directory: String) -> Int32 {
        let folder = URL(fileURLWithPath: directory, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            print("icon: cannot create \(folder.path): \(error.localizedDescription)")
            return 1
        }
        let instant = arguments.frozenInstant ?? Instant(unixSeconds: SnapshotRunner.vectorA) ?? .now
        let reading = InstrumentReading.read(.saros141, at: instant, focus: .helion, depth: 2)
        let theme = Theme.named(arguments.themeName)
        var failures = 0
        for (name, rounded) in [("icon-ios.png", false), ("icon-mac.png", true)] {
            let content = IconView(reading: reading, theme: theme, rounded: rounded)
                .frame(width: side, height: side)
            let renderer = ImageRenderer(content: content)
            renderer.proposedSize = ProposedViewSize(width: side, height: side)
            let size = CGSize(width: side, height: side)
            guard let image = SnapshotRunner.rasterize(renderer, size: size, scale: 1, opaque: !rounded),
                  SnapshotRunner.write(image, to: folder.appendingPathComponent(name))
            else {
                failures += 1
                continue
            }
        }
        return failures == 0 ? 0 : 1
    }
}

/// The icon as a view: the plate, its machining marks and the bare ring.
private struct IconView: View {
    let reading: InstrumentReading
    let theme: Theme
    /// A Mac icon carries its own shape: a rounded square inside a margin.
    let rounded: Bool

    /// The drawing's own box, in the instrument's points: the ring is drawn
    /// at R 44 with the phone's line weights, so that the hero line is still
    /// a line when the icon is 60 points wide.
    private static let box: CGFloat = 150
    private static let ringRadius: CGFloat = 44

    var body: some View {
        let reading = reading, theme = theme, rounded = rounded
        Canvas { context, size in
            // The proportions of Apple's Mac icon grid: 824 of 1024, corners 185.
            let inset = rounded ? size.width * 100 / 1024 : 0
            let side = size.width - 2 * inset
            let plate = Path(
                roundedRect: CGRect(x: inset, y: inset, width: side, height: side),
                cornerRadius: rounded ? side * 185 / 824 : 0, style: .continuous
            )
            context.clip(to: plate)
            context.fill(plate, with: .color(theme.palette.void))
            let scale = side / IconView.box
            context.translateBy(x: inset, y: inset)
            context.scaleBy(x: scale, y: scale)
            var ink = Ink(context: context, theme: theme, layout: .phone, pixelsPerPoint: scale,
                          pixelOrigin: CGPoint(x: inset, y: inset))
            let center = CGPoint(x: IconView.box / 2, y: IconView.box / 2)
            // The plate: the whole icon is its bright centre.
            ink.circle(center, radius: IconView.box, fill: theme.palette.plate)
            PlateRenderer.draw(center: center, firstRadius: IconView.ringRadius * 1.37, in: &ink)
            let metrics = InstrumentMetrics.inspector(center: center, radius: IconView.ringRadius)
            InstrumentRenderer.draw(reading, geometry: InstrumentGeometry(metrics: metrics, focus: reading.focus), in: &ink)
        }
    }
}
