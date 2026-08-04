import XCTest
import Metal
import SwiftUI
@testable import SwiftShaders

/// The binding oracle.
///
/// `ShaderLibrary` is `@dynamicMemberLookup` and `ShaderFunction` is
/// `@dynamicCallable`, and both are non-optional and non-throwing. A misspelt
/// function name, a missing argument, or the wrong `View` effect method all
/// compile cleanly and fail — silently, per frame — only once SwiftUI draws.
/// There is no checked lookup, no optional variant and no throwing variant to
/// reach for; see the plan's Phase 0.3.
///
/// These tests are that missing check. Each defect class gets its own test so
/// the counts stay legible, and each broken call site reports its own failure
/// with a clickable `file:line`.
final class ShaderBindingTests: XCTestCase {

    // MARK: - The manifest describes the library that ships

    /// Guards the oracle itself: every later test trusts the manifest, so a
    /// manifest regenerated from a different metallib than the one in the
    /// bundle would quietly invalidate all of them.
    func testManifestDescribesTheCompiledLibrary() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device in this test process.")
        }
        let compiled = Set(try device.makeDefaultLibrary(bundle: .module).functionNames)
        let manifest = Set(try ShaderSignatureManifest.load().keys)

        XCTAssertEqual(
            manifest.subtracting(compiled).sorted(), [],
            "shader-signatures.tsv lists functions the metallib does not contain. "
            + "Regenerate it: ./Scripts/extract-metal-signatures.py"
        )
        XCTAssertEqual(
            compiled.subtracting(manifest).sorted(), [],
            "The metallib contains functions the manifest does not list. "
            + "Regenerate it: ./Scripts/extract-metal-signatures.py"
        )
    }

    // MARK: - Defect class 1: the function does not exist

    func testEveryCallSiteResolvesToAFunctionInTheLibrary() throws {
        let signatures = try ShaderSignatureManifest.load()
        var unresolved = 0

        for site in try ShaderCallSiteScanner.scanSources() where signatures[site.functionName] == nil {
            unresolved += 1
            XCTFail(
                "\(site.file):\(site.line): no [[stitchable]] function named '\(site.functionName)' "
                + "exists in default.metallib. This call site draws nothing."
            )
        }
        print("[binding] unresolved function names: \(unresolved)")
    }

    // MARK: - Defect class 2: the argument count is wrong

    /// SwiftUI supplies only `position` (plus `color` or `layer`); there is no
    /// implicit `bounds` and no implicit `size`, so a shader declaring
    /// `float4 bounds` needs an explicit `.boundingRect` from Swift. When the
    /// count is short every argument slides one position left and the shader
    /// reads a neighbouring uniform as its first parameter.
    func testEveryCallSitePassesTheNumberOfArgumentsItsFunctionExpects() throws {
        let signatures = try ShaderSignatureManifest.load()
        var mismatched = 0

        for site in try ShaderCallSiteScanner.scanSources() {
            // The other two defect classes have their own tests; counting them
            // here as well would inflate this one.
            guard let signature = signatures[site.functionName],
                  signature.kind == site.effectMethod.manifestKind
            else { continue }
            guard site.argumentKinds.count != signature.explicitArgumentCount else { continue }

            mismatched += 1
            XCTFail(
                "\(site.file):\(site.line): '\(site.functionName)' expects "
                + "\(signature.explicitArgumentCount) explicit argument(s) "
                + "(\(signature.parameters.joined(separator: ", "))) but the call site passes "
                + "\(site.argumentKinds.count) (\(site.argumentKinds.joined(separator: ", ")))."
                + (signature.parameters.dropFirst().contains("float4")
                   ? " Its first explicit parameter is a float4 — this is the missing `.boundingRect`."
                   : "")
            )
        }
        print("[binding] argument-count mismatches: \(mismatched)")
    }

    // MARK: - Defect class 3: the wrong effect method

    /// The effect method decides what SwiftUI passes implicitly and what return
    /// type it expects, so invoking a `distortionEffect` function through
    /// `.colorEffect` is a defect even when the argument count lines up.
    func testEveryCallSiteUsesTheEffectMethodItsFunctionDeclares() throws {
        let signatures = try ShaderSignatureManifest.load()
        var misdirected = 0

        for site in try ShaderCallSiteScanner.scanSources() {
            guard let signature = signatures[site.functionName],
                  signature.kind != site.effectMethod.manifestKind
            else { continue }

            misdirected += 1
            XCTFail(
                "\(site.file):\(site.line): '\(site.functionName)' is declared as a "
                + "\(signature.kind) (returns \(signature.returnType)) but is invoked through "
                + ".\(site.effectMethod.manifestKind)."
            )
        }
        print("[binding] wrong effect method: \(misdirected)")
    }

    // MARK: - Defect class 4: the argument type is wrong

    /// A call site can pass the right *number* of arguments and still be
    /// unbindable, because `Shader.Argument` cannot produce every MSL type. In
    /// particular there is no `half3` factory — the only half-typed argument
    /// SwiftUI can supply is `.color`, which is a `half4` — so a shader
    /// declaring `half3` cannot be driven from Swift at all, whatever the caller
    /// passes. SwiftUI's stitcher rejects it with "unsupported MTLDataType: 18".
    ///
    /// Counting arguments does not see this class, which is why it survived the
    /// earlier inventory.
    func testEveryCallSitePassesArgumentsOfTheDeclaredTypes() throws {
        let signatures = try ShaderSignatureManifest.load()
        var mistyped = 0
        var unchecked: [String] = []

        for site in try ShaderCallSiteScanner.scanSources() {
            // Sites already counted by the name, kind and arity tests are
            // skipped so the four counts partition the defects rather than
            // overlapping.
            guard let signature = signatures[site.functionName],
                  signature.kind == site.effectMethod.manifestKind,
                  site.argumentKinds.count == signature.explicitArgumentCount
            else { continue }

            let declared = Array(signature.parameters.suffix(signature.explicitArgumentCount))
            var wrong: [String] = []
            for (index, kind) in site.argumentKinds.enumerated() {
                guard let supplied = Self.typeSupplied[kind] else {
                    unchecked.append("\(site.file):\(site.line) argument \(index) is .\(kind)")
                    continue
                }
                guard supplied != declared[index] else { continue }
                wrong.append("argument \(index) is declared \(declared[index]) but .\(kind) supplies \(supplied)")
            }
            guard !wrong.isEmpty else { continue }

            // Counted per call site, not per argument, so this number is
            // directly comparable with the other three classes and with the
            // compile(as:) oracle.
            mistyped += 1
            XCTFail(
                "\(site.file):\(site.line): '\(site.functionName)' — \(wrong.joined(separator: "; "))."
                + (declared.contains { $0.hasPrefix("half") }
                   ? " No Shader.Argument factory produces a half3; this one needs the Metal "
                   + "declaration changed, not the call site."
                   : "")
            )
        }

        XCTAssertEqual(
            unchecked, [],
            "These arguments use a Shader.Argument factory with no entry in the type table, "
            + "so their types went unchecked."
        )
        print("[binding] argument-type mismatches: \(mistyped)")
    }

    /// The MSL type each `Shader.Argument` factory delivers. Factories that
    /// expand to more than one MSL parameter (`.floatArray`, `.colorArray`,
    /// `.data`, and `.image`'s texture) are deliberately absent: they need a
    /// different comparison, and the `unchecked` assertion above reports them
    /// rather than letting them pass unexamined.
    private static let typeSupplied: [String: String] = [
        "float": "float",
        "float2": "float2",
        "float3": "float3",
        "float4": "float4",
        "boundingRect": "float4",
        "color": "half4",
    ]

    // MARK: - The first-party oracle

    /// `Shader.compile(as:)` is Apple's own validation of a binding, and the
    /// only check that sees argument *types* rather than counts. It is a
    /// separate, independent confirmation of the three tests above — if their
    /// totals and this one's disagree, one of them is wrong.
    ///
    /// macOS 15 / iOS 18 only, so it is gated rather than assumed.
    func testEveryCallSiteCompiles() async throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, visionOS 2.0, *) else {
            throw XCTSkip("Shader.compile(as:) requires macOS 15 / iOS 18.")
        }
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("No Metal device in this test process.")
        }
        try await compileEveryCallSite()
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, visionOS 2.0, *)
    private func compileEveryCallSite() async throws {
        var rejections: [String] = []
        var unrepresentable: [String] = []
        var probed = 0

        for site in try ShaderCallSiteScanner.scanSources() {
            guard let usage = site.effectMethod.usageType else {
                unrepresentable.append("\(site.file):\(site.line) unattributed effect method")
                continue
            }
            guard let arguments = try? site.argumentKinds.map(Self.placeholderArgument(for:)) else {
                unrepresentable.append("\(site.file):\(site.line) unsupported argument kind")
                continue
            }
            probed += 1

            let shader = ShaderLibrary.swiftShaders[dynamicMember: site.functionName]
                .dynamicallyCall(withArguments: arguments)
            do {
                try await shader.compile(as: usage)
            } catch {
                rejections.append(
                    "\(site.file):\(site.line): '\(site.functionName)' as .\(site.effectMethod.manifestKind) "
                    + "with \(site.argumentKinds.count) argument(s): "
                    + error.localizedDescription.split(separator: "\n")
                        .map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: " ")
                )
            }
        }

        XCTAssertEqual(
            unrepresentable, [],
            "These call sites could not be probed, so compile(as:) says nothing about them."
        )
        // Reported as one aggregate failure rather than one per site: when this
        // test raised an issue per rejection, XCTest's console reporter printed
        // only 85 of 157: the visible count silently understated the damage.
        if !rejections.isEmpty {
            XCTFail(
                "Shader.compile(as:) rejected \(rejections.count) of \(probed) call sites:\n"
                + rejections.joined(separator: "\n")
            )
        }
        print("[binding] rejected by Shader.compile(as:): \(rejections.count) of \(probed)")
    }

    /// A stand-in argument of the right *type* for each `Shader.Argument`
    /// factory a call site uses. `compile(as:)` checks types and arity, not
    /// values, so the values are arbitrary.
    private static func placeholderArgument(for kind: String) throws -> Shader.Argument {
        switch kind {
        case "float": return .float(1)
        case "float2": return .float2(1, 2)
        case "float3": return .float3(1, 2, 3)
        case "float4": return .float4(1, 2, 3, 4)
        case "boundingRect": return .boundingRect
        case "color": return .color(.red)
        case "colorArray": return .colorArray([.red])
        case "floatArray": return .floatArray([1])
        case "data": return .data(Data([0]))
        case "image": return .image(Image(systemName: "circle"))
        default: throw UnsupportedArgumentKind(kind: kind)
        }
    }

    private struct UnsupportedArgumentKind: Error { let kind: String }

    // MARK: - The metallib matches the sources it claims to be built from

    /// `build-shaders.sh` passes `-frecord-sources`, so the metallib carries its
    /// own `.metal` sources and can be asked what it was built from. Without
    /// this, every test above passes happily against a stale metallib compiled
    /// from shader code that no longer exists.
    func testMetallibWasBuiltFromTheCheckedInMetalSources() throws {
        guard which("metal-source") else {
            throw XCTSkip("xcrun metal-source is unavailable on this machine.")
        }
        let root = ShaderCallSiteScanner.repositoryRoot
        let metallib = try XCTUnwrap(
            Bundle.module.url(forResource: "default", withExtension: "metallib"),
            "default.metallib is missing from the resource bundle."
        )
        let extracted = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("swiftshaders-metal-source-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: extracted, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: extracted) }

        let extraction = run("xcrun", ["metal-source", "--extract=raw", "-f",
                                       "-o=\(extracted.path)", metallib.path])
        XCTAssertEqual(extraction.status, 0, "metal-source failed: \(extraction.output)")

        // The recorded paths are absolute and belong to the machine that built
        // the metallib, so sources are matched by file name.
        var recovered: [String: URL] = [:]
        let walk = FileManager.default.enumerator(at: extracted, includingPropertiesForKeys: nil)
        while let url = walk?.nextObject() as? URL {
            if url.pathExtension == "metal" { recovered[url.lastPathComponent] = url }
        }

        let metalDirectory = root.appendingPathComponent("Sources/SwiftShaders/Metal")
        let onDisk = try FileManager.default
            .contentsOfDirectory(at: metalDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "metal" }

        for source in onDisk.sorted(by: { $0.path < $1.path }) {
            let name = source.lastPathComponent
            guard let embedded = recovered[name] else {
                XCTFail(
                    "\(name) is not in default.metallib. The metallib is stale — "
                    + "run ./Scripts/build-shaders.sh."
                )
                continue
            }
            XCTAssertEqual(
                try String(contentsOf: embedded, encoding: .utf8),
                try String(contentsOf: source, encoding: .utf8),
                "\(name) differs from the copy recorded in default.metallib. The metallib is "
                + "stale — run ./Scripts/build-shaders.sh."
            )
        }
        XCTAssertEqual(
            recovered.count, onDisk.count,
            "default.metallib was built from \(recovered.count) sources but "
            + "\(onDisk.count) are checked in."
        )
    }

    // MARK: - Subprocess helpers

    private func which(_ tool: String) -> Bool {
        run("xcrun", ["--find", tool]).status == 0
    }

    @discardableResult
    private func run(_ launchPath: String, _ arguments: [String]) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [launchPath] + arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do { try process.run() } catch { return (-1, "\(error)") }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(data: data, encoding: .utf8) ?? "")
    }
}

@available(iOS 18.0, macOS 15.0, tvOS 18.0, visionOS 2.0, *)
private extension ShaderEffectMethod {
    var usageType: Shader.UsageType? {
        switch self {
        case .color: return .colorEffect
        case .distortion: return .distortionEffect
        case .layer: return .layerEffect
        case .unknown: return nil
        }
    }
}
