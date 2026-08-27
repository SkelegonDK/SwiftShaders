import XCTest
import SwiftShadersGalleryCore
@testable import SwiftShaders

/// Does the Gallery represent the library?
///
/// Three separate claims, kept separate because they fail for different reasons:
///
/// - **No phantoms.** Every gallery entry names a public effect that exists.
///   This is the one property that was already true and is now locked.
/// - **Completeness.** `EffectCoverage` accounts for every public effect method
///   in the sources — the ledger cannot quietly stop mentioning one.
/// - **The ratchet.** The number of effects with no gallery entry may fall, never
///   rise.
///
/// The yardstick for completeness is `PublicViewMethodScanner`, which reads the
/// sources; the ledger is a hand-written file. Neither derives from the other.
final class EffectCoverageTests: XCTestCase {

    // MARK: - No phantom gallery entries

    /// A gallery entry whose id names no public method generates code that does
    /// not compile, and — before the split into `SwiftShadersGalleryCore` — the
    /// only thing standing between the catalogue and that state was that someone
    /// had compiled the executable recently.
    func testEveryGalleryEntryNamesAPublicEffectMethod() throws {
        let methodNames = Set(try PublicViewMethodScanner.scanSources().map(\.name))
        let phantoms = EffectCatalog.all.map(\.id).filter { !methodNames.contains($0) }

        XCTAssertEqual(
            phantoms, [],
            "Gallery entries naming no public View method: \(phantoms). "
            + "Either the method was renamed or removed, or the id is a typo."
        )
    }

    /// The ledger's side of the same coin: `.inGallery(id)` must name an entry
    /// the catalogue actually has, or the ledger is claiming coverage it does
    /// not have.
    func testEveryLedgerGalleryIdIsInTheCatalogue() {
        let catalogued = Set(EffectCatalog.all.map(\.id))
        let claimed = EffectCoverage.galleryIds.filter { !catalogued.contains($0) }

        XCTAssertEqual(
            claimed.sorted(), [],
            "Ledger claims these are in the Gallery, but the catalogue has no such entry: \(claimed.sorted())"
        )
    }

    /// …and every catalogue entry is claimed by exactly one ledger row, so the
    /// two counts cannot drift apart in either direction.
    func testTheLedgerAccountsForEveryCatalogueEntryExactlyOnce() {
        let claimed = EffectCoverage.galleryIds.sorted()
        let catalogued = EffectCatalog.all.map(\.id).sorted()

        XCTAssertEqual(
            claimed, catalogued,
            "The ledger's .inGallery ids and the catalogue's ids differ. "
            + "Missing from the ledger: \(Set(catalogued).subtracting(claimed).sorted()); "
            + "not in the catalogue: \(Set(claimed).subtracting(catalogued).sorted())."
        )
    }

    // MARK: - Ledger completeness

    /// The ledger must name every public effect method, and no method it does
    /// not. A method missing here is an effect nobody has decided anything about
    /// — which is exactly the state 7a exists to end.
    func testTheLedgerListsEveryPublicEffectMethod() throws {
        let found = try PublicViewMethodScanner.scanSources()
        let declared = EffectCoverage.selectors

        let missing = found.filter { !declared.contains($0.selector) }
        let invented = declared.subtracting(found.map(\.selector)).sorted()

        XCTAssertEqual(
            missing.map(\.description), [],
            "Public effect methods missing from EffectCoverage.entries — add a line for each, "
            + "choosing .inGallery / .presetOf / .deliberatelyAbsent:\n"
            + missing.map(\.description).joined(separator: "\n")
        )
        XCTAssertEqual(
            invented, [],
            "EffectCoverage lists methods that no longer exist in Sources/: \(invented)"
        )
    }

    /// Selectors are the ledger's keys, so two rows sharing one would let a
    /// method be silently double-counted.
    func testLedgerSelectorsAreUnique() {
        let duplicates = Dictionary(grouping: EffectCoverage.entries, by: \.selector)
            .filter { $0.value.count > 1 }
            .keys
            .sorted()

        XCTAssertEqual(duplicates, [], "Duplicate ledger selectors: \(duplicates)")
    }

    /// `.presetOf(base)` is only meaningful if the base is itself accounted for.
    func testEveryPresetNamesABaseMethodInTheLedger() {
        let declared = EffectCoverage.selectors
        let dangling = EffectCoverage.presetBases
            .filter { !declared.contains($0.base) }
            .map { "\($0.selector) → \($0.base)" }

        XCTAssertEqual(dangling, [], "Presets whose base method is not in the ledger: \(dangling)")
    }

    /// The scanner is the yardstick for everything above, so it needs a yardstick
    /// of its own that is not itself.
    ///
    /// `rawDeclarationCount` counts declarations by line shape — four spaces,
    /// `func `, minus a named list of non-effect helpers — with no comment
    /// stripping, no brace matching and no notion of an extension block. The
    /// structural scan and the raw count reaching the same number is evidence;
    /// a scanner checked only against itself is not. (Phase 6 shipped a parser
    /// that agreed with itself over 89% of a file.)
    func testTheScannerSeesEveryDeclarationTheSourcesContain() throws {
        let scanned = try PublicViewMethodScanner.scanSources().count
        let raw = try PublicViewMethodScanner.rawDeclarationCount()

        XCTAssertEqual(
            scanned, raw,
            "The structural scan found \(scanned) public View methods but the sources declare \(raw) "
            + "by line shape. PublicViewMethodScanner is under- or over-scanning; every coverage "
            + "assertion is weaker than it looks until this agrees."
        )
    }

    // MARK: - The ratchet

    /// **Lower this number when you add gallery entries. Raising it needs an
    /// argued reason in the ledger.**
    ///
    /// 133 of the library's 226 public effect methods have no Gallery entry.
    /// That is a real gap, deliberately made visible rather than closed here:
    /// closing it means authoring ~350 slider ranges by hand, which is its own
    /// piece of work. This test is what stops the gap growing in the meantime —
    /// a new effect method added without a gallery entry pushes the count up and
    /// fails here.
    ///
    /// Raised 121 → 133 on 2026-08-27: the maintainer removed the gallery's
    /// colour-adjustment entries as not relevant to it (see
    /// `Absence.ruledOutOfGallery`) — a curation decision, not backlog growth.
    static let deliberatelyAbsentCeiling = 133

    /// Equality, not `<=`.
    ///
    /// A ceiling the count may sit *below* is a ratchet with slack in it: drain
    /// ten entries from the backlog and the constant stays at 121, so the next
    /// ten effects can be added with no gallery entry at all and nothing goes
    /// red. The slack is invisible — the suite is green the whole time. Pinning
    /// the number exactly means draining the backlog and lowering the constant
    /// are the same commit, and the ratchet never holds a debt that has already
    /// been paid.
    func testTheAbsentCountOnlyEverFalls() {
        let absent = EffectCoverage.absent

        XCTAssertEqual(
            absent.count, Self.deliberatelyAbsentCeiling,
            "\(absent.count) effects have no gallery entry; `deliberatelyAbsentCeiling` says "
            + "\(Self.deliberatelyAbsentCeiling).\n"
            + (absent.count > Self.deliberatelyAbsentCeiling
               ? "The backlog grew. A new effect needs a gallery entry, or an argued "
                 + ".deliberatelyAbsent reason and a raised ceiling — which is the thing this "
                 + "test exists to make you justify."
               : "The backlog shrank, which is good: lower `deliberatelyAbsentCeiling` to "
                 + "\(absent.count) in this same commit, or the ratchet keeps holding room for "
                 + "\(Self.deliberatelyAbsentCeiling - absent.count) uncatalogued effects.")
        )
    }

    /// A `.presetOf` row claims its method takes no arguments, and is therefore
    /// covered by the gallery entry of the method it wraps. That claim is what
    /// makes it not count against the ratchet — so if it goes unchecked, any
    /// `.deliberatelyAbsent` row can be relabelled `.presetOf` to buy a slot
    /// under the ceiling without anything changing in the library.
    ///
    /// The claim is checkable from the selector alone: a zero-argument method's
    /// selector ends in `()`.
    func testEveryPresetIsAZeroArgumentConvenience() {
        let parameterised = EffectCoverage.presetBases
            .filter { !$0.selector.hasSuffix("()") }
            .map { "\($0.selector) → \($0.base)" }

        XCTAssertEqual(
            parameterised, [],
            "These are marked .presetOf but take arguments, so the base method's gallery entry "
            + "does not cover them. They belong in the Gallery or in the counted backlog:\n"
            + parameterised.joined(separator: "\n")
        )
    }

    /// Every absence carries one of the documented reasons — a free-text reason
    /// would let "TODO" count as a decision.
    func testEveryAbsenceGivesADocumentedReason() {
        let known: Set<String> = [
            EffectCoverage.Absence.backlog,
            EffectCoverage.Absence.unsliderableInput,
            EffectCoverage.Absence.soleEntryPoint,
            EffectCoverage.Absence.deprecated,
            EffectCoverage.Absence.ruledOutOfGallery,
        ]
        let unknown = EffectCoverage.absent
            .filter { !known.contains($0.reason) }
            .map { "\($0.selector): \($0.reason)" }

        XCTAssertEqual(unknown, [], "Absences with an undocumented reason: \(unknown)")
    }

    /// The three dispositions partition the ledger; this pins the shape of the
    /// public surface so a change to any one of the numbers has to be looked at.
    func testTheLedgerPartitionsTheEntirePublicSurface() {
        let total = EffectCoverage.entries.count
        let gallery = EffectCoverage.galleryIds.count
        let presets = EffectCoverage.presetBases.count
        let absent = EffectCoverage.absent.count

        XCTAssertEqual(gallery + presets + absent, total, "A ledger entry has no disposition.")
        XCTAssertEqual(gallery, EffectCatalog.all.count, "Gallery entries and .inGallery rows disagree.")
    }
}
