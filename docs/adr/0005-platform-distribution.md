# 0005 — Platform distribution: SPM stays macOS-only for now; CocoaPods removed

**Status:** Accepted · **Date:** 2026-08-05 · **Phase:** 7d of `plans/00-shader-integrity-remediation.md`

## Context

`SwiftShaders` ships its Metal functions as one compiled `default.metallib`, reached at
runtime via `ShaderLibrary.bundle(.module)` (`Sources/SwiftShaders/Core/ShaderLibrary+Bundle.swift`).
`Package.swift` declares `.iOS(.v17), .macOS(.v14), .tvOS(.v17), .visionOS(.v1)` as supported
platforms, but only one metallib is ever produced, by `Scripts/build-shaders.sh` running
`xcrun -sdk macosx metal` — hardcoded to macOS.

Phase 0.8 established three hard constraints, reverified here:

1. **One metallib per platform is mandatory.** `xcrun metallib macosx.air iphoneos.air -o
   fat.metallib` → `LLVM ERROR: multiple symbols`. `xcrun metal-lipo -create ... ` also
   refuses (`have the same architecture air64_v28`). Root cause: `-print-target-triple` is
   `air64-apple-darwin25.5.0` for **every** SDK — no OS discriminator, so the linker cannot
   tell two platforms' AIR apart when asked to combine them.
2. **`ShaderLibrary.bundle(_:)` resolves exactly one filename, `default.metallib`, with no
   documented platform-selection hook.**
3. **SwiftPM's CLI build (`swift build` / `swift test`) never compiles `.metal`, on any
   platform.** This is not macOS-specific — cross-compiling for another Darwin target via
   `swift build --triple` would hit the identical gap, since the CLI has no Metal build rule
   at all (`TargetSourcesBuilder.swift`: `metal` only appears in `xcbuildFileTypes`).

The open question this ADR resolves: **how should one SPM package serve the right
`default.metallib` to iOS / tvOS / visionOS / macOS consumers**, given (1)–(3)?

### Investigation

**Per-SDK compilation works fine in isolation** — only the *merge* step is blocked. Spiked
directly:
```
$ xcrun -sdk iphoneos metal -frecord-sources -c Sources/SwiftShaders/Metal/InvertShader.metal -o invert-ios.air
$ xcrun -sdk iphoneos metallib invert-ios.air -o invert-ios.metallib
```
Both succeed with zero errors, on the same machine that failed to merge two platforms
(above). This machine has every relevant SDK installed (`xcodebuild -showsdks`: iOS, iOS
Simulator, macOS, tvOS, tvOS Simulator, visionOS, visionOS Simulator), so **building N
separate per-platform metallibs is not blocked by tooling availability** — it is blocked by
what happens after that, at the distribution/selection layer.

**Xcode's build system auto-compiles `.metal` sources in an SPM target; `swift build` does
not — this is corroborated by multiple independent sources** (GitHub
`swiftlang/swift-package-manager` issues #5822 and #7716, a public writeup at mtldoc.com, and
an Apple Developer Forums thread on Swift packages with Metal). Consensus: SwiftPM added
transparent `.metal` → `default.metallib` compilation for **Xcode-driven** builds of a
package (i.e. `xcodebuild`/Xcode IDE building an app that depends on the package), matching
each active build's platform automatically, with no author-side plumbing. The CLI build
(`swift build`) has never done this.

**Local spike: can the current `exclude: ["Metal"]` + `.copy("Resources/default.metallib")`
setup coexist with un-excluded `.metal` sources, so Xcode could compile them too?** Tested by
temporarily removing `exclude: ["Metal"]` from `Package.swift` while keeping the `.copy`
resource, then running `swift build`:

```
warning: 'SwiftShaders': found 33 file(s) which are unhandled; explicitly declare them
as resources or exclude from the target
    .../Sources/SwiftShaders/Metal/NeonShader.metal
    ...
Build complete! (10.68s)
```

Two findings from this:

- Under the CLI, un-excluded `.metal` files with no resource rule are a **warning, not an
  error** — the build still succeeds, still uses the pre-built `default.metallib`. So leaving
  `Metal/` un-excluded would not, by itself, break `swift build`/`swift test`/CI.
- But `.copy("Resources/default.metallib")` was confirmed (by inspecting
  `.build/arm64-apple-macosx/debug/SwiftShaders_SwiftShaders.bundle/`) to place the file at
  **the resource bundle's top level** — `default.metallib`, not `Resources/default.metallib`.
  If `Metal/` were left un-excluded specifically so Xcode could auto-compile it, Xcode's own
  compilation would **also** produce a resource named `default.metallib` at that same bundle
  root, in the same target. That is a same-path, two-producer conflict — the same shape as
  Xcode's "multiple commands produce" build error — the moment a consumer builds this package
  through Xcode instead of `swift build`. Change was reverted; `Package.swift` is back to
  `exclude: ["Metal"]`.

**A second, more fundamental blocker for CocoaPods specifically** (relevant to Part 2, below):
`ShaderLibrary+Bundle.swift` calls `.bundle(.module)` unconditionally, with no
`#if SWIFT_PACKAGE` fallback. `Bundle.module` is a symbol SwiftPM *generates* for targets that
declare resources (`resource_bundle_accessor.swift`, synthesized at build time) — it does not
exist under CocoaPods or a plain Xcode project. Phase 1 already observed the error this
produces when the symbol is unavailable: `error: type 'Bundle' has no member 'module'`.

**Today's actual distribution state, orthogonal to platform selection:** `default.metallib` is
gitignored (`.gitignore:26`, a Phase 1 decision: "generated, never committed, CI rebuilds
it"). `git ls-files Sources/SwiftShaders/Resources/` returns only `shader-signatures.tsv` —
the metallib itself is not in the git repository at all. `swift build` never invokes
`Scripts/build-shaders.sh` on its own. So **a bare `git clone` + `.package(url:)` add by an
external SwiftPM consumer today produces no metallib and no `Bundle.module` for *any*
platform, including macOS**, unless that consumer separately runs the build script first —
something only this repo's own `Makefile`/CI does. This is Phase 1's decision to record in its
own ADR, not this one's to re-litigate, but it materially weakens the case for investing effort
in cross-platform selection machinery right now: the base distribution path needs fixing
before the platform-selection question is the binding constraint.

## Decision

**Keep SwiftPM distribution macOS-only for now** (outcome iii from the plan). Do not pursue
Xcode-auto-compile (i) or per-platform metallib resources with runtime selection (ii) in this
phase. **Remove CocoaPods support entirely** — delete `SwiftShaders.podspec` — rather than
attempt to fix it.

### Why not (i), Xcode-driven compilation

It cannot be layered on top of the current, working setup: shipping raw `.metal` sources
*and* a pre-built `default.metallib` in the same target collides at the identical resource
path the moment a consumer builds through Xcode (shown above). Removing the pre-built
metallib to avoid that collision breaks `swift build`/`swift test`/CI — the entire
verification apparatus this remediation plan spent six phases building (the binding oracle,
`Shader.compile(as:)` coverage, `ShaderRenderingTests`, the drift check against
`-frecord-sources`) runs exclusively through the CLI on macOS. Trading that away to gain
unverified iOS/tvOS/visionOS support is a bad trade.

### Why not (ii), per-platform resources selected at runtime

Technically reachable — the per-SDK compile spike above shows nothing stops producing
`default-iphoneos.metallib`, `default-appletvos.metallib`, etc., and shipping them all as
`.copy` resources with a `#if os(...)`/`targetEnvironment(simulator)` selector feeding
`ShaderLibrary(url:)` instead of `.bundle(.module)`. But:

- It roughly **7×s** the generated-artifact surface (macOS, iOS device, iOS simulator, tvOS
  device, tvOS simulator, visionOS device, visionOS simulator) that `Scripts/build-shaders.sh`
  and CI would need to produce and keep in sync with the manifest/drift-check machinery Phase
  2 built for the single macOS artifact.
- **The library's tests and CI are macOS-only today** (`.github/workflows/ci.yml` runs on
  `macos-15`; no simulator boot, no device build, no XCTest run on any non-macOS destination
  exists anywhere in this repo). Shipping six more platform metallibs with zero automated
  verification of any of them does not extend test coverage — it extends the *unverified*
  surface. This plan's entire premise, established in Phases 1–6, is that an unverified
  shader binding renders **pure black**, silently, with no crash (Phase 3 result). Shipping
  unverified per-platform libraries is exactly the failure mode this plan exists to eliminate,
  applied to three more platforms at once.
- The pre-existing "metallib isn't even committed for macOS" gap (above) is the actual
  blocking issue for distribution today, and is orthogonal to this decision.

If either changes — CI grows real device/simulator build+test coverage for the other
platforms, or the project commits to Xcode-only distribution and drops CLI-based testing —
this decision should be revisited. Until then, the maintenance cost of (ii) is not justified
by current test coverage.

### Why not fix CocoaPods

Fixing the podspec is not a metadata-only change. Beyond the two problems already known
(`ios.deployment_target = '15.0'` contradicts `Package.swift`'s iOS 17 and every
`@available(iOS 17.0)` annotation; no metallib and no `resource_bundles` are declared, so
today's podspec ships a library that cannot resolve a single shader), the library's own
source is SwiftPM-specific: `.bundle(.module)` does not compile outside a SwiftPM build.
Making CocoaPods actually work would require:

1. Introducing and maintaining a second bundle-resolution code path
   (`#if SWIFT_PACKAGE ... #else ...`) purely to serve a distribution channel with **zero**
   existing verification — no `pod lib lint` run anywhere in this repo, no CI job, no test.
2. Deciding how CocoaPods gets its metallib. CocoaPods pod targets *are* native Xcode
   framework targets, so — unlike SwiftPM — Xcode's automatic Metal compilation would apply if
   `.metal` files were added to `s.source_files`, correctly producing one metallib per
   platform for free. This is a genuine asymmetry worth recording: CocoaPods sidesteps the
   SwiftPM-CLI Metal gap entirely, because it never uses `swift build`. But exploiting that
   still requires (1)'s bundle-accessor rewrite, plus new CI to prove it, for a distribution
   channel the project has otherwise been silent about (not mentioned anywhere in `README.md`
   or `Documentation/`).

That is new feature work with its own verification burden, not a fix to something the plan is
already carrying. `SwiftShaders.podspec` is therefore deleted rather than repaired.

## Consequences

- `SwiftShaders.podspec` is deleted. `README.md` and `Documentation/` were grepped for
  CocoaPods/podspec/Podfile instructions before and after — **none existed**, so no doc
  edits were needed. (`.gitignore` still has a generic, inert `Pods/` ignore rule; left as
  harmless boilerplate, not a CocoaPods instruction.)
- SwiftPM remains the only supported distribution channel. `Package.swift`'s platform list
  (`iOS 17 / macOS 14 / tvOS 17 / visionOS 1`) states the *language/API* availability floor,
  not a distribution promise — today only `swift build`/`swift test` on macOS is exercised or
  verified. This gap between "declared platforms" and "actually verified platform" is not
  fixed by this ADR and should be called out wherever the package's platform support is
  documented (Phase 8 / README work).
- No source or `Package.swift` changes were kept from the investigation — the
  `exclude: ["Metal"]` + `.copy("Resources/default.metallib")` setup is confirmed correct as
  read (0.8) and is *why* the resource-collision finding above is worth recording: it explains
  precisely why that structure cannot be casually extended to "just also let Xcode compile the
  raw sources."
- Future work, if platform support becomes a real goal: fix the metallib-provenance gap
  first (commit it or otherwise make `swift build` self-sufficient on a bare clone — Phase 1's
  ADR), then build out CI coverage for the target platform(s) before shipping a metallib for
  it, per outcome (ii).

## Alternatives considered

| Outcome | Verdict | Why |
|---|---|---|
| (i) Xcode auto-compiles `.metal`; CLI stays macOS-only "by design" | Rejected | Collides with the existing pre-built-metallib resource at the same bundle path the moment a consumer builds via Xcode (shown above); the only way to avoid the collision is dropping the pre-built metallib, which breaks `swift build`/`swift test`/CI — this plan's entire verification apparatus. |
| (ii) Per-platform metallibs shipped as resources, selected at runtime via `ShaderLibrary(url:)`/`ShaderLibrary(data:)` | Rejected for now | Technically reachable (spiked: per-SDK `.metal` → `.air` → `.metallib` succeeds cleanly for iphoneos on this machine) but multiplies the build/test/manifest surface ~7× with **zero** current CI coverage on any of the added platforms — ships unverified libraries, which is the exact failure mode (silent black rendering) this whole remediation plan was built to catch. Revisit if CI grows real per-platform verification. |
| (iii) Document macOS-only for now | **Chosen** | Matches what is actually built, tested, and verified today. Costs nothing beyond stating the limitation; does not foreclose (i) or (ii) later. |
| Fix `SwiftShaders.podspec` | Rejected | Not a metadata fix — `.bundle(.module)` doesn't exist outside SwiftPM, so the library wouldn't compile under CocoaPods even with a correct deployment target and `resource_bundles`. Would require a second, unverified bundle-accessor code path and new CI. Not mentioned in any user-facing docs today, so removing it changes nothing consumers currently rely on. |
| Remove `SwiftShaders.podspec` | **Chosen** | Matches reality: the podspec has never produced a working artifact (wrong deployment target, no metallib, no resource_bundles, and a source-level dependency on an SPM-only symbol). No README/Documentation content referenced it. |

## Note for the docs phase (Phase 8), out of scope here

README/podspec org-name drift (`muhittinpalamutcu/SwiftShaders` vs `muhittincamdali/SwiftShaders`)
was flagged in Phase 2's/Appendix's notes as still present. **Re-checked while investigating
this ADR: it is no longer present in the working tree.** `README.md` and the now-deleted
`SwiftShaders.podspec` both consistently used `muhittincamdali/SwiftShaders`
(`grep -n "github.com/muhittin" README.md` → only `muhittincamdali` hits, for `SwiftNetwork`,
`SwiftAI`, `LiquidGlassKit`, and this package's own `.package(url:)` line). `git log -S` shows
`muhittinpalamutcu` did exist historically (an early README and the now-deleted
`SwiftShadersInfo.repositoryURL`) but was already cleaned up by earlier commits (the
appendix cleanup, `3e6f6b2`, deleted the last source-level occurrence). What **is** still
wrong, already flagged in the Appendix results and repeated here so it isn't lost:
`CHANGELOG.md` is unrelated-project boilerplate — its entries describe `NavigationStack`
routing features, not shaders, and its compare/release links point at
`github.com/muhittincamdali/SwiftRouter` (correct org, wrong repo). That rewrite is Phase 8
work; a salvaged replacement patch is noted in `plans/01-orchestration-remaining-work.md`
under "nifty-rhodes."
