import Foundation

/// One `Effect(...)` entry in the gallery catalogue.
struct GalleryEffect: Equatable {
    let id: String
    let name: String
    let category: String
    /// 1-based, so failure messages are clickable.
    let line: Int
    var params: [GalleryParam]
}

/// One `.init("label", lo...hi, value)` slider declaration.
struct GalleryParam: Equatable {
    let label: String
    let lowerBound: Double
    let upperBound: Double
    let value: Double
    let line: Int

    var isInRange: Bool { value >= lowerBound && value <= upperBound }
}

/// Reads `Sources/SwiftShadersGallery/EffectCatalog.swift` as text.
///
/// The catalogue lives in the `SwiftShadersGallery` *executable* target, which a
/// test target cannot import, so parsing the source is the only way to assert
/// anything about it — the same approach `ShaderCallSiteScanner` takes, and for
/// the same reason.
///
/// The parser is deliberately strict: it recognises exactly the one shape the
/// catalogue is written in, and `rawCounts` counts the same declarations by line
/// prefix alone. A parser that silently matched fewer entries than the file
/// contains would make every assertion built on it weaker than it looks, so the
/// two counts are asserted equal.
enum EffectCatalogSource {

    static var sourceURL: URL {
        ShaderCallSiteScanner.repositoryRoot
            .appendingPathComponent("Sources/SwiftShadersGallery/EffectCatalog.swift")
    }

    static func parse() throws -> [GalleryEffect] {
        parse(source: try String(contentsOf: sourceURL, encoding: .utf8))
    }

    /// What the file declares, counted by line prefix alone — the yardstick the
    /// parser's own output is measured against.
    static func rawCounts() throws -> (effects: Int, params: Int) {
        rawCounts(source: try String(contentsOf: sourceURL, encoding: .utf8))
    }

    static func rawCounts(source: String) -> (effects: Int, params: Int) {
        var effects = 0
        var params = 0
        for line in lines(of: source) {
            effects += occurrences(of: "Effect(", in: line, requiringWordBoundary: true).count
            params += occurrences(of: ".init(", in: line, requiringWordBoundary: false).count
        }
        return (effects, params)
    }

    // MARK: - Parsing

    static func parse(source: String) -> [GalleryEffect] {
        var effects: [GalleryEffect] = []

        for (index, line) in lines(of: source).enumerated() {
            let number = index + 1

            // An entry may be written across several lines or entirely on one
            // (`params: [.init("angle", -360...360, 180)]`), so occurrences are
            // taken anywhere on the line and processed left to right. Keying on
            // a line *prefix* instead would silently skip every inline param.
            var events: [(index: String.Index, isEffect: Bool)] =
                occurrences(of: "Effect(", in: line, requiringWordBoundary: true).map { ($0, true) }
            events += occurrences(of: ".init(", in: line, requiringWordBoundary: false).map { ($0, false) }
            events.sort { $0.index < $1.index }

            for event in events {
                let fragment = String(line[event.index...])
                if event.isEffect {
                    if let effect = parseEffect(fragment, at: number) { effects.append(effect) }
                } else if let param = parseParam(fragment, at: number), !effects.isEmpty {
                    // A param always belongs to the effect it follows.
                    effects[effects.count - 1].params.append(param)
                }
            }
        }
        return effects
    }

    /// Start indices of every occurrence of `needle` in `line`.
    ///
    /// `requiringWordBoundary` exists for `Effect(`, which is also a suffix of
    /// the call names in the closure bodies — `v.rippleEffect(time:)` must not
    /// register as the start of a catalogue entry.
    private static func occurrences(
        of needle: String,
        in line: String,
        requiringWordBoundary: Bool
    ) -> [String.Index] {
        var found: [String.Index] = []
        var searchStart = line.startIndex

        while let range = line.range(of: needle, range: searchStart ..< line.endIndex) {
            if requiringWordBoundary, range.lowerBound > line.startIndex {
                let previous = line[line.index(before: range.lowerBound)]
                if previous.isLetter || previous.isNumber || previous == "_" || previous == "." {
                    searchStart = range.lowerBound < line.endIndex
                        ? line.index(after: range.lowerBound)
                        : line.endIndex
                    continue
                }
            }
            found.append(range.lowerBound)
            searchStart = range.upperBound
        }
        return found
    }

    /// `Effect("rippleEffect", "Ripple", .distortion, "Concentric ripples.",`
    ///
    /// Takes the first two quoted fields as id and name, then the first
    /// dot-prefixed identifier that appears after the name as the category.
    private static func parseEffect(_ line: String, at number: Int) -> GalleryEffect? {
        let scan = scanQuoted(line)
        guard scan.fields.count >= 2, let nameEnd = scan.ends.dropFirst().first else { return nil }

        let tail = line[nameEnd...]
        guard let dot = tail.firstIndex(of: ".") else { return nil }
        let category = String(tail[tail.index(after: dot)...].prefix { $0.isLetter || $0.isNumber })
        guard !category.isEmpty else { return nil }

        return GalleryEffect(
            id: scan.fields[0],
            name: scan.fields[1],
            category: category,
            line: number,
            params: []
        )
    }

    /// `.init("amplitude", 0...0.1, 0.02, decimals: 3)`
    ///
    /// Only the label, the range and the default are read; trailing arguments
    /// (`decimals:`, `isInteger:`, `title:`) are deliberately ignored.
    private static func parseParam(_ line: String, at number: Int) -> GalleryParam? {
        let scan = scanQuoted(line)
        guard let label = scan.fields.first, let labelEnd = scan.ends.first else { return nil }

        let fields = line[labelEnd...]
            .drop { $0 == "," || $0 == " " }
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard fields.count >= 2 else { return nil }

        // A single-param entry written inline leaves the value field as
        // `1)]) { v, p, _ in`, so each number is read as a leading prefix rather
        // than by trimming a fixed set of trailing characters.
        let bounds = fields[0].components(separatedBy: "...")
        guard bounds.count == 2,
              let lower = leadingNumber(bounds[0]),
              let upper = leadingNumber(bounds[1]),
              let value = leadingNumber(fields[1])
        else { return nil }

        return GalleryParam(
            label: label,
            lowerBound: lower,
            upperBound: upper,
            value: value,
            line: number
        )
    }

    // MARK: - Helpers

    /// The number at the start of `text`, ignoring whatever follows it.
    private static func leadingNumber(_ text: String) -> Double? {
        var digits = ""
        for character in text.trimmingCharacters(in: .whitespaces) {
            if character == "-" && digits.isEmpty {
                digits.append(character)
            } else if character.isNumber || character == "." {
                digits.append(character)
            } else {
                break
            }
        }
        return Double(digits)
    }

    private static func lines(of source: String) -> [String] {
        source
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// The contents of every `"..."` on the line, plus the index just past each
    /// closing quote so a caller can keep parsing from there.
    private static func scanQuoted(_ line: String) -> (fields: [String], ends: [String.Index]) {
        var fields: [String] = []
        var ends: [String.Index] = []
        var current = ""
        var inside = false
        var escaped = false
        var index = line.startIndex

        while index < line.endIndex {
            let character = line[index]
            let next = line.index(after: index)

            if escaped {
                if inside { current.append(character) }
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if character == "\"" {
                if inside {
                    fields.append(current)
                    ends.append(next)
                    current = ""
                }
                inside.toggle()
            } else if inside {
                current.append(character)
            }
            index = next
        }
        return (fields, ends)
    }
}
