# SwiftShaders — Shader Integrity & Architecture Remediation

**Status:** ready to execute · **Created:** 2026-08-04 · **Branch:** `claude/learn-codebase-37f658`

Each phase is self-contained and executable in a fresh chat context. Read **Phase 0** first, every time — it is the verified API contract that the rest of the plan depends on. Do not proceed to a later phase until the previous phase's verification checklist passes.

---

## Phase 0 — Verified facts (READ FIRST, EVERY SESSION)

Everything below was verified firsthand on this machine (Xcode 26.6, Swift 6.3.3, macOS SDK 26.5) by reading SDK files and running commands. **Do not re-derive these from memory, and do not trust web summaries that contradict them.**

### 0.1 The stitchable calling convention — the "Allowed APIs" list

Source: `/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.5.sdk/System/Library/Frameworks/SwiftUICore.framework/Versions/A/Modules/SwiftUICore.swiftmodule/arm64e-apple-macos.swiftdoc` (doc comments live here; the `.swiftinterface` strips them — extract with `strings -n 4 <swiftdoc> | grep stitchable`).

| Effect kind | Metal signature | SwiftUI supplies implicitly |
|---|---|---|
| `colorEffect` | `[[stitchable]] half4 name(float2 position, half4 color, args...)` | `position`, `color` (2) |
| `distortionEffect` | `[[stitchable]] float2 name(float2 position, args...)` | `position` (1) |
| `layerEffect` | `[[stitchable]] half4 name(float2 position, SwiftUI::Layer layer, args...)` | `position`, `layer` (2) |
| `ShapeStyle` fill | `[[stitchable]] half4 name(float2 position, args...)` | `position` (1) |

> **🚨 THE LOAD-BEARING FACT.** There is **no implicit `bounds` and no implicit `size`.** A function declaring `float4 bounds` requires the Swift caller to pass it explicitly. This is confirmed three ways: (a) the doc comments enumerate the implicit prefix exhaustively and never mention bounds; (b) `Shader.Argument.boundingRect` exists *precisely because* it is not implicit; (c) the repo's `float2 size` shaders, which pass size explicitly, are 100% correctly wired while every `float4 bounds` shader is broken.

```swift
// SwiftUICore.swiftinterface:6929
public static var boundingRect: SwiftUICore.Shader.Argument { get }
// doc: "Returns an argument value representing the bounding rect of the shape or view
//       that the shader is attached to, as `float4(x, y, width, height)`."
```

### 0.2 `Shader.Argument` — complete, exact

From `SwiftUICore.swiftinterface:6898–6936`. **Use only these. Do not invent factories.**

```swift
.float<T: BinaryFloatingPoint>(_ x: T)
.float2<T>(_ x: T, _ y: T)   .float2(_ point: CGPoint)   .float2(_ size: CGSize)   .float2(_ vector: CGVector)
.float3<T>(_ x: T, _ y: T, _ z: T)
.float4<T>(_ x: T, _ y: T, _ z: T, _ w: T)
.floatArray(_ array: [Float])          // → TWO MSL params: device const float*, int count
.boundingRect                          // → float4(x, y, width, height)
.color(_ color: Color)                 // → half4, premultiplied
.colorArray(_ array: [Color])          // → TWO MSL params
.image(_ image: Image)                 // → texture2d<half>; only ONE image per Shader
.data(_ data: Data)                    // → TWO MSL params
```

### 0.3 `ShaderLibrary` — there is no checked lookup

```swift
@dynamicMemberLookup public struct ShaderLibrary: Equatable, @unchecked Sendable {
  public static let `default`: ShaderLibrary
  public static func bundle(_ bundle: Bundle) -> ShaderLibrary
  public init(data: Data);  public init(url: URL)
  public static subscript(dynamicMember name: String) -> ShaderFunction { get }
  public subscript(dynamicMember name: String) -> ShaderFunction { get }
}
@dynamicCallable public struct ShaderFunction: Equatable, Sendable {
  public func dynamicallyCall(withArguments args: [Shader.Argument]) -> Shader
}
```

Both subscripts return **non-optional, non-throwing**. `dynamicallyCall` returns non-optional, non-throwing. **No compile-time check, no optional variant, no throwing variant exists.** This is why the 129 defects survived to runtime.

**The one first-party validation hook:**

```swift
@available(iOS 18.0, macOS 15.0, tvOS 18.0, visionOS 2.0, *)
extension Shader {
  public func compile(as type: Shader.UsageType) async throws
  public struct UsageType: Hashable, Sendable {
    public static let shapeStyle, colorEffect, distortionEffect, layerEffect: Shader.UsageType
  }
}
// doc: "For compilation to be successful the specified usage type must match how the
//       shader is eventually used to render, and its current argument values must match
//       the types of the arguments used when rendering."
// Throws: an error describing why compilation failed.
```

⚠️ **macOS 15+ only.** Package minimum is `.macOS(.v14)`; CI runs `macos-14`. This test must be `@available`-gated and CI must move to `macos-15`/`macos-latest` for it to run.

### 0.4 Availability of all shader APIs

`@available(iOS 17.0, macOS 14.0, tvOS 17.0, *)` + `@available(watchOS, unavailable)`. No explicit visionOS clause — it comes via iOS. The repo writes `visionOS 1.0` explicitly, which is stricter but compatible.

### 0.5 The verification oracle — `metal-objdump`

**Tool availability on this machine** (`xcrun --find`): `metal`, `metal-nm`, `metal-objdump`, `metal-readobj`, `metal-source`, `metallib`, `metal-ar`, `metal-lipo` all present. **`metallib-dis` does NOT exist** — `xcrun: error: unable to find utility "metallib-dis"`.

```bash
xcrun metal-objdump --metallib -d Sources/SwiftShaders/Resources/default.metallib
```
Runs in **0.12 s**, emits 66,399 lines containing exactly **256 entry-point `define` lines** — one per stitchable function, fully typed:

```llvm
define <4 x half>  @invert(<2 x float> noundef %0, <4 x half> noundef %1, float noundef %2)
define <2 x float> @ripple(<2 x float> noundef %0, <4 x float> noundef %1, float noundef %2, ...)
define <4 x half>  @crtLayerEffect(<2 x float> noundef %0, %"struct.metal::texture2d" %1, [5 x <2 x float>] %2, ...)
```

Type map: `<2 x float>`=`float2`, `<4 x half>`=`half4`, `<4 x float>`=`float4`, `float`=`float`.

⚠️ **Gotcha:** `SwiftUI::Layer` lowers to **two** IR parameters (`texture2d` + `[5 x <2 x float>]`). Naive IR-param counting over-counts layerEffect functions by one.

Other useful tools:
- `xcrun metal-nm --defined-only <metallib>` → names only, no types.
- `xcrun metal-readobj --all <metallib>` → per-function name, type, content hash. Confirms all 256 are `METALLIB_VISIBLE_FUNCTION`.
- `xcrun metal-source --extract=raw -f -o=<dir> <metallib>` → **recovers the original `.metal` sources byte-identically** (works because `build-shaders.sh` passes `-frecord-sources`). This is a free drift check: extracted source vs on-disk source.

### 0.6 The defect inventory — ground truth

Independently recounted with a comment-stripping, depth-counting parser. Artifacts in scratchpad: `metal-functions.tsv` (256), `swift-callsites.tsv` (216), `reconciliation.tsv` (216), `duplicate-view-methods.tsv`, plus reproducible `extract.py`.

| | Count |
|---|---|
| `[[stitchable]]` Metal functions | **256** (157 color, 60 distortion, 39 layer, 0 malformed; all names distinct) |
| Swift call sites | **216** (218 raw grep − 2 in doc comments) |
| **MATCH** | **87** |
| **ARITY** (all delta exactly −1) | **121** |
| **MISSING** (no such Metal function) | **6** |
| **KIND** (wrong effect method) | **2** |
| **Total broken** | **129 of 216 (59.7%)** — ⚠️ superseded: **157**, see the Phase 2 results box. This count is argument-*count* based and misses the 28 `half3` type mismatches. |
| Unreferenced stitchable functions | **49** |
| Duplicate `View` extension names | **7** |

**The `bounds`/`size` split is the whole story:**

| Convention | Metal fns | Call sites | Passing a matching arg | Result |
|---|---|---|---|---|
| `float4 bounds` | 144 | 122 | **0 (0.0%)** | 121 ARITY + 1 KIND, **zero MATCH** |
| `float2 size` | 85 | 68 | **67 (98.5%)** | 67 MATCH + 1 KIND, **zero ARITY** |
| Neither | 27 | 26 | — | 20 MATCH + 6 MISSING |

`.float4(` and `.boundingRect` occur **zero times** in all of `Sources/`. 121 of 129 defects (94%) are this one omission.

**All 6 MISSING** — every one in `Sources/SwiftShaders/Shaders/FluidSimulation/FluidSimulationModifier.swift`, and there is no `FluidSimulation.metal`:

| Line | Function | Args passed |
|---|---|---|
| 80 | `fluidSimulation` | 6 |
| 162 | `smoke` | 6 |
| 315 | `inkDiffusion` | 7 |
| 387 | `plasmaFluid` | 6 |
| 458 | `magneticField` | 6 |
| 529 | `oilSlick` | 6 |

**All 2 KIND** — also in `FluidSimulationModifier.swift`:

| Line | Function | Invoked as | Actually is | Metal decl |
|---|---|---|---|---|
| 244 | `waterSurface` | colorEffect, 6 args | distortionEffect, expects 5 | `Metal/WaterShader.metal:24` |
| 600 | `vortex` | colorEffect, 7 args | layerEffect, expects 5 | `Metal/SwirlShader.metal:209` |

> `smoke` is shipped to users — `Sources/SwiftShadersGallery/EffectCatalog.swift:558` lists it.

### 0.7 Build & CI state — verified by running

- `bash Scripts/build-shaders.sh` → **succeeds**, "Compiled 33 shaders". Warnings only (12 files, all unused-function/variable). Zero errors.
- `swift build` → `Build complete! (0.23s)`. `swift test` → `Executed 155 tests, with 0 failures`.
- **`Sources/SwiftShaders/Resources/default.metallib` is UNTRACKED in git and NOT gitignored.** `git ls-files` returns empty; `git check-ignore` exits 1.
- **CI never builds shaders.** `.github/workflows/ci.yml` runs `swift build -c release` + `swift test` directly; never `make shaders`.
- **SwiftPM emits a *warning*, not an error, for a declared-but-missing resource** (verified in SwiftPM's `TargetSourcesBuilder.swift`: `self.observabilityScope.emit(warning:)`). So a fresh CI checkout builds **green** with no shader library at all.
- **Both CI steps have `continue-on-error: true`** — test failures do not fail the build today.
- Toolchain: swift-tools-version 5.9, Swift 6.3.3. Tests are XCTest. **swift-testing already runs** alongside (Testing Library 1902, 0 tests found) — new tests may use either.

### 0.8 SwiftPM & Metal — hard constraints

- **SwiftPM's native build system never compiles `.metal`.** In `TargetSourcesBuilder.swift`, the `metal` rule appears only in `xcbuildFileTypes`, not `builtinRules`. Under `swift build`, `.process` on a `.metal` file **copies it verbatim**. Proof is still in this tree: `.build/.../SwiftShaders_SwiftShaders.bundle/` contains raw uncompiled `.metal` **and** swallowed `.swift` files from the previous config.
- **Keep `exclude: ["Metal"]` and `.copy("Resources/default.metallib")`.** Never `.process` the Metal directory.
- **One metallib per platform is mandatory.** All 8 SDKs compile fine individually, but merging fails — verified:
  ```
  $ xcrun metallib macosx.air iphoneos.air -o fat.metallib
  LLVM ERROR: multiple symbols ('invert')!
  $ xcrun metal-lipo -create m.metallib i.metallib -output uni.metallib
  air-lipo: error: ... have the same architecture air64_v28 and therefore cannot be in the
                   same universal binary
  ```
  Root cause: `-print-target-triple` is `air64-apple-darwin25.5.0` for **every** SDK — no OS discriminator.
- **`ShaderLibrary.bundle(_:)` looks for exactly one filename: `default.metallib`.** No documented platform-selection hook. ⚠️ This is an unresolved constraint — see Phase 7's open decision.
- `makeLibrary(filepath:)` is **deprecated** → use `makeLibrary(URL:)` (note the capitalised label, from `Metal.apinotes`).

### 0.9 Anti-patterns — DO NOT DO THESE

| ❌ Don't | ✅ Why / instead |
|---|---|
| Assume `bounds` or `size` is implicit | It isn't. Pass `.boundingRect` / `.float2(proxy.size)`. |
| Use `MTLFunction` to enumerate parameters | **No such API.** Full protocol read from `MTLLibrary.h:130–206` — no parameter list property. |
| Use `MTLComputePipelineReflection` on a stitchable fn | Impossible. All 256 are `MTLFunctionTypeVisible`, not `Kernel`; you cannot make a compute pipeline state from one. |
| Use `metallib-dis` | Does not exist on this machine. Use `metal-objdump --metallib -d`. |
| Assume `ImageRenderer` rasterizes shader effects | **UNPROVEN.** Apple's docs never mention shaders. Spike it in Phase 1 before relying on it. |
| `.process` the `Metal/` directory | Silently swallows sibling `.swift` files. Proven in this tree. |
| Build a fat multi-platform metallib | `metal-lipo` refuses. Verified above. |
| `grep '\[\[stitchable\]\]'` | Repo uses **two spellings** — `[[stitchable]]` (`InvertShader.metal:31`) and `[[ stitchable ]]` (`RippleShader.metal:46`). Use `\[\[\s*stitchable\s*\]\]`. |
| Count IR params naively for layerEffect | `SwiftUI::Layer` = 2 IR params. |
| Call `Shader.compile(as:)` unguarded | macOS 15+ / iOS 18+ only. |
| Trust "SwiftPM now compiles Metal automatically" | False for CLI builds. That describes Xcode. |

---

## Phase 1 — Make the build able to fail

**Nothing in this plan is verifiable until CI can go red.** Today it cannot: shaders aren't built, the metallib isn't tracked, a missing resource is a warning, and both CI steps swallow errors.

### Implement

1. **Decide metallib provenance.** *Recommendation: build in CI, do not commit.* A 2.4 MB binary regenerated on every shader edit is bad git churn, and Phase 7 will produce one per platform anyway. Add `Sources/SwiftShaders/Resources/*.metallib` to `.gitignore` and make CI run `make shaders` before `swift build`.
   *Alternative if you want `swift build` to work on a bare clone with no Xcode:* commit it instead, and add the drift check from step 3 to catch staleness. Pick one and record it in an ADR (Phase 8).
2. **Fix `.github/workflows/ci.yml`:**
   - Add a `make shaders` (or `bash Scripts/build-shaders.sh`) step **before** `swift build`.
   - **Remove `continue-on-error: true` from the test step.** This is the single highest-value line change in the plan.
   - Bump `runs-on: macos-14` → `macos-15` (required for `Shader.compile(as:)` in Phase 3).
3. **Fix `make clean`.** It currently deletes `Resources/default.metallib`, which `Package.swift:36` requires to exist — leaving the package unbuildable until `make shaders` reruns. Either make `clean` not delete it, or make `build` depend on regenerating it unconditionally.
4. **Spike: can `ImageRenderer` rasterize a shader effect?** ~20 lines, settles Phase 6's design:
   ```swift
   let v = Color.white.frame(width: 8, height: 8)
       .colorEffect(ShaderLibrary.swiftShaders.invert(.float(1.0)))
   let cg = ImageRenderer(content: v).cgImage   // inspect centre pixel: black or white?
   ```
   `invert` is a good probe — `Metal/InvertShader.metal:31`, colorEffect, 1 explicit arg, currently a MATCH.
   **Record the result in this file.** If white → `ImageRenderer` drops shader effects and Phase 6 must drop the golden-pixel test.
5. **Spike: does `Shader.compile(as:)` throw on an arity mismatch?** Apple documents type matching, not arity. Try it against `wave` (`Metal/WaveShader.metal:19`, needs 5, gets 4) and record the outcome.

### Verify

- [ ] `git status` shows metallib either tracked or ignored — not in limbo.
- [ ] Delete `Resources/default.metallib`, push, and confirm **CI is red** (or that the build step regenerates it). Green here means the gate still doesn't work.
- [ ] Introduce a deliberately failing test, push, confirm **CI is red**. Revert.
- [ ] `make clean && make build` succeeds from clean.
- [ ] Both spike results written into this file under "Phase 1 results".

### Guards

- Do not skip the two spikes. Phases 3 and 6 both branch on their answers.
- Do not `.process` the Metal directory to "fix" the resource problem.

### ✅ Phase 1 RESULTS — executed 2026-08-04

**Spike 1 — `ImageRenderer` DOES rasterize shader effects. Golden-pixel testing is viable.**

`Color.white` + `.colorEffect(invert(.float(1.0)))` rendered at scale 1, headless in `swift test`, 0.115 s:

| | centre pixel |
|---|---|
| with shader | `(0, 0, 0, 255)` — black |
| control, no shader | `(255, 255, 255, 255)` — white |

Phase 6 may keep the golden-pixel test. Apple's "may change in future releases" caveat still applies, so keep goldens coarse (a few probe pixels, generous tolerance), not full-image hashes.

**Spike 2 — `Shader.compile(as:)` catches ALL THREE defect classes, with precise diagnostics.** This is much stronger than the plan assumed and **simplifies Phase 2 substantially.**

| Probe | Result |
|---|---|
| `invert(.float(1.0))` as `.colorEffect` — correct | compiled OK |
| `wave(4 args)` as `.distortionEffect` — the repo's current ARITY bug | **THREW** |
| `wave(.boundingRect + 4 args)` — the Phase 3 fix | compiled OK |
| `invert` as `.distortionEffect` — KIND mismatch | **THREW** |
| `smoke(...)` — MISSING function | **THREW** |

Verbatim diagnostics — note the second line names the exact defect Phase 0.1 predicted:

```
ARITY   RBShaderError Code=2 "Function stitching failed: wave.
        Parameter at index 1: invalid type, float4, expected float.
        Too few function arguments: expected 5, received 4."
KIND    RBShaderError Code=2 "Function stitching failed: invert.
        Expected float2 result, has MTLDataTypeHalf4."
MISSING RBShaderError Code=1 "Unknown Metal function: smoke"
```

> **Revision to Phase 2.** Do **not** build a `metal-objdump` parser as the primary oracle. Enumerate every binding, call `compile(as:)`, assert it does not throw. `metal-objdump` remains useful for generating the *manifest* and for the drift check, but it is no longer needed to detect defects. This removes the `SwiftUI::Layer` two-IR-param gotcha and the two-spelling `[[stitchable]]` parsing problem from the critical path.

**Spike 3 — metallib loads in-process:** 256 function names via `device.makeDefaultLibrary(bundle: .module)`; `invert` ✅, `wave` ✅, `smoke` ❌. Ground truth from Phase 0.6 confirmed at runtime.

**❌ Correction to Phase 0.7 — "CI goes green with no metallib" is WRONG for this package.**

Verified by removing `default.metallib` and rebuilding: SwiftPM emits the predicted warning *and then the build fails hard*, because with no valid resources SwiftPM stops generating `Bundle.module` at all:

```
warning: Invalid Resource 'Resources/default.metallib': File not found.
Sources/SwiftShaders/Core/ShaderLibrary+Bundle.swift:19:18: error: type 'Bundle' has no member 'module'
```

The general inference (SwiftPM warns rather than errors on a missing resource) is correct, but this target declares exactly *one* resource, so losing it removes `Bundle.module` and the compile fails. Good news — but it is a confusing error, so `ShaderLibraryIntegrityTests` still earns its place by catching a *partial or truncated* metallib, which would compile fine.

**Changes landed**

| File | Change |
|---|---|
| `.github/workflows/ci.yml` | `macos-14` → `macos-15` (required for `compile(as:)`); added a **Compile Metal shaders** step before build; **removed `continue-on-error: true` from both jobs** |
| `.gitignore` | added `Sources/SwiftShaders/Resources/*.metallib` — decision recorded: generated, never committed, CI rebuilds it |
| `Makefile` | `clean` now removes `*.metallib`; comments explain why bare `swift build` is unsafe |
| `Tests/.../ShaderLibraryIntegrityTests.swift` | **new** — 2 tests: metallib present in bundle (no GPU needed), and loads with ≥200 functions plus spot checks across all three effect kinds |

`swift test` → **160 tests, 0 failures**. `make clean && make build` → clean.

> **🚨 BLOCKER FOR CI, discovered during verification.** Only **8 files** are tracked under `Sources/` — `Bridge/MetalToSwiftUIBridge.swift`, `Core/ShaderCore.swift`, all five `Enterprise/*.swift`, and `SwiftShaders.swift`. That is *exactly* the dead code from the Appendix, and nothing else. The other **89** source files, all 33 `.metal` files, `Makefile`, and `Scripts/` are untracked. **CI on `main` has been building a package that contains only the dead modules.** The workflow changes above do nothing until the real library is committed. Commit before Phase 2.

---

## Phase 2 — Build the binding oracle

Make the 129 defects visible as failing tests **before** fixing any of them. This is the seam the whole plan hangs on.

> **⚠️ Read the Phase 1 results box first.** The spikes proved `Shader.compile(as:)` throws on all three defect classes (arity, kind, missing) with precise diagnostics. **It is the primary oracle — build the tests on it.** The `metal-objdump` manifest below is now a secondary aid (for the generated signature record and the drift check), not the detection mechanism. Steps 1–2 are optional; step 3 is not.

### Implement

1. **`Scripts/extract-metal-signatures.sh`** — run `xcrun metal-objdump --metallib -d Resources/default.metallib`, parse the 256 `define` lines, emit a normalized manifest (TSV or JSON) of `name → (effect kind, ordered explicit param types)`.
   - Copy the parser shape from the scratchpad's `extract.py` (depth-counting, comment-stripping) rather than writing a line-based regex.
   - **Handle the `SwiftUI::Layer` two-IR-param collapse** (Phase 0.5).
   - Derive effect kind from IR shape: return `<4 x half>` + 2nd param `<4 x half>` → color; return `<2 x float>` → distortion; return `<4 x half>` + `texture2d` → layer.
2. **Check the manifest into the repo** at `Sources/SwiftShaders/Resources/shader-signatures.tsv` (or similar). It becomes the reviewable record of the Metal surface.
3. **`Tests/SwiftShadersTests/ShaderBindingTests.swift`** — three tests:
   - **Name existence:** every Swift call-site name is in `MTLLibrary.functionNames`. Get the library via `MTLCreateSystemDefaultDevice()?.makeDefaultLibrary(bundle: .module)` — copy the device pattern from `Sources/SwiftShaders/Utilities/MetalHelpers.swift:16`. *This catches the 6 MISSING.*
   - **Arity + kind:** every call site's explicit arg count and effect method match the manifest. *This catches the 121 ARITY and 2 KIND.*
   - **Drift:** `xcrun metal-source --extract=raw` output matches the on-disk `.metal` sources, proving the metallib is current.
4. **Expect these tests to FAIL on first run, with 129 failures.** That is the success criterion for this phase.

### Verify

- [x] `xcrun metal-objdump --metallib -d ... | grep -c '^define'` → 4035 total, **256** non-`internal` entry points. (The plan's original "256 define lines" omitted the `internal` stitching-traits templates; filter on ` internal `.)
- [x] Manifest has 256 rows; kind histogram is **157 color / 60 distortion / 39 layer**.
- [x] `swift test` reports the binding failures — **157**, not the 129 predicted here: 121 arity, 28 type, 6 missing, 2 kind. See the results box.
- [x] CI is red.

### Guards

- Do not fix any defect in this phase. The failing count is the deliverable.
- Do not use `MTLFunction` reflection (0.9). `functionNames` is the only runtime introspection that works.
- Do not hand-maintain the manifest — it must be generated.

### ✅ Phase 2 RESULTS — executed 2026-08-04

**The oracle is built and red. Two independent oracles agree exactly: 157 of 216 call sites are broken.**

> **🚨 THE DEFECT COUNT IS 157, NOT 129.** Phase 0.6's inventory counted arguments, so it could not
> see a fourth defect class: **28 call sites pass `.float3(…)` to a `half3` parameter.** No
> `Shader.Argument` factory produces a `half3` — the only half-typed argument SwiftUI can supply is
> `.color`, which is a `half4` — so these shaders cannot be driven from Swift at all, whatever the
> caller passes. SwiftUI's stitcher rejects them with `unsupported MTLDataType: 18` (= `MTLDataTypeHalf3`).
> **They need the Metal declaration changed, not the call site**, which makes them a different kind of
> work from Phase 3's 121. See "New work" below.

| Defect class | Count | Test | Fixed in |
|---|---|---|---|
| ARITY — wrong number of arguments | **121** | `testEveryCallSitePassesTheNumberOfArgumentsItsFunctionExpects` | Phase 3 |
| TYPE — `half3` parameter, unbindable | **28** | `testEveryCallSitePassesArgumentsOfTheDeclaredTypes` | **new, see below** |
| MISSING — no such Metal function | **6** | `testEveryCallSiteResolvesToAFunctionInTheLibrary` | Phase 4 |
| KIND — wrong effect method | **2** | `testEveryCallSiteUsesTheEffectMethodItsFunctionDeclares` | Phase 4 |
| **Total broken** | **157 of 216 (72.7%)** | | |

The four static tests partition the defects — each site is counted once, in the first class that
applies. `Shader.compile(as:)` then rejects **exactly the same 157**, independently: no site the
static tests call broken is accepted, and no site they call clean is rejected other than the 28. The
121 / 6 / 2 figures reproduce Phase 0.6 exactly.

`swift test` → **176 tests, 158 failures** (157 defects + 1 aggregate from the compile oracle).

**What landed**

| File | What it is |
|---|---|
| `Scripts/extract-metal-signatures.py` | Parses `metal-objdump --metallib -d` into a manifest. Collapses `SwiftUI::Layer`'s two IR params; derives effect kind from IR shape; fails on duplicate or unclassifiable names. Called from `build-shaders.sh`, so it cannot drift. |
| `Sources/SwiftShaders/Resources/shader-signatures.tsv` | **Committed.** 256 rows, `157 color / 60 distortion / 39 layer`. Declared as a package resource, so tests read it from `Bundle.module`. |
| `Tests/…/Support/ShaderCallSiteScanner.swift` | Comment-stripping, depth-counting scanner over `Sources/**/*.swift`. Finds 216 call sites with effect method and argument kinds. |
| `Tests/…/Support/ShaderSignatureManifest.swift` | Manifest reader. |
| `Tests/…/ShaderCallSiteScannerTests.swift` | 12 tests on the scanner itself. |
| `Tests/…/ShaderBindingTests.swift` | 7 tests: the four defect classes, the manifest-matches-metallib guard, and the drift check. |
| `.github/workflows/ci.yml` | Fails if the committed manifest is stale w.r.t. the `.metal` sources. |

**Verification**

- Manifest cross-checked against Phase 0.6's independently *source*-derived inventory: 256 names, **0 signature disagreements**.
- The Swift scanner cross-checked against Phase 0.6's Python extractor: **216 sites, 0 disagreements** on file, line, function, effect method, argument count and argument kinds. Two independent implementations.
- Manifest is byte-identical across a `make clean && make build`.
- **Negative controls, all red:**
  | Control | Result |
  |---|---|
  | Rename a `[[stitchable]]` function, rebuild, regenerate | MISSING 6 → **7**; compile oracle 157 → **158** |
  | Regenerate shaders but not the manifest | manifest guard fails, naming both the added and removed function |
  | Edit a `.metal` source without rebuilding | drift check fails |
  | Delete `default.metallib` | **8 tests fail** |

**❌ Correction to Phase 1 — deleting the metallib is no longer a build failure.** Phase 1 recorded
that removing `default.metallib` breaks the build outright, because losing the target's only resource
stops SwiftPM generating `Bundle.module`. Declaring `shader-signatures.tsv` as a second resource ends
that: the package now builds, and 8 tests fail instead — including `ShaderLibraryIntegrityTests`,
which Phase 1 added for exactly this. **This is an improvement** (a legible test failure beats
`error: type 'Bundle' has no member 'module'`), but it means the resource-bundle tests are now
load-bearing rather than a backstop. Do not delete them.

**⚠️ `XCTFail` issues raised from an async test are not all reported.** `testEveryCallSiteCompiles`
raised 157 issues; XCTest's console printed **85**, and the run summary counted 85. The internal
counter and a written-out dump both said 157. The compile oracle therefore reports one aggregate
failure containing every rejection. **If you add a test that raises many issues from an `async`
method, do not trust the reported count** — count in-process and assert on that number.

### New work this phase uncovered — the 28 `half3` bindings

34 of the 256 Metal functions declare a `half3` parameter; 28 call sites bind to them, across 9
modules (`Emboss`, `Mosaic`, `Neon`, `Particles`, `Posterize`, `Sepia`, `Sketch`, `Threshold`,
`Vignette`). Every one is a colour-ish uniform (`lowColor`, `highColor`, `tintColor`, …).

Two options, and this needs a decision before Phase 3 is called done:

1. **`half3` → `float3` in the Metal declarations** (28 functions actually referenced, 34 in total).
   Call sites already pass `.float3(…)`, so no Swift changes. Costs a little register bandwidth.
2. **`half3` → `half4` and pass `.color(…)`** from Swift. Idiomatic for colour uniforms, and
   `.color` is the factory Apple provides for exactly this, but it changes the shader bodies and the
   28 call sites, and drags alpha into functions that do not want it.

*Recommendation: option 1.* It is a one-token edit per declaration, keeps the call sites untouched,
and does not change any shader body. Fold it into Phase 3, which is already the mechanical-edit phase,
and record the choice in a Phase 8 ADR.

> Note for Phase 3: the diagnostic for a `half3` function also complains that the `SwiftUI::Layer`
> parameter is an "unsupported struct type". That is a **cascade, not a second defect** — `kaleidoscope`
> declares the identical `SwiftUI::Layer` parameter and compiles cleanly. Fix the `half3` and the
> layer complaint goes with it.

---

## Phase 3 — Fix the 121 arity defects

Mechanical and uniform: every one is a `float4 bounds` shader missing its bounds argument, delta exactly −1, bounds always the **first** explicit parameter.

### Implement

For each of the 122 `float4 bounds` call sites, insert `.boundingRect` as the **first** argument:

```swift
// before — Sources/SwiftShaders/Shaders/Wave/WaveModifier.swift:62
ShaderLibrary.swiftShaders.wave(.float(time), .float(amplitude), .float(frequency), .float(direction))
// after
ShaderLibrary.swiftShaders.wave(.boundingRect, .float(time), .float(amplitude), .float(frequency), .float(direction))
```

- Work file by file, using `scratchpad/reconciliation.tsv` as the worklist. `Shaders/Water/` (6 sites) and `Shaders/Distortion/` (7 sites) are good starters — small, fully broken, self-contained.
- **Copy the correct pattern from `Sources/SwiftShaders/Shaders/Kaleidoscope/KaleidoscopeModifier.swift:87-93`**, which already passes its size argument explicitly and is a MATCH.
- Alternative: change the Metal side to the `float2 size` convention instead. *Not recommended* — it means editing 144 Metal declarations plus their bodies rather than adding one token at 122 Swift sites, and `.boundingRect` gives the shader the origin too.

### Verify

- [ ] `grep -rc '\.boundingRect' Sources/ ` → **122**.
- [ ] Binding tests: **0 arity failures**. Remaining: **36** (28 type + 6 missing + 2 kind), or **8** if the `half3` work from the Phase 2 results box is folded in here as recommended.
- [ ] `swift build` clean.
- [ ] Run the Gallery (`make app` / `Scripts/make-app.sh`) and confirm a `bounds`-convention effect (e.g. Wave, Ripple, Barrel) now renders correctly rather than reading a garbage first uniform.

### Guards

- Do not "fix" a site by deleting the `float4 bounds` parameter from the Metal function — that breaks the shader body, which uses it.
- Do not use `.float4(0,0,w,h)` where `.boundingRect` is meant. The latter is supplied by SwiftUI at draw time and is correct under transforms.
- Do not touch the 85 `float2 size` shaders. They are already 100% correct.

### ✅ Phase 3 RESULTS — executed 2026-08-04

**149 of the 157 defects are fixed. 8 remain, all of them Phase 4's.**

| | Before | After |
|---|---|---|
| ARITY | 121 | **0** |
| TYPE (`half3`) | 28 | **0** |
| MISSING | 6 | 6 |
| KIND | 2 | 2 |
| `Shader.compile(as:)` rejections | 157 | **8** |

`swift test` → **178 tests, 9 failures** (8 defects + 1 aggregate), all in `FluidSimulationModifier.swift`.

**The 121 arity fixes.** Every one was uniform, which was checked before editing rather than assumed:
all 121 had a delta of exactly −1 and `float4` as their first explicit parameter. `.boundingRect` was
inserted as the first argument at each, preserving both call-site layouts in the codebase (inline for
single-line calls, its own line matching the existing indentation for multi-line ones). 17 files.

**The 28 `half3` fixes** *(option 1, chosen by the user)*. 55 parameters across 34 stitchable
functions retyped `half3` → `float3`. Only parameter lists were touched — `half3` locals inside
shader bodies are untouched, since half arithmetic is cheaper and nothing outside the function can
observe it. That produced 43 compile errors where a now-`float3` parameter met a `half3` local; each
was fixed by wrapping the parameter at the point of use in `half3(…)`, which restores exactly the
previous semantics (the value was rounded to half before the arithmetic anyway). One expression in
`EmbossShader.metal:209` was reassociated (`metalColor * half(highlight)` → `half3(metalColor * highlight)`).

**Verification**

- `make clean && make build` clean, Gallery target included. Shader build: 0 errors, and no new warnings.
- `grep -rho '\.boundingRect' Sources/` → **121**. The 122nd `float4 bounds` call site is `waterSurface`,
  which is a KIND defect and belongs to Phase 4.
- `.float4(` in `Sources/` → **0**. No site fakes the bounds rect.
- `half3` in stitchable parameter lists → **0**. Manifest still 256 rows, 157/60/39.
- New `Tests/…/ShaderRenderingTests.swift` — see below.

**🚨 A broken binding renders the view PURE BLACK, it does not degrade to unmodified content.**
Measured directly: a 64×64 black→white gradient under `pixelate`, sampled along one row.

| | row 8, every 4th pixel |
|---|---|
| no shader | `0,1,8,20,36,51,66,84,102,119,138,156,177,196,216,237` — smooth |
| with `.boundingRect` (fixed) | `7,7,7,7, 65,65,65,65, 135,135,135,135, 213,213,213,213` — quantised at exactly 16 |
| without `.boundingRect` (the bug) | `0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0` — **all black** |

So the 121 arity defects were not a subtle visual degradation; those effects were rendering black.
This is also why the tautological test suite never noticed: nothing rendered anything.

**New test — `ShaderRenderingTests`.** The binding tests prove a call site's arguments have the right
count and types; they cannot prove the shader receives the right *values*. A site missing its
`.boundingRect` still passed a well-typed argument list — every later argument simply slid one
position left. `pixelate` is the probe because its output is a direct function of one argument, so
the test asserts the image is quantised at exactly the block size it passed. **Negative control run:
remove `.boundingRect` from the test's own call site and it fails** ("the whole row is one colour").
A second test asserts the source gradient is not already flat, so the first cannot pass vacuously.

This is an early down-payment on Phase 6 item 6, which the Phase 1 spike had already cleared.

> ⚠️ When writing a negative control for a rendering test, edit the call site **the test itself
> uses**. The first attempt here edited `PixelateModifier.swift`, which the test never calls, and the
> control passed — briefly looking like the test was worthless when it was the control that was wrong.

---

## Phase 4 — Resolve the FluidSimulation family

All 8 remaining defects (6 MISSING + 2 KIND) live in one file: `Sources/SwiftShaders/Shaders/FluidSimulation/FluidSimulationModifier.swift` (761 lines). There is no `FluidSimulation.metal`.

### Implement

**Decide:** write the 6 missing shaders, or delete the module.

*Recommendation: delete.* The module has never worked — 6 of its 8 functions bind to nothing, and the other 2 hijack `waterSurface` and `vortex` from `Shaders/Water/` and `Shaders/Swirl/` through the wrong effect method. Writing 6 new fluid shaders is new feature work, not remediation, and shouldn't block this plan.

- **If deleting:** remove the file, remove `smoke` from `Sources/SwiftShadersGallery/EffectCatalog.swift:558`, and check the 7 duplicate `View` extension names (`scratchpad/duplicate-view-methods.tsv`) — deleting this file resolves `vortex` and `waterSurface` collisions outright.
- **If implementing:** add `Sources/SwiftShaders/Metal/FluidSimulation.metal` with the 6 functions matching the arg counts already at the call sites (80: 6, 162: 6, 315: 7, 387: 6, 458: 6, 529: 6 — **plus** `.boundingRect` or a `float2 size`, per the convention you choose). Fix line 244 to `.distortionEffect` and line 600 to `.layerEffect` with the correct arg counts (5 each).

Either way, resolve the remaining 5 duplicate `View` extension names (`embers`, `neonElectric`, `pinch`, `twirl`, `voronoiNoise`) — they compile as label-distinguished overloads but are a real navigability hazard.

### Verify

- [ ] Binding tests: **0 failures**, all 216 (or fewer, if deleted) call sites MATCH.
- [ ] `swift build` clean; Gallery launches; no effect in the catalog resolves to a missing function.
- [ ] `scratchpad/dupes.py` rerun shows the intended set of duplicates resolved.

### Guards

- Do not stub the missing shaders with pass-through bodies to make the tests green. Delete or implement.
- Do not leave `smoke` in the Gallery if the module is deleted.

### ✅ Phase 4 RESULTS — executed 2026-08-05

**Deleted, per the user's decision. The binding tests are green: 0 defects across all 208 call sites.**

| | |
|---|---|
| `Sources/SwiftShaders/Shaders/FluidSimulation/` | removed (761 lines, 8 modifiers, 8 `View` methods) |
| `Sources/SwiftShadersGallery/EffectCatalog.swift` | `smoke` entry removed — it was the one effect of this module shipped to users. Catalog: 92 → **91** |
| Call sites | 216 → **208** |
| `Shader.compile(as:)` rejections | 8 → **0 of 208** |
| `swift test` | **178 tests, 0 failures** |

Nothing outside the module referenced it — no other file mentioned any of its eight types. `make build`
and `make app` both clean; the Gallery packages.

**Duplicate `View` extension names: 7 → 5, as predicted.** Deleting the module resolved the `vortex`
and `waterSurface` collisions outright.

**⚠️ The remaining 5 were NOT renamed — this is a deliberate deferral, not an oversight.** Every one is
the same shape: an older static variant taking `Float` and no clock, and a newer animated variant
taking `time: Double` first.

| Name | Static variant | Animated variant |
|---|---|---|
| `embers` | `Particles/…:320` `(density:speed:)` | `Fire/…:272` `(time:density:speed:size:)` |
| `neonElectric` | `Neon/…:263` `(color:intensity:)` | `Electric/…:282` `(time:glowIntensity:flickerSpeed:)` |
| `pinch` | `Swirl/…:280` `(strength:radius:)` | `Displacement/…:1134` `(time:amount:radius:center:)` |
| `twirl` | `Swirl/…:290` `(angle:)` | `Displacement/…:1119` `(time:angle:radius:center:)` |
| `voronoiNoise` | `Noise/…:297` `(time:scale:intensity:)` | `Voronoi/…:716` `(time:scale:jitter:edgeWidth:)` |

These are legal, label-distinguished overloads bound to genuinely different Metal functions. They are
**not defects** — no test can be made to fail on them — and renaming any of them is a **breaking change
to the published public API** (`Package.swift` product and `SwiftShaders.podspec`).

The collision is a *taxonomy* problem: two different effects claiming one name. That is precisely what
**7a** is for, which already has to reconcile identity and category drift across four competing
catalogues, and **Phase 5**, which reshapes how effects are addressed at all. Renaming here would churn
the public API once now and again in 5/7a. → **Folded into 7a.** The `voronoiNoise` pair is the one to
look at first: both are animated, so it is a true duplicate rather than a static/animated pair.

### Verify (4)

- [x] Binding tests: **0 failures**, all 208 call sites MATCH.
- [x] `swift build` clean; Gallery builds and packages; no catalogued effect resolves to a missing function.
- [x] Duplicate `View` method names: 7 → 5, with the intended two resolved.

---

## Phase 5 — Deepen: one binding module

Only now, with the seam verified, is it worth changing its shape. *(Report candidate 1.)*

### Implement

Introduce a module that owns name + effect kind + argument list, so the 216 call sites stop each restating the convention:

```swift
// sketch — design it properly before committing to this shape
public struct ShaderBinding {
    let name: String
    let kind: EffectKind          // .color | .distortion | .layer
    let arguments: [Shader.Argument]
}
```

The interface should make the wrong thing unrepresentable: a caller cannot pick the effect method independently of the binding, and `.boundingRect` is supplied by the module rather than remembered at each site.

- **Before implementing, run `/design-an-interface`** to explore 2–3 shapes. There is a real fork: a generated enum of bindings (compile-time safe, needs codegen) vs a runtime-validated value type (simpler, checked by Phase 2's tests).
- The Phase 2 manifest is the natural codegen input if you go that route.

### Verify

- [ ] Binding tests still pass, now exercising the module's interface rather than raw call sites.
- [ ] `grep -c 'ShaderLibrary.swiftShaders' Sources/` drops sharply — call sites go through the module.
- [ ] Gallery renders identically. Capture before/after screenshots.

### Guards

- Do not add this layer *on top of* the existing call sites — replace them. Two paths is the problem you're fixing.
- Do not invent a `ShaderLibrary` API that doesn't exist (0.3). The module wraps the dynamic lookup; it cannot make it checked.

### ✅ Phase 5 RESULTS — executed 2026-08-05 (commit `ec57571` + docs commit)

**Done. All 208 call sites go through one internal binding module; the tests enumerate the module;
the migration itself was caught making 4 mistakes, and the stricter tests exposed 2 latent
pre-existing bugs no earlier oracle could see.**

**The design** — `/design-an-interface` ran with three deliberately divergent briefs:

| Design | Verdict |
|---|---|
| A — one string-keyed value type, manifest consulted at runtime | Rejected: per-site checking degrades to debug-time preconditions, tests can only compile synthesized arguments, every modifier stack gains a `.visualEffect` wrapper, and the TSV becomes load-bearing in the shipped product |
| B — 256 generated factories with typed labels, codegen from the manifest | Rejected *for now*: strongest compile-time story, but it commits Metal parameter names and 256 symbols as public API before 7a decides the descriptor's shape, and needs a second extraction pipeline (parameter names). **Kept as input to 7a.** |
| C — per-kind types, phantom geometry, registry | **Chosen, with two amendments** |

The amendments, both driven by measurement: geometry became a declared *value* rather than a phantom
type (the phantom bought no call-site safety — callers never spell geometry either way — and cost a
9-overload diagnostics tax), and `maxSampleOffset` kept a per-site override because ~10 sites compute
it from effect parameters (`radius`, `pixelSize`, …) — a per-binding constant cannot express that.
A third choice against all three agents: the module is **`internal`**. Its only consumers are the
208 in-target call sites; the public `View` extensions and modifiers are untouched, and 7a keeps its
freedom.

**The shape** (`Sources/SwiftShaders/Core/ShaderBinding.swift`, ~250 lines): three concrete types
`ShaderBinding.Color/.Distortion/.Layer` (kind is nominal — the applier method is picked by overload
resolution, unrepresentable to get wrong); `LeadingGeometry` = `.boundingRect | .viewSize | .plain`;
`SampleRegion` = `.fixed | .viewSize | .perSite` (perSite = every application must pass
`maxSampleOffset:`, asserted in debug); one `View.shaderEffect(_:_:)` applier per kind; declarations
live in a `ShaderFamily` enum per modifier file (33 families, 207 bindings), listed in
`ShaderBindingRegistry`.

**The test rework** — the four defect classes survive, retargeted, plus a fifth:

| Check | Yardstick |
|---|---|
| name exists / kind matches | manifest, per *declaration* |
| **geometry matches (new)** | manifest's first explicit parameter type — `float4`⇔bounds, `float2`⇔size, verified exact against Phase 0.6's name-derived split (144/85/27) before being trusted |
| arity / argument types | manifest, per *application site*, via a new declaration+application scanner |
| perSite sites pass an offset | declaration ↔ site cross-check |
| registry completeness | declarations scanned from source — the registry cannot vouch for itself |
| compile oracle | `Shader.compile(as:)` over every site, assembled by the binding's own `makeShader`, so it verifies the production prefix path |

Raw-call-site scanning is now a **zero-tolerance lint** (2 legitimate occurrences remain in
`Sources/`: the module's lookup and a doc comment). `ShaderRenderingTests` renders through the
module and goes red if `pixelate`'s declared geometry is wrong (control 6).

**Defects caught on the suite's first run — all five fixed:**

1. **4 migration-script bugs**: the transformer didn't strip comments, so an inline `// comment`
   after an argument swallowed the following argument onto a commented-out line (`scanlinesLCD`,
   `scanlinesRolling`, `vignetteAnimated`, `emboss`). Swift compiled it happily; the arity tests and
   compile oracle named all four.
2. **2 latent pre-existing bugs** (`emboss`, `polaroid`): size-convention functions whose sites
   passed a literal `.float2(1, 1)` annotated *"Will be replaced by proxy"* — nothing ever replaced
   it. Types and arity were correct, so Phase 2's oracle and `compile(as:)` had always passed them;
   only the new geometry class could see it. Both now declare `.viewSize` and receive the real view
   size — **a deliberate rendering change** (emboss computed texel offsets against a 1×1 surface).

**Negative controls — six, all red, each edit confirmed in the file before the run:**
geometry lie · kind lie · registry omission · perSite site without offset · dropped argument ·
`pixelate` declared `.plain` (rendering test red). Tree restored, full suite green after.

**🔴 New trap, earned the hard way — a control's *cleanup* is an edit too.** The first control run
"restored" files with `git checkout --` while the migration was still uncommitted — silently
reverting three files to their pre-migration state — and its verdict grep matched `failures` but
XCTest prints `1 failure`, so every control printed no verdict at all. Two silent no-ops in one
harness, in a session already carrying trap #7. The fixes now in practice: **commit before running
destructive controls; make control edits with an asserted exact-string replace; grep verdicts with a
pattern that matches the singular; and confirm the restore the same way as the edit.**

**Verification** (all fresh): `swift test` → **69 tests, 0 failures**; compile oracle **0 rejections
of 208**; `make clean && make build` clean; `make app` packages the Gallery.

- [x] Binding tests pass, exercising the module's interface rather than raw call sites.
- [x] `ShaderLibrary.swiftShaders` in `Sources/` → **2** (module lookup + doc comment), from 209.
- [x] Gallery builds and packages. *Deviation from the checklist:* no before/after screenshots were
  captured — rendering equivalence rests on `ShaderRenderingTests` going through the module plus the
  0-of-208 oracle, and `emboss`/`polaroid` are *deliberately not identical* (see above).

---

## Phase 6 — Replace the test suite

*(Report candidate 6.)* Today: 155 tests, ~100 tautological, ~22 `XCTAssertNotNil` on a non-optional `some View`, **all pass with `Metal/` deleted**.

### Implement

1. **Delete** the ~122 tautological and vacuous tests in `Tests/SwiftShadersTests/ShaderEffectsTests.swift`. Keep the ~19 that assert real behavior (`testHSLToRGB`, `testSmoothstep`, `testKeyframeInterpolation`, `testOpacityClamping`, the easing and `ShaderMath` tests).
2. **Delete** `testMemoryFootprint`-style assertions — `MemoryLayout<CGPoint>.size == 16` is a platform ABI fact, and the 0.1 s wall-clock loop is flaky.
3. **Keep** Phase 2's binding tests as the core.
4. **Add a descriptor-consistency test** (feeds Phase 7): ids unique, every default inside its declared range, categories agree across catalogs.
5. **Add `Shader.compile(as:)` coverage**, gated `@available(macOS 15, *)`, per the Phase 1 spike result. This is the only first-party validation of argument *types*.
6. **Golden-pixel test — only if the Phase 1 spike proved `ImageRenderer` applies shader effects.** If it didn't, note that here and skip it; do not substitute a hand-rolled Metal compute harness, which duplicates SwiftUI's binding semantics and proves less than it appears to.

### Verify

- [ ] Delete `Sources/SwiftShaders/Metal/` locally, rebuild the metallib empty, run `swift test` → **tests FAIL**. This is the acceptance criterion for the whole phase. Restore afterward.
- [ ] Test count drops from 155 to roughly 40–60, and the suite covers more.
- [ ] CI red on a deliberately broken shader name; green on `main`.

### Guards

- Do not assert `XCTAssertNotNil` on a non-optional. It cannot fail.
- Do not write a test that constructs a value and asserts its stored properties equal the literals just passed in.
- Do not assume `ImageRenderer` works (0.9).

### ✅ Phase 6 RESULTS — executed 2026-08-05 (commit `f0854b4`)

**Done. 178 → 65 tests, 0 failures.**

| | |
|---|---|
| `ShaderEffectsTests.swift` | **deleted whole** — 1250 lines, 124 tests, 5 suites |
| `SwiftShadersTests.swift` | 4 tautologies deleted, 2 mixed tests rewritten as clamping-only |
| `CatalogConsistencyTests.swift` + `Support/EffectCatalogSource.swift` | **new**, 15 tests |
| `XCTAssertNotNil` in `Tests/` | 38 → **2**, both on genuinely `Optional` values |
| `Shader.compile(as:)` | **0 rejections of 208** |
| Acceptance: suite with no shaders | **216 failures** ✅ |

**⚠️ Two of this phase's stated premises were wrong. Do not repeat them.**

1. **"All 155 pass with `Metal/` deleted" was already false before this phase started.** It described the
   suite as it was at Phase 0. Phases 2–3 added the binding and rendering tests, so the acceptance
   criterion was *already* met on arrival — measured, not assumed: a metallib built from a placeholder
   `.metal` declaring no `[[stitchable]]` function produced **216 failures**. The phase's real value was
   never making the suite fail; it was deleting the 124 tests that could not.
2. **Item 5 (`Shader.compile(as:)` coverage) and item 6 (golden-pixel test) were already done** by
   Phases 2 and 3. `ShaderRenderingTests` carries its own negative control. Nothing was added for either.

**How the dead tests were identified — the method matters more than the verdict.** Rather than reading
them, the whole suite was run against a shader library containing zero stitchable functions. Suites that
*passed* under that condition prove nothing about shaders:

| Passed with zero shaders | Failed (real coverage) |
|---|---|
| `VoronoiShaderTests`, `DisplacementShaderTests`, `ViewExtensionTests`, `EdgeCaseTests`, `PerformanceCharacteristicTests` — **all five from `ShaderEffectsTests.swift`** | `ShaderBindingTests`, `ShaderLibraryIntegrityTests`, `ShaderRenderingTests` |
| `SwiftShadersTests`, `ShaderCallSiteScannerTests` — legitimately shader-independent (math, config, fixtures); **kept** | |

Its 302 assertions were 262 `XCTAssertEqual` comparing a stored property to the literal just passed to the
initialiser, 36 `XCTAssertNotNil` on a non-optional `some View`, and exactly 3 others — the two
`MemoryLayout` ones and the 0.1 s wall-clock loop the plan already called out.

**🔴 The new parser found its own under-scanning bug — this is the lesson of the phase.**
`EffectCatalogSource` first keyed on a **line prefix**, exactly like `ShaderCallSiteScanner`. That made the
**21 params the catalogue declares inline** (`params: [.init("angle", -360...360, 180)]`) invisible — and
the completeness guard invisible to them too, because it counted the same way. **It agreed with itself and
reported success over 89% of the file.** Both now scan occurrences anywhere on a line, with a word-boundary
check so the `v.rippleEffect(` calls in the closure bodies are not counted as entries: **91 effects, 194
params**, up from 173. Proven by breaking one of the previously invisible params and watching the test name
it by file and line.

> **Generalise this.** A completeness guard that derives its yardstick the same way as the thing it guards
> is not a guard. The Phase 2 manifest avoids this by construction — its yardstick is the metallib, an
> independent artefact — but any future scanner needs a yardstick it does not itself produce.

**Negative controls — every new test was proven able to fail, then restored:**

| Control | Result |
|---|---|
| Slider default pushed out of range | 🔴 named `EffectCatalog.swift:26` |
| Same, on a previously *invisible* inline param | 🔴 named `EffectCatalog.swift:133 sepia.intensity` |
| Gallery effect id duplicated | 🔴 |
| `ShaderCatalog` id duplicated | 🔴 |
| `max(1.0, pixelSize)` clamp removed | 🔴 3 assertions |
| `progress.clamped(to: 0...1)` removed | 🔴 2 assertions |

⚠️ **Two controls silently no-op'd on the first attempt** — a `sed` pattern that never matched and a
Python replace whose guard was false — and each produced a *green* run that looked like proof. This is the
Phase 3 lesson recurring in a new form: **always confirm the control actually changed the file** before
believing the run. `grep` for the edit, or `diff` against a copy.

**Not done, deliberately:** the plan's "categories agree across catalogs". `ShaderCatalog` (30, library)
and `EffectCatalog` (91, gallery executable) use disjoint id vocabularies and different category enums, so
a cross-catalogue assertion cannot be written until 7a decides which is authoritative. The invariants that
hold today are locked instead: ids unique within each catalogue, every entry reachable by its own id, every
gallery default inside its declared range.

---

## Phase 7 — Descriptor, catalogs, clock, Metal header, distribution

The remaining report candidates. Each is independent — execute in any order, or drop any of them.

### 7a — One effect descriptor *(candidate 3)*

Same facts are authored four times: init defaults, `View` extension defaults, `ShaderCatalog` row, `EffectCatalog` row. Measured drift: **30 / 92 / ~213** competing effect counts; `gaussianBlur` catalogued with no Swift function; 8 category conflicts; `chromatic` default 0.02 in `ShaderPreset` vs 0.01 everywhere else; `isAnimatable` and `minimumVersion` dead (all 30 rows take defaults); 8 Particles entries flagged `animated: false` that self-animate; ~120 public effects in neither catalog.
*Note:* all ~200 Gallery slider defaults **do** match their function defaults — the drift is identity and taxonomy, not numbers.
→ Make the descriptor the module; `View` extension, catalog and Gallery read it. Verify with the Phase 6 consistency test.

### 7b — One clock *(candidate 4)*

Two conventions ~7.8×10⁸ s apart: `timeIntervalSinceReferenceDate` (ShaderView, AnimatedShader, `RippleModifier.swift:187`) vs `startTime.distance(to:)` (22 modifiers, Gallery). `ShaderView.animationTime` is never written, so the non-animated branch is frozen at 0. `ShaderAnimator` is a 468-line `CADisplayLink` engine with zero call sites.
→ One `ShaderClock` owning elapsed time, pause and speed, with `TimelineView` as its implementation and an injectable clock for tests. Delete `ShaderAnimator` or move it behind the same interface.

### 7c — Metal common header *(candidate 5)*

No project-local `#include` exists in any of the 33 `.metal` files. `hash` defined 5×, `luminance` 6× under two names, 2D value noise **3× with different results for the same input** (`FrostShader.metal:27` / `SketchShader.metal:25` use `mix(a,b,u.x) + …`; `NoiseShader.metal:19` uses `mix(mix(a,b,u.x), mix(c,d,u.x), u.y)`). 2D rotation open-coded 12+ times, 5× inside `SwirlShader.metal` alone.
→ `Sources/SwiftShaders/Metal/SwiftShadersCommon.h`, included everywhere. `build-shaders.sh` already compiles the directory as a unit. While here, clear the 12 unused-function/variable warnings from 0.7.

### 7d — Distribution *(candidate 7)* — ⚠️ HAS AN OPEN DECISION

Verified constraints (0.8): one metallib per platform is mandatory; they cannot be merged; `ShaderLibrary.bundle(_:)` resolves exactly `default.metallib` with **no documented platform-selection hook**.

> **Open decision — needs an answer before this sub-phase can be planned.** How does a single SPM resource bundle serve the right `default.metallib` to iOS, tvOS, visionOS and macOS consumers? Phase 0 could not determine whether Apple's resource-variant/thinning machinery handles this for `.copy`'d resources. **Investigate before building.** Possible outcomes: (i) Xcode-driven builds handle it and CLI `swift build` is macOS-only by design; (ii) ship per-platform bundles and select at runtime with `ShaderLibrary(url:)` instead of `.bundle(.module)`; (iii) accept macOS-only and document it.

Also fix, independent of that: `SwiftShaders.podspec` declares `ios.deployment_target = '15.0'` (contradicts `Package.swift`'s iOS 17 and every `@available(iOS 17.0)`) and ships **no** metallib and no `resource_bundles` — the CocoaPods distribution is broken outright. Either fix it or remove CocoaPods support.

### Verify (7)

- [ ] 7a: consistency test green; one authoritative effect count; Gallery renders unchanged.
- [ ] 7b: single time convention; `grep -c timeIntervalSinceReferenceDate Sources/` → 0 or 1.
- [ ] 7c: `bash Scripts/build-shaders.sh` succeeds with **zero warnings**; the three noise implementations produce identical output for identical input.
- [ ] 7d: decision recorded as an ADR; podspec either correct or removed.

---

## Phase 8 — Final verification & documentation

### Verify everything

- [ ] `make clean && make build && make test` from a clean checkout — green.
- [ ] `swift test` — all tests pass; binding tests report **0** of 216 broken.
- [ ] **Negative controls, all must go red:** (a) rename one `[[stitchable]]` function; (b) drop one `.boundingRect`; (c) delete `Resources/default.metallib`. Revert each.
- [ ] `xcrun metal-source --extract=raw` output matches on-disk `.metal` sources.
- [ ] CI green on `main`, red on each negative control.
- [ ] Gallery builds, launches, and every catalogued effect renders.

### Anti-pattern sweep

```bash
grep -rn 'XCTAssertNotNil' Tests/                          # expect 0 on non-optionals
grep -rn 'continue-on-error' .github/workflows/            # expect 0
grep -rnE '\[\[\s*stitchable\s*\]\]' Sources/ | wc -l      # expect 256 (or fewer if 7c removed dead fns)
grep -rn 'timeIntervalSinceReferenceDate' Sources/         # expect ≤1 after 7b
grep -rn 'opacity(0.99)' Sources/                          # expect 0 — the Bridge stub
grep -rn 'applyMetalShader\|CircuitBreaker\|EventBus' Sources/ README.md   # expect 0
```

### Document

- Create `CONTEXT.md` with the domain vocabulary this plan introduces: **effect**, **binding**, **descriptor**, **clock**, **effect kind**. None of these are currently defined anywhere.
- Create `docs/adr/` and record the load-bearing decisions: metallib provenance (Phase 1), FluidSimulation deleted vs implemented (Phase 4), binding module shape (Phase 5), platform distribution (7d).
- Fix `README.md:19`, which describes `MetalToSwiftUIBridge` mapping `.metal` shaders into SwiftUI modifiers. It does not — it prints a line and returns `content.opacity(0.99)`. (Deleted in the candidate-2 cleanup; see below.)

---

## Appendix — Candidate 2 (delete unreferenced modules)

Not given its own phase because it blocks nothing and conflicts with nothing. Do it whenever convenient — it is the cheapest win in the plan. **487 lines, zero call sites:**

| Module | Lines | Note |
|---|---|---|
| `Enterprise/CircuitBreaker.swift` | 33 | `.halfOpen` unreachable — never resets once tripped |
| `Enterprise/RetryPolicy.swift` | 24 | 1 s/2 s backoff in a 60 Hz render library |
| `Enterprise/EventBus.swift` | 21 | No unsubscribe; leaks by construction |
| `Enterprise/MetricsCollector.swift` | 19 | 1 caller — `ErrorHandler`, inside `Enterprise/` |
| `Enterprise/ErrorHandler.swift` | 16 | — |
| `Bridge/MetalToSwiftUIBridge.swift` | 28 | Applies no shader; per-frame unguarded `print`; escaped `\\(shaderName)` never interpolates |
| `Core/ShaderModifier.swift` | 335 | `ShaderModifierProtocol` has zero conformances |
| `Core/ShaderCore.swift` + `SwiftShadersInfo` | 39 | Two disagreeing version constants (1.0.0 / 2.0.0) |

The shader path is synchronous and non-throwing end to end, so no resilience module can attach to it even in principle. Deleting collapses nine ways to apply an effect down to four. Update `README.md:19` at the same time.

### ✅ APPENDIX RESULTS — executed 2026-08-05 (commit `3e6f6b2`)

**Done. 505 lines deleted — the table's 487 plus the 18-line `SwiftShadersInfo` block.**

Every symbol was reference-swept individually before deletion, not taken on the table's word. All 15
public symbols came back with references that were *only* the declaration itself or a mention inside
its own doc comment. Swept across `Sources Tests Examples Documentation Templates README.md CHANGELOG.md`.

| | |
|---|---|
| `swift test` | **178 tests, 0 failures** (unchanged) |
| `Shader.compile(as:)` rejections | **0 of 208** (unchanged) |
| `make build` | clean, Gallery links and packages |
| `grep -c 'opacity(0.99)' Sources/` | **0** |
| `grep -c 'applyMetalShader\|CircuitBreaker\|EventBus' Sources/ README.md` | **0** |
| stitchable functions | **256** (untouched) |

**Two traps worth recording for anyone re-reading the table:**

1. **`Core/ShaderModifier.swift` is not homogeneous.** The table justifies it with "`ShaderModifierProtocol`
   has zero conformances," but the protocol is 12 of its 335 lines. The file also defines four other
   public types — `BaseShaderModifier`, `AnimatedShaderModifier`, `ConditionalShaderModifier`,
   `ChainedShaderModifier`. Each was swept separately and each was genuinely unreferenced, so the whole
   file went; but the stated reason only covered a twelfth of it.

2. **`AnimatedShaderModifier` appears to have a second definition** at `Templates/ModifierTemplate.swift:65`
   with a different init (`speed:`). It is not a conflict and not a call site: `Templates/` and `Examples/`
   live outside `Sources/`, so `Package.swift` never compiles them. Verified against the target paths
   before deleting — a naive grep makes this look load-bearing.

**⚠️ This removes `public` API — breaking for any external consumer.** Nothing in this repo used any of
it. Removed: `SwiftShadersCircuitBreaker`, `CircuitError`, `SwiftShadersRetryPolicy`, `SwiftShadersEventBus`,
`SwiftShadersMetricsCollector`, `SwiftShadersErrorHandler`, `MetalToSwiftUIBridge`, `applyMetalShader(_:)`,
`ShaderModifierProtocol`, `BaseShaderModifier`, `AnimatedShaderModifier`, `ConditionalShaderModifier`,
`ChainedShaderModifier`, `ShaderConfig`, `SwiftShadersInfo`, `SwiftShaders.version`.

Both version constants are now gone rather than reconciled — they disagreed (1.0.0 / 2.0.0), nothing read
either, and SPM resolves the version from the git tag. The library no longer vends a version constant at
all. If one is wanted back, that is a Phase 8 documentation decision, not a restoration of these files.

`README.md:19` now describes the real mechanism — `ShaderLibrary.bundle(.module)` over
`colorEffect`/`distortionEffect`/`layerEffect` — instead of the Bridge, which applied no shader.
The README's "34 Production-Ready Metal Shaders" claim was left alone **deliberately**: the count
drift across five inventories is 7a's subject and should be fixed once, there.

**🔴 Found while here, not fixed: `CHANGELOG.md` is boilerplate from an unrelated project.** Its 1.0.0
entries describe type-safe navigation, `NavigationStack` integration, deep linking and routers — SwiftRouter,
not SwiftShaders — and its compare/release links point at `github.com/muhittincamdali/SwiftRouter` (note
also that the README and podspec use `muhittinpalamutcu/SwiftShaders`, a *different* org, so the URLs are
wrong twice over). No breaking-change entry was written for this deletion, because writing an accurate
entry into the wrong product's changelog compounds the problem. → **Phase 8 documentation work.**

---

## Appendix — Corrections to the earlier architecture review

| Earlier claim | Verified |
|---|---|
| 116 mismatched of ~213 | **129 mismatched of 216** — 13 sites were missed, most likely those nested two closures deep inside `TimelineView` |
| 6 missing functions (named set) | ✅ confirmed exactly |
| 49 unreferenced stitchable functions | ✅ confirmed exactly |
| 256 stitchable functions | ✅ confirmed exactly |
| "Golden pixel test via `ImageRenderer`" | ✅ **proven in Phase 1** — the shader is applied; white→black through `invert` |
| "2.4 MB binary checked into git" | ❌ **wrong** — it was *untracked and un-ignored*. Now explicitly gitignored and CI-generated (Phase 1) |
| "CI goes green with no metallib" | ❌ **wrong for this package** — a missing resource removes `Bundle.module`, so the build fails hard (Phase 1) |
| "The metallib is the only untracked artifact" | ❌ **far worse** — only 8 of 97 source files are tracked, and they are exactly the dead modules (Phase 1) |
| 129 broken call sites | ❌ **understated** — **157 of 216**. A fourth defect class (28 `half3` type mismatches) is invisible to argument counting (Phase 2) |
| `metal-objdump` needed as the Phase 2 oracle | ❌ not for detection — `Shader.compile(as:)` finds all 157 on its own. The disassembly is still what generates the manifest (Phase 2) |
