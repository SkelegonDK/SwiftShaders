# 0002 — Retype stitchable `half3` parameters to `float3`

**Status:** Accepted · **Date:** 2026-08-04 · **Phase:** 3 of `plans/00-shader-integrity-remediation.md`

## Context

Phase 2's binding oracle found 28 call sites, across 34 `[[stitchable]]` Metal
functions, passing `.float3(...)` to a Metal parameter declared `half3` — every one a
colour-ish uniform (`lowColor`, `highColor`, `tintColor`, …). These were not a
mismatched-count bug like the 121 `.boundingRect` sites; they were structurally
unbindable. `Shader.Argument` (`SwiftUICore.swiftinterface:6898–6936`) has no factory
that produces a `half3` — the only half-typed value it can supply is `.color(_:)`,
which lowers to `half4`. Whatever a call site passed, SwiftUI's stitcher rejected it:
`unsupported MTLDataType: 18` (`MTLDataTypeHalf3`).

## Decision

**Retype the 55 affected parameters from `half3` to `float3` in the Metal
declarations.** Call sites already passed `.float3(...)`, so no Swift-side change was
needed. Inside each shader body, the parameter is wrapped in `half3(...)` at its
point of use, restoring the previous arithmetic exactly (the value was rounded to
half before use anyway) — only the parameter list changed, not internal `half3`
locals, since half arithmetic is cheaper there and nothing outside the function
observes it.

## Consequences

- 55 parameters across 34 stitchable functions retyped. That produced 43 compile
  errors where a now-`float3` parameter met `half3`-typed local arithmetic; each was
  fixed with an explicit `half3(...)` wrap at the use site. One expression in
  `EmbossShader.metal:209` was reassociated (`metalColor * half(highlight)` →
  `half3(metalColor * highlight)`) to keep the same result shape.
- `shader-signatures.tsv`'s row count and kind histogram are unchanged (256 rows,
  157/60/39) — this only changed a parameter *type* within existing rows, not the
  set of functions or their kinds.
- Costs a little register bandwidth (`float3` vs `half3`) for values that are
  colour-precision uniforms, not per-pixel intermediates — judged negligible against
  making the functions callable at all.

## Alternatives considered

| Option | Verdict | Why |
|---|---|---|
| **`half3` → `float3` in the 34 Metal declarations** | **Chosen** | One-token edit per declaration; the 28 call sites already pass `.float3(...)`, so zero Swift changes; no shader body semantics change once the point-of-use wrap is added. |
| `half3` → `half4`, pass `.color(...)` from Swift | Rejected | Idiomatic for colour uniforms, and `.color` is the factory Apple provides for exactly this — but it changes every shader body's parameter shape *and* all 28 call sites, and drags an alpha channel into functions that never wanted one. |
