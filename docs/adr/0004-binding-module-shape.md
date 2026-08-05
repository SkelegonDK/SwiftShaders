# 0004 — One internal binding module, per-kind types, declared geometry

**Status:** Accepted · **Date:** 2026-08-05 · **Phase:** 5 of `plans/00-shader-integrity-remediation.md`

## Context

With the binding oracle green (Phase 2–4), all 208 call sites still each restated
the same three facts by hand: the Metal function's name, its effect kind (which
picks `.colorEffect`/`.distortionEffect`/`.layerEffect`), and its leading geometry
convention (`.boundingRect` vs. the live view size vs. neither). That restatement
was the entire cause of the 121 missing-`.boundingRect` defects — nothing forced a
call site to remember the convention its function used.

`/design-an-interface` ran three deliberately divergent briefs before any code was
written.

## Decision

**Design C — per-kind concrete types, declared (not phantom) geometry, and a
source-scanned registry — with two amendments, and one further constraint against
all three explored designs: the module is `internal`.**

The shape (`Sources/SwiftShaders/Core/ShaderBinding.swift`, ~250 lines): three
concrete types, `ShaderBinding.Color` / `.Distortion` / `.Layer` — the effect kind is
nominal, so the applier method is picked by overload resolution and cannot be
mismatched. `LeadingGeometry` is `.boundingRect | .viewSize | .plain`. `SampleRegion`
is `.fixed | .viewSize | .perSite`, where `.perSite` requires every application to
pass `maxSampleOffset:` explicitly, asserted in debug builds. One
`View.shaderEffect(_:_:)` applier exists per kind. Declarations live in a
`ShaderFamily` enum per modifier file (33 families) and are listed in
`ShaderBindingRegistry`, which the binding tests scan and cross-check against
`shader-signatures.tsv`.

The module is `internal`: its only consumers are the in-target call sites. The
public `View` extensions and modifiers that call it are untouched, which keeps
Phase 7a free to design the Gallery-facing catalogue independently (see
`docs/adr/0006-coverage-ledger.md`) without the binding module constraining it.

## Consequences

- All 208 call sites route through the module; raw `ShaderLibrary.swiftShaders.*`
  calls in `Sources/` dropped from 209 to 2 (the module's own lookup, plus one doc
  comment) and are now a zero-tolerance lint.
- The test suite gained a geometry-matching check (the manifest's first explicit
  parameter type, `float4`↔bounds / `float2`↔size, cross-verified against Phase
  0.6's independently derived 144/85/27 split) alongside the existing name/kind/
  arity/type checks — a fifth defect class the binding module made checkable that
  raw call sites could not have been.
- The migration itself surfaced 6 real defects the earlier oracle could not see: 4
  migration-script bugs (an unstripped trailing comment swallowed the next
  argument) and 2 latent pre-existing bugs (`emboss`, `polaroid` passing a literal
  `.float2(1, 1)` instead of the real view size — recorded in `CHANGELOG.md`'s
  Fixed section). All six were caught by the new tests before being merged, not
  after.
- Because the module is internal, it adds no new public API surface, and nothing
  about it needs to appear in the changelog as a breaking or additive change.

## Alternatives considered

| Design | Verdict | Why |
|---|---|---|
| A — one string-keyed value type, manifest consulted at runtime | Rejected | Per-site checking degrades to debug-time preconditions instead of compile-time structure; tests could only compile synthesized arguments rather than the production path; every modifier stack would gain a `.visualEffect` wrapper; and `shader-signatures.tsv` — meant as a test-time artifact — becomes load-bearing in the shipped product. |
| B — 256 generated factories with typed argument labels, codegen from the manifest | Rejected *for now*, kept as input to Phase 7a | Strongest compile-time story, but it would commit Metal parameter names and 256 generated symbols as public API before Phase 7a had decided the Gallery-facing descriptor's shape, and needs a second extraction pipeline (parameter *names*, which the manifest does not currently carry). |
| **C — per-kind types, declared geometry, source-scanned registry, `internal`** | **Chosen**, with amendments | Geometry became a declared *value* rather than a phantom type — a phantom type bought no call-site safety (callers never spell geometry either way) and cost a 9-overload diagnostics tax. `maxSampleOffset` kept a per-site override because ~10 sites compute it from effect parameters (radius, pixel size, …), which a per-binding constant cannot express. Making the module `internal` rather than public was decided against all three designs, to keep Phase 7a's catalogue design unconstrained. |
