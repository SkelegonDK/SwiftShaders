import XCTest
import SwiftUI
import SwiftShadersGalleryCore

/// Renders every entry in the Gallery catalogue and looks at the result.
///
/// The binding tests prove each call site's arguments have the right count and
/// types; `ShaderRenderingTests` proves one shader receives the right *values*.
/// Neither says anything about the other 90 entries, and the failure mode this
/// package actually had is invisible to both: a shader whose arguments are
/// well-typed but shifted renders the view **pure black**, not "slightly wrong"
/// (Phase 3 measured it). A user sees a black rectangle; every test stays green.
///
/// So this sweep asserts two things per entry, and they catch different faults:
///
/// - the output **differs from the unshaded control** — the effect did something;
/// - the output **is not one flat colour** — it did not swallow the view. Pure
///   black passes the first check easily, which is why the second exists.
///
/// The source view is deliberately structured in both axes so that a legitimate
/// effect cannot flatten it by accident: a diagonal four-stop gradient with an
/// opaque disc on top.
@available(macOS 14.0, iOS 17.0, *)
@MainActor
final class GalleryRenderSweepTests: XCTestCase {

    private let side = 48

    /// Animated entries are rendered at a fixed non-zero time. Zero is a bad
    /// choice: several shaders multiply by `time` and are identity at t = 0.
    private let time: Double = 1.7

    func testEveryCatalogueEntryRendersSomethingVisible() throws {
        let control = try render(source)
        XCTAssertFalse(
            control.isFlat,
            "The unshaded control is already one flat colour, so the sweep proves nothing."
        )

        var blank: [String] = []
        var inert: [String] = []
        var neededMidRange: [String] = []

        for effect in EffectCatalog.all {
            var pixels = try render(effect.build(AnyView(source), ParamValues(effect.params), time))

            // An effect may legitimately be a no-op at its defaults (a strength
            // that defaults to 0, a progress that defaults to the start). Retry
            // with each slider at the middle of its own declared range before
            // calling it inert.
            if pixels.matches(control) {
                pixels = try render(effect.build(AnyView(source), midRange(of: effect), time))
                if !pixels.matches(control) { neededMidRange.append(effect.id) }
            }

            if pixels.isFlat {
                blank.append("\(effect.id) renders as one flat colour (\(pixels.colour(x: 1, y: 1)))")
            } else if pixels.matches(control) {
                inert.append("\(effect.id) renders identically to the unshaded view")
            }
        }

        if !neededMidRange.isEmpty {
            // Not a failure — but the gallery opens on the defaults, so these
            // entries show nothing until the user moves a slider.
            print("GalleryRenderSweep: no-ops at their defaults, visible at mid-range: "
                  + neededMidRange.sorted().joined(separator: ", "))
        }

        XCTAssertEqual(
            blank, [],
            "Catalogue entries that render as a solid colour — the classic symptom of a shader "
            + "receiving shifted arguments:\n" + blank.joined(separator: "\n")
        )
        XCTAssertEqual(
            inert, [],
            "Catalogue entries that change nothing, even at mid-range parameters:\n"
            + inert.joined(separator: "\n")
        )
    }

    /// Times to sample an animated entry at.
    ///
    /// Four, irregularly spaced and deliberately not round: two timestamps is
    /// not enough. `filmGrain` uses `fract(time * 100)`, which is exactly 0 for
    /// *every* time with two decimal places, and `wireframeHologram`'s
    /// `sin(time * 3)` happened to land within a rounding error of itself at the
    /// first pair tried. Both looked frozen and neither is.
    private let sampleTimes: [Double] = [0.3137, 1.2711, 2.7183, 4.1892]

    /// Animated entries must actually depend on their time argument, or the
    /// gallery's `TimelineView` is driving a still image.
    ///
    /// This exercises the *gallery's* path, where time is an explicit argument
    /// the catalogue passes. Whether the library's self-animating modifiers
    /// advance is a separate question, and 7b's.
    /// Entries that take a `time:` argument and provably ignore it, with the
    /// reason each does. Every one was measured, not assumed: the rendered bytes
    /// are *identical* at all four sample times, so these are not
    /// under-sensitivity of the probe.
    ///
    /// None of the fixes belong to 7a — the first two need a decision about the
    /// Metal function's signature, the third is a shader bug — so they are
    /// recorded here rather than papered over. **Removing an entry from this set
    /// is the fix.**
    static let knownTimeIndependentEntries: Set<String> = [
        // `VoronoiShader.metal:263` — declares `float time` and then calls
        // `voronoiF1F2(uv, scale, 0.0, 1.0)`: "Static voronoi for consistent
        // cracks". The argument is accepted and discarded.
        "voronoiShattered",
        // `VoronoiShader.metal:541` — the same, "Static cells for consistent
        // glass panes".
        "voronoiStainedGlass",
        // `RaymarchingShader.metal:464` — this one is a bug, not a decision. The
        // grid is the only time-dependent term, and it never draws: its
        // antialiasing divides by `fwidth(p.xz / gridSize)`, which comes out
        // small enough here that `line` always exceeds the smoothstep's upper
        // edge and `gridIntensity` is 0 everywhere. What renders is the static
        // horizon glow alone.
        "infiniteGrid",
    ]

    func testEveryAnimatedEntryDependsOnItsTimeArgument() throws {
        var frozen: [String] = []

        for effect in EffectCatalog.all
        where effect.animated && !Self.knownTimeIndependentEntries.contains(effect.id) {
            let values = midRange(of: effect)
            let frames = try sampleTimes.map { try render(effect.build(AnyView(source), values, $0)) }
            if frames.dropFirst().allSatisfy({ $0.matches(frames[0]) }) {
                frozen.append(effect.id)
            }
        }

        XCTAssertEqual(
            frozen, [],
            "Animated entries that render identically at \(sampleTimes.count) different times:\n"
            + frozen.joined(separator: "\n")
        )
    }

    /// The allowlist above must stay a list of *real* offenders. If one of them
    /// starts animating, the entry comes off the list — otherwise the list slowly
    /// becomes a place where working effects go to stop being checked.
    func testTheTimeIndependentAllowlistIsStillAccurate() throws {
        var nowAnimating: [String] = []

        for id in Self.knownTimeIndependentEntries.sorted() {
            let effect = try XCTUnwrap(EffectCatalog.effect(id: id), "\(id) is no longer catalogued")
            let values = midRange(of: effect)
            let frames = try sampleTimes.map { try render(effect.build(AnyView(source), values, $0)) }
            if !frames.dropFirst().allSatisfy({ $0.matches(frames[0]) }) { nowAnimating.append(id) }
        }

        XCTAssertEqual(
            nowAnimating, [],
            "These now depend on their time argument — remove them from "
            + "knownTimeIndependentEntries: \(nowAnimating)"
        )
    }

    // MARK: - Inputs

    /// Every slider at the middle of its declared range.
    private func midRange(of effect: Effect) -> ParamValues {
        var values = ParamValues(effect.params)
        for (index, param) in effect.params.enumerated() {
            values[index] = (param.range.lowerBound + param.range.upperBound) / 2
        }
        return values
    }

    private var source: AnyView {
        AnyView(
            LinearGradient(
                colors: [.black, .blue, .orange, .white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                Circle()
                    .fill(Color(red: 0.1, green: 0.9, blue: 0.3))
                    .frame(width: CGFloat(side) / 3)
            )
            .frame(width: CGFloat(side), height: CGFloat(side))
        )
    }

    // MARK: - Rendering

    private func render(_ view: AnyView) throws -> Bitmap {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.cgImage, "ImageRenderer produced no image.")
        return try Bitmap(image)
    }

    struct Bitmap {
        let width: Int
        let height: Int
        fileprivate let bytes: [UInt8]

        init(_ image: CGImage) throws {
            width = image.width
            height = image.height
            var buffer = [UInt8](repeating: 0, count: width * height * 4)
            let context = CGContext(
                data: &buffer,
                width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
            guard let context else { throw NSError(domain: "GalleryRenderSweepTests", code: 1) }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            bytes = buffer
        }

        func colour(x: Int, y: Int) -> Colour {
            let offset = (y * width + x) * 4
            return Colour(r: bytes[offset], g: bytes[offset + 1], b: bytes[offset + 2], a: bytes[offset + 3])
        }

        /// Every sampled pixel the same — a solid rectangle, transparent or not.
        /// This is what a shader reading shifted arguments produces.
        var isFlat: Bool {
            let first = colour(x: 0, y: 0)
            return probes.allSatisfy { colour(x: $0.x, y: $0.y).isClose(to: first) }
        }

        /// Byte-exact, over every pixel.
        ///
        /// "Did this shader change anything?" is a yes/no question, and both
        /// bitmaps come from the same renderer in the same process, so there is
        /// no cross-release rasterisation drift to absorb — only the shader's own
        /// arithmetic. A coarse lattice with a generous tolerance was tried first
        /// and called three effects inert that are merely subtle: a one-pixel
        /// chromatic shift across a smooth gradient moves each channel by less
        /// than the tolerance nearly everywhere.
        func matches(_ other: Bitmap) -> Bool {
            width == other.width && height == other.height && bytes == other.bytes
        }

        /// A coarse lattice is enough to tell a solid rectangle from a picture.
        private var probes: [(x: Int, y: Int)] {
            stride(from: 1, to: width, by: 5).flatMap { x in
                stride(from: 1, to: height, by: 5).map { (x: x, y: $0) }
            }
        }
    }

    struct Colour: CustomStringConvertible, Equatable {
        let r, g, b, a: UInt8
        var description: String { "rgba(\(r), \(g), \(b), \(a))" }

        func isClose(to other: Colour, tolerance: Int = 6) -> Bool {
            abs(Int(r) - Int(other.r)) <= tolerance
                && abs(Int(g) - Int(other.g)) <= tolerance
                && abs(Int(b) - Int(other.b)) <= tolerance
                && abs(Int(a) - Int(other.a)) <= tolerance
        }
    }
}
