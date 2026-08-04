import Foundation
// `Bundle.module` is generated as internal to the SwiftShaders target; the
// resource bundle is only reachable from tests through a testable import.
@testable import SwiftShaders

/// One `[[stitchable]]` function as it exists in the compiled metallib.
struct ShaderSignature: Equatable {
    let name: String
    /// `colorEffect`, `distortionEffect`, `layerEffect` or `shapeStyle`.
    let kind: String
    let returnType: String
    /// Parameters the Swift caller must supply — the declared parameters minus
    /// the ones SwiftUI fills in implicitly for this effect kind.
    let explicitArgumentCount: Int
    /// Every parameter including the implicit ones, in declaration order, with
    /// `SwiftUI::Layer` collapsed back into a single `layer`.
    let parameters: [String]
}

/// Reads `shader-signatures.tsv`, generated from the metallib by
/// `Scripts/extract-metal-signatures.py`.
///
/// The manifest exists because Metal offers no way to ask a compiled
/// `[[stitchable]]` function what it takes: `MTLFunction` has no parameter
/// list, and a visible function cannot back a compute pipeline, so
/// `MTLComputePipelineReflection` is unreachable. Disassembling once at build
/// time and checking the result in is the only route to a machine-readable
/// signature.
enum ShaderSignatureManifest {

    enum LoadError: Error, CustomStringConvertible {
        case resourceMissing
        case malformedRow(line: Int, contents: String)

        var description: String {
            switch self {
            case .resourceMissing:
                return """
                shader-signatures.tsv is missing from the SwiftShaders resource bundle.
                Regenerate it with `./Scripts/extract-metal-signatures.py` (or `make shaders`).
                """
            case let .malformedRow(line, contents):
                return "shader-signatures.tsv line \(line) is malformed: \(contents)"
            }
        }
    }

    /// Signatures keyed by function name. Names are unique across the metallib —
    /// the generator fails rather than emit a duplicate.
    static func load() throws -> [String: ShaderSignature] {
        guard let url = Bundle.module.url(forResource: "shader-signatures", withExtension: "tsv") else {
            throw LoadError.resourceMissing
        }
        let rows = try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: true)

        var signatures: [String: ShaderSignature] = [:]
        for (offset, row) in rows.enumerated() where offset > 0 {  // skip the header
            let columns = row.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard columns.count == 5, let explicit = Int(columns[3]) else {
                throw LoadError.malformedRow(line: offset + 1, contents: String(row))
            }
            signatures[columns[0]] = ShaderSignature(
                name: columns[0],
                kind: columns[1],
                returnType: columns[2],
                explicitArgumentCount: explicit,
                parameters: columns[4].split(separator: ",").map(String.init)
            )
        }
        return signatures
    }
}
