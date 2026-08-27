# Diagnose and decide the fix for X-Ray

Part of [the Library refresh map](../map.md)
Type: task
Status: closed (out of scope)

## Question

User-reported (2026-08-26): the **X-Ray** entry (`xray`) is broken or its
example fails to show the effect. Diagnose from scratch — no prior triage on this entry. Determine which defect class this is —
shader-logic (D2a: the Metal code is wrong) or presentation (D2b: the catalog
entry's defaults, sample element, or `animated:` flag undersell a correct
shader) — with a reproduction, and decide the fix. Respect the integrity guards
(map Notes): say which guard moves if rendering or signatures change. The answer
feeds [Decide the gallery fix plan](08-gallery-fix-plan.md).

## Closed out of scope (2026-08-27)

The maintainer removed the gallery's colour-adjustment entries (Color category
trimmed to chromaticAberration alone) as not relevant to the gallery, so this
entry no longer exists to diagnose. The effect method remains in the library,
ledgered as `deliberatelyAbsent` under `Absence.ruledOutOfGallery`.
