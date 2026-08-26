# Diagnose and decide the fix for Earthquake

Part of [the Library refresh map](../map.md)
Type: task
Status: open

## Question

User-reported (2026-08-26): the **Earthquake** entry (`earthquakeDisplacement`) is broken or its
example fails to show the effect. Check the animated flag and default amplitude — a shake effect frozen or too subtle reads as broken. Determine which defect class this is —
shader-logic (D2a: the Metal code is wrong) or presentation (D2b: the catalog
entry's defaults, sample element, or `animated:` flag undersell a correct
shader) — with a reproduction, and decide the fix. Respect the integrity guards
(map Notes): say which guard moves if rendering or signatures change. The answer
feeds [Decide the gallery fix plan](08-gallery-fix-plan.md).
