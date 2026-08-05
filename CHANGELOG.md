# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - Unreleased

Nothing has been tagged since 1.0.0, so everything below is unreleased and lives on
`main`. This release removes public API that never worked, so it is major rather than
minor.

### Removed

**Breaking — public API.** These had zero call sites anywhere in `Sources`, `Tests`,
`Examples` or `Templates`, and the shader path is synchronous and non-throwing end to
end, so none of it could attach to a shader even in principle:

- `SwiftShadersCircuitBreaker`, `CircuitError`, `SwiftShadersRetryPolicy`,
  `SwiftShadersEventBus`, `SwiftShadersMetricsCollector`, `SwiftShadersErrorHandler`
  (the `Enterprise/` module).
- `MetalToSwiftUIBridge` and `applyMetalShader(_:)`. The bridge applied no shader — it
  did a per-frame unguarded `print` and returned `content.opacity(0.99)` — while the
  README advertised it as the headline feature.
- `ShaderModifierProtocol`, `BaseShaderModifier`, `AnimatedShaderModifier`,
  `ConditionalShaderModifier`, `ChainedShaderModifier`, `ShaderConfig`
  (`Core/ShaderModifier.swift`). The protocol had zero conformances.
- `SwiftShadersInfo` and the `SwiftShaders.version` enum. The two version constants
  disagreed with each other (1.0.0 vs 2.0.0), and nothing read either.
- `ShaderCatalog`, `ShaderCatalog.shared`, `.availableShaders`, `.count`,
  `.shader(named:)`, `.shaders(in:)`, the eight per-category accessors,
  `ShaderCatalog.ShaderInfo` and `ShaderCatalog.ShaderCategory`. 19 of its 30 ids
  matched no public `View` method, and one (`gaussianBlur`) matched no Metal function
  either — 63% phantom. Its five real `View` methods (`rippleEffect`,
  `chromaticAberration`, `glitchEffect`, `pixelateEffect`, `waveEffect`) moved next to
  their modifiers, signatures unchanged.
- `ShaderAnimator` — a `CADisplayLink`/`Timer` animation engine
  (`time`, `progress`, `isRunning`, `speed`, `duration`, `loops`, `loopCount`,
  `autoReverse`, `start()`, `pause()`, `stop()`, `reset()`, `seek(to:)`) with zero call
  sites in the library, the Gallery, `Examples`, the tests or the docs. `ShaderClock`
  plus `TimelineView` is now the one way the library measures time. Migration: drive a
  `TimelineView` through `ShaderClock`, or use `AnimatedShaderView` / `ShaderTimeline`,
  which already do.
- CocoaPods support. `SwiftShaders.podspec` is deleted rather than fixed: it declared
  `ios.deployment_target = '15.0'` against `Package.swift`'s iOS 17 floor, shipped no
  metallib and no `resource_bundles`, and the library calls the SwiftPM-only
  `Bundle.module` with no CocoaPods-compatible fallback — it could never have produced
  a working build. See `docs/adr/0005-platform-distribution.md`.

Also removed:

- The `FluidSimulation` module and all eight of its effects. Six called Metal functions
  that never existed — there is no `FluidSimulation.metal` — and the other two reached
  into `Water` and `Swirl` through the wrong effect method (`waterSurface` as a color
  effect when it is a distortion, `vortex` as a color effect when it is a layer
  effect). All eight rendered black. The one entry this module contributed to the
  Gallery catalogue, `smoke`, went with it (92 effects → 91). See
  `docs/adr/0003-fluidsimulation-deleted.md`.

### Deprecated

- `voronoiNoise(time:scale:intensity:)` → `cellularNoise(time:scale:intensity:)`. Two
  files each declared a `voronoiNoise`, bound to two different Metal functions, both
  accepting `(time:)` and `(time:scale:)`; Swift's fewest-defaults tiebreaker silently
  resolved the short forms to the wrong one (the Noise shader instead of Voronoi's).
  The deprecated shim carries no default values, which is what actually removes the
  ambiguity — a shim with defaults reproduces the bug.

### Fixed

- **149 shader bindings that rendered pure black.** SwiftUI's shader lookup is dynamic
  end to end (`ShaderLibrary` is `@dynamicMemberLookup`, `ShaderFunction` is
  `@dynamicCallable`), so a call site with the wrong arguments compiles cleanly and
  fails silently, every frame, at draw time.
  - `.boundingRect` added at 121 call sites. A `float4 bounds` parameter is not
    implicit — SwiftUI supplies only `position` (plus `color` or `layer`).
  - `half3` → `float3` on 55 parameters across 34 stitchable functions. No
    `Shader.Argument` factory produces a `half3`, so those functions could not be
    driven from Swift at all as declared.
- **The frozen-animation clock bug.** `Shader.Argument.float` is 32-bit; at
  `Date.timeIntervalSinceReferenceDate`'s magnitude (~7.8×10⁸) a `Float`'s ulp is 64
  seconds, so every uniform fed from an absolute reference date was indistinguishable
  frame to frame — the animation did not just look slow, it rendered nothing.
  `AnimatedRippleModifier`, `ShaderView`'s animated branch, `ShaderPreview`,
  `AnimatedShaderView`/`PulsingShaderView`/`SequencedShaderView` and `ShaderTimeline`
  now derive their time from `ShaderClock` (`Sources/SwiftShaders/Core/ShaderClock.swift`),
  which measures small elapsed seconds instead of an absolute date. See
  `docs/adr/0007-one-clock.md`.
- `emboss` and `polaroid` received a literal `.float2(1, 1)` where their real view size
  belonged, behind a stale "Will be replaced by proxy" comment that nothing ever
  fulfilled. Both now receive the real view size.
- The README's opening example called four methods that do not exist: `.hologram()`,
  `.glitch()`, `.ripple()`, `.fire()`.
- The `SwiftShaders` target declared shader *directories* as `.process` resources,
  which made SwiftPM treat the sibling `.swift` files as resource data and silently
  drop most modifiers from the build.
- Broken logo reference removed from the README, and the advertised shader count
  corrected.

### Added

- The shader library is under version control. Previously only 8 files under
  `Sources/` were tracked, and they were exactly the unreferenced modules removed
  above — the 33 `.metal` shaders, the effect modifiers, the Gallery app and the build
  scripts existed only in working trees, so CI was building a package of dead code.
- The binding oracle: `ShaderBindingTests` and a call-site scanner, checking every call
  site's name, effect kind, argument count and argument types against a manifest
  generated from the compiled metallib (`Scripts/extract-metal-signatures.py` →
  `Sources/SwiftShaders/Resources/shader-signatures.tsv`, committed), plus
  `ShaderLibraryIntegrityTests` (the metallib ships and loads with the expected
  function count) and `ShaderRenderingTests` (a binding's arguments reach the shader
  with the right values, not just the right shape, checked by rendering a gradient).
- A coverage ledger (`Tests/SwiftShadersTests/Support/EffectCoverageLedger.swift`)
  recording every one of the library's 226 public `View` effect methods as
  `.inGallery`, `.presetOf(...)` or `.deliberatelyAbsent(reason)`, with a ratchet test
  that only lets the absent count fall. See `docs/adr/0006-coverage-ledger.md`.
- `GalleryRenderSweepTests` — renders all 91 gallery entries headlessly and asserts
  each differs from its unshaded control.
- `ShaderClock` — the library's one time source for animated effects, `TimelineView`-
  backed, with an injectable start instant and "now" so a headless render is exact
  rather than sleep-based.
- `SwiftShadersGalleryCore`, an importable library target holding `Effect`,
  `EffectCatalog` and `SampleElements`, so tests import the catalogue instead of
  parsing its source text. The Gallery executable is now a thin `@main` + `ContentView`.
- `Sources/SwiftShaders/Metal/SwiftShadersCommon.h`, a shared header included by all 33
  `.metal` files, holding `luminance` and the value-noise helpers that were previously
  retyped per file.
- `Sources/SwiftShaders/Resources/unbound-functions.txt` — a generated,
  staleness-guarded inventory of the 49 stitchable Metal functions no `ShaderBinding`
  declaration reaches yet.
- `Scripts/build-shaders.sh`, `Scripts/make-app.sh` and a `Makefile`. SwiftPM's
  command-line build has no Metal rule, so `default.metallib` is generated rather than
  committed and reached at runtime via `ShaderLibrary.bundle(.module)`. See
  `docs/adr/0001-metallib-provenance.md`.
- 30 further shader effects beyond the initial three: Blur, ColorGrading, Dissolve,
  Distortion, Electric, Fire, Hologram, Noise, Pixelate, Water, Wave, Displacement,
  Raymarching, Voronoi, CRT, Emboss, Frost, Invert, Kaleidoscope, Mosaic, Neon,
  Particles, Posterize, Scanlines, Sepia, Sharpen, Sketch, Swirl, Threshold and
  Vignette.
- CocoaPods support via `SwiftShaders.podspec` (later removed above, once it turned
  out never to have produced a working build).
- CI workflow, Dependabot, issue and pull-request templates, `.editorconfig`,
  `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, `Documentation/API.md`, a
  getting-started guide, an example, and shader/modifier templates.

### Changed

- **CI can now fail.** Both jobs carried `continue-on-error: true`, and the workflow
  never ran `build-shaders.sh`, so it exercised a package with no shader library at
  all. The flags are gone and a "Compile Metal shaders" step runs before `swift build`.
- CI runners moved from `macos-14` to `macos-15`. `Shader.compile(as:)` — the primary
  defect oracle the test suite now uses — requires macOS 15 / iOS 18.
- `default.metallib` is generated and gitignored rather than left untracked-and-
  unignored; CI regenerates it every run.
- The 208 call sites that build a `Shader` now go through one internal binding module
  (`Sources/SwiftShaders/Core/ShaderBinding.swift`) instead of each restating the
  function name, effect kind and geometry convention by hand. See
  `docs/adr/0004-binding-module-shape.md`.
- The 33 `.metal` files deduplicated against the new shared header: `luminance` /
  `getLuminance` (6 definitions under two names → 1) and the value-noise interpolation
  form (algebraically identical across the three prior implementations — the apparent
  difference was always the hash, not the maths). The two remaining hash-constant
  families are kept as distinctly named helpers, because unifying them would
  re-randomise every noise field built on them.
- The tautological legacy test suite (`ShaderEffectsTests.swift` — 1250 lines, 124
  tests, all passing even with `Metal/` deleted) was deleted in favor of tests that
  render, compile and cross-check against the metallib.
- The README's headline feature now describes the real mechanism —
  `ShaderLibrary.bundle(.module)` over `colorEffect`, `distortionEffect` and
  `layerEffect` — instead of the Bridge that applied no shader.
- `.metal` sources moved to `Sources/SwiftShaders/Metal/` and are excluded from the
  Swift build; the compiled `default.metallib` ships as a copied resource.

## [1.0.0] - 2026-02-03

Initial release.

### Added

- `ShaderLibrary` and `ShaderModifier`, the Metal-shader-as-SwiftUI-view-modifier core.
- Three shader effects: chromatic aberration, glitch and ripple, each as a `.metal`
  shader with a Swift modifier.
- Swift 5.9 package targeting iOS 17, macOS 14, tvOS 17 and visionOS 1, with no
  dependencies.
- SwiftLint configuration and MIT license.

[2.0.0]: https://github.com/SkelegonDK/SwiftShaders/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/SkelegonDK/SwiftShaders/releases/tag/v1.0.0
