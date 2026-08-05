import XCTest

/// Two public effects claiming one method name.
///
/// This is legal Swift — the overloads are distinguished by their argument
/// labels — but it is not harmless. `voronoiNoise` was declared twice, in
/// `Noise` and in `Voronoi`, bound to two different Metal functions, and *both*
/// spellings accepted `voronoiNoise(time:)` and `voronoiNoise(time:scale:)`.
/// Swift resolved those to the Noise one, silently, by preferring the overload
/// with fewer defaulted parameters. A caller reading `Voronoi`'s documentation
/// got `Noise`'s shader and no diagnostic of any kind.
///
/// So there are two tests here, and they are not the same test:
///
/// - ``testNoTwoOverloadsOfOneNameAcceptTheSameCallShape`` is the one with teeth.
///   It would have failed on `voronoiNoise` before 2.0.0 renamed it.
/// - ``testTheSetOfDuplicatedNamesIsTheKnownSet`` is a ratchet over the merely
///   confusing ones — a new duplicate name has to be argued for here.
final class DuplicateEffectNameTests: XCTestCase {

    /// Names declared in more than one file. Each is an older static variant and
    /// a newer animated one, bound to genuinely different Metal functions and
    /// distinguished by their labels. Renaming them is a public API break that
    /// buys navigability and nothing else, so they are tolerated — but the set
    /// may not grow.
    ///
    /// `voronoiNoise` is on this list only because of the deprecated shim that
    /// keeps 1.x callers compiling; it comes off when the shim is removed.
    static let knownDuplicateNames: Set<String> = [
        "embers",        // Particles(density:speed:) · Fire(time:density:speed:size:)
        "neonElectric",  // Neon(color:intensity:) · Electric(time:glowIntensity:flickerSpeed:)
        "pinch",         // Swirl(strength:radius:) · Displacement(time:amount:radius:center:)
        "twirl",         // Swirl(angle:) · Displacement(time:angle:radius:center:)
        "voronoiNoise",  // Voronoi(time:scale:jitter:edgeWidth:) · the deprecated Noise shim
    ]

    func testTheSetOfDuplicatedNamesIsTheKnownSet() throws {
        let methods = try PublicViewMethodScanner.scanSources()
        let acrossFiles = Dictionary(grouping: methods, by: \.name)
            .filter { Set($0.value.map(\.file)).count > 1 }

        XCTAssertEqual(
            Set(acrossFiles.keys), Self.knownDuplicateNames,
            "Duplicate effect names changed.\n"
            + "New: \(Set(acrossFiles.keys).subtracting(Self.knownDuplicateNames).sorted()) — "
            + "give the effect its own name, or add it here with a reason.\n"
            + "Resolved: \(Self.knownDuplicateNames.subtracting(acrossFiles.keys).sorted()) — "
            + "remove it from the list."
        )
    }

    /// Same-file overloads are a different, milder thing: both declarations are
    /// visible at once and jump-to-definition lands on the right file. They are
    /// listed rather than ignored so that a new one is still a decision.
    static let knownSameFileOverloads: Set<String> = [
        "neonGlow",   // (_: NeonConfiguration) and (color:intensity:threshold:)
        "threshold",  // (_:) and (_:low:high:) — see the allowlist below
    ]

    func testTheSetOfSameFileOverloadsIsTheKnownSet() throws {
        let methods = try PublicViewMethodScanner.scanSources()
        let sameFile = Dictionary(grouping: methods, by: \.name)
            .filter { $0.value.count > 1 && Set($0.value.map(\.file)).count == 1 }

        XCTAssertEqual(Set(sameFile.keys), Self.knownSameFileOverloads)
    }

    // MARK: - The one that has teeth

    /// `threshold(_:)` and `threshold(_:low:high:)` both accept `threshold()` and
    /// `threshold(0.3)`, and Swift picks the first by the fewest-defaults rule.
    /// Unlike `voronoiNoise` this is benign — both apply `ThresholdModifier`, and
    /// `low`/`high` default to exactly what the one-argument form uses — so the
    /// two calls render identically. It is allowlisted with that reason rather
    /// than tolerated silently.
    static let allowedAmbiguousNames: Set<String> = ["threshold"]

    /// Two overloads of one name that accept the *same* call must not exist:
    /// which shader runs is then decided by an overload-resolution tiebreaker
    /// the caller cannot see.
    func testNoTwoOverloadsOfOneNameAcceptTheSameCallShape() throws {
        let methods = try PublicViewMethodScanner.scanSources()
        var offenders: [String] = []

        for (name, group) in Dictionary(grouping: methods, by: \.name) where group.count > 1 {
            guard !Self.allowedAmbiguousNames.contains(name) else { continue }

            for (a, b) in pairs(of: group) {
                let shared = a.acceptedCallShapes.intersection(b.acceptedCallShapes)
                guard !shared.isEmpty else { continue }
                let calls = shared
                    .map { "\(name)(\($0.map { $0 == "_" ? "" : "\($0):" }.joined()))" }
                    .sorted()
                offenders.append(
                    "\(name): \(a.file):\(a.line) and \(b.file):\(b.line) both accept "
                    + calls.joined(separator: ", ")
                )
            }
        }

        XCTAssertEqual(
            offenders.sorted(), [],
            "Ambiguous effect overloads — the compiler picks one silently:\n"
            + offenders.sorted().joined(separator: "\n")
        )
    }

    private func pairs(of methods: [PublicViewMethod]) -> [(PublicViewMethod, PublicViewMethod)] {
        var out: [(PublicViewMethod, PublicViewMethod)] = []
        for i in methods.indices {
            for j in methods.index(after: i)..<methods.endIndex {
                out.append((methods[i], methods[j]))
            }
        }
        return out
    }
}
