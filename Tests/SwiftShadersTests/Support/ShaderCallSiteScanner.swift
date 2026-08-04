import Foundation

/// Which `View` method a shader is handed to. This decides how many parameters
/// SwiftUI fills in implicitly, so it is part of a call site's contract — the
/// same Metal function invoked through the wrong method is a defect even when
/// the argument count happens to line up.
enum ShaderEffectMethod: String {
    case color
    case distortion
    case layer
    case unknown

    /// The `kind` column of `shader-signatures.tsv`.
    var manifestKind: String {
        switch self {
        case .color: return "colorEffect"
        case .distortion: return "distortionEffect"
        case .layer: return "layerEffect"
        case .unknown: return "unknown"
        }
    }
}

/// One `ShaderLibrary.<accessor>.<function>(...)` expression in the Swift sources.
struct ShaderCallSite: CustomStringConvertible, Equatable {
    /// Repository-relative, so failure messages are clickable.
    let file: String
    let line: Int
    let functionName: String
    let effectMethod: ShaderEffectMethod
    /// The `Shader.Argument` factory used for each explicit argument, in order —
    /// `"float"`, `"float2"`, `"boundingRect"`, and so on.
    let argumentKinds: [String]

    var description: String {
        "\(file):\(line) \(functionName)(\(argumentKinds.joined(separator: ", ")))"
    }
}

/// Finds every shader call site in the Swift sources.
///
/// The bindings are `@dynamicMemberLookup` + `@dynamicCallable`, so neither the
/// function name nor the argument list is checked by the Swift compiler, and
/// nothing at runtime enumerates the call sites either — a shader is only
/// resolved when SwiftUI draws it. Reading the sources is the only way to get
/// the list of bindings to check.
enum ShaderCallSiteScanner {

    // MARK: - Scanning the repository

    /// Every call site under `Sources/`, ordered by file then line.
    static func scanSources() throws -> [ShaderCallSite] {
        let sources = repositoryRoot.appendingPathComponent("Sources")
        let enumerator = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)
        var files: [URL] = []
        while let url = enumerator?.nextObject() as? URL {
            if url.pathExtension == "swift" { files.append(url) }
        }
        return try files.sorted { $0.path < $1.path }.flatMap { url -> [ShaderCallSite] in
            let relative = url.path.replacingOccurrences(of: repositoryRoot.path + "/", with: "")
            return scan(source: try String(contentsOf: url, encoding: .utf8), file: relative)
        }
    }

    /// The package root, derived from this file's location at compile time:
    /// `<root>/Tests/SwiftShadersTests/Support/ShaderCallSiteScanner.swift`.
    static let repositoryRoot: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // Support
        .deletingLastPathComponent()   // SwiftShadersTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // <root>

    // MARK: - Scanning one file

    static func scan(source: String, file: String) -> [ShaderCallSite] {
        let characters = Array(strippingComments(from: source))
        var sites: [ShaderCallSite] = []
        var index = 0

        while index < characters.count {
            guard let call = matchCallHead(characters, at: index) else {
                index += 1
                continue
            }
            guard let close = indexAfterMatchingParenthesis(characters, openAt: call.openParenthesis) else {
                index = call.openParenthesis + 1
                continue
            }
            let arguments = splitTopLevel(Array(characters[(call.openParenthesis + 1)..<(close - 1)]))
            sites.append(
                ShaderCallSite(
                    file: file,
                    line: characters[..<index].reduce(1) { $1 == "\n" ? $0 + 1 : $0 },
                    functionName: call.functionName,
                    effectMethod: enclosingEffectMethod(characters, before: index),
                    argumentKinds: arguments.map(argumentKind(of:))
                )
            )
            index = close
        }
        return sites
    }

    // MARK: - Pieces

    /// Matches `ShaderLibrary.<accessor>.<function>(` starting at `index`.
    ///
    /// The accessor is not pinned to `swiftShaders`: a call site that reached
    /// the library by another route is still a binding that has to be correct,
    /// and a scanner that quietly skipped it would under-report.
    private static func matchCallHead(
        _ characters: [Character], at index: Int
    ) -> (functionName: String, openParenthesis: Int)? {
        let prefix = Array("ShaderLibrary.")
        guard index + prefix.count < characters.count,
              Array(characters[index..<(index + prefix.count)]) == prefix
        else { return nil }
        // A preceding identifier character means this is some longer name that
        // merely ends in "ShaderLibrary".
        if index > 0, isIdentifier(characters[index - 1]) { return nil }

        var cursor = index + prefix.count
        guard let accessor = readIdentifier(characters, from: &cursor), !accessor.isEmpty,
              cursor < characters.count, characters[cursor] == "."
        else { return nil }
        cursor += 1
        guard let function = readIdentifier(characters, from: &cursor), !function.isEmpty else { return nil }
        // Allow whitespace between the name and its argument list.
        while cursor < characters.count, characters[cursor].isWhitespace { cursor += 1 }
        guard cursor < characters.count, characters[cursor] == "(" else { return nil }
        return (function, cursor)
    }

    private static func readIdentifier(_ characters: [Character], from cursor: inout Int) -> String? {
        var identifier = ""
        while cursor < characters.count, isIdentifier(characters[cursor]) {
            identifier.append(characters[cursor])
            cursor += 1
        }
        return identifier.isEmpty ? nil : identifier
    }

    private static func isIdentifier(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
    }

    /// Index one past the `)` that closes the `(` at `openAt`.
    private static func indexAfterMatchingParenthesis(_ characters: [Character], openAt: Int) -> Int? {
        var depth = 0
        var index = openAt
        while index < characters.count {
            if characters[index] == "(" { depth += 1 }
            else if characters[index] == ")" {
                depth -= 1
                if depth == 0 { return index + 1 }
            }
            index += 1
        }
        return nil
    }

    /// Splits an argument list on commas that are not nested inside brackets.
    ///
    /// `.float2(Float(a.x), Float(a.y))` is one argument, not two. Getting this
    /// wrong inflates the argument count and turns a broken call site green.
    private static func splitTopLevel(_ characters: [Character]) -> [String] {
        var parts: [String] = []
        var depth = 0
        var current = ""
        for character in characters {
            if "([{".contains(character) { depth += 1 }
            else if ")]}".contains(character) { depth -= 1 }
            if character == "," && depth == 0 {
                parts.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        parts.append(current)
        return parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    /// The `Shader.Argument` factory an argument expression names.
    ///
    /// Longest match first, so `.float2(…)` is not read as `.float`.
    private static let argumentFactories = [
        "boundingRect", "blendMode", "colorArray", "floatArray",
        "float2", "float3", "float4", "float", "color", "image", "data",
    ]

    private static func argumentKind(of expression: String) -> String {
        guard expression.hasPrefix(".") else { return expression }
        let body = expression.dropFirst()
        for factory in argumentFactories.sorted(by: { $0.count > $1.count }) where body.hasPrefix(factory) {
            let next = body.dropFirst(factory.count).first
            if next == nil || !isIdentifier(next!) { return factory }
        }
        return String(body.prefix { isIdentifier($0) })
    }

    /// Effect methods, longest first so `.layerEffect` is not read as a prefix
    /// of anything shorter.
    private static let effectMethods: [(token: String, method: ShaderEffectMethod)] = [
        (".distortionEffect", .distortion),
        (".colorEffect", .color),
        (".layerEffect", .layer),
    ]

    /// The innermost effect method enclosing a call site.
    ///
    /// Shader calls sit inside the effect method's parentheses, so the nearest
    /// preceding one is the enclosing one. The window is bounded because a
    /// modifier body far above is not this call's method.
    private static func enclosingEffectMethod(_ characters: [Character], before index: Int) -> ShaderEffectMethod {
        let window = String(characters[max(0, index - lookbehind)..<index])
        var best: (offset: String.Index, method: ShaderEffectMethod)?
        for (token, method) in effectMethods {
            guard let range = window.range(of: token, options: .backwards) else { continue }
            if best == nil || range.lowerBound > best!.offset {
                best = (range.lowerBound, method)
            }
        }
        return best?.method ?? .unknown
    }

    private static let lookbehind = 400

    // MARK: - Comments

    /// Blanks out comments while preserving every offset and newline, so line
    /// numbers computed on the result still point at the original source.
    static func strippingComments(from source: String) -> String {
        var output = ""
        output.reserveCapacity(source.count)
        let characters = Array(source)
        var index = 0

        while index < characters.count {
            if characters[index] == "/", index + 1 < characters.count, characters[index + 1] == "*" {
                var depth = 1
                var scan = index + 2
                output += "  "
                while scan < characters.count, depth > 0 {
                    if characters[scan] == "/", scan + 1 < characters.count, characters[scan + 1] == "*" {
                        depth += 1
                        output += "  "
                        scan += 2
                    } else if characters[scan] == "*", scan + 1 < characters.count, characters[scan + 1] == "/" {
                        depth -= 1
                        output += "  "
                        scan += 2
                    } else {
                        output.append(characters[scan] == "\n" ? "\n" : " ")
                        scan += 1
                    }
                }
                index = scan
            } else if characters[index] == "/", index + 1 < characters.count, characters[index + 1] == "/" {
                while index < characters.count, characters[index] != "\n" {
                    output.append(" ")
                    index += 1
                }
            } else if characters[index] == "\"" {
                // String literals are copied verbatim; a `//` inside one is not
                // a comment. Multi-line literals are handled by the same walk.
                output.append(characters[index])
                index += 1
                while index < characters.count {
                    if characters[index] == "\\", index + 1 < characters.count {
                        output.append(characters[index])
                        output.append(characters[index + 1])
                        index += 2
                        continue
                    }
                    output.append(characters[index])
                    index += 1
                    if characters[index - 1] == "\"" || characters[index - 1] == "\n" { break }
                }
            } else {
                output.append(characters[index])
                index += 1
            }
        }
        return output
    }
}
