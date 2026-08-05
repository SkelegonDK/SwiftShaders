import Foundation

/// One publicly visible `func` declared in an `extension View` block in
/// `Sources/` — either because the extension is `public` or because the member
/// itself is.
struct PublicViewMethod: Equatable, Comparable, CustomStringConvertible {
    /// Name plus argument labels, e.g. `vignette(radius:softness:intensity:)`.
    /// This is the identity an effect actually has: four of the library's method
    /// *names* are declared twice, in different files, and only the labels tell
    /// them apart.
    let selector: String
    let name: String
    /// Repository-relative, so failure messages are clickable.
    let file: String
    let line: Int
    /// One per parameter, in order. `_` for an unlabelled parameter.
    let labels: [String]
    /// Indices of the parameters that have a default value, and may therefore be
    /// left out at a call site.
    let defaultedParameters: Set<Int>

    var description: String { "\(file):\(line) \(selector)" }

    /// Every argument-label list a caller can write for this method.
    ///
    /// A defaulted parameter may be omitted independently of the others — Swift
    /// does not require the omissions to be trailing — so this is the power set
    /// of the defaulted positions. It is what makes two overloads of one name
    /// *ambiguous* rather than merely similarly named: overlapping shapes mean a
    /// call that both could serve, resolved by a tiebreaker the caller never
    /// sees.
    var acceptedCallShapes: Set<[String]> {
        var shapes: Set<[String]> = []
        let optional = defaultedParameters.sorted()
        for mask in 0..<(1 << optional.count) {
            var omitted: Set<Int> = []
            for (bit, index) in optional.enumerated() where mask & (1 << bit) != 0 {
                omitted.insert(index)
            }
            shapes.insert(labels.indices.filter { !omitted.contains($0) }.map { labels[$0] })
        }
        return shapes
    }

    static func < (lhs: PublicViewMethod, rhs: PublicViewMethod) -> Bool {
        (lhs.selector, lhs.file, lhs.line) < (rhs.selector, rhs.file, rhs.line)
    }
}

/// Finds every public `View` effect method in the library sources.
///
/// The public surface of SwiftShaders *is* this set of methods: there is no
/// registry to enumerate, and nothing at runtime can list them, because they are
/// static extension members. Reading the sources is the only way to get the list
/// the coverage ledger has to account for — the same reason
/// `ShaderCallSiteScanner` exists.
///
/// The scanner must not derive its answer the way the thing it guards does, or
/// the guard is worthless (Phase 6's lesson). So it is paired with
/// ``rawDeclarationCount(source:file:)``, which counts declarations by line
/// shape alone, with no brace matching and no knowledge of extension blocks; the
/// tests assert the two agree.
enum PublicViewMethodScanner {

    // MARK: - Scanning the repository

    static func scanSources() throws -> [PublicViewMethod] {
        try swiftFiles().flatMap { url -> [PublicViewMethod] in
            let relative = url.path.replacingOccurrences(
                of: ShaderCallSiteScanner.repositoryRoot.path + "/", with: ""
            )
            return scan(source: try String(contentsOf: url, encoding: .utf8), file: relative)
        }
        .sorted()
    }

    /// The raw yardstick over the same files. See ``rawDeclarationCount(source:file:)``.
    static func rawDeclarationCount() throws -> Int {
        try swiftFiles().reduce(0) { total, url in
            total + rawDeclarationCount(source: try String(contentsOf: url, encoding: .utf8))
        }
    }

    private static func swiftFiles() throws -> [URL] {
        let sources = ShaderCallSiteScanner.repositoryRoot
            .appendingPathComponent("Sources/SwiftShaders")
        let enumerator = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)
        var files: [URL] = []
        while let url = enumerator?.nextObject() as? URL {
            if url.pathExtension == "swift" { files.append(url) }
        }
        return files.sorted { $0.path < $1.path }
    }

    // MARK: - The structural scan

    /// Enters **every** `extension View` block, `public` or not.
    ///
    /// Matching the exact literal `public extension View` was a hole big enough
    /// to drive an effect through: `extension View { public func … }` declares
    /// exactly as much public API as `public extension View { func … }` does,
    /// and the scanner never opened the block. So the block is entered either
    /// way, and publicness is decided per member: the extension's `public`
    /// applies to all its members, and a member may carry its own.
    static func scan(source: String, file: String) -> [PublicViewMethod] {
        let characters = Array(ShaderCallSiteScanner.strippingComments(from: source))
        var methods: [PublicViewMethod] = []

        for start in occurrences(of: Array(extensionHeader), in: characters) {
            guard isExtensionOfView(characters, at: start),
                  let brace = indexOfOpeningBrace(characters, from: start + extensionHeader.count),
                  let end = indexAfterMatchingBrace(characters, openAt: brace)
            else { continue }
            methods += scanBody(
                characters, from: brace, to: end, file: file,
                membersArePublic: isPublicExtension(characters, endingBefore: start)
            )
        }
        return methods
    }

    private static let extensionHeader = "extension View"

    /// Rejects the two ways the literal `extension View` can appear without
    /// being a `View` extension header: as the tail of a longer identifier, and
    /// as the prefix of `extension ViewModifier` / `extension ViewBuilder`.
    private static func isExtensionOfView(_ characters: [Character], at start: Int) -> Bool {
        if start > 0, isIdentifier(characters[start - 1]) { return false }
        let after = start + extensionHeader.count
        return after >= characters.count || !isIdentifier(characters[after])
    }

    /// Whether `public` is the modifier immediately preceding the `extension`
    /// keyword, in which case every member of the block is public.
    ///
    /// Attributes above the declaration end in `)` or a newline, neither of
    /// which is an identifier character, so `@available(…) extension View` is
    /// correctly read as non-public.
    private static func isPublicExtension(_ characters: [Character], endingBefore start: Int) -> Bool {
        var cursor = start - 1
        while cursor >= 0, characters[cursor].isWhitespace { cursor -= 1 }
        var word = ""
        while cursor >= 0, isIdentifier(characters[cursor]) {
            word.insert(characters[cursor], at: word.startIndex)
            cursor -= 1
        }
        return word == "public"
    }

    private static func scanBody(
        _ characters: [Character], from start: Int, to end: Int, file: String,
        membersArePublic: Bool
    ) -> [PublicViewMethod] {
        var methods: [PublicViewMethod] = []
        var index = start

        while index < end {
            guard let head = matchFunctionHead(characters, at: index, limit: end) else {
                index += 1
                continue
            }
            guard let close = ShaderCallSiteScanner.indexAfterMatchingParenthesis(
                characters, openAt: head.openParenthesis
            ) else {
                index = head.openParenthesis + 1
                continue
            }
            guard membersArePublic || declaresPublic(characters, before: index) else {
                index = close
                continue
            }
            let parameters = ShaderCallSiteScanner.splitTopLevel(
                Array(characters[(head.openParenthesis + 1)..<(close - 1)])
            )
            let labels = parameters.map(label(ofParameter:))
            let defaulted = parameters.indices.filter { parameters[$0].contains("=") }
            methods.append(
                PublicViewMethod(
                    selector: head.name + "(" + labels.map { $0 + ":" }.joined() + ")",
                    name: head.name,
                    file: file,
                    line: characters[..<index].reduce(1) { $1 == "\n" ? $0 + 1 : $0 },
                    labels: labels,
                    defaultedParameters: Set(defaulted)
                )
            )
            index = close
        }
        return methods
    }

    /// Whether the declaration whose `func` keyword is at `funcKeyword` carries
    /// `public` among its modifiers.
    ///
    /// Access modifiers sit on the declaration's own line in every style this
    /// package uses — `public func`, `@discardableResult public func` — so the
    /// line prefix is the whole search space.
    private static func declaresPublic(_ characters: [Character], before funcKeyword: Int) -> Bool {
        var cursor = funcKeyword - 1
        var modifiers: [Character] = []
        while cursor >= 0, characters[cursor] != "\n" {
            modifiers.append(characters[cursor])
            cursor -= 1
        }
        return String(modifiers.reversed())
            .split(whereSeparator: { !isIdentifier($0) })
            .contains("public")
    }

    /// Matches `func <name>(` — optionally preceded by `public`, and rejecting
    /// generic declarations, which in this library are helpers such as
    /// `shaderIf<T: View>(_:transform:)` rather than effects.
    private static func matchFunctionHead(
        _ characters: [Character], at index: Int, limit: Int
    ) -> (name: String, openParenthesis: Int)? {
        let keyword = Array("func ")
        guard index + keyword.count < limit,
              Array(characters[index..<(index + keyword.count)]) == keyword
        else { return nil }
        if index > 0, isIdentifier(characters[index - 1]) { return nil }

        var cursor = index + keyword.count
        while cursor < limit, characters[cursor].isWhitespace { cursor += 1 }
        var name = ""
        while cursor < limit, isIdentifier(characters[cursor]) {
            name.append(characters[cursor])
            cursor += 1
        }
        guard !name.isEmpty, cursor < limit, characters[cursor] == "(" else { return nil }
        return (name, cursor)
    }

    /// The argument label of one parameter declaration: `at center: CGPoint` → `at`,
    /// `radius: Float = 1` → `radius`, `_ value: Float` → `_`.
    private static func label(ofParameter declaration: String) -> String {
        String(declaration.prefix { isIdentifier($0) || $0 == "_" })
    }

    private static func isIdentifier(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
    }

    /// Index one past the `}` that closes the `{` at `openAt`.
    private static func indexAfterMatchingBrace(_ characters: [Character], openAt: Int) -> Int? {
        var depth = 0
        var index = openAt
        while index < characters.count {
            if characters[index] == "{" { depth += 1 }
            else if characters[index] == "}" {
                depth -= 1
                if depth == 0 { return index + 1 }
            }
            index += 1
        }
        return nil
    }

    /// The `{` opening the body of the extension whose header ends at `index`.
    ///
    /// A `where` clause may stand between the extended type and the body —
    /// `extension View where Self: Equatable { … }` — and bailing on it made
    /// the whole block invisible. Anything else between the two is not a header
    /// this scanner understands, and is refused rather than guessed at.
    private static func indexOfOpeningBrace(_ characters: [Character], from index: Int) -> Int? {
        var cursor = index
        while cursor < characters.count {
            if characters[cursor] == "{" { return cursor }
            if !characters[cursor].isWhitespace {
                guard startsWord(characters, at: cursor, "where") else { return nil }
                return characters[cursor...].firstIndex(of: "{")
            }
            cursor += 1
        }
        return nil
    }

    private static func startsWord(_ characters: [Character], at index: Int, _ word: String) -> Bool {
        let letters = Array(word)
        guard index + letters.count <= characters.count,
              Array(characters[index..<(index + letters.count)]) == letters
        else { return false }
        let after = index + letters.count
        return after >= characters.count || !isIdentifier(characters[after])
    }

    private static func occurrences(of needle: [Character], in characters: [Character]) -> [Int] {
        guard !needle.isEmpty, characters.count >= needle.count else { return [] }
        var found: [Int] = []
        for start in 0...(characters.count - needle.count)
        where Array(characters[start..<(start + needle.count)]) == needle {
            found.append(start)
        }
        return found
    }

    // MARK: - The raw yardstick

    /// Declarations counted by line shape alone: a line that begins with exactly
    /// four spaces and `func ` — or four spaces, `public`, `func ` — minus the
    /// handful of names that are known not to be effects.
    ///
    /// Both shapes are counted because both declare API. Counting only the
    /// unqualified one meant a `public func` inside a plain `extension View`
    /// was missed by the yardstick *and* by the structural scan, so the two
    /// agreed on a number that was wrong — the failure mode this pairing exists
    /// to prevent.
    ///
    /// This shares nothing with the structural scan — no comment stripping, no
    /// brace matching, no notion of an extension block — so the two agreeing is
    /// evidence rather than a tautology. If someone adds a member to a
    /// `View` extension the structural scan cannot see, this count still rises
    /// and the test goes red.
    ///
    /// The exclusions are named individually rather than pattern-matched, so
    /// adding a new non-effect helper is a deliberate, reviewable edit here.
    static let nonEffectMembers: Set<String> = [
        "makeShader",   // ShaderBinding — assembles the Shader, not a View method
        "shaderEffect", // ShaderBinding — the internal applier, one per effect kind
        "clamped",      // three copies of a numeric helper on Double/Comparable
        "shaderIf",     // ShaderView — conditional wrapper, applies no shader
        "elapsed",      // ShaderClock — time conversion, not a View method
        "body",         // every ViewModifier's requirement, one per effect type
        "update",       // MetalHelpers — frame-rate counter
        "reset",        // MetalHelpers — frame-rate counter
    ]

    static func rawDeclarationCount(source: String) -> Int {
        source.split(separator: "\n", omittingEmptySubsequences: false).reduce(0) { total, line in
            guard let name = declaredName(onLine: line) else { return total }
            return nonEffectMembers.contains(name) ? total : total + 1
        }
    }

    /// The name declared by a line of exactly the shape `    func x(` or
    /// `    public func x(` — four spaces, no more, then the keyword. The
    /// indentation is what stands in for "a member of a top-level type".
    private static func declaredName(onLine line: Substring) -> String? {
        for prefix in ["    func ", "    public func "] where line.hasPrefix(prefix) {
            return String(line.dropFirst(prefix.count).prefix { isIdentifier($0) })
        }
        return nil
    }
}
