import XCTest

/// Tests for the scanner that the binding oracle rests on.
///
/// `ShaderBindingTests` claims "N call sites are wrong". That claim is only
/// worth as much as the scanner's ability to find every call site and count its
/// arguments correctly — an under-counting scanner reports a comfortable zero.
/// These are the tests that make the count trustworthy.
final class ShaderCallSiteScannerTests: XCTestCase {

    // MARK: - Finding call sites

    func testFindsASingleCallSiteWithItsArgumentCount() {
        let source = """
        .colorEffect(ShaderLibrary.swiftShaders.invert(.float(1.0)))
        """

        let sites = ShaderCallSiteScanner.scan(source: source, file: "F.swift")

        XCTAssertEqual(sites.count, 1)
        XCTAssertEqual(sites.first?.functionName, "invert")
        XCTAssertEqual(sites.first?.argumentKinds, ["float"])
    }

    func testCountsAnArgumentWithNestedParenthesesAsOneArgument() {
        // The failure this guards: splitting on every comma makes
        // `.float2(Float(a), Float(b))` look like two arguments, which turns a
        // broken call site into a passing one.
        let source = """
        .layerEffect(ShaderLibrary.swiftShaders.kaleidoscope(
            .float2(proxy.size),
            .float2(Float(configuration.center.x), Float(configuration.center.y)),
            .float(configuration.segments)
        ), maxSampleOffset: .zero)
        """

        let sites = ShaderCallSiteScanner.scan(source: source, file: "F.swift")

        XCTAssertEqual(sites.first?.argumentKinds, ["float2", "float2", "float"])
    }

    func testTreatsATrailingCommaAndWhitespaceAsNoArgument() {
        let source = ".colorEffect(ShaderLibrary.swiftShaders.sepia(  ))"

        let sites = ShaderCallSiteScanner.scan(source: source, file: "F.swift")

        XCTAssertEqual(sites.first?.argumentKinds, [])
    }

    func testFindsEveryCallSiteInAFileWithSeveral() {
        let source = """
        .colorEffect(ShaderLibrary.swiftShaders.invert(.float(1.0)))
        .distortionEffect(ShaderLibrary.swiftShaders.wave(.float(t), .float(a)), maxSampleOffset: .zero)
        """

        let sites = ShaderCallSiteScanner.scan(source: source, file: "F.swift")

        XCTAssertEqual(sites.map(\.functionName), ["invert", "wave"])
    }

    // MARK: - Comments

    func testIgnoresACallSiteInsideALineComment() {
        let source = """
        // .colorEffect(ShaderLibrary.swiftShaders.documented(.float(1.0)))
        .colorEffect(ShaderLibrary.swiftShaders.real(.float(1.0)))
        """

        let sites = ShaderCallSiteScanner.scan(source: source, file: "F.swift")

        XCTAssertEqual(sites.map(\.functionName), ["real"])
    }

    func testIgnoresACallSiteInsideABlockComment() {
        let source = """
        /* usage:
           .colorEffect(ShaderLibrary.swiftShaders.documented(.float(1.0)))
        */
        .colorEffect(ShaderLibrary.swiftShaders.real(.float(1.0)))
        """

        let sites = ShaderCallSiteScanner.scan(source: source, file: "F.swift")

        XCTAssertEqual(sites.map(\.functionName), ["real"])
    }

    // MARK: - Line numbers

    func testReportsTheLineOfTheCallSiteInTheOriginalSource() {
        let source = """
        import SwiftUI

        /* a block comment
           spanning lines */
        let v = content
            .colorEffect(ShaderLibrary.swiftShaders.invert(.float(1.0)))
        """

        let sites = ShaderCallSiteScanner.scan(source: source, file: "F.swift")

        XCTAssertEqual(sites.first?.line, 6)
    }

    // MARK: - Effect method attribution

    func testAttributesTheEnclosingEffectMethod() {
        let source = """
        .colorEffect(ShaderLibrary.swiftShaders.invert(.float(1.0)))
        .distortionEffect(ShaderLibrary.swiftShaders.wave(.float(1.0)), maxSampleOffset: .zero)
        .layerEffect(ShaderLibrary.swiftShaders.vortex(.float(1.0)), maxSampleOffset: .zero)
        """

        let sites = ShaderCallSiteScanner.scan(source: source, file: "F.swift")

        XCTAssertEqual(sites.map(\.effectMethod), [.color, .distortion, .layer])
    }

    func testAttributesTheNearestPrecedingEffectMethodWhenSeveralAppear() {
        // Modifier bodies routinely nest a shader call inside a TimelineView
        // inside another modified view; only the innermost enclosing effect
        // method describes how this shader is invoked.
        let source = """
        content
            .colorEffect(ShaderLibrary.swiftShaders.tint(.float(1.0)))
            .distortionEffect(ShaderLibrary.swiftShaders.wave(.float(1.0)), maxSampleOffset: .zero)
        """

        let sites = ShaderCallSiteScanner.scan(source: source, file: "F.swift")

        XCTAssertEqual(sites.last?.effectMethod, .distortion)
    }

    // MARK: - Argument kinds

    func testClassifiesArgumentKinds() {
        let source = """
        .colorEffect(ShaderLibrary.swiftShaders.everything(
            .boundingRect,
            .float(1.0),
            .float2(1.0, 2.0),
            .float3(1.0, 2.0, 3.0),
            .float4(1.0, 2.0, 3.0, 4.0),
            .color(.red),
            .image(Image("x"))
        ))
        """

        let sites = ShaderCallSiteScanner.scan(source: source, file: "F.swift")

        XCTAssertEqual(
            sites.first?.argumentKinds,
            ["boundingRect", "float", "float2", "float3", "float4", "color", "image"]
        )
    }

    func testDoesNotConfuseFloat2WithFloat() {
        // `.float2` starts with `.float`; a shortest-prefix match silently
        // rewrites every float2 argument into a float and corrupts the
        // compile(as:) probes built from these kinds.
        let source = ".colorEffect(ShaderLibrary.swiftShaders.f(.float2(1.0, 2.0)))"

        let sites = ShaderCallSiteScanner.scan(source: source, file: "F.swift")

        XCTAssertEqual(sites.first?.argumentKinds, ["float2"])
    }

    // MARK: - Scanning the repository

    func testScanningTheRepositoryFindsCallSitesInEveryShaderModule() throws {
        let sites = try ShaderCallSiteScanner.scanSources()

        XCTAssertGreaterThan(
            sites.count, 100,
            "Found \(sites.count) call sites in Sources/. A collapse to zero means the "
            + "scanner lost the repository root, not that the bindings are clean."
        )
        XCTAssertFalse(
            sites.contains { $0.effectMethod == .unknown },
            "Every call site must be attributable to an effect method; unattributed "
            + "sites would be silently skipped by the arity and kind checks: "
            + sites.filter { $0.effectMethod == .unknown }.map(\.description).joined(separator: ", ")
        )
    }
}
