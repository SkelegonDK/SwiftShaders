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
/// Since Phase 5 the convention lives in one place: every call site declares a
/// `ShaderBinding` once and applies it with `View.shaderEffect`. These tests
/// are the missing check, retargeted at that module:
///
/// - the *declarations* are checked against `shader-signatures.tsv` (name,
///   kind, geometry — each its own defect class, so the counts stay legible);
/// - the *application sites* are checked for argument count and types;
/// - `ShaderBindingRegistry` is checked against the declarations found in
///   source, because a registry test that only consulted the registry could
///   not notice a binding that was declared but never registered;
/// - `Shader.compile(as:)` independently re-verifies every site through the
///   module's own argument-assembly path.
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

    // MARK: - The convention has one home

    /// After Phase 5 no call site spells the convention by hand. The raw-site
    /// scanner still works — its fixture tests prove it — so finding zero raw
    /// sites means they are gone, not that the scanner is broken. The root
    /// check guards against the third possibility: the scanner looking at the
    /// wrong directory and finding zero of everything.
    func testNoRawCallSitesRemainOutsideTheBindingModule() throws {
        let shaders = ShaderCallSiteScanner.repositoryRoot
            .appendingPathComponent("Sources/SwiftShaders/Shaders")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: shaders.path),
            "The scanner's repository root is wrong; a zero count below would be meaningless."
        )
        XCTAssertEqual(
            try ShaderCallSiteScanner.scanSources().map(\.description), [],
            "These call sites bypass ShaderBinding and restate the convention by hand. "
            + "Declare a binding and apply it with .shaderEffect instead."
        )
    }

    /// A collapse of either scan to a trivial count would quietly turn every
    /// test below vacuous.
    func testTheScannersFindTheDeclaredPopulation() throws {
        let declarations = try ShaderBindingSourceScanner.scanDeclarations()
        let applications = try ShaderBindingSourceScanner.scanApplications()

        XCTAssertGreaterThan(
            declarations.count, 150,
            "Found \(declarations.count) binding declarations; the library declares ~200."
        )
        XCTAssertGreaterThan(
            applications.count, 150,
            "Found \(applications.count) application sites; the library has ~200."
        )
    }

    // MARK: - Defect class 1: the function does not exist

    func testEveryBindingResolvesToAFunctionInTheLibrary() throws {
        let signatures = try ShaderSignatureManifest.load()
        var unresolved = 0

        for declaration in try ShaderBindingSourceScanner.scanDeclarations()
        where signatures[declaration.functionName] == nil {
            unresolved += 1
            XCTFail(
                "\(declaration.file):\(declaration.line): no [[stitchable]] function named "
                + "'\(declaration.functionName)' exists in default.metallib. "
                + "Every site applying this binding draws nothing."
            )
        }
        print("[binding] unresolved function names: \(unresolved)")
    }

    // MARK: - Defect class 2: the wrong effect kind

    /// The binding's type decides which `View` effect method the applier
    /// compiles to, so declaring a distortion function as `ShaderBinding.Color`
    /// is the old wrong-effect-method defect in its new home.
    func testEveryBindingDeclaresTheKindItsFunctionDeclares() throws {
        let signatures = try ShaderSignatureManifest.load()
        var misdeclared = 0

        for declaration in try ShaderBindingSourceScanner.scanDeclarations() {
            guard let signature = signatures[declaration.functionName],
                  signature.kind != Self.manifestKind[declaration.kindType]
            else { continue }

            misdeclared += 1
            XCTFail(
                "\(declaration.file):\(declaration.line): '\(declaration.functionName)' is a "
                + "\(signature.kind) (returns \(signature.returnType)) but is declared as "
                + "ShaderBinding.\(declaration.kindType)."
            )
        }
        print("[binding] wrong effect kind: \(misdeclared)")
    }

    private static let manifestKind: [String: String] = [
        "Color": "colorEffect",
        "Distortion": "distortionEffect",
        "Layer": "layerEffect",
    ]

    // MARK: - Defect class 3: the wrong geometry

    /// The declared geometry decides what the module prepends, so a wrong
    /// declaration re-creates the missing-`.boundingRect` bug at one site
    /// instead of two hundred. The yardstick is the manifest, not the
    /// declaration: by library convention a first explicit parameter of
    /// `float4` is a bounding rect and one of `float2` is the view size —
    /// exactly the split Phase 0.6 measured (144 / 85 / 27) — so the derived
    /// geometry is independent of the code under test.
    func testEveryBindingDeclaresTheGeometryItsFunctionDeclares() throws {
        let signatures = try ShaderSignatureManifest.load()
        var misdeclared = 0

        for declaration in try ShaderBindingSourceScanner.scanDeclarations() {
            // Name and kind defects have their own tests; skipping them here
            // keeps the classes a partition rather than an overlap.
            guard let signature = signatures[declaration.functionName],
                  signature.kind == Self.manifestKind[declaration.kindType]
            else { continue }
            let derived = Self.derivedGeometry(of: signature)
            guard declaration.geometry != derived else { continue }

            misdeclared += 1
            XCTFail(
                "\(declaration.file):\(declaration.line): '\(declaration.functionName)' has "
                + "first explicit parameter "
                + "\(signature.parameters.suffix(signature.explicitArgumentCount).first ?? "none"), "
                + "so its geometry is .\(derived), but the binding declares .\(declaration.geometry)."
            )
        }
        print("[binding] wrong geometry: \(misdeclared)")
    }

    private static func derivedGeometry(of signature: ShaderSignature) -> String {
        switch signature.parameters.suffix(signature.explicitArgumentCount).first {
        case "float4": return "boundingRect"
        case "float2": return "viewSize"
        default: return "plain"
        }
    }

    /// How many arguments the module prepends for a geometry.
    private static func prefixCount(ofGeometry geometry: String) -> Int {
        geometry == "plain" ? 0 : 1
    }

    // MARK: - Defect class 4: the argument count is wrong

    /// SwiftUI supplies only `position` (plus `color` or `layer`), and the
    /// module supplies the geometry prefix; everything else is the site's to
    /// pass. When the count is short every argument slides one position left
    /// and the shader reads a neighbouring uniform.
    func testEveryApplicationSitePassesTheNumberOfArgumentsItsFunctionExpects() throws {
        let signatures = try ShaderSignatureManifest.load()
        let declarations = try Self.declarationsByReference()
        var mismatched = 0
        var unresolved: [String] = []

        for site in try ShaderBindingSourceScanner.scanApplications() {
            guard let declaration = declarations["\(site.family).\(site.property)"] else {
                unresolved.append(site.description)
                continue
            }
            // Declaration-level defects have their own tests above.
            guard let signature = signatures[declaration.functionName],
                  signature.kind == Self.manifestKind[declaration.kindType]
            else { continue }
            let derived = Self.derivedGeometry(of: signature)
            guard declaration.geometry == derived else { continue }

            let expected = signature.explicitArgumentCount - Self.prefixCount(ofGeometry: derived)
            guard site.argumentKinds.count != expected else { continue }

            mismatched += 1
            XCTFail(
                "\(site.file):\(site.line): '\(declaration.functionName)' expects \(expected) "
                + "site argument(s) after the module-supplied prefix but the site passes "
                + "\(site.argumentKinds.count) (\(site.argumentKinds.joined(separator: ", ")))."
            )
        }
        XCTAssertEqual(
            unresolved, [],
            "These sites reference a binding the declaration scanner did not find, "
            + "so nothing checked them."
        )
        print("[binding] argument-count mismatches: \(mismatched)")
    }

    // MARK: - Defect class 5: the argument type is wrong

    /// A site can pass the right *number* of arguments and still be unbindable
    /// — the 28 `half3` sites Phase 2 found were exactly this. The manifest
    /// carries the declared parameter types, so each site argument is compared
    /// against the type at its position (after the module-supplied prefix).
    func testEveryApplicationSitePassesArgumentsOfTheDeclaredTypes() throws {
        let signatures = try ShaderSignatureManifest.load()
        let declarations = try Self.declarationsByReference()
        var mistyped = 0
        var unchecked: [String] = []

        for site in try ShaderBindingSourceScanner.scanApplications() {
            guard let declaration = declarations["\(site.family).\(site.property)"],
                  let signature = signatures[declaration.functionName],
                  signature.kind == Self.manifestKind[declaration.kindType]
            else { continue }
            let derived = Self.derivedGeometry(of: signature)
            let expected = signature.explicitArgumentCount - Self.prefixCount(ofGeometry: derived)
            guard declaration.geometry == derived, site.argumentKinds.count == expected else { continue }

            let declared = signature.parameters
                .suffix(signature.explicitArgumentCount)
                .dropFirst(Self.prefixCount(ofGeometry: derived))
            var wrong: [String] = []
            for (index, kind) in site.argumentKinds.enumerated() {
                guard let supplied = Self.typeSupplied[kind] else {
                    unchecked.append("\(site.file):\(site.line) argument \(index) is .\(kind)")
                    continue
                }
                let declaredType = declared[declared.startIndex + index]
                guard supplied != declaredType else { continue }
                wrong.append("argument \(index) is declared \(declaredType) but .\(kind) supplies \(supplied)")
            }
            guard !wrong.isEmpty else { continue }

            mistyped += 1
            XCTFail(
                "\(site.file):\(site.line): '\(declaration.functionName)' — "
                + wrong.joined(separator: "; ") + "."
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

    // MARK: - Per-site sampling

    /// A `.perSite` binding has no offset of its own, so a site that forgets
    /// `maxSampleOffset:` falls into the applier's debug assertion at render
    /// time. This catches it earlier, with a `file:line`.
    func testEverySiteOfAPerSiteBindingPassesItsSampleOffset() throws {
        let declarations = try Self.declarationsByReference()
        var missing = 0

        for site in try ShaderBindingSourceScanner.scanApplications() {
            guard let declaration = declarations["\(site.family).\(site.property)"],
                  declaration.sampling == "perSite",
                  !site.overridesSampleOffset
            else { continue }

            missing += 1
            XCTFail(
                "\(site.file):\(site.line): '\(declaration.functionName)' is declared "
                + ".perSite (\(declaration.file):\(declaration.line)) but this site passes "
                + "no maxSampleOffset:."
            )
        }
        print("[binding] perSite sites missing an offset: \(missing)")
    }

    // MARK: - The registry lists what the sources declare

    /// The compile oracle below enumerates `ShaderBindingRegistry`, so a
    /// declared-but-unregistered binding would silently escape it. The
    /// declarations scanned from source are the independent yardstick.
    func testRegistryListsEveryDeclaredBinding() throws {
        let declared = try ShaderBindingSourceScanner.scanDeclarations()
        let registered = ShaderBindingRegistry.all

        let declaredNames = declared.map(\.functionName).sorted()
        let registeredNames = registered.map(\.descriptor.name).sorted()
        XCTAssertEqual(
            registeredNames.count, Set(registeredNames).count,
            "Two registered bindings share a function name; the oracle's lookup "
            + "would silently test only one of them."
        )
        XCTAssertEqual(
            declaredNames, registeredNames,
            "ShaderBindingRegistry disagrees with the declarations in source. "
            + "Missing from the registry: "
            + Set(declaredNames).subtracting(registeredNames).sorted().joined(separator: ", ")
            + ". Registered but not declared: "
            + Set(registeredNames).subtracting(declaredNames).sorted().joined(separator: ", ")
            + ". Check the family's `bindings` array and ShaderBindingRegistry.families."
        )
    }

    // MARK: - The first-party oracle

    /// `Shader.compile(as:)` is Apple's own validation of a binding, and the
    /// only check that sees argument *types* rather than counts. Each probe is
    /// assembled by the binding's own `makeShader`, so the geometry prefix the
    /// oracle verifies is the one production applies — not a re-derivation.
    ///
    /// macOS 15 / iOS 18 only, so it is gated rather than assumed.
    func testEveryApplicationSiteCompiles() async throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, visionOS 2.0, *) else {
            throw XCTSkip("Shader.compile(as:) requires macOS 15 / iOS 18.")
        }
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("No Metal device in this test process.")
        }
        try await compileEveryApplicationSite()
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, visionOS 2.0, *)
    private func compileEveryApplicationSite() async throws {
        let declarations = try Self.declarationsByReference()
        let bindings = Dictionary(
            ShaderBindingRegistry.all.map { ($0.descriptor.name, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var rejections: [String] = []
        var unrepresentable: [String] = []
        var probed = 0

        for site in try ShaderBindingSourceScanner.scanApplications() {
            guard let declaration = declarations["\(site.family).\(site.property)"],
                  let binding = bindings[declaration.functionName]
            else {
                unrepresentable.append("\(site.file):\(site.line) unresolved binding")
                continue
            }
            guard let arguments = try? site.argumentKinds.map(Self.placeholderArgument(for:)) else {
                unrepresentable.append("\(site.file):\(site.line) unsupported argument kind")
                continue
            }
            probed += 1

            let shader = binding.makeShader(
                arguments: arguments,
                proxySize: CGSize(width: 100, height: 100)
            )
            do {
                try await shader.compile(as: binding.descriptor.kind.usageType)
            } catch {
                rejections.append(
                    "\(site.file):\(site.line): '\(declaration.functionName)' as "
                    + ".\(binding.descriptor.kind.rawValue) with \(site.argumentKinds.count) "
                    + "site argument(s): "
                    + error.localizedDescription.split(separator: "\n")
                        .map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: " ")
                )
            }
        }

        XCTAssertEqual(
            unrepresentable, [],
            "These sites could not be probed, so compile(as:) says nothing about them."
        )
        // Reported as one aggregate failure rather than one per site: when this
        // test raised an issue per rejection, XCTest's console reporter printed
        // only 85 of 157: the visible count silently understated the damage.
        if !rejections.isEmpty {
            XCTFail(
                "Shader.compile(as:) rejected \(rejections.count) of \(probed) application sites:\n"
                + rejections.joined(separator: "\n")
            )
        }
        print("[binding] rejected by Shader.compile(as:): \(rejections.count) of \(probed)")
    }

    /// A stand-in argument of the right *type* for each `Shader.Argument`
    /// factory a site uses. `compile(as:)` checks types and arity, not
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

    private static func declarationsByReference() throws -> [String: ShaderBindingDeclarationSite] {
        try Dictionary(
            ShaderBindingSourceScanner.scanDeclarations().map { ("\($0.family).\($0.property)", $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

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
        //
        // `.h` is checked alongside `.metal`: SwiftShadersCommon.h defines the
        // hashes, luminance and value noise that most shaders are built from, so
        // an edit to it that never reached the metallib is exactly as invisible
        // as an edit to a `.metal` file.
        let sourceExtensions: Set<String> = ["metal", "h"]

        var recovered: [String: URL] = [:]
        let walk = FileManager.default.enumerator(at: extracted, includingPropertiesForKeys: nil)
        while let url = walk?.nextObject() as? URL {
            if sourceExtensions.contains(url.pathExtension) {
                recovered[url.lastPathComponent] = url
            }
        }

        let metalDirectory = root.appendingPathComponent("Sources/SwiftShaders/Metal")
        let onDisk = try FileManager.default
            .contentsOfDirectory(at: metalDirectory, includingPropertiesForKeys: nil)
            .filter { sourceExtensions.contains($0.pathExtension) }

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
private extension ShaderBinding.Kind {
    var usageType: Shader.UsageType {
        switch self {
        case .colorEffect: return .colorEffect
        case .distortionEffect: return .distortionEffect
        case .layerEffect: return .layerEffect
        }
    }
}
