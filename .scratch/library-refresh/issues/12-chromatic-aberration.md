# Diagnose and decide the fix for Chromatic Aberration

Part of [the Library refresh map](../map.md)
Type: task
Status: open

## Question

User-reported (2026-08-26): the **Chromatic Aberration** entry (`chromaticAberration`) is broken or its
example fails to show the effect. Known D2a (plans/7c-unused-variable-triage.md): the per-pixel sample offset is computed and discarded, so the effect is a colour-shift approximation; a true version needs a layerEffect (new stitchable function + binding). Determine which defect class this is —
shader-logic (D2a: the Metal code is wrong) or presentation (D2b: the catalog
entry's defaults, sample element, or `animated:` flag undersell a correct
shader) — with a reproduction, and decide the fix. Respect the integrity guards
(map Notes): say which guard moves if rendering or signatures change. The answer
feeds [Decide the gallery fix plan](08-gallery-fix-plan.md).
