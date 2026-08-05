# 0003 — Delete `FluidSimulation` rather than implement it

**Status:** Accepted · **Date:** 2026-08-05 · **Phase:** 4 of `plans/00-shader-integrity-remediation.md`

## Context

After Phase 3 fixed the 149 arity/type defects, 8 remained, all in one file:
`Sources/SwiftShaders/Shaders/FluidSimulation/FluidSimulationModifier.swift` (761
lines, 8 effects). Six called Metal functions that never existed — there is no
`FluidSimulation.metal` anywhere in the tree — and the other two (`waterSurface`,
`vortex`) reached into the unrelated `Water` and `Swirl` modules through the wrong
effect method (`waterSurface` invoked as a `colorEffect` when its real function is a
`distortionEffect`; `vortex` invoked as a `colorEffect` when its real function is a
`layerEffect`). All eight rendered black. One of them, `smoke`, was listed in the
Gallery catalogue and shipped to users despite never having worked.

## Decision

**Delete the module.** Remove
`Sources/SwiftShaders/Shaders/FluidSimulation/` entirely, remove `smoke` from the
Gallery catalogue, and let the two hijacked names (`waterSurface`, `vortex`) resolve
cleanly to their real owners in `Water`/`Swirl`.

## Consequences

- 761 lines removed: 8 modifiers, 8 public `View` methods.
- Gallery catalogue: 92 → 91 entries.
- Call sites the binding oracle tracks: 216 → 208; all 8 remaining defects from
  Phase 2 (6 MISSING + 2 KIND) resolved by removal, bringing the binding suite to 0
  failures.
- Two of the seven duplicate `View` extension names (`vortex`, `waterSurface`)
  were resolved as a side effect, since deleting the module removed the colliding
  declaration. The other five duplicate names were a separate, deliberate deferral
  — see Phase 4's results box in `plans/00-shader-integrity-remediation.md` and
  ADV‑1 amendment 8 in `plans/01-orchestration-remaining-work.md` (only
  `voronoiNoise` turned out to be genuinely ambiguous; it was fixed in Phase 7a via
  a deprecation, recorded in `CHANGELOG.md`).
- Nothing else in the tree referenced any of the module's eight types — the deletion
  was a clean removal, not a refactor.
- Breaking change for any external consumer of the removed `View` methods, though
  none of them ever rendered anything but black.

## Alternatives considered

| Option | Verdict | Why |
|---|---|---|
| **Delete the module** | **Chosen** | The module never worked — 6 of 8 functions bound to nothing, the other 2 hijacked working shaders through the wrong effect method. Writing 6 new fluid-simulation shaders is new feature work, not remediation, and would have blocked the rest of the plan on unrelated shader authoring. |
| Implement the 6 missing shaders | Rejected | Requires writing `Sources/SwiftShaders/Metal/FluidSimulation.metal` from scratch (6 functions) plus fixing the 2 KIND call sites to the correct effect method — genuinely new content, out of scope for a remediation plan whose job is fixing what exists, not adding what was only ever a stub. |
| Stub the missing shaders with pass-through bodies to make tests green | Rejected (explicit guard in the plan) | Would hide the defect behind a fake pass rather than resolve it. |
