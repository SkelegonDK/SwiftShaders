# Phase 7c — the 12 unused-variable warnings that were deliberately left in place

**Created:** 2026-08-05, alongside the `SwiftShadersCommon.h` change.

## Why this file exists

Phase 7c set out to clear "the 12 unused-function/variable warnings" from Phase 0.7.
The real count was **22**, and they are two different kinds of problem:

| Kind | Count | Disposition |
|---|---|---|
| Unused **function** (`-Wunused-function`) | 10 | **Deleted.** Dead non-stitchable helpers. Safe: nothing referenced them, and no `[[stitchable]]` function was touched. |
| Unused **variable** (`-Wunused-variable`, `-Wunused-const-variable`) | 12 | **Left in place.** Listed below. |

The 12 were left because **silencing them would hide a real defect and fixing
them is out of 7c's scope.** In most cases the variable is the only use of a
shader parameter, so:

- deleting the variable makes a `[[stitchable]]` parameter dead, and the honest
  follow-up — removing the parameter — would change
  `Sources/SwiftShaders/Resources/shader-signatures.tsv`, which 7c is required
  to keep byte-identical; or
- actually *using* the variable changes what the shader renders, which is a
  product decision, not a cleanup.

So the warnings stay, as visible markers, until someone takes the rendering
decision. **"Zero warnings" for 7c means zero unused-*function* warnings and
zero warnings introduced by the header change.** Both hold.

## The 12

Line numbers are as of the `SwiftShadersCommon.h` commit.

### Latent bugs — a shader parameter is accepted and then ignored

| File:line | Function | What is ignored | What the fix would be |
|---|---|---|---|
| `ChromaticShader.metal:57` | `directionalChromatic` | `float2 direction = float2(cos(angle), sin(angle));` — the **`angle` parameter is never used at all**. The effect's channel separation is computed purely from `intensity`, so `directionalChromatic` is not directional. The public `directionalChromatic(intensity:angle:)` modifier lets callers set an angle that does nothing. | Apply `direction` to the per-channel offsets. Changes rendering; signature unchanged, so this one is *not* blocked by the manifest. |
| `EmbossShader.metal:169` | `deboss` | `float lightAngle = 3.14159 + 0.785;` — deboss's stated "inverted light angle" is never applied. The function instead relies on the top-left/bottom-right sampling order, so deboss and emboss differ only in sample order, not in lighting. | Either drive the sample offsets from `lightAngle`, or delete it and document that the inversion is encoded in the sampling order. |
| `ChromaticShader.metal:34` | `chromaticAberration` | `float2 offset = normalize(direction + 0.0001) * intensity * dist * bounds.zw;` — a full per-pixel sample offset is computed and discarded. The comment two lines below admits the effect is a colour-shift approximation because a true version needs `layerEffect`. | Reimplement as a `layerEffect` that samples at `position ± offset`. That is a new stitchable function and a new binding — a separate change. |
| `ChromaticShader.metal:117` | `lensChromatic` | `distortG`, the green channel's lens distortion factor. `distortR` and `distortB` are used; green is silently left undistorted. | Include green in the chroma shift, or delete it and document that the effect is R/B-only. |
| `DissolveShader.metal:209` | `scatterDissolve` | `float2 velocity = ...` — particles are supposed to scatter, and the scatter velocity is computed from `randomAngle` and `time` and then thrown away. `scatterDissolve` currently only fades. | Sample at `position + velocity`, which requires this to be a `layerEffect`; as a `colorEffect` it cannot displace. Blocked on an effect-kind change. |
| `ElectricShader.metal:233` | `electricNeon` | `float2 uv = position / bounds.zw;` — the `bounds` parameter is consumed only here, so `electricNeon` ignores the view geometry entirely and its edge detection is resolution-dependent. | Use `uv`, or drop `bounds` from the signature (**manifest change — out of scope**). |
| `SepiaShader.metal:147` | `polaroid` | `float2 uv = position / size;` — same shape: `size` is accepted and unused, so the vignette/edge behaviour a Polaroid look implies was never implemented. | Add the position-dependent term, or drop `size` (**manifest change**). |
| `NeonShader.metal:72` | `neonOutline` | `float2 pixelSize = 1.0 / size;` — the glow ring is sampled at `glowWidth` in *points*, not scaled by `pixelSize`, so glow width does not track resolution. | Multiply the sample offsets by `pixelSize * size` as the sibling shaders in `SketchShader.metal` do. Rendering change, signature unchanged. |
| `SketchShader.metal:167` | `sketchCharcoal` | `float2 pixelSize = 1.0 / size;` — same as above; the smudge offset is in raw position units. | Same fix. |

### Dead computation, no parameter implicated

| File:line | Function | What is ignored | What the fix would be |
|---|---|---|---|
| `FrostShader.metal:66` | `frostedGlass` | `float pattern = frost * 0.7 + noise * 0.3;` — a combined frost/noise pattern is built and never sampled. `frost` alone drives the highlight. | Either blend `pattern` into the highlight (rendering change) or delete both it and the `noise` line that feeds it. |
| `DissolveShader.metal:197` | `scatterDissolve` | `float2 localUV = fract(uv / particleSize);` — per-particle local coordinates, needed to draw a particle *shape*; nothing draws one. | Falls out of the `velocity` fix above; both belong to the same unimplemented scatter. |
| `SharpenShader.metal:29` | file scope | `constant float strongKernel[9]` — a second, stronger 3×3 convolution kernel that no shader references. `sharpenKernel` next to it is used. | Delete it, or expose a "strong" variant. This is the only one of the 12 that is safe to delete outright; it is kept here so the whole set is triaged in one place rather than split across two policies. |

## Suggested sequencing

1. `ChromaticShader.metal:57` (`directionalChromatic` ignoring `angle`) is the
   highest-value fix: it is a documented, publicly bound parameter that does
   nothing, and it needs no signature change.
2. `NeonShader.metal:72` and `SketchShader.metal:167` are one-line
   resolution-independence fixes with no signature change.
3. `ElectricShader.metal:233` and `SepiaShader.metal:147` need a decision about
   whether `bounds`/`size` should be used or removed. Removing them changes
   `shader-signatures.tsv` and the Swift call sites together, so they belong
   with whatever phase revisits the binding surface.
4. `chromaticAberration` and `scatterDissolve` both want to become
   `layerEffect`s. That is a new-shader change, not a repair.
