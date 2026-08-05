import XCTest
import SwiftShadersGalleryCore

/// The README makes claims about the library. These check them.
///
/// It claimed "34 Production-Ready Metal Shaders" in three places, through every
/// phase of the remediation, while the package held 256 Metal functions and 226
/// view modifiers — and its opening example called `.hologram()`, `.glitch()`,
/// `.ripple()` and `.fire()`, none of which exist. Nothing could have noticed:
/// documentation is not compiled.
///
/// So the counts in the README's "By the numbers" table are parsed out of the
/// file and compared with the same sources the other tests use, and every effect
/// method named in a Swift code fence has to resolve.
final class ReadmeClaimsTests: XCTestCase {

    /// Row label → the value it must state.
    ///
    /// Keyed on a distinctive fragment of the row's first column so that
    /// rewording the prose does not silently disable the check — if the fragment
    /// stops matching, the row is reported missing.
    private func expectedCounts() throws -> [(fragment: String, value: Int)] {
        let methods = try PublicViewMethodScanner.scanSources()
        let bindings = try ShaderBindingSourceScanner.scanDeclarations()
        let manifest = try ShaderSignatureManifest.load()
        let bound = Set(bindings.map(\.functionName))

        return [
            ("Metal functions in", manifest.count),
            ("reachable through a", bindings.count),
            ("no binding, listed in", manifest.keys.filter { !bound.contains($0) }.count),
            ("Public `View` effect methods", methods.count),
            ("previewable in the Gallery", EffectCatalog.all.count),
            ("zero-argument presets", EffectCoverage.presetBases.count),
            ("no Gallery entry yet", EffectCoverage.absent.count),
            ("Metal source files", try Self.metalSourceCount()),
        ]
    }

    func testTheByTheNumbersTableIsTrue() throws {
        let rows = try Self.readme()
            .split(separator: "\n")
            .filter { $0.hasPrefix("|") }

        for (fragment, value) in try expectedCounts() {
            guard let row = rows.first(where: { $0.contains(fragment) }) else {
                XCTFail("README has no 'By the numbers' row matching “\(fragment)”")
                continue
            }
            let stated = row
                .split(separator: "|")
                .compactMap { Int($0.trimmingCharacters(in: CharacterSet(charactersIn: " *"))) }
                .first

            XCTAssertEqual(
                stated, value,
                "README row “\(fragment)” states \(stated.map(String.init) ?? "no number"), "
                + "but the sources say \(value)."
            )
        }
    }

    /// Every effect method a Swift code fence calls must exist. The README is
    /// the first code a user copies.
    func testEveryEffectCalledInACodeFenceExists() throws {
        let known = Set(try PublicViewMethodScanner.scanSources().map(\.name))
        var unknown: [String] = []

        for fence in Self.swiftFences(in: try Self.readme()) {
            for call in Self.methodCalls(in: fence)
            where !known.contains(call) && !Self.nonSwiftShadersCalls.contains(call) {
                unknown.append(call)
            }
        }

        XCTAssertEqual(
            Set(unknown).sorted(), [],
            "README code calls effects that do not exist: \(Set(unknown).sorted()). "
            + "Either the method was renamed, or the example was never real."
        )
    }

    /// Calls in the README's examples that are not SwiftShaders effects — SwiftUI,
    /// Foundation and SwiftPM. Listed explicitly so a new fabricated effect name
    /// cannot hide among them.
    private static let nonSwiftShadersCalls: Set<String> = [
        "resizable", "scaledToFit", "gesture", "distance", "package",
    ]

    /// The old count claim must not come back. Three separate places said 34.
    func testTheOldShaderCountClaimIsGone() throws {
        let readme = try Self.readme()

        XCTAssertFalse(readme.contains("34 Production-Ready"), "README still claims 34 shaders.")
        XCTAssertFalse(readme.contains("34 production-ready"), "README still claims 34 shaders.")
        XCTAssertFalse(readme.contains("All 34 Shaders"), "README still claims 34 shaders.")
    }

    // MARK: - Reading

    private static func readme() throws -> String {
        try String(
            contentsOf: ShaderCallSiteScanner.repositoryRoot.appendingPathComponent("README.md"),
            encoding: .utf8
        )
    }

    private static func metalSourceCount() throws -> Int {
        let metal = ShaderCallSiteScanner.repositoryRoot
            .appendingPathComponent("Sources/SwiftShaders/Metal")
        return try FileManager.default
            .contentsOfDirectory(atPath: metal.path)
            .filter { $0.hasSuffix(".metal") }
            .count
    }

    private static func swiftFences(in markdown: String) -> [String] {
        var fences: [String] = []
        var current: String?
        for line in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("```swift") {
                current = ""
            } else if line.hasPrefix("```") {
                if let fence = current { fences.append(fence) }
                current = nil
            } else if current != nil {
                current! += line + "\n"
            }
        }
        return fences
    }

    /// `.methodName(` occurrences — the shape every effect application takes.
    private static func methodCalls(in source: String) -> [String] {
        var calls: [String] = []
        let characters = Array(source)
        var index = 0
        while index < characters.count {
            defer { index += 1 }
            guard characters[index] == "." else { continue }
            // `.sepia` but not `0.5` or `Date.now`: a call follows an
            // expression, and only a lowercase identifier starts a method name.
            if index > 0, characters[index - 1].isNumber { continue }
            var cursor = index + 1
            var name = ""
            while cursor < characters.count,
                  characters[cursor].isLetter || characters[cursor].isNumber || characters[cursor] == "_" {
                name.append(characters[cursor])
                cursor += 1
            }
            guard !name.isEmpty,
                  let first = name.first, first.isLowercase,
                  cursor < characters.count, characters[cursor] == "("
            else { continue }
            calls.append(name)
        }
        return calls
    }
}
