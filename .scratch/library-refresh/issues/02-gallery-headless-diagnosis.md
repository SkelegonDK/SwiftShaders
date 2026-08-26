# Build and exercise the gallery app headlessly

Part of [the Library refresh map](../map.md)
Type: task
Status: resolved
Assignee: Manuel Thomsen (session wayfinder-docs-shader-transitions-5dc4e7)

## Question

Characterize every defect findable without a human at the screen, so the fix
decision has evidence. AFK: run `make shaders` then `swift build --package-path
Gallery`, run the test suite (`make test`), including `GalleryRenderSweepTests` and
`CatalogConsistencyTests`, and capture compiler/runtime warnings. Record: what
fails, what renders wrong, exact reproduction, and suspected owning component
(binding, catalog entry, clock, app shell). Fold in the already-triaged latent bugs
from `plans/7c-unused-variable-triage.md` (e.g. `directionalChromatic` ignores its
angle, `voronoiShattered`/`voronoiStainedGlass` ignore time, `infiniteGrid` never
draws its grid) so the inventory is complete. The answer is a defect inventory —
fixing anything is a later, separate decision. Cross-check against the resolved
defect list in [Name the gallery app's defects](01-gallery-defect-symptoms.md)
(classes D1/D2a/D2b), so headless findings and user-visible symptoms land in one
inventory; presentation-only judgments (class D2b) belong to
[Sweep the catalog for undemonstrative examples](07-catalog-example-sweep.md),
not here.

## Answer

Resolved 2026-08-26 (session wayfinder-docs-shader-transitions-5dc4e7), on the
clean worktree at commit 59bb46d.

**Headline: the headless surface is green.** A clean `make shaders`, clean rebuilds
of both packages, and the full `make test` run (91 tests, 0 failures — including
`GalleryRenderSweepTests` and `CatalogConsistencyTests`) surfaced **no defect that
was not already documented and pinned**. Every headlessly-findable defect is one of
the known latent bugs below; the test suite itself carries them as pinned
known-sets, so the harness cannot find them "again". The complete inventory:

### Build & warning evidence

- `make shaders`: 33 Metal files → 256 stitchable functions (157 colorEffect,
  60 distortionEffect, 39 layerEffect), 49 unbound. Exactly **12 unused-variable
  warnings**, byte-for-byte the set documented in
  `plans/7c-unused-variable-triage.md` — no new warnings, none silently fixed.
- Root package, clean `swift build`: **0 warnings**.
- Gallery package, clean `swift build --package-path Gallery`: **0 warnings**,
  exit 0.
- `make test`: 91/91 passed. Binding diagnostics all zero (0 rejected compiles,
  0 argument-type/count mismatches, 0 wrong geometry/effect-kind, 0 unresolved
  names).

### D2a — shader-logic defects (code wrong; no example can help). 12 items, all pre-triaged, all confirmed still present

The 9 latent bugs of `plans/7c-unused-variable-triage.md` (each is an accepted
parameter or computed effect that is then ignored; owning component: **the Metal
source**, signatures unchanged unless noted):

1. `directionalChromatic` ignores `angle` — not directional at all
   (`ChromaticShader.metal:57`).
2. `deboss` never applies its inverted light angle (`EmbossShader.metal:169`).
3. `chromaticAberration` computes and discards its sample offset — colour-shift
   approximation; true fix needs a `layerEffect` (`ChromaticShader.metal:34`).
4. `lensChromatic` leaves the green channel undistorted
   (`ChromaticShader.metal:117`).
5. `scatterDissolve` never scatters, only fades — displacement needs a
   `layerEffect` (`DissolveShader.metal:209`, `:197`).
6. `electricNeon` ignores view geometry; edge detection is resolution-dependent
   (`ElectricShader.metal:233`).
7. `polaroid` ignores `size` — no vignette/edge behaviour (`SepiaShader.metal:147`).
8. `neonOutline` glow width not scaled by resolution (`NeonShader.metal:72`).
9. `sketchCharcoal` smudge offset in raw position units (`SketchShader.metal:167`).

Plus the 3 from `plans/00-shader-integrity-remediation.md`, pinned in
`GalleryRenderSweepTests.knownTimeIndependentEntries`:

10. `voronoiShattered` accepts `time`, passes `0.0` (`VoronoiShader.metal:263`).
11. `voronoiStainedGlass` — same (`VoronoiShader.metal:541`).
12. `infiniteGrid` **never draws its grid** — antialiasing quotient always exceeds
    the smoothstep's upper edge, so only the static horizon glow renders
    (`RaymarchingShader.metal:464`).

Dead computation, not user-visible (cleanup, not defect): `frostedGlass`'s unused
`pattern` (`FrostShader.metal:66`), `SharpenShader.metal:29`'s unreferenced
`strongKernel`.

### D2b — mechanical presentation facts (feed [the catalog sweep](07-catalog-example-sweep.md))

- **`colorGrading` and `levels` are invisible at the gallery's default
  parameters** (identity grade / identity transfer curve) — pinned in
  `GalleryRenderSweepTests.knownInvisibleAtDefaults`. A user opening either entry
  sees a no-op until they move a slider.
- **`rain` is the weakest-measuring entry in the whole catalog** (difference 828
  against a change threshold of 128; the sweep's floor is 512) — it passes, but
  it is the entry closest to invisible. Corroborates the user naming Rain in
  their 24.
- The three time-ignoring entries above are driven by the gallery's
  `TimelineView`, which redraws a still image every frame — wasted work and a
  false "animated" promise in the UI.

### D1 cross-check (app shell)

The sidebar-truncation mechanism from
[Name the gallery app's defects](01-gallery-defect-symptoms.md) is confirmed
unchanged: single-line `Label` rows in a `.navigationSplitViewColumnWidth(min:
210, ideal: 240)` column (`Gallery/Sources/SwiftShadersGallery/ContentView.swift:50-73`).

### Significance for the 24 per-shader tickets (09–32)

The sweep mechanically proves every one of the 91 entries (a) renders something
different from the unshaded control, (b) is not one flat colour, and (c) if marked
`animated:`, actually varies with time (the three pinned exceptions aside). So for
the user's 24 named entries, **"broken" cannot mean black/no-op/frozen** — except
where the entry overlaps the D2a list (Chromatic Aberration, Infinite Grid) or the
weak-signal fact (Rain). The other 21 diagnoses should start from *what* renders
(visual quality, defaults, sample element), not *whether* anything renders.

### Corrections to the map's record

- `EffectCatalog` has **91 entries, not 100** — the "100 entries" in tickets 01
  and 07 was a loose grep counting `Effect(` constructor mentions. 91 is the
  README-pinned, `ReadmeClaimsTests`-asserted number. Ticket 07's body corrected.

### Reproduction

```
make shaders                          # 12 known warnings, 256 functions
swift build --package-path Gallery    # clean
make test                             # 91/91 green; sweep prints weakest entry
```
