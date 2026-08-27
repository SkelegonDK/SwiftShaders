import XCTest
import SwiftUI
import UniformTypeIdentifiers
import SwiftShadersGalleryCore

/// Scratch tool for the wayfinder catalog-example sweep (ticket 07): renders
/// every non-user-named catalogue entry on the gallery's default stage (card
/// sample, checkerboard backdrop) into labelled contact sheets for visual
/// review. Skips itself unless CATALOG_SWEEP_DUMP_DIR is set, so it never
/// runs as part of the normal suite.
@available(macOS 14.0, *)
@MainActor
final class CatalogExampleSweepDumpTests: XCTestCase {

    /// The 24 user-named entries with their own diagnosis tickets (09–32).
    private let excluded: Set<String> = [
        "earthquakeDisplacement", "solarize", "posterize", "chromaticAberration",
        "xray", "halftone", "emboss", "sketchPencil", "sketchCrossHatch",
        "sketchInk", "vhsGlitch", "digitalCorruption", "negativeFilm",
        "wireframeHologram", "motionBlur", "tiltShift", "lavaEffect",
        "noiseEffect", "infiniteGrid", "volumetricClouds", "rain", "snow",
        "bubbles", "confetti",
    ]

    func testDumpContactSheets() throws {
        guard let dir = ProcessInfo.processInfo.environment["CATALOG_SWEEP_DUMP_DIR"] else {
            throw XCTSkip("Set CATALOG_SWEEP_DUMP_DIR to dump the sweep sheets.")
        }
        try FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true)

        // 67 at the time of the resolved sweep (91 − 24 excluded); the catalogue
        // has since shrunk, so the count is not pinned.
        let entries = EffectCatalog.all.filter { !excluded.contains($0.id) }

        let time = 1.7
        var cells: [(label: String, view: AnyView)] = [
            ("CONTROL — no effect", AnyView(SampleElement.card.view))
        ]
        for effect in entries {
            let built = effect.build(
                AnyView(SampleElement.card.view),
                ParamValues(effect.params),
                effect.animated ? time : 0
            )
            let suffix = effect.animated ? "  [anim t=1.7]" : ""
            cells.append(("\(effect.id)\(suffix)", built))
        }

        let perSheet = 9
        var sheet = 0
        var index = 0
        while index < cells.count {
            let chunk = Array(cells[index..<min(index + perSheet, cells.count)])
            index += perSheet
            sheet += 1
            let image = try render(sheetView(chunk))
            try write(image, to: "\(dir)/sheet-\(String(format: "%02d", sheet)).png")
        }
        print("CatalogExampleSweepDump: wrote \(sheet) sheets covering \(cells.count) cells to \(dir)")
    }

    private func sheetView(_ chunk: [(label: String, view: AnyView)]) -> AnyView {
        let columns = 3
        var rows: [[(label: String, view: AnyView)]] = []
        var i = 0
        while i < chunk.count {
            rows.append(Array(chunk[i..<min(i + columns, chunk.count)]))
            i += columns
        }
        return AnyView(
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 0) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            VStack(spacing: 6) {
                                Text(cell.label)
                                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.black)
                                ZStack {
                                    Checkerboard().opacity(0.35)
                                    cell.view
                                }
                                .frame(width: 380, height: 280)
                                .clipped()
                                .border(.black.opacity(0.4))
                            }
                            .padding(8)
                        }
                    }
                }
            }
            .padding(8)
            .background(Color(white: 0.85))
        )
    }

    private func render(_ view: AnyView) throws -> CGImage {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return try XCTUnwrap(renderer.cgImage, "ImageRenderer produced no image.")
    }

    private func write(_ image: CGImage, to path: String) throws {
        let url = URL(fileURLWithPath: path)
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination), "Could not write \(path)")
    }
}

/// The gallery's backdrop, replicated from ContentView (where it is private).
private struct Checkerboard: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 16
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.gray.opacity(0.10)))
            var y: CGFloat = 0
            var row = 0
            while y < size.height {
                var x: CGFloat = (row % 2 == 0) ? 0 : step
                while x < size.width {
                    context.fill(
                        Path(CGRect(x: x, y: y, width: step, height: step)),
                        with: .color(.gray.opacity(0.18))
                    )
                    x += step * 2
                }
                y += step
                row += 1
            }
        }
    }
}

@available(macOS 14.0, *)
@MainActor
final class CatalogExampleSweepMeasureTests: XCTestCase {

    /// Sum-of-absolute-differences of every entry at its defaults against the
    /// unshaded card, printed sorted — the card-sample analogue of the
    /// quadrant-source measurement in GalleryRenderSweepTests.
    func testMeasureCardVisibility() throws {
        guard ProcessInfo.processInfo.environment["CATALOG_SWEEP_DUMP_DIR"] != nil else {
            throw XCTSkip("Set CATALOG_SWEEP_DUMP_DIR to run the measurement.")
        }
        let control = try pixels(AnyView(SampleElement.card.view))
        var scores: [(id: String, sad: Int)] = []
        for effect in EffectCatalog.all {
            let built = effect.build(
                AnyView(SampleElement.card.view),
                ParamValues(effect.params),
                effect.animated ? 1.7 : 0
            )
            let p = try pixels(built)
            let sad = p.count == control.count
                ? zip(p, control).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
                : -1
            scores.append((effect.id, sad))
        }
        for s in scores.sorted(by: { $0.sad < $1.sad }) {
            print("CARDSAD \(s.sad)\t\(s.id)")
        }
    }

    private func pixels(_ view: AnyView) throws -> [UInt8] {
        let renderer = ImageRenderer(content: AnyView(view.frame(width: 380, height: 280)))
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.cgImage)
        var buffer = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = try XCTUnwrap(CGContext(
            data: &buffer, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return buffer
    }
}
