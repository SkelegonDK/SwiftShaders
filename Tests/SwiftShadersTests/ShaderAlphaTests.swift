import XCTest
import SwiftUI
@testable import SwiftShaders

/// Proves that an effect leaves the transparent parts of its view invisible.
///
/// `colorEffect` and `layerEffect` run over every pixel of the view's
/// rectangular frame — including fully transparent ones — and SwiftUI works
/// in premultiplied alpha, so a shader that computes a non-zero rgb for a
/// transparent input pixel emits *additive light* even though it copies the
/// input's zero alpha. The effect then visibly fills its whole bounding box,
/// which reads as "the effect applied to the parent container".
///
/// The probe: a small red square centred in a larger transparent frame,
/// composited over a green background. The padding pixel must stay green.
@available(macOS 14.0, iOS 17.0, *)
@MainActor
final class ShaderAlphaTests: XCTestCase {

    private let side = 64
    private let square = 16

    func testXrayLeavesTransparentPaddingInvisible() throws {
        try assertPaddingStaysGreen { AnyView($0.xray(intensity: 1.0)) }
    }

    func testEmbossLeavesTransparentPaddingInvisible() throws {
        try assertPaddingStaysGreen { AnyView($0.emboss(strength: 1.0, lightAngle: 0.8)) }
    }

    // MARK: - Probe

    private func assertPaddingStaysGreen(
        _ apply: (AnyView) -> AnyView,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let padded = AnyView(
            Rectangle()
                .fill(Color(red: 1, green: 0, blue: 0))
                .frame(width: CGFloat(square), height: CGFloat(square))
                .frame(width: CGFloat(side), height: CGFloat(side))
        )

        let control = try render(composite(padded))
        let effected = try render(composite(apply(padded)))

        // Sanity: the composite is what the probe assumes — green padding,
        // red centre — before any effect is applied.
        let corner = (x: 6, y: 6)
        let centre = (x: side / 2, y: side / 2)
        XCTAssertTrue(control.colour(x: corner.x, y: corner.y).isGreen,
                      "Control corner is \(control.colour(x: corner.x, y: corner.y)), not green; "
                      + "the probe is not testing what it thinks.", file: file, line: line)
        XCTAssertTrue(control.colour(x: centre.x, y: centre.y).isRed,
                      "Control centre is \(control.colour(x: centre.x, y: centre.y)), not red.",
                      file: file, line: line)

        // The claim under test: the effect must not paint the transparent
        // padding, so the background shows through unchanged.
        let paddingPixel = effected.colour(x: corner.x, y: corner.y)
        XCTAssertTrue(
            paddingPixel.isGreen,
            "The transparent padding renders \(paddingPixel) instead of the background green: "
            + "the shader emits colour for zero-alpha pixels, so the effect visibly fills its "
            + "whole frame. In premultiplied alpha the result's rgb must be scaled by alpha.",
            file: file, line: line
        )
    }

    private func composite(_ view: AnyView) -> AnyView {
        AnyView(
            ZStack {
                Color(red: 0, green: 1, blue: 0)
                view
            }
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
                throw NSError(domain: "ShaderAlphaTests", code: 1)
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            bytes = buffer
        }

        func colour(x: Int, y: Int) -> Colour {
            let offset = (y * width + x) * 4
            return Colour(r: bytes[offset], g: bytes[offset + 1], b: bytes[offset + 2])
        }
    }

    private struct Colour: CustomStringConvertible {
        let r, g, b: UInt8
        var description: String { "rgb(\(r), \(g), \(b))" }

        /// Coarse on purpose: colour management may move values a little,
        /// but the failure mode under test moves them a lot.
        var isGreen: Bool { g > 180 && r < 80 && b < 80 }
        var isRed: Bool { r > 180 && g < 80 && b < 80 }
    }
}
