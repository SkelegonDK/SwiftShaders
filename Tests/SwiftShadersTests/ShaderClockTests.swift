import XCTest
import SwiftUI
@testable import SwiftShaders

/// Proves that the library's animated entry points actually advance.
///
/// ## The defect this test exists for
///
/// Animated effects pass their time as `Shader.Argument.float`, which is
/// **32-bit** (Phase 0.2). Several entry points sourced that time from
/// `timeline.date.timeIntervalSinceReferenceDate` — ≈7.8×10⁸ today. The ulp of a
/// `Float` at that magnitude is 64 seconds, so a whole frame's worth of elapsed
/// time (1/60 s) rounds away entirely: `Float(7.8e8) == Float(7.8e8 + 1.0/60.0)`.
/// The uniform reaching the shader was *bit-identical* from one frame to the
/// next and stepped only every ~64 s. Those effects were frozen, not slow, and
/// no test short of rendering could see it — the argument had the right type,
/// the right arity and the right position.
///
/// So this test renders a real animated entry point at two instants and compares
/// pixels. It is deliberately end-to-end: rendering is the only vantage point
/// from which a frozen uniform is distinguishable from a moving one.
///
/// ## Why the clock is pinned rather than slept through
///
/// Two `ImageRenderer` passes are two *different* view instances, so each gets
/// its own `ShaderClock` start and both would render at elapsed ≈ 0 for an
/// honest reason. Pinning `\.shaderClockStart` and `\.shaderClockNow` fixes both
/// ends of the subtraction, so the two renders differ by exactly the interval
/// under test and nothing else — no sleeping, no wall-clock flakiness. Code that
/// ignores the clock and reads `timeline.date` absolutely ignores the pins too,
/// and renders the same frame twice.
///
/// `@MainActor` because `ImageRenderer` is main-actor isolated.
@available(macOS 14.0, iOS 17.0, *)
@MainActor
final class ShaderClockTests: XCTestCase {

    private let side = 64

    /// The interval under test. Large enough that the ripple's phase
    /// (`sin(distance * frequency - time * 10)`) moves several radians — and
    /// two orders of magnitude *below* the 64 s ulp the old code rounded to.
    private let gap: TimeInterval = 0.5

    /// A start instant of realistic magnitude: this is the number whose `Float`
    /// ulp is 64 seconds, so the test is exercising the exact regime the bug
    /// lived in rather than a convenient small one.
    private let epoch = Date(timeIntervalSinceReferenceDate: 780_000_000)

    // MARK: - The acceptance test

    func testAnimatedRippleRendersDifferentlyHalfASecondLater() throws {
        let first = try render(ripple(at: epoch))
        let second = try render(ripple(at: epoch.addingTimeInterval(gap)))

        let moved = first.pixelsDiffering(from: second)
        XCTAssertGreaterThan(
            moved, side * side / 20,
            """
            AnimatedRippleModifier rendered only \(moved) differing pixels \(gap)s apart — \
            the animation is frozen. The time uniform is almost certainly derived from an \
            absolute date: Shader.Argument.float is 32-bit, and at reference-date magnitude \
            (~7.8e8) its ulp is 64 seconds, so \(gap)s of elapsed time rounds to nothing. \
            Feed animated effects elapsed seconds from a ShaderClock instead.
            """
        )
    }

    // MARK: - Controls

    /// Without this, "the pixels differed" could just mean `ImageRenderer` is
    /// nondeterministic, and the acceptance test would pass for a reason that
    /// has nothing to do with the clock.
    func testTheSameInstantRendersIdentically() throws {
        let first = try render(ripple(at: epoch))
        let second = try render(ripple(at: epoch))

        XCTAssertEqual(
            first.pixelsDiffering(from: second), 0,
            "Two renders of the same instant disagree; ImageRenderer output is not "
            + "deterministic, so the acceptance test's comparison proves nothing."
        )
    }

    /// The ripple must be visibly doing something at all — otherwise the
    /// acceptance test's threshold is measuring an effect that never touches a
    /// pixel.
    func testTheRippleActuallyDistortsTheGradient() throws {
        let shaded = try render(ripple(at: epoch.addingTimeInterval(0.3)))
        let plain = try render(AnyView(gradient))

        XCTAssertGreaterThan(
            shaded.pixelsDiffering(from: plain), side * side / 20,
            "The ripple leaves the gradient unchanged, so this file's other assertions "
            + "are measuring nothing."
        )
    }

    // MARK: - ShaderClock itself

    func testElapsedIsMeasuredFromTheStartInstantAndScaledBySpeed() {
        let clock = ShaderClock(start: epoch)

        XCTAssertEqual(clock.elapsed(to: epoch), 0)
        XCTAssertEqual(clock.elapsed(to: epoch.addingTimeInterval(2)), 2, accuracy: 1e-9)
        XCTAssertEqual(
            clock.elapsed(to: epoch.addingTimeInterval(2), speed: 3), 6, accuracy: 1e-9
        )
    }

    /// The premise of the whole fix, asserted rather than assumed.
    func testOnlyElapsedTimeSurvivesTheNarrowingToFloat() {
        let absolute = epoch.timeIntervalSinceReferenceDate
        let frame = 1.0 / 60.0

        XCTAssertEqual(
            Float(absolute), Float(absolute + frame),
            "A reference-date-magnitude time no longer collapses under Float. If this "
            + "assertion fails the platform changed and 7b's premise needs rechecking."
        )
        // A view that has been on screen for an hour still resolves a frame.
        XCTAssertNotEqual(Float(3600.0), Float(3600.0 + frame))
    }

    // MARK: - Fixtures

    /// The probe effect: `AnimatedRippleModifier`, one of the entry points that
    /// fed `.float(time)` from an absolute date.
    ///
    /// `amplitude` and `decay` are pushed away from their defaults so the
    /// displacement is tens of pixels across a 64 pt view rather than one or
    /// two — the assertion is about *whether* time moves, and a threshold
    /// sitting on the edge of the colour tolerance would make it about
    /// rasterisation instead.
    private func ripple(at instant: Date) -> AnyView {
        AnyView(
            gradient
                .modifier(AnimatedRippleModifier(amplitude: 0.25, frequency: 12, decay: 1.5))
                .environment(\.shaderClockStart, epoch)
                .environment(\.shaderClockNow, instant)
        )
    }

    private var gradient: some View {
        LinearGradient(
            colors: [.black, .white],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: CGFloat(side), height: CGFloat(side))
    }

    // MARK: - Rendering

    private func render(_ view: AnyView) throws -> Bitmap {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.cgImage, "ImageRenderer produced no image.")
        return try Bitmap(image)
    }

    /// A rendered image with RGBA byte access.
    private struct Bitmap {
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
            guard let context else {
                throw NSError(domain: "ShaderClockTests", code: 1)
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            bytes = buffer
        }

        /// Rasterisation is allowed to move a little between OS releases, so the
        /// per-channel tolerance is deliberately coarse.
        func pixelsDiffering(from other: Bitmap, tolerance: Int = 8) -> Int {
            guard width == other.width, height == other.height else { return width * height }
            var count = 0
            for pixel in 0..<(width * height) {
                let offset = pixel * 4
                for channel in 0..<3 where
                    abs(Int(bytes[offset + channel]) - Int(other.bytes[offset + channel])) > tolerance {
                    count += 1
                    break
                }
            }
            return count
        }
    }
}
