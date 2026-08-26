# Diagnose and decide the fix for Rain

Part of [the Library refresh map](../map.md)
Type: task
Status: open

## Question

User-reported (2026-08-26): the **Rain** entry (`rain`) is broken or its
example fails to show the effect. User-reported symptom is specific: particles fall UPWARDS. Suspect a y-axis sign flip (SwiftUI's top-left origin vs. shader math). Determine which defect class this is —
shader-logic (D2a: the Metal code is wrong) or presentation (D2b: the catalog
entry's defaults, sample element, or `animated:` flag undersell a correct
shader) — with a reproduction, and decide the fix. Respect the integrity guards
(map Notes): say which guard moves if rendering or signatures change. The answer
feeds [Decide the gallery fix plan](08-gallery-fix-plan.md).
