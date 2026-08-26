# Diagnose and decide the fix for Infinite Grid

Part of [the Library refresh map](../map.md)
Type: task
Status: open

## Question

User-reported (2026-08-26): the **Infinite Grid** entry (`infiniteGrid`) is broken or its
example fails to show the effect. Known D2a (plans/00-shader-integrity-remediation.md): the grid is never drawn — its antialiasing math zeroes it out. Determine which defect class this is —
shader-logic (D2a: the Metal code is wrong) or presentation (D2b: the catalog
entry's defaults, sample element, or `animated:` flag undersell a correct
shader) — with a reproduction, and decide the fix. Respect the integrity guards
(map Notes): say which guard moves if rendering or signatures change. The answer
feeds [Decide the gallery fix plan](08-gallery-fix-plan.md).

**Headless evidence (2026-08-26, [headless diagnosis](02-gallery-headless-diagnosis.md)):** this is a confirmed D2a — `infiniteGrid` never draws its grid
(`RaymarchingShader.metal:464`): the antialiasing quotient always exceeds the
smoothstep's upper edge, so `gridIntensity` is 0 everywhere and only the static
horizon glow renders. Pinned in `GalleryRenderSweepTests.knownTimeIndependentEntries`.
