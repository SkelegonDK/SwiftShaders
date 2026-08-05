import XCTest
import SwiftShadersGalleryCore

/// Invariants of the Gallery catalogue.
///
/// These used to be checked by parsing `EffectCatalog.swift` as text, because a
/// test target cannot import an executable target. The parser could only ever be
/// as good as its own idea of the file's shape, and it was once wrong about
/// 89% of it. `SwiftShadersGalleryCore` makes the catalogue importable, so the
/// assertions now run against the real values — including the ones the parser
/// could not see at all, such as a range built from a constant.
///
/// Whether the catalogue *covers* the library is a different question, asked by
/// `EffectCoverageTests`.
final class CatalogConsistencyTests: XCTestCase {

    /// `Effect.id` is the `View` extension name and the key the UI selects by,
    /// so a duplicate silently shadows an effect in the sidebar.
    func testEffectIdsAreUnique() {
        let duplicates = Dictionary(grouping: EffectCatalog.all, by: \.id)
            .filter { $0.value.count > 1 }
            .map { "\($0.key) declared \($0.value.count)×" }
            .sorted()

        XCTAssertEqual(duplicates, [], "Duplicate gallery effect ids: \(duplicates)")
    }

    /// A slider whose default sits outside its own range opens the gallery
    /// showing a value the user cannot return to, and generates Swift that does
    /// not match what is on screen.
    func testEverySliderDefaultLiesWithinItsRange() {
        let offenders = EffectCatalog.all.flatMap { effect in
            effect.params
                .filter { !$0.range.contains($0.value) }
                .map { "\(effect.id).\($0.label) defaults to \($0.value), outside \($0.range)" }
        }

        XCTAssertEqual(offenders, [], "Slider defaults outside their declared range:\n"
                       + offenders.joined(separator: "\n"))
    }

    /// Ranges must be non-degenerate, or the slider cannot be moved and the
    /// parameter is decoration.
    func testEverySliderRangeIsNonDegenerate() {
        let offenders = EffectCatalog.all.flatMap { effect in
            effect.params
                .filter { $0.range.lowerBound >= $0.range.upperBound }
                .map { "\(effect.id).\($0.label) has range \($0.range)" }
        }

        XCTAssertEqual(offenders, [], "Degenerate slider ranges: \(offenders)")
    }

    /// Every entry is reachable through the lookup the UI uses.
    func testEveryEffectIsReachableByItsOwnId() {
        for effect in EffectCatalog.all {
            XCTAssertEqual(
                EffectCatalog.effect(id: effect.id)?.id, effect.id,
                "\(effect.id) is in `all` but `effect(id:)` does not return it"
            )
        }
    }

    /// An entry missing a display name or a blurb renders as a blank row.
    func testEveryEffectHasANameAndABlurb() {
        for effect in EffectCatalog.all {
            XCTAssertFalse(effect.name.isEmpty, "\(effect.id) has no display name")
            XCTAssertFalse(effect.blurb.isEmpty, "\(effect.id) has no blurb")
        }
    }

    /// `grouped()` drives the sidebar. Every effect must appear in it exactly
    /// once, or an effect is unreachable in the UI even though it is catalogued.
    func testGroupingCoversEveryEffectExactlyOnce() {
        let grouped = EffectCatalog.grouped().flatMap { $0.1 }.map(\.id).sorted()

        XCTAssertEqual(grouped, EffectCatalog.all.map(\.id).sorted())
    }

    /// The generated code is what a user copies out of the gallery. It must name
    /// the effect it belongs to and mention every parameter by label.
    func testGeneratedCodeNamesTheEffectAndAllItsLabelledParameters() {
        for effect in EffectCatalog.all {
            let code = effect.code(ParamValues(effect.params))

            XCTAssertTrue(code.contains(".\(effect.id)("), "\(effect.id): generated code does not call it:\n\(code)")
            for param in effect.params where !param.label.isEmpty {
                XCTAssertTrue(
                    code.contains("\(param.label):"),
                    "\(effect.id): generated code omits the \(param.label) argument:\n\(code)"
                )
            }
            if effect.animated {
                XCTAssertTrue(code.contains("time: time"), "\(effect.id) is animated but its code passes no time")
            }
        }
    }

    /// Integer parameters print without a decimal point, so the generated Swift
    /// type-checks against an `Int` argument.
    func testIntegerParametersRenderWithoutADecimalPoint() {
        for effect in EffectCatalog.all {
            for param in effect.params where param.isInteger {
                XCTAssertFalse(
                    param.literal(param.value).contains("."),
                    "\(effect.id).\(param.label) is an integer parameter but renders as \(param.literal(param.value))"
                )
            }
        }
    }

    /// `ParamValues` is index-addressed with a fallback, so an out-of-range read
    /// must not trap — the preview closures index by position.
    func testParamValuesReadsOutOfRangeIndicesSafely() {
        let values = ParamValues([EffectParam("a", 0...1, 0.25)])

        XCTAssertEqual(values[0], 0.25)
        XCTAssertEqual(values[7], 0)
    }
}
