import XCTest
import SwiftUI
@testable import SwiftShaders

/// Proves that arguments arrive at the shader with the values Swift passed.
///
/// The binding tests check that a call site's arguments have the right count and
/// types. That is not the same as the shader receiving the right *values*: a
/// call site missing its `.boundingRect` still had the correct number of
/// arguments as far as any type check was concerned — every later argument
/// simply slid one position left, and the shader read a neighbouring uniform.
/// Only rendering catches that.
///
/// `pixelate` is the probe because its behaviour is a direct, legible function
/// of one argument: it snaps sampling positions to a grid of `pixelSize`. If
/// `pixelSize` arrives intact the output is visibly blocky at exactly that
/// pitch; if the arguments are shifted it is not.
/// `@MainActor` because `ImageRenderer` is main-actor isolated.
@available(macOS 14.0, iOS 17.0, *)
@MainActor
final class ShaderRenderingTests: XCTestCase {

    private let side = 64
    private let block = 16

    func testPixelateQuantisesTheImageAtTheBlockSizeItWasPassed() throws {
        let pixels = try render(
            AnyView(
                gradient.shaderEffect(
                    PixelateShaderBindings.pixelate,
                    .float(Float(block)),
                    maxSampleOffset: CGSize(width: block, height: block)
                )
            )
        )

        // Within one block every pixel samples the same source point, so the
        // colour is flat. Compared near the block's edges, where the underlying
        // gradient differs most.
        let row = block / 2
        for blockIndex in 0..<(side / block) {
            let left = pixels.colour(x: blockIndex * block + 1, y: row)
            let right = pixels.colour(x: blockIndex * block + block - 2, y: row)
            XCTAssertTrue(
                left.isClose(to: right),
                "Block \(blockIndex) is not flat (\(left) vs \(right)): pixelate did not receive "
                + "its pixelSize. Check that its binding declares .boundingRect geometry."
            )
        }

        // ...and neighbouring blocks differ, so the effect is not simply a
        // uniform smear that would satisfy the check above trivially.
        let first = pixels.colour(x: 1, y: row)
        let last = pixels.colour(x: side - 2, y: row)
        XCTAssertFalse(
            first.isClose(to: last),
            "The whole row is one colour (\(first)); the gradient was flattened rather than pixelated."
        )
    }

    /// The negative control for the test above, kept as a test in its own right:
    /// the unmodified gradient must *not* be flat, or the assertions above would
    /// pass no matter what the shader did.
    func testTheSourceGradientIsNotAlreadyFlat() throws {
        let pixels = try render(AnyView(gradient))
        let row = block / 2

        XCTAssertFalse(
            pixels.colour(x: 1, y: row).isClose(to: pixels.colour(x: block - 2, y: row)),
            "The source gradient is flat within a block, so the pixelation test proves nothing."
        )
    }

    // MARK: - Rendering

    private var gradient: some View {
        LinearGradient(
            colors: [.black, .white],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: CGFloat(side), height: CGFloat(side))
    }

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
                throw NSError(domain: "ShaderRenderingTests", code: 1)
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            bytes = buffer
        }

        func colour(x: Int, y: Int) -> Colour {
            let offset = (y * width + x) * 4
            return Colour(r: bytes[offset], g: bytes[offset + 1], b: bytes[offset + 2])
        }
    }

    private struct Colour: CustomStringConvertible, Equatable {
        let r, g, b: UInt8
        var description: String { "rgb(\(r), \(g), \(b))" }

        /// Rasterisation is allowed to move a little between OS releases, so
        /// comparisons are deliberately coarse.
        func isClose(to other: Colour, tolerance: Int = 8) -> Bool {
            abs(Int(r) - Int(other.r)) <= tolerance
                && abs(Int(g) - Int(other.g)) <= tolerance
                && abs(Int(b) - Int(other.b)) <= tolerance
        }
    }
}
