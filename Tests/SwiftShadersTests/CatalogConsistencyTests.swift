import XCTest
@testable import SwiftShaders

/// Consistency of the effect catalogues.
///
/// The same effect is described in several places — `ShaderCatalog` in the
/// library, `EffectCatalog` in the gallery, the `View` extension defaults, and
/// the README. Nothing keeps them in agreement, so drift is silent. These tests
/// lock the invariants that hold today; reconciling the identities and
/// taxonomies the catalogues still disagree on is Phase 7a's job.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
final class CatalogConsistencyTests: XCTestCase {

    // MARK: - Gallery catalogue

    /// A slider whose default sits outside its own range opens the gallery
    /// showing a value the user cannot return to, and generates Swift that does
    /// not match what is on screen.
    func testEveryGallerySliderDefaultLiesWithinItsRange() throws {
        let effects = try EffectCatalogSource.parse()
        var offenders: [String] = []

        for effect in effects {
            for param in effect.params where !param.isInRange {
                offenders.append(
                    "Sources/SwiftShadersGallery/EffectCatalog.swift:\(param.line): "
                    + "\(effect.id).\(param.label) defaults to \(param.value), outside "
                    + "\(param.lowerBound)...\(param.upperBound)"
                )
            }
        }

        XCTAssertEqual(
            offenders.count, 0,
            "Slider defaults outside their declared range:\n" + offenders.joined(separator: "\n")
        )
    }

    /// `Effect.id` is the `View` extension name and the identifier used to
    /// generate code, so a duplicate silently shadows an effect in the sidebar.
    func testGalleryEffectIdsAreUnique() throws {
        let effects = try EffectCatalogSource.parse()
        let duplicates = Dictionary(grouping: effects, by: \.id)
            .filter { $0.value.count > 1 }
            .map { "\($0.key) declared \($0.value.count)× (lines \($0.value.map(\.line)))" }
            .sorted()

        XCTAssertEqual(duplicates.count, 0, "Duplicate gallery effect ids:\n" + duplicates.joined(separator: "\n"))
    }

    /// Every parsed effect must carry a display name and a category — an entry
    /// missing either renders as a blank row.
    func testEveryGalleryEffectHasANameAndACategory() throws {
        for effect in try EffectCatalogSource.parse() {
            XCTAssertFalse(effect.name.isEmpty, "\(effect.id) at line \(effect.line) has no display name")
            XCTAssertFalse(effect.category.isEmpty, "\(effect.id) at line \(effect.line) has no category")
        }
    }

    /// The assertions above are only worth the parser's ability to see every
    /// entry. If the catalogue is ever written in a shape the parser does not
    /// recognise, this fails rather than quietly checking a subset.
    func testTheParserSeesEveryDeclarationInTheSource() throws {
        let effects = try EffectCatalogSource.parse()
        let raw = try EffectCatalogSource.rawCounts()

        XCTAssertEqual(
            effects.count, raw.effects,
            "Parsed \(effects.count) effects but the source declares \(raw.effects). "
            + "EffectCatalogSource is under-scanning; every other assertion here is weaker than it looks."
        )
        XCTAssertEqual(
            effects.reduce(0) { $0 + $1.params.count }, raw.params,
            "Parsed \(effects.reduce(0) { $0 + $1.params.count }) params but the source declares \(raw.params)."
        )
    }

    // MARK: - Library catalogue

    func testShaderCatalogIdsAreUnique() {
        let ids = ShaderCatalog.shared.availableShaders.map(\.id)
        let duplicates = Dictionary(grouping: ids, by: { $0 }).filter { $0.value.count > 1 }.keys.sorted()

        XCTAssertEqual(duplicates.count, 0, "Duplicate ShaderCatalog ids: \(duplicates)")
    }

    func testEveryShaderCatalogEntryIsLookedUpByItsOwnId() {
        for info in ShaderCatalog.shared.availableShaders {
            XCTAssertEqual(
                ShaderCatalog.shared.shader(named: info.id)?.id, info.id,
                "\(info.id) is in availableShaders but shader(named:) does not return it"
            )
        }
    }

    func testEveryShaderCatalogEntryHasANameAndDescription() {
        for info in ShaderCatalog.shared.availableShaders {
            XCTAssertFalse(info.name.isEmpty, "\(info.id) has no display name")
            XCTAssertFalse(info.description.isEmpty, "\(info.id) has no description")
        }
    }

    // MARK: - The parser itself

    func testParserReadsIdNameAndCategory() {
        let source = """
        static let distortion: [Effect] = [
            Effect("rippleEffect", "Ripple", .distortion, "Concentric water ripples.",
                   animated: true,
                   params: [
                    .init("amplitude", 0...0.1, 0.02, decimals: 3),
                   ]) { v, p, t in
        """
        let effects = EffectCatalogSource.parse(source: source)

        XCTAssertEqual(effects.count, 1)
        XCTAssertEqual(effects.first?.id, "rippleEffect")
        XCTAssertEqual(effects.first?.name, "Ripple")
        XCTAssertEqual(effects.first?.category, "distortion")
    }

    func testParserReadsRangeAndDefault() {
        let source = """
        Effect("e", "E", .color, "d",
               params: [
                .init("amplitude", 0...0.1, 0.02, decimals: 3),
                .init("strength", -1...1, 0.3),
                .init("segments", 2...24, 6, decimals: 0),
               ])
        """
        let params = EffectCatalogSource.parse(source: source).first?.params ?? []

        XCTAssertEqual(params.count, 3)
        XCTAssertEqual(params[0].label, "amplitude")
        XCTAssertEqual(params[0].lowerBound, 0)
        XCTAssertEqual(params[0].upperBound, 0.1)
        XCTAssertEqual(params[0].value, 0.02)
        // Negative lower bounds must survive the `...` split.
        XCTAssertEqual(params[1].lowerBound, -1)
        XCTAssertEqual(params[1].upperBound, 1)
        XCTAssertEqual(params[2].value, 6)
    }

    func testParserFlagsADefaultOutsideItsRange() {
        let source = """
        Effect("e", "E", .color, "d",
               params: [
                .init("good", 0...1, 0.5),
                .init("tooHigh", 0...1, 4),
                .init("tooLow", 0...1, -2),
               ])
        """
        let params = EffectCatalogSource.parse(source: source).first?.params ?? []

        XCTAssertEqual(params.filter { !$0.isInRange }.map(\.label), ["tooHigh", "tooLow"])
    }

    func testParserAttributesParamsToTheEffectTheyFollow() {
        let source = """
        Effect("first", "First", .color, "d",
               params: [
                .init("a", 0...1, 0.5),
               ])
        Effect("second", "Second", .retro, "d",
               params: [
                .init("b", 0...1, 0.5),
                .init("c", 0...1, 0.5),
               ])
        """
        let effects = EffectCatalogSource.parse(source: source)

        XCTAssertEqual(effects.map(\.id), ["first", "second"])
        XCTAssertEqual(effects[0].params.map(\.label), ["a"])
        XCTAssertEqual(effects[1].params.map(\.label), ["b", "c"])
    }

    /// Regression: the parser originally keyed on a line *prefix*, so the 21
    /// params the catalogue declares inline with their effect were invisible to
    /// it — and invisible to the completeness guard too, since that counted the
    /// same way. Both forms must parse, and the value must survive the `)]) {`
    /// that follows it on an inline single-param line.
    func testParserReadsAParamWrittenInlineWithItsEffect() {
        let source = """
        Effect("twirl", "Twirl", .distortion, "Rotates pixels.",
               params: [.init("angle", -360...360, 180, decimals: 0)]) { v, p, _ in
            AnyView(v.twirl(angle: Float(p[0])))
        },
        Effect("sepia", "Sepia", .color, "Warm monochrome.",
               params: [.init("intensity", 0...1, 1)]) { v, p, _ in
            AnyView(v.sepia(intensity: Float(p[0])))
        },
        """
        let effects = EffectCatalogSource.parse(source: source)

        XCTAssertEqual(effects.map(\.id), ["twirl", "sepia"])
        XCTAssertEqual(effects[0].params.map(\.label), ["angle"])
        XCTAssertEqual(effects[0].params.first?.lowerBound, -360)
        XCTAssertEqual(effects[0].params.first?.value, 180)
        XCTAssertEqual(effects[1].params.first?.value, 1)
        XCTAssertEqual(EffectCatalogSource.rawCounts(source: source).params, 2)
    }

    /// `Effect(` is also a suffix of the call names in the closure bodies, so a
    /// naive substring search would count `v.rippleEffect(time:)` as an entry.
    func testParserDoesNotMistakeAnEffectSuffixedCallForAnEntry() {
        let source = """
        Effect("rippleEffect", "Ripple", .distortion, "Ripples.",
               params: [.init("amplitude", 0...1, 0.5)]) { v, p, t in
            AnyView(v.rippleEffect(time: t, amplitude: p[0]))
        },
        """
        let effects = EffectCatalogSource.parse(source: source)

        XCTAssertEqual(effects.count, 1)
        XCTAssertEqual(EffectCatalogSource.rawCounts(source: source).effects, 1)
    }

    func testParserHandlesAnUnlabelledParam() {
        let source = """
        Effect("e", "E", .color, "d",
               params: [
                .init("", 0...1, 0.5),
               ])
        """
        let params = EffectCatalogSource.parse(source: source).first?.params ?? []

        XCTAssertEqual(params.count, 1)
        XCTAssertEqual(params.first?.label, "")
        XCTAssertEqual(params.first?.value, 0.5)
    }

    func testRawCountsAgreeWithTheParserOnAFixture() {
        let source = """
        Effect("first", "First", .color, "d",
               params: [
                .init("a", 0...1, 0.5),
               ])
        Effect("second", "Second", .retro, "d",
               params: [
                .init("b", 0...1, 0.5),
               ])
        """
        let raw = EffectCatalogSource.rawCounts(source: source)

        XCTAssertEqual(raw.effects, 2)
        XCTAssertEqual(raw.params, 2)
    }
}
