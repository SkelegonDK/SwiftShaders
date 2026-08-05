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
/// So the sweep asserts two things per entry, and they catch different faults:
///
/// - the output **differs from the unshaded control** — the effect did something;
/// - the output **is not one flat colour** — it did not swallow the view. Pure
///   black passes the first check easily, which is why the second exists.
///
/// ## The source view, and why it has no gradient
///
/// The first version previewed effects over a four-stop `LinearGradient`. That
/// made the sweep unable to fail: `ImageRenderer` renders a dithered gradient
/// slightly differently depending on what was rendered before it, and the
/// resulting noise — 491 in the sum-of-absolute-differences used below — was
/// larger than several real effects. A negative control that replaced an entry's
/// closure with the identity stayed green.
///
/// Four flat quadrants and a disc dither nothing: the same measurement over the
/// same 30 interleaved renders drops from 491 to **2**, while the weakest real
/// effect in the catalogue scores 806. Hard edges also make displacement effects
/// far more visible than a smooth ramp does.
@available(macOS 14.0, iOS 17.0, *)
@MainActor
final class GalleryRenderSweepTests: XCTestCase {

    private let side = 48

    /// How far two renders must be apart to count as different, as a sum of
    /// absolute byte differences over the whole image.
    ///
    /// 64× the measured renderer noise (2) and a sixth of the weakest real
    /// effect (806), so there is a wide margin on both sides.
    /// `testTheRendererIsQuietEnoughForTheSweepToMeanAnything` asserts the noise
    /// is really that small, so this number cannot quietly stop separating them.
    private let changeThreshold = 128

    // MARK: - The sweep

    func testEveryCatalogueEntryRendersSomethingVisible() throws {
        let control = try render(source)
        XCTAssertFalse(
            control.isFlat,
            "The unshaded control is already one flat colour, so the sweep proves nothing."
        )

        var blank: [String] = []
        var inert: [String] = []
        var neededStrongerParameters: [String] = []

        for effect in EffectCatalog.all {
            // An effect may legitimately be a no-op at its defaults — a strength
            // that defaults to 0, a colour grade whose defaults are neutral. Try
            // progressively stronger parameters before calling it inert, and say
            // which entries needed it: the gallery opens on the defaults, so
            // those entries show nothing until the user moves a slider.
            var chosen: Bitmap?
            for (index, values) in parameterSettings(for: effect).enumerated() {
                let pixels = try render(effect.build(AnyView(source), values, time))
                if difference(pixels, control) > changeThreshold {
                    chosen = pixels
                    if index > 0 { neededStrongerParameters.append(effect.id) }
                    break
                }
                chosen = pixels
            }
            guard let pixels = chosen else { continue }

            if difference(pixels, control) <= changeThreshold {
                inert.append("\(effect.id) renders identically to the unshaded view")
            } else if pixels.isFlat {
                blank.append("\(effect.id) renders as one flat colour (\(pixels.colour(x: 1, y: 1)))")
            }
        }

        if !neededStrongerParameters.isEmpty {
            print("GalleryRenderSweep: invisible at their defaults, visible further along the slider: "
                  + neededStrongerParameters.sorted().joined(separator: ", "))
        }

        XCTAssertEqual(
            blank, [],
            "Catalogue entries that render as a solid colour — the classic symptom of a shader "
            + "receiving shifted arguments:\n" + blank.joined(separator: "\n")
        )
        XCTAssertEqual(
            inert, [],
            "Catalogue entries that change nothing, at any point on their own sliders:\n"
            + inert.joined(separator: "\n")
        )
    }

    /// The whole sweep rests on two renders of the same view being comparable.
    /// They are not exactly equal — this is what that costs, measured rather than
    /// assumed, so that a future OS making rendering noisier fails here instead
    /// of quietly turning every assertion above into a tautology.
    func testTheRendererIsQuietEnoughForTheSweepToMeanAnything() throws {
        let control = try render(source)
        var worst = 0

        for effect in EffectCatalog.all.prefix(30) {
            _ = try render(effect.build(AnyView(source), ParamValues(effect.params), time))
            worst = max(worst, difference(try render(source), control))
        }

        XCTAssertLessThan(
            worst, changeThreshold / 4,
            "Re-rendering the same view differs from the original by \(worst), which is close to "
            + "the \(changeThreshold) the sweep treats as 'the effect did something'. The sweep "
            + "can no longer tell an effect from rasterisation noise."
        )
    }

    // MARK: - Animation

    /// Times to sample an animated entry at.
    ///
    /// Four, irregularly spaced and deliberately not round: two timestamps is
    /// not enough. `filmGrain` uses `fract(time * 100)`, which is exactly 0 for
    /// *every* time with two decimal places, and `wireframeHologram`'s
    /// `sin(time * 3)` happened to land within a rounding error of itself at the
    /// first pair tried. Both looked frozen and neither is.
    private let sampleTimes: [Double] = [0.3137, 1.2711, 2.7183, 4.1892]

    /// Entries that take a `time:` argument and provably ignore it, with the
    /// reason each does. Every one was measured, not assumed: the rendered bytes
    /// are *identical* at all four sample times.
    ///
    /// None of the fixes belong to 7a — the first two need a decision about the
    /// Metal function's signature, the third is a shader bug — so they are
    /// recorded here rather than papered over. **Removing an entry from this set
    /// is the fix**, and `testTheTimeIndependentAllowlistIsStillAccurate` makes
    /// sure the set does not outlive the faults.
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

    /// Animated entries must actually depend on their time argument, or the
    /// gallery's `TimelineView` is driving a still image.
    ///
    /// This exercises the *gallery's* path, where time is an explicit argument
    /// the catalogue passes. Whether the library's self-animating modifiers
    /// advance is a separate question, and 7b's.
    func testEveryAnimatedEntryDependsOnItsTimeArgument() throws {
        var frozen: [String] = []

        for effect in EffectCatalog.all
        where effect.animated && !Self.knownTimeIndependentEntries.contains(effect.id) {
            if try !movesOverTime(effect) { frozen.append(effect.id) }
        }

        XCTAssertEqual(
            frozen, [],
            "Animated entries that render identically at \(sampleTimes.count) different times:\n"
            + frozen.joined(separator: "\n")
        )
    }

    /// The allowlist above must stay a list of *real* offenders, or it becomes a
    /// place where working effects go to stop being checked.
    func testTheTimeIndependentAllowlistIsStillAccurate() throws {
        var nowAnimating: [String] = []

        for id in Self.knownTimeIndependentEntries.sorted() {
            let effect = try XCTUnwrap(EffectCatalog.effect(id: id), "\(id) is no longer catalogued")
            if try movesOverTime(effect) { nowAnimating.append(id) }
        }

        XCTAssertEqual(
            nowAnimating, [],
            "These now depend on their time argument — remove them from "
            + "knownTimeIndependentEntries: \(nowAnimating)"
        )
    }

    private func movesOverTime(_ effect: Effect) throws -> Bool {
        let values = midRange(of: effect)
        let frames = try sampleTimes.map { try render(effect.build(AnyView(source), values, $0)) }
        // Any measurable movement counts: the question is whether `time` reaches
        // the shader at all, not whether the animation is vigorous.
        return frames.dropFirst().contains { difference($0, frames[0]) > changeThreshold / 4 }
    }

    // MARK: - Inputs

    private let time: Double = 1.7

    /// Parameter settings to try, weakest first: the defaults the gallery opens
    /// on, then the middle of each slider, then its far end.
    ///
    /// The ladder matters. Mid-range alone is wrong for a symmetric slider —
    /// `rgbSplit`'s `splitX` runs -0.5…0.5, so its midpoint is *no split at all*
    /// while its default of 0.1 is clearly visible. Defaults alone are wrong for
    /// `colorGrading`, whose defaults are a neutral grade by construction.
    private func parameterSettings(for effect: Effect) -> [ParamValues] {
        [ParamValues(effect.params), midRange(of: effect), extreme(of: effect)]
    }

    private func midRange(of effect: Effect) -> ParamValues {
        settings(of: effect) { ($0.range.lowerBound + $0.range.upperBound) / 2 }
    }

    private func extreme(of effect: Effect) -> ParamValues {
        settings(of: effect) { $0.range.upperBound }
    }

    private func settings(of effect: Effect, _ value: (EffectParam) -> Double) -> ParamValues {
        var values = ParamValues(effect.params)
        for (index, param) in effect.params.enumerated() { values[index] = value(param) }
        return values
    }

    /// Four flat quadrants and a disc — no gradient anywhere, so nothing dithers.
    /// See the type's documentation for why that is load-bearing.
    private var source: AnyView {
        AnyView(
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Color(red: 0.05, green: 0.05, blue: 0.10)
                    Color(red: 0.95, green: 0.35, blue: 0.05)
                }
                HStack(spacing: 0) {
                    Color(red: 0.10, green: 0.45, blue: 0.95)
                    Color(red: 0.98, green: 0.98, blue: 0.95)
                }
            }
            .overlay(
                Circle()
                    .fill(Color(red: 0.10, green: 0.90, blue: 0.30))
                    .frame(width: CGFloat(side) / 3)
            )
            .frame(width: CGFloat(side), height: CGFloat(side))
        )
    }

    // MARK: - Rendering

    /// Sum of absolute differences over every byte of the two images.
    ///
    /// A whole-image measure rather than a per-pixel comparison because the
    /// effects differ enormously in *shape*: `rain` changes a few hundred bytes
    /// by up to 112, `chromaticAberration` changes several thousand by at most 6.
    /// Either is real; neither is expressible as one tolerance.
    private func difference(_ a: Bitmap, _ b: Bitmap) -> Int {
        a.sumOfAbsoluteDifferences(from: b)
    }

    private func render(_ view: AnyView) throws -> Bitmap {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.cgImage, "ImageRenderer produced no image.")
        return try Bitmap(image)
    }

    struct Bitmap {
        let width: Int
        let height: Int
        private let bytes: [UInt8]

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

        func sumOfAbsoluteDifferences(from other: Bitmap) -> Int {
            guard width == other.width, height == other.height else { return .max }
            return zip(bytes, other.bytes).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
        }

        /// Every sampled pixel the same — a solid rectangle, transparent or not.
        /// This is what a shader reading shifted arguments produces.
        ///
        /// Alpha counts: a render that is black everywhere but keeps a varying
        /// alpha is a different picture, not a swallowed view. (Learned from a
        /// negative control: `.brightness(-1)` blacks out the colour and leaves
        /// the effect's alpha alone, so it is not flat and was not caught.
        /// `.overlay(Color.black)`, which is opaque, is.)
        var isFlat: Bool {
            let first = colour(x: 0, y: 0)
            return probes.allSatisfy { colour(x: $0.x, y: $0.y).isClose(to: first) }
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
