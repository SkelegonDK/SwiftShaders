# Survey shader-based view-transition prior art

Part of [the Library refresh map](../map.md)
Type: research
Status: resolved

## Question

What do existing libraries and repos do for shader-driven view transitions, and
which of their transitions are worth adopting? Survey at minimum: twostraws/Inferno
(SwiftUI Metal shaders, its transitions if any), movingparts/Pow (its
transitions/effects API shape), the gl-transitions collection (the canonical
catalog of ~70 GLSL transitions — which port cleanly to a SwiftUI
`colorEffect`/`layerEffect` world), and any notable SwiftUI + Metal transition
demos/repos. For each: the API the consumer writes, how transition progress drives
the shader, and license compatibility with MIT. Deliver a shortlist of candidate
transitions (name, visual, source, port difficulty) and the API patterns observed.

## Answer

Full findings: `docs/research/transition-prior-art.md` (committed on branch
`research/transition-prior-art`, commit 215a284; the doc also rides along in the
map branch's tree).

**Survey.** Inferno (MIT) is the only polished prior art: ten shader transitions
(circles/diamonds ± wave, crosswarp LTR/RTL, pixellate, radial, swirl, wind, genie)
exposed as `AnyTransition` statics over `.modifier(active:identity:)` with a plain
`progress` uniform — colorEffect for masks, layerEffect (`maxSampleOffset: .zero`)
for warps, distortionEffect for genie; always `.asymmetric`, with an epsilon-scale
no-op removal hack and mirrored LTR/RTL shader pairs to fake crossfades. Pow (MIT,
open-sourced 2023) ships zero Metal — its value is API shape: a `.movingParts`
empty-enum namespace on `AnyTransition` plus `Animatable` modifiers with
`progress ⇄ animatableData`. gl-transitions (MIT repo, per-file headers, 125
entries) defines `vec4 transition(vec2 uv)` with `getFromColor`/`getToColor` +
`progress`/`ratio`. **Core porting rule:** a gl-transition fits SwiftUI's
single-layer model iff `getToColor` is sampled only at raw `uv` — then
`getToColor(uv) → transparent` yields a valid removal shader; two-texture
transitions (crosswarp, morph, cube family, CrossZoom, luma/displacement) cannot be
faithfully ported. Also: iShader (9 transitions, no license — reference only),
gonchar's spark-burn demo (progress overshoot −0.2→1.2, unlicensed), Pavel Zak's
out-of-bounds-transparency technique, Apple's WWDC24 Transition-protocol sample,
MTTransitions (MIT, ~76 GLSL→MSL translations). **No library ships iOS 17
`Transition`-protocol shader transitions — an open niche.** Inferno/iShader/gonchar
all skip `Animatable` and still animate (SwiftUI interpolates shader uniforms
internally, undocumented); Pow's explicit `animatableData` is the contract-safe
choice — agreeing with the mechanics ticket.

**Shortlist** (MIT unless noted):
- *Trivial (colorEffect)*: directional wipe, clock wipe (`angular`), circle iris,
  heart iris, wind, window slice/blinds, random squares (near-duplicate of the
  existing `pixelDissolve`), polka-dot/diamond curtain.
- *Moderate*: squareswire, pixelize (layerEffect; existing Pixelate shader
  reusable), crosswarp pair, swirl, doorway from-side, per-side ripple
  (distortionEffect), genie.
- *Hard*: InvertedPageCurl (BSD-3, Hewlett-Packard).

**Recommendations:** add `Animatable` to progress modifiers (the library currently
has none — a real gap); ship both `AnyTransition` statics and `Transition`-protocol
types; adopt the trivial tier first; carry per-file attribution headers mirroring
Inferno's LICENSE provenance section.
