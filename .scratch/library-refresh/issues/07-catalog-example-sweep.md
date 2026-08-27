# Sweep the catalog for undemonstrative examples

Part of [the Library refresh map](../map.md)
Type: task
Status: resolved
Assignee: Manuel Thomsen (session wayfinder-docs-shader-transitions-5dc4e7, 2026-08-27)

## Question

[Name the gallery app's defects](01-gallery-defect-symptoms.md) established defect
class **D2b**: catalog entries whose shader is correct but whose gallery example
fails to show the effect. Enumerate them. AFK where possible: render each of the
91 `EffectCatalog` entries at its default parameter values against its default
sample element (reuse the `GalleryRenderSweepTests` harness for offscreen
rendering) and flag entries where the before/after difference is invisible or
unrepresentative — checking specifically for: default parameter values that render
near-invisibly, a sample element ill-suited to the effect, a time-driven effect not
marked `animated:` (frozen at t=0), and effects that only read against the
checkerboard backdrop. Exclude the known shader-logic bugs (class D2a — those are
code defects, inventoried by
[the headless diagnosis](02-gallery-headless-diagnosis.md)). User-named priority
cases may be appended here as they arrive. The answer is the flagged-entry list
with the suspected presentation mechanism per entry — choosing new defaults or
samples is the fix plan's decision, not this sweep's.

**Scope narrowed 2026-08-26:** the user named 24 entries, each now carrying its
own diagnosis ticket (09–32). This sweep covers only the *remaining* 67 catalog
entries (91 total, not 100 — the earlier count was a grep artifact; corrected by
[the headless diagnosis](02-gallery-headless-diagnosis.md)) — its job is catching
what the user didn't happen to notice.

**Headless priority flags (from
[the headless diagnosis](02-gallery-headless-diagnosis.md), 2026-08-26):**
`colorGrading` and `levels` are invisible at the gallery's default parameters
(identity defaults, pinned in `GalleryRenderSweepTests.knownInvisibleAtDefaults`) —
the exact "default parameter values that render near-invisibly" mechanism this
sweep looks for. Everything else in the remaining 67 passes the mechanical
visibility checks, so what's left here is visual judgment, not render failure.

## Answer

Resolved 2026-08-27. Method: all 67 remaining entries rendered on the gallery's
default stage (card sample, checkerboard backdrop, defaults; animated entries at
t=1.7) into labelled contact sheets and reviewed visually, plus a
sum-of-absolute-differences (SAD) measurement of every entry against the unshaded
card — the card-sample analogue of the quadrant-source check in
`GalleryRenderSweepTests`. Tool committed as
`Tests/SwiftShadersTests/CatalogExampleSweepDumpTests.swift` (skips unless
`CATALOG_SWEEP_DUMP_DIR` is set); regenerate the sheets with
`CATALOG_SWEEP_DUMP_DIR=<dir> swift test --filter CatalogExampleSweep`.
Noise floor on the card is ≈8,100 (colorGrading/levels, the pinned identities);
the weakest healthy entry scores ≈360,000.

### New shader-logic bugs (D2a) — found by the sweep, diagnosed to the line

- **sepia** — the sepia matrix is **transposed**: standard coefficient *rows*
  are written as `float3x3` *columns* (`SepiaShader.metal:21–25`), and
  `dot(color.rgb, sepiaMatrix[i])` then mixes with the wrong weights
  (`:46–48`). White → (1.0, 1.99→1, 0.49) = acid yellow; the orange avatar
  renders green. Wrong everywhere, not subtle.
- **invert** — inverts **premultiplied** rgb without unpremultiplying
  (`InvertShader.metal:31`): transparent pixels (rgb 0, a 0) become
  rgb 1 / a 0, an over-unity premultiplied colour that composites as additive
  white. At the default amount 1 the entire sample layer — card and padding —
  renders as one white slab; the card content is unreadable. Sibling
  `invertSmart` shares the pattern.
- **rgbSplit** — never splits: the shader is a colorEffect that scales R and B
  by at most **1.02×** (`ChromaticShader.metal:132–152`, `redShift * 0.2` with
  splitX ≤ 0.5) — a no-op-grade approximation. Card SAD 9,209 ≈ the 8,100 noise
  floor. Same structural class as the already-triaged chromaticAberration: a
  true channel offset needs a layerEffect that samples neighbours.

### Presentation defects (D2b) — shader plausible, example fails to show it

Invisible or at/near the noise floor on the default card:

- **colorGrading, levels** — known identity defaults (pinned in
  `knownInvisibleAtDefaults`); confirmed, for the fix plan: give them live
  defaults or accept opening as a no-op.
- **vibrance** (SAD 22k) — default 0.3 on an almost-desaturated card changes
  nothing visible; needs a colourful sample (photo) or stronger default.
- **softGlow** (35k) — bloom is invisible on a white card; needs bright-on-dark
  content.
- **filmGrain** (41k) — intensity 0.15 on the white card is barely
  perceptible in a still; borderline.
- **torchFlame** (51k) — the flame at defaults is a faint smudge on the card;
  reads as "does nothing".
- **unsharpMask** (52k) / **sharpen** (77k) — the card has no fine texture to
  sharpen; both indistinguishable from control by eye. Sample ill-suited —
  needs the photo sample.

Defaults or sample bury the content (mechanically "visible", visually broken):

- **dotMatrix** — dotSize 1 / spacing 0.02 renders the white card as a
  near-solid **black** rectangle (only the avatar survives as dots).
- **mosaicHexagon** — grout swallows the card: black field with white **circular**
  dots (the cells don't even read as hexagons — possible D2a in the cell shape);
  contrast mosaicSquare, which reads correctly.
- **stainedGlass** — paints opaque cells over the entire layer including the
  transparent padding; at cellSize 30 the card is unrecognizable.
- **lightning** — white bolts on a white card: signal invisible at defaults.
- **electricField** — white field lines on white card, plus painted padding.
- **caustics** — white-on-white wash; bleaches the whole cell.
- **hologramEffect** — scanline bands paint the full layer including padding;
  reads as a glitch slab around the card.
- **frostedGlass** — the scatter pattern renders as a dominant regular white
  dot lattice over card *and* padding; reads as polka dots, not frost.
- Minor notes: **fireflies** (white blobs on white read as smudges),
  **kaleidoscope** (white card yields a near-blank hexagon — ill-suited sample;
  fine on structured content).

### Systemic mechanism: shaders paint the transparent padding

Many shaders ignore `color.a` and return an opaque pattern where the source is
transparent, so the effect fills the sample layer's whole bounding box as a
hard-edged rectangle around the card: invert, hologramEffect, electricField,
caustics, underwater, rainDrops, frostedGlass, stainedGlass, voronoiCrystal,
voronoiStainedGlass, sparkle/embers/starField/fireflies, and the halo family
(polaroid, crossProcess, vintagePhoto). For particle "field" effects this may be
intended; for surface effects it reads as a defect. One fix-plan decision covers
the family: mask output by source alpha (or document field behaviour per effect).

### Corroboration for user-ticketed entries

The card SAD places user-named entries in the same weak band the user reported:
chromaticAberration 36k, posterize 98k, rain 168k, tiltShift 185k — consistent
with tickets 12, 11, 29, 24.

### Healthy

Everything else in the 67 demonstrates its effect clearly at defaults — all
distortions, thresholds, splitToning, scanlines/LCD, glitch, vintage trio,
neon pair, vignette, fire, waterSurface, underwater, rainDrops, the voronoi
family, plasma, turbulence, metaballs, blackHole, sparkle/embers/starField,
and all five transitions. (Generative entries replace the sample content
entirely — metaballs, blackHole, voronoiCells — which is their design, noted
only in case the fix plan wants content-aware variants.)
