import Foundation

/// One `static let <property> = ShaderBinding.<Kind>("<function>", …)`
/// declaration in the Swift sources.
struct ShaderBindingDeclarationSite: CustomStringConvertible, Equatable {
    let file: String
    let line: Int
    /// The enclosing `ShaderFamily` enum, e.g. `WaveShaderBindings`.
    let family: String
    let property: String
    let functionName: String
    /// `"Color"`, `"Distortion"`, or `"Layer"`.
    let kindType: String
    /// `"boundingRect"`, `"viewSize"`, or `"plain"`.
    let geometry: String
    /// `"fixed"`, `"viewSize"`, `"perSite"`, or nil for color bindings.
    let sampling: String?

    var description: String {
        "\(file):\(line) \(family).\(property) → \(functionName)"
    }
}

/// One `.shaderEffect(<Family>.<property>, …)` application site.
struct ShaderApplicationSite: CustomStringConvertible, Equatable {
    let file: String
    let line: Int
    let family: String
    let property: String
    /// The `Shader.Argument` factory of each effect-specific argument, in
    /// order. The module-supplied geometry prefix never appears here.
    let argumentKinds: [String]
    /// Whether the site passes `maxSampleOffset:` explicitly.
    let overridesSampleOffset: Bool

    var description: String {
        "\(file):\(line) \(family).\(property)(\(argumentKinds.joined(separator: ", ")))"
    }
}

/// Finds every binding declaration and every application site under
/// `Sources/`. The declarations are the yardstick `ShaderBindingRegistry` is
/// checked against — a registry test that only consulted the registry itself
/// could not notice a binding that was declared but never registered.
enum ShaderBindingSourceScanner {

    static func scanDeclarations() throws -> [ShaderBindingDeclarationSite] {
        try sourceFiles().flatMap { url -> [ShaderBindingDeclarationSite] in
            declarations(in: try contents(of: url), file: relativePath(of: url))
        }
    }

    static func scanApplications() throws -> [ShaderApplicationSite] {
        try sourceFiles().flatMap { url -> [ShaderApplicationSite] in
            applications(in: try contents(of: url), file: relativePath(of: url))
        }
    }

    // MARK: - Declarations

    static func declarations(in source: String, file: String) -> [ShaderBindingDeclarationSite] {
        let stripped = ShaderCallSiteScanner.strippingComments(from: source)
        var sites: [ShaderBindingDeclarationSite] = []
        var family = "?"
        for (offset, line) in stripped.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            if let match = line.firstMatch(of: #/enum\s+(\w+)\s*:\s*ShaderFamily/#) {
                family = String(match.1)
                continue
            }
            guard let match = line.firstMatch(
                of: #/static let (\w+)\s*=\s*ShaderBinding\.(Color|Distortion|Layer)\(\s*"(\w+)",\s*geometry:\s*\.(\w+)/#
            ) else { continue }
            let sampling = line.firstMatch(of: #/sampling:\s*\.(\w+)/#).map { String($0.1) }
            sites.append(
                ShaderBindingDeclarationSite(
                    file: file,
                    line: offset + 1,
                    family: family,
                    property: String(match.1),
                    functionName: String(match.3),
                    kindType: String(match.2),
                    geometry: String(match.4),
                    sampling: sampling
                )
            )
        }
        return sites
    }

    // MARK: - Application sites

    static func applications(in source: String, file: String) -> [ShaderApplicationSite] {
        let characters = Array(ShaderCallSiteScanner.strippingComments(from: source))
        var sites: [ShaderApplicationSite] = []
        var index = 0
        let token = Array(".shaderEffect")

        while index < characters.count {
            guard index + token.count < characters.count,
                  Array(characters[index..<(index + token.count)]) == token,
                  characters[index + token.count] == "("
            else {
                index += 1
                continue
            }
            let open = index + token.count
            guard let close = ShaderCallSiteScanner.indexAfterMatchingParenthesis(characters, openAt: open) else {
                index = open + 1
                continue
            }
            let arguments = ShaderCallSiteScanner.splitTopLevel(Array(characters[(open + 1)..<(close - 1)]))
            let line = characters[..<index].reduce(1) { $1 == "\n" ? $0 + 1 : $0 }

            // The first argument names the binding: `<Family>.<property>`.
            guard let head = arguments.first,
                  let match = head.wholeMatch(of: #/(\w+)\.(\w+)/#)
            else {
                index = close
                continue
            }
            var kinds: [String] = []
            var overrides = false
            for argument in arguments.dropFirst() {
                if argument.hasPrefix("maxSampleOffset:") {
                    overrides = true
                } else {
                    kinds.append(ShaderCallSiteScanner.argumentKind(of: argument))
                }
            }
            sites.append(
                ShaderApplicationSite(
                    file: file,
                    line: line,
                    family: String(match.1),
                    property: String(match.2),
                    argumentKinds: kinds,
                    overridesSampleOffset: overrides
                )
            )
            index = close
        }
        return sites
    }

    // MARK: - Files

    private static func sourceFiles() throws -> [URL] {
        let sources = ShaderCallSiteScanner.repositoryRoot.appendingPathComponent("Sources")
        let enumerator = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)
        var files: [URL] = []
        while let url = enumerator?.nextObject() as? URL {
            if url.pathExtension == "swift" { files.append(url) }
        }
        return files.sorted { $0.path < $1.path }
    }

    private static func contents(of url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    private static func relativePath(of url: URL) -> String {
        url.path.replacingOccurrences(
            of: ShaderCallSiteScanner.repositoryRoot.path + "/", with: ""
        )
    }
}
