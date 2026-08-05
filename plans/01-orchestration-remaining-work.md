# Orchestration — remaining work to a working library + faithful gallery

**Created:** 2026-08-05 · **Orchestrator:** Fable 5 · **Base plan:** `00-shader-integrity-remediation.md`

## Where we are (verified 2026-08-05)

- `main` (local, 1 unpushed commit) contains **all work through Phase 6 + the appendix cleanup**: 208/208 call sites bind, 69 tests green, one binding module, tautological suite deleted.
- **Remaining from the base plan:** Phase 7a (one effect descriptor + catalog unification + 5 duplicate `View` names), 7b (one clock), 7c (Metal common header, zero warnings), 7d (platform distribution decision + broken podspec), Phase 8 (final verification, CONTEXT.md, ADRs, CHANGELOG rewrite).
- **Pending PRs/branches:**
  - Fork PR #1 (`claude/learn-codebase-37f658`) — 12 of its 13 commits are already on `main`; the only unmerged content is `Tests/SwiftShadersTests/ShaderAlphaTests.swift` (+ a duplicate Serena config). → cherry-pick the tests, then the PR is fully landed.
  - `claude/missing-shader-effects-9ca209`, `claude/nifty-rhodes-012a4a` — both at the pre-remediation upstream head, **0 commits ahead**. nifty-rhodes has one uncommitted treasure: a **CHANGELOG.md rewrite** documenting the breaking removals (Phase 8 work, half-done). Salvage the patch, then delete both worktrees + branches.
  - Upstream dependabot PRs (actions/checkout v6, actions/cache v5) are on the upstream repo we don't control → adopt the same bumps in our fork's workflow.
- Issues are disabled on the fork; there are no fork issues to triage.

## Goal

A working library (all bindings verified, CI honest) and a Gallery that **faithfully represents the library** — one authoritative effect inventory that the gallery is derived from, no phantom or missing entries.

## Stages

### Stage 0 — Housekeeping (sequential, orchestrator inline)

1. Baseline: `swift test` green on `main`.
2. Salvage the nifty-rhodes CHANGELOG patch to the scratchpad (input to Stage 4 docs).
3. Land PR #1's `ShaderAlphaTests.swift` on `main`; run tests; commit.
4. Remove the three worktrees and the two dead branches.
5. Adopt the dependabot action bumps in `.github/workflows/ci.yml`.

### Stage 1 — Parallel wave 1 (background agents, isolated worktrees)

| Agent | Model | Task | Why parallel-safe |
|---|---|---|---|
| **ADV‑1** | Opus | Adversarial review of this plan's assumptions (see list below). Read-only. | No writes |
| **C** | Opus | **7c** — `SwiftShadersCommon.h`, dedupe `hash`/`luminance`/noise/rotation, zero shader-build warnings. **Must not** add/remove/retype any `[[stitchable]]` function (manifest must stay 256 rows, byte-identical signatures). | Touches only `Metal/*.metal` + header — disjoint from all Swift work |
| **D** | Sonnet | **7d** — investigate platform-specific metallib distribution (the open decision), write ADR draft; fix or remove the broken podspec. | Research + `SwiftShaders.podspec` + `docs/adr/` — disjoint |

### Stage 2 — 7a, the critical path (after ADV‑1 findings are incorporated)

| Agent | Model | Task |
|---|---|---|
| **A** | Opus | **7a** — one effect descriptor as the single source of truth; `View` extensions, `ShaderCatalog`, and Gallery `EffectCatalog` read from it; resolve the 5 duplicate `View` names; reconcile the 30/91/~208 count drift; fix the README count claims. This is the "gallery faithfully represents the library" deliverable. |

7a runs **after** ADV‑1 because it is the largest, most design-sensitive task — an adversarial pass on its direction is cheap insurance. It runs **before** 7b because both touch the same modifier files (merge-conflict risk, not logical dependency).

### Stage 3 — 7b + adversarial merge gate (sequential after A lands)

| Agent | Model | Task |
|---|---|---|
| **B** | Opus | **7b** — one `ShaderClock` (elapsed/pause/speed, `TimelineView`-backed, injectable); kill the two ~7.8×10⁸ s-apart time conventions; delete or absorb the zero-call-site `ShaderAnimator`. |
| **ADV‑2** | Opus | Adversarial review of the merged 7a+7b+7c+7d diff: hunt rendering changes, API breaks, tests that can no longer fail. |

### Stage 4 — Phase 8 finish line (orchestrator + Sonnet, sequential)

1. Merge all tracks; `make clean && make build && make test` from clean.
2. Negative controls (rename a stitchable fn / drop a `.boundingRect` / delete the metallib → each must go red; revert).
3. Docs (Sonnet): CONTEXT.md vocabulary, ADRs (metallib provenance, FluidSimulation deletion, binding-module shape, 7d decision, half3→float3), CHANGELOG rewrite from the salvaged patch (it's currently SwiftRouter boilerplate).
4. Gallery visual verification: `make app`, launch, spot-check effects across all three kinds.
5. Push `main` to the fork; PR #1 is then fully landed → close with a note; report.

## Dependency graph

```
Stage 0 ──► ADV-1 ──► A (7a) ──► B (7b) ──► ADV-2 ──► Stage 4
       ├──► C (7c) ─────────────────────────┘
       └──► D (7d) ─────────────────────────┘
```

C and D run concurrently with ADV‑1/A/B and merge at the ADV‑2 gate.

## Assumptions for ADV‑1 to attack

1. Descriptor direction: descriptor is authored in the library; Gallery catalog is *derived*. (Alternative: gallery stays hand-curated and a test enforces consistency.)
2. "Faithful" = every public `View` effect appears in the Gallery exactly once — not the 49 unreferenced Metal functions (they are not public API).
3. The 5 duplicate `View` names get resolved by renaming (breaking change) rather than tolerated as overloads.
4. 7c's noise unification may change rendered output for `FrostShader`/`SketchShader` — acceptable, or must each keep its own noise?
5. Sequencing A before B is worth the latency vs running them concurrently with a merge step.
6. The 49 unreferenced stitchable functions: leave in place (this plan) vs delete vs expose.
