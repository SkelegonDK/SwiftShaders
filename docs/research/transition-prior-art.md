Resolves the wayfinder ticket 'Survey shader-based view-transition prior art' (.scratch/library-refresh/issues/04-transition-prior-art.md).

# Shader-based view-transition prior art

_Survey date: 2026-08-26. Scope: shader-driven **view transitions** (view insertion/removal), not mere effects._

## 0. Where SwiftShaders stands today

- The package already ships progress-parameterized "transition-style" effects — the Dissolve family (`DissolveModifier`, `DirectionalDissolveModifier`, `RadialDissolveModifier`, `BurnDissolveModifier`, `PixelDissolveModifier` in `Sources/SwiftShaders/Shaders/Dissolve/DissolveModifier.swift`) and Pixelate — each taking a `progress: Double` and forwarding it as a float uniform via `shaderEffect(_:...)`.
- All three SwiftUI shader entry points are abstracted by `ShaderBinding` (`Sources/SwiftShaders/Core/ShaderBinding.swift`): `.colorEffect`, `.distortionEffect`, `.layerEffect`.
- **Gap:** no modifier in the package conforms to `Animatable` (zero hits for `animatableData` in `Sources/`), and there is no `Transition` / `AnyTransition` integration. Consumers must drive `progress` manually with `withAnimation`; the modifiers cannot yet be used as real insertion/removal transitions.

## 1. twostraws/Inferno

Sources: [README](https://raw.githubusercontent.com/twostraws/Inferno/main/README.md), [Transitions.swift](https://raw.githubusercontent.com/twostraws/Inferno/main/Sources/Inferno/SwiftUI/Transitions.swift), [LICENSE](https://raw.githubusercontent.com/twostraws/Inferno/main/LICENSE), Transition/*.metal sources, repo tree via GitHub API.

**Yes — Inferno ships ten real shader-driven view transitions**, in `Sources/Inferno/Shaders/Transition/`: Circle, CircleWave, Crosswarp, Diamond, DiamondWave, Genie, Pixellate, Radial, Swirl, Wind.

### Consumer API

`AnyTransition` static extensions built on **`AnyTransition.modifier(active:identity:)`** wrapping plain `ViewModifier` structs holding a `progress` value — **not** the iOS 17 `Transition` protocol:

```swift
.transition(.circles(size: 20))          // also .circleWave, .diamonds, .diamondWave
.transition(.crosswarpLTR)               // and .crosswarpRTL (static properties)
.transition(.pixellate(squares: 20, steps: 20))
.transition(.radial)
.transition(.swirl(radius: 0.5))
.transition(.wind())
.transition(.genie())
```

driven by an ordinary `withAnimation { showingFirstView.toggle() }`. README examples add `.drawingGroup()` to the transitioning view.

Representative declaration:

```swift
public static func circles(size: Double = 20) -> AnyTransition {
    .asymmetric(
        insertion: .modifier(
            active: CircleTransition(size: size, progress: 0),
            identity: CircleTransition(size: size, progress: 1)
        ),
        removal: .scale(scale: 1 + Double.ulpOfOne)   // epsilon-scale = effectively no-op removal
    )
}
```

Notable idioms:

- Every transition is `.asymmetric`. Reveal-style ones use `removal: .scale(scale: 1 + Double.ulpOfOne)` so removal is a near-no-op rather than the default fade.
- `crosswarpLTR` pairs an LTR insertion shader with an RTL removal shader so the two views appear to move in unison — Inferno's answer to "no second texture": run one shader per view, choreographed to complement each other.
- A generic `InfernoTransition(name:progress:)` wrapper (dynamic-member `ShaderLibrary` lookup) covers most layer-based transitions; size-dependent shaders get `proxy.size` via `.visualEffect`.

### Progress plumbing

`progress` is a plain `var progress = 0.0` stored property — **no `Animatable`/`animatableData` anywhere in Transitions.swift**. It is passed as `.float(progress)`; SwiftUI interpolates between the `active` and `identity` modifier instances because shader uniforms are animatable render attributes inside `visualEffect`/effect modifiers on iOS 17. Entry points used:

| Transition | Entry point |
|---|---|
| Circle, Diamond | `colorEffect` |
| CircleWave, DiamondWave | `colorEffect` inside `visualEffect` (needs size) |
| Crosswarp LTR/RTL, Radial, Pixellate, Swirl, Wind | `layerEffect(..., maxSampleOffset: .zero)` |
| Genie | `distortionEffect(..., maxSampleOffset: .zero)` |

Metal-side signature example: `[[stitchable]] half4 crosswarpLTRTransition(float2 position, SwiftUI::Layer layer, float2 size, float amount)`.

### Catalog (one-liners)

- **Circle / Diamond** — grid of circles/diamonds grows to reveal content.
- **CircleWave / DiamondWave** — same, rippling outward from the top-left.
- **Crosswarp LTR/RTL** — pixels stretch toward center and fade, sweeping edge-to-edge.
- **Pixellate** — view pixellates up, cross-fades, resolves (steps param for retro look).
- **Radial** — old-school clock wipe from 12 o'clock.
- **Swirl** — twists around center, cross-fades, untwists.
- **Wind** — pixels blown away in horizontal streaks.
- **Genie** — view sucked into the top-right corner, macOS-genie style.

### License and caveats

- MIT ("Copyright (c) 2023 Paul Hudson and other authors"); the LICENSE file documents provenance — most transition shaders are Metal ports from gl-transitions.com authors (bobylito, Eke Péter, Xaychru/gre, Sergey Kosarevsky) plus one Shadertoy (Genie), with the note "All licenses are MIT". Fully MIT-compatible; attribution required.
- Availability gate `@available(iOS 17, macOS 14, macCatalyst 17, tvOS 17, visionOS 1, *)` — identical to SwiftShaders' floor.
- Intended distribution is copy-paste ("copy this Swift file into your project alongside the Metal files"), though it also builds as an SPM package.

## 2. movingparts/Pow (EmergeTools/Pow)

Sources: [README](https://raw.githubusercontent.com/EmergeTools/Pow/main/README.md), [LICENSE](https://raw.githubusercontent.com/EmergeTools/Pow/main/LICENSE), `Sources/Pow/Infrastructure/Namespace.swift`, `Sources/Pow/Transitions/{Iris,Anvil,Vanish}.swift`, [Package.swift](https://raw.githubusercontent.com/EmergeTools/Pow/main/Package.swift), GitHub API recursive file tree, [movingparts.io/pow](https://movingparts.io/pow).

### API shape — the namespace pattern

All transitions live under a `.movingParts` namespace on `AnyTransition`, implemented as an empty enum used as a namespace (`Namespace.swift`, verbatim):

```swift
public extension AnyTransition {
    enum MovingParts { }

    /// The namespace of Moving Parts transitions.
    static var movingParts: MovingParts.Type { MovingParts.self }
}
```

Individual transitions are `static var`/`static func` members on `AnyTransition.MovingParts`:

```swift
myView.transition(.movingParts.anvil)
.transition(.movingParts.blinds(slatWidth: 25))
.transition(.movingParts.iris(origin: .center, blurRadius: 8))
```

`.movingParts` returns the metatype, so `.movingParts.anvil` resolves as a static member — a pure namespacing trick; there is no iOS 17 `Transition` protocol usage (the package targets iOS 15 / macOS 12).

### Mechanism and progress plumbing

Every transition is `AnyTransition.modifier(active:identity:)` over a modifier conforming to `ViewModifier` + `Animatable` (plus Pow's own `ProgressableAnimation: Animatable { var progress: CGFloat }`):

```swift
struct Iris: ViewModifier, DebugProgressableAnimation, AnimatableModifier {
    var animatableData: CGFloat = 0
    var progress: CGFloat {
        get { animatableData }
        set { animatableData = newValue }
    }
    // body: content.mask(GeometryReader { Circle().frame(width: progress * diagonal) ... })
}
```

SwiftUI interpolates `animatableData` 0↔1 each frame; `body` maps the scalar into mask diameter, blur radius, particle positions, or transforms. Removal-only transitions use `.asymmetric(insertion: .identity, removal: .modifier(...))`; several ship a `defaultAnimation` (e.g. Vanish: `.easeOut(duration: 0.9)`).

### Shader usage: none

**Pow contains zero Metal shaders** — the complete file tree has no `.metal`/`.metallib`; resources are pre-rendered PNGs (anvil smoke, poof frames). Anvil and Vanish draw particles with `Canvas`, Iris is `.mask` + `.blur`, Flip/Swoosh use projection transforms. Pow is prior art for the **API and progress plumbing**, not for shader dispatch.

### History and license

- Built by Moving Parts (Robb Böhnke), originally a commercial closed-source binary. Open-sourced free in **November 2023** in partnership with Emerge Tools; repo moved to `EmergeTools/Pow` (v1.0.0 = the open-source release; maintainer Joe Fabisevich). movingparts.io/pow now reads "Pow is free and Open Source."
- LICENSE: standard **MIT**, "Copyright (c) 2023 Emerge Tools, Inc." — fully compatible.

### Transition catalog (17 source files)

Anvil (cartoon slam-down with dust), Blinds (venetian reveal), Blur (blurry↔sharp), Boing (elastic drop with overshoot squash), Clock (clockwise sweep), Film Exposure (fade from dark), Flicker (visibility toggles), Flip (3D rotation), Glare (diagonal wipe + light streak), Iris (growing circular mask), Move (slide from edge), Poof (cartoon dust-cloud removal), Pop (ripple + particle flurry), Skid (elastic shear slide), Swoosh (3D swoop), Vanish (dissolve into tinted particles), Wipe (straight-edge sweep, optional blur). Change Effects (`.changeEffect`) are a separate non-transition API: Spray, Shake, Shine, Spin, Jump, Ping, Rise, haptics, sounds, etc.

## 3. gl-transitions

Sources: [README/spec](https://github.com/gl-transitions/gl-transitions/blob/master/README.md), [LICENSE](https://github.com/gl-transitions/gl-transitions/blob/master/LICENSE), [contents API](https://api.github.com/repos/gl-transitions/gl-transitions/contents/transitions), plus the raw GLSL of 18 transitions read line-by-line (directionalwipe, circleopen, heart, pixelize, wind, squareswire, windowslice, randomsquares, angular, dissolve, crosswarp, morph, doorway, cube, ripple, InvertedPageCurl, ColourDistance, CrossZoom, and fade from the README).

### The spec (GL Transition Specification v1)

- A transition is GLSL implementing `vec4 transition(vec2 uv)`, returning the mixed color.
- Contextual functions `vec4 getFromColor(vec2 uv)` / `vec4 getToColor(vec2 uv)` (direct `texture2D` is forbidden so the host controls ratio-preservation and out-of-bounds); contextual uniforms `float progress` (0→1) and `float ratio` (viewport width/height).
- Hard endpoint rule: "When progress is 0.0, exclusively the from texture must be rendered. When progress is 1.0, exclusively the to texture must be rendered."
- Custom parameters are extra uniforms with defaults in comments (`uniform float foo; // = 42.0`), parsed by the official tooling ([gl-transition-libs](https://github.com/gre/gl-transition-libs)).
- Canonical example: fade = `mix(getFromColor(uv), getToColor(uv), progress)`.

### License

Repo LICENSE is **MIT** ("Copyright (c) 2017-present gl-transitions contributors"), with the rule that individual files may carry their own license in the `// Author:` / `// License:` header; when none is specified, MIT applies. Of 18 files examined, all are MIT **except `InvertedPageCurl.glsl` (Author: Hewlett-Packard, License: BSD 3-Clause)** — still MIT-compatible (permissive; requires preserving its notice), but must be tracked per-file.

### Catalog size

**125 transitions** today (the commonly cited "~70" is stale). Full listing in the contents API; representative names: fade, directionalwipe, wipeLeft/Right/Up/Down, angular, circle/circleopen, heart, wind, windowslice, windowblinds, randomsquares, squareswire, pixelize, ripple, doorway, crosswarp, morph, cube, swap, BookFlip, GridFlip, Fold, Rolls, CrossZoom, ColourDistance, InvertedPageCurl, DreamyZoom, GlitchMemories, luma, displacement, DoomScreenTransition, FilmBurn, WaterDrop, hexagonalize, kaleidoscope, StarWipe, Mosaic, …

### The single-layer question

SwiftUI's `layerEffect` can only sample the transitioning view's own layer — there is **no destination texture**. The portability test, applied to the actual GLSL: is `getToColor` only ever sampled at the raw `uv`? If yes, replacing `getToColor(uv)` with transparent (`vec4(0)`) turns the shader into a valid single-layer removal (the incoming view simply shows through underneath); mirrored for insertion.

**(a) Ports cleanly (mask-only; `getToColor` at raw uv — verified in source):** fade, directionalwipe, wipeLeft/Right/Up/Down, angular (clock sweep), circleopen/circle, heart, wind, windowslice, randomsquares, squareswire.

**(a′) Portable per-side (both textures sampled, but at the same displaced coordinate — each layer can self-distort + fade):** pixelize (both sampled at quantized coords), ripple (radial sine offset), doorway (from-side only: perspective door-split with a transparent middle slit; the to-side's background zoom/reflection needs the real second texture and gets dropped).

**(b) Requires both textures (getToColor sampled at displaced coordinates, or color-dependent mixing) — not reproducible as a SwiftUI transition:**

| Transition | Why |
|---|---|
| crosswarp | `getToColor((p-.5)*x+.5)` — to-texture scaled about center (Inferno fakes it by pairing complementary LTR/RTL shaders on the two views) |
| morph | warp offset computed from **both textures' colors** |
| cube / swap / BookFlip / GridFlip / Fold / Rolls | 3D faces of both images visible simultaneously |
| CrossZoom | both sampled in a zoom-blur loop |
| ColourDistance | mix factor depends on both pixels' colors |
| luma / displacement | need a third `sampler2D` uniform |
| perlin, flyeye, Dreamy, GlitchMemories | displaced-`getToColor` family (inferred from family, not individually verified) |

**Edge case — InvertedPageCurl** is single-layer portable (verified: its final `getToColor` calls are at raw `p`; the displacement only computes the curl shadow): curl the from-layer and emit transparency where the to-image would show, with the shadow as semi-transparent black. Hardest port in the set, and BSD-3 (HP) rather than MIT.

### Existing Metal ports for reference

- **[MTTransitions](https://github.com/alexiscn/MTTransitions)** (alexiscn) — MIT, Swift, ports ~76 gl-transitions to Metal (image/UIView/VC/video use). Best line-by-line GLSL→MSL translation reference; but it renders true two-texture transitions offscreen — the single-layer adaptation remains SwiftShaders' own work.
- **Inferno** (section 1) is itself largely a set of single-layer gl-transitions ports and demonstrates the adaptation pattern end to end.

## 4. Other SwiftUI + Metal transition demos, and Apple's two API patterns

### Apple's standard patterns

Sources: [TransitionPhase](https://developer.apple.com/documentation/swiftui/transitionphase), [Transition](https://developer.apple.com/documentation/swiftui/transition), [createwithswift.com guide](https://www.createwithswift.com/creating-view-transitions-in-swiftui/).

**(a) `AnyTransition.modifier(active:identity:)`** (iOS 13+): SwiftUI animates between the `active` and `identity` instances of a ViewModifier; when the modifier conforms to `Animatable` (progress stored in `animatableData`), SwiftUI interpolates the scalar every frame. This is what both Inferno and Pow build on.

**(b) The iOS 17 `Transition` protocol**:

```swift
struct MyShaderTransition: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content.myShaderModifier(progress: phase.isIdentity ? 0 : 1)
    }
}
// consumer: MyView().transition(MyShaderTransition())
```

`TransitionPhase` has three cases — `willAppear`, `identity`, `didDisappear` — with `phase.isIdentity` and `phase.value` (−1 / 0 / +1). Apple's docs: "In the `willAppear` and `didDisappear` phases, transitions should apply a change that will be animated… If no animatable change is applied, then the transition will be a no-op" — i.e. the protocol still relies on an animatable change (an `Animatable` modifier, or animatable built-ins) to interpolate; it adds type-safety, `TransitionProperties`, and asymmetry via `AsymmetricTransition`. Neither surveyed library uses it yet (Pow predates it; Inferno chose `AnyTransition`).

### Ecosystem sweep results

GitHub/web sweep (firecrawl developer index + GitHub API + web search, 2026-08-26). Genuine shader-transition finds beyond Inferno:

- **[Treata11/iShader](https://github.com/Treata11/iShader)** (34★, last push 2024-06) — the closest peer to Inferno's transitions: 9 shader transitions in `Sources/Transition/Transitions.swift` (circles, swirl, genie, wind, radial, crosswarp, dreamy, windowBlinds, **morph**), mostly gl-transitions ports. Same pattern as Inferno — `AnyTransition` statics over `.modifier(active:identity:)`, an `isFinished` flag turned into a `.float(isFinished ? 1 : 0)` uniform, `colorEffect` or `layerEffect`-inside-`visualEffect`, and the same `.scale(1 + .ulpOfOne)` removal hack. **No LICENSE file (GitHub API: license = none)** — not safely adoptable; reference only.
- **[gonchar/swiftui-shader-spark-transition](https://github.com/gonchar/swiftui-shader-spark-transition)** (Sergey Gonchar, 2023) — a single "spark/burn" transition: content burns away along a noise edge with particle sparks (texture-assisted `layerEffect`). Interesting detail: its `effectValue` runs **−0.2 → 1.2**, deliberately overshooting 0–1 for edge margin. **No license declared** — technique reference only.
- **[Pavel Zak, "SwiftUI transitions with distortion effect and Metal Shaders"](https://nerdyak.tech/development/2023/06/16/distortionEffect-with-Metal-shaders-for-better-transitions.html)** (2023) — the clearest `distortionEffect` transition write-up: skew/slide-away transitions where the shader returns **out-of-bounds positions to make pixels effectively transparent** (needs a generous `maxSampleOffset`). `.modifier(active:identity:)` with `effectValue` +1 for insertion, −1 for removal. Blog code, no stated license.
- **Apple's WWDC24 sample, ["Creating visual effects with SwiftUI"](https://developer.apple.com/documentation/swiftui/creating-visual-effects-with-swiftui)** (session 10151) — the canonical first-party reference for both halves: `TwirlTransition.swift` demonstrates the `Transition` protocol (not shader-backed), and Ripple (`layerEffect` driven by a keyframe animator's elapsed time) demonstrates shader-parameter animation. Apple sample-code license (permissive, not MIT).
- **[Victor Baro, "Custom SwiftUI transitions with Metal"](https://medium.com/@victorbaro/custom-swiftui-transitions-with-metal-680d4e31a49b)** (Medium, member-gated; fetches 403) — search snippets indicate `TransitionPhase`-driven shaders with distortion + clip shapes. Unverified; corroborating only.

Everything else in the dense SwiftUI+Metal ecosystem ships **effects, not transitions**: [ShaderKit](https://github.com/jamesrochabrun/shaderkit), [krispuckett/SwiftUIShaders](https://github.com/krispuckett/swiftuishaders) (MIT, 41 layerEffects incl. transition-shaped material — disintegrate, smoke-reveal, shatter — but `TimelineView`-driven, not wired to insertion/removal; best MIT raw material), [Aurora](https://github.com/tornikegomareli/aurora), [Sticker](https://github.com/bpisano/sticker), [eleev/swiftui-new-metal-shaders](https://github.com/eleev/swiftui-new-metal-shaders), [0Itsuki0/SwiftUI_MetalShaderDemo](https://github.com/0Itsuki0/SwiftUI_MetalShaderDemo), [TearKit](https://github.com/nsstudent/tearkit) (gesture-driven tear with progress callbacks — interactive-progress precedent). Also useful: [MTTransitions](https://github.com/alexiscn/MTTransitions) (MIT, ~76 gl-transitions in MSL — see §3) and [pommdau/swiftui-metal-shader-tutorial](https://github.com/pommdau/swiftui-metal-shader-tutorial) (GLSL→MSL recipes).

**Takeaway: shader-driven view transitions are an underserved niche** — one polished competitor (Inferno, copy-paste distribution, ten transitions), one unlicensed follower (iShader), one API-shape exemplar (Pow, shader-free), and a 125-item shader catalog (gl-transitions) largely unported to SwiftUI. Notably, **no library ships `Transition`-protocol shader transitions**.

### Field note on interpolation (verified across three codebases)

None of Inferno, iShader, or gonchar's demo declares `Animatable`/`animatableData` on its transition modifiers, yet a plain stored `Double` (even `isFinished ? 1 : 0`) animates smoothly — `Shader`'s public conformances don't include `Animatable`, so the float-uniform interpolation happens inside SwiftUI's effect-modifier machinery, not the classic `animatableData` path. Declaring `animatableData` (as Pow does) remains the documented-contract-safe option and is what this survey recommends, but the ecosystem demonstrably ships without it.

## 5. API patterns observed

1. **Namespace pattern (Pow)** — an empty enum + metatype static (`AnyTransition.movingParts` → `MovingParts.Type`) groups all transitions under one discoverable prefix: `.transition(.movingParts.anvil)`. Zero runtime cost, pure ergonomics.
2. **`AnyTransition.modifier(active:identity:)` + progress modifier (Inferno and Pow)** — the universal mechanism. Pow does it correctly with `Animatable`/`animatableData` (progress ⇄ animatableData computed property); Inferno omits `Animatable` and leans on iOS 17 shader-uniform animation inside `visualEffect`. **Adopt the Pow plumbing** — explicit `Animatable` conformance is the documented, version-robust contract, and it also unlocks `AnyTransition.modifier` for non-shader use.
3. **Asymmetric-by-default (Inferno)** — every shader transition is `.asymmetric`; reveal-style transitions neutralize removal with the `scale(1 + .ulpOfOne)` epsilon hack; bidirectional ones pair complementary shaders (crosswarp LTR insertion + RTL removal) to fake a two-texture crossfade.
4. **Progress delivery to the shader** — always a plain `.float(progress)` uniform, 0→1; geometry via `.boundingRect`/`float2 size` (Inferno passes `proxy.size` through `.visualEffect`; SwiftShaders' `ShaderBinding` geometry plumbing already covers this).
5. **Entry-point choice follows the effect**: pure masks → `colorEffect`; anything that moves pixels → `layerEffect` (Inferno uses `maxSampleOffset: .zero` everywhere); pure geometric warps → `distortionEffect`.
6. **iOS 17 `Transition` protocol** — unused by prior art but the modern surface; trivially layered over pattern 2 (`content.modifier(X(progress: phase.isIdentity ? 1 : 0))`), and `phase.value`'s sign distinguishes insertion from removal, letting one transition struct choose directional variants.
7. **Single-layer adaptation rule (this survey's core technical finding)** — a gl-transition ports to SwiftUI iff `getToColor` is only sampled at raw `uv`; then `getToColor(uv) → vec4(0)` (transparent) yields a valid removal shader and the incoming view shows through underneath. Transitions sampling the destination at displaced coordinates (crosswarp, morph, cube family, CrossZoom, ColourDistance, luma) cannot be faithfully reproduced — only approximated per-side.

## 6. Candidate-transition shortlist

Quick wins first. "Existing overlap" = SwiftShaders already has the shader math, only the transition wrapper is missing.

| # | Name | Visual | Source (author) | License | Entry point | Port difficulty | Existing overlap |
|---|------|--------|-----------------|---------|-------------|-----------------|------------------|
| 1 | Directional wipe | soft-edged straight wipe, any angle | gl-transitions `directionalwipe` + `wipeL/R/U/D` (gre) | MIT | colorEffect | **Trivial** | `directionalDissolve` is close kin |
| 2 | Clock wipe | radial sweep from an angle | gl-transitions `angular` (Fernando Kuteken); Inferno `Radial` | MIT | colorEffect | **Trivial** | — |
| 3 | Circle iris | circle grows/shrinks from a point, soft edge | gl-transitions `circleopen`/`circle` (gre); cf. Pow Iris | MIT | colorEffect | **Trivial** | `radialDissolve` is close kin |
| 4 | Heart iris | heart-shaped wipe | gl-transitions `heart` (gre) | MIT | colorEffect | **Trivial** | — |
| 5 | Wind | streaky per-scanline random wipe | gl-transitions `wind` (gre); Inferno `Wind` | MIT | colorEffect | **Trivial** | — |
| 6 | Window slice / blinds | slat-by-slat reveal | gl-transitions `windowslice` (gre); cf. Pow Blinds | MIT | colorEffect | **Trivial** | — |
| 7 | Random squares | grid cells dissolve in random order | gl-transitions `randomsquares` (gre) | MIT | colorEffect | **Trivial** | `pixelDissolve` near-duplicate — wrapper only |
| 8 | Polka-dot / diamond curtain | dot/diamond grid grows to reveal, optional wave | Inferno Circle/Diamond(+Wave) (from bobylito's `PolkaDotsCurtain`) | MIT | colorEffect | **Trivial** | — |
| 9 | Squares wire | directional front of shrinking cell-windows | gl-transitions `squareswire` (gre) | MIT | colorEffect | Moderate | — |
| 10 | Pixelize | mosaic into blocks while fading | gl-transitions `pixelize` (gre); Inferno `Pixellate` | MIT | layerEffect | Moderate | Pixelate shader exists — reuse |
| 11 | Crosswarp (paired) | stretch-toward-center + fade sweep; LTR/RTL pair fakes crossfade | Inferno `Crosswarp` (from Eke Péter) | MIT | layerEffect | Moderate | — |
| 12 | Swirl | twist around center + fade | Inferno `Swirl` (Sergey Kosarevsky/gre) | MIT | layerEffect | Moderate | Swirl-family distortions exist |
| 13 | Doorway (from-side) | perspective double-door split | gl-transitions `doorway` (gre) | MIT | layerEffect | Moderate | — |
| 14 | Ripple (per-side) | radial water-wave distortion + fade | gl-transitions `ripple` (gre) | MIT | distortionEffect | Moderate | Wave/ripple distortions exist |
| 15 | Genie | sucked into a corner, macOS-style | Inferno `Genie` (altaha-ansari Shadertoy port) | MIT | distortionEffect | Moderate–Hard | — |
| 16 | Page curl | page peels off with rolling curl + shadow | gl-transitions `InvertedPageCurl` (Hewlett-Packard) | **BSD-3** | layerEffect | **Hard** | — |

Not portable as true SwiftUI transitions (two-texture): morph, cube/swap/BookFlip/GridFlip/Fold/Rolls, CrossZoom, ColourDistance, luma, displacement, GlitchMemories/Dreamy family.

## 7. Recommendations for SwiftShaders

1. **Close the `Animatable` gap first.** Give the progress-driven modifiers (Dissolve family, Pixelate, future transition modifiers) `Animatable` conformance with `progress ⇄ animatableData` (Pow's `ProgressableAnimation` protocol is a clean template). The ecosystem demonstrably ships without it (see the §4 field note — shader uniforms interpolate via SwiftUI's effect-modifier machinery), but `Animatable` is the documented contract, is version-robust, and is required the moment a modifier animates anything that is *not* a shader uniform.
2. **Ship both API surfaces**: `AnyTransition` statics for parity with prior art, plus iOS 17 `Transition`-protocol types (the modern, un-erased surface no competitor offers). A Pow-style namespace (`.transition(.swiftShaders.circleIris())` or plain statics like Inferno) keeps 20+ transitions discoverable.
3. **Adopt tiers 1–8 of the shortlist immediately** (all trivial colorEffect masks, all MIT, several already half-built as dissolve shaders), then the layerEffect/distortion tier. Skip page curl initially or track its BSD-3 notice deliberately.
4. **Follow Inferno's asymmetric idioms**: epsilon-scale no-op removals for reveal transitions; complementary shader pairs (crosswarp-style) where a pseudo-crossfade is wanted.
5. **License hygiene**: everything recommended is MIT except `InvertedPageCurl` (BSD-3). Ported shaders should carry `// Ported from gl-transitions/<name>.glsl — Author: X — License: MIT` headers, mirroring Inferno's LICENSE provenance section.
