# 0006 — A coverage ledger with a ratchet, not full gallery coverage or codegen

**Status:** Accepted · **Date:** 2026-08-05 · **Phase:** 7a, per the ADV‑1 amendments in `plans/01-orchestration-remaining-work.md`

## Context

The base plan's Phase 7a brief was "one effect descriptor": author each effect's
facts once in the library, and have `View` extension defaults, the (now-deleted)
`ShaderCatalog` row, and the Gallery's `EffectCatalog` row all derive from it.
Measured drift motivating this: competing effect counts of 30 / 92 / ~213 across the
three catalogs, `gaussianBlur` catalogued with no backing Metal function, 8 category
conflicts, and roughly 120 public effects in neither catalog.

Before implementation, an adversarial review (ADV‑1, recorded in
`plans/01-orchestration-remaining-work.md`) attacked the descriptor-direction
assumption directly and found it did not fit: `ShaderBinding.Descriptor` already
existed as the internal binding module's descriptor type (see
`docs/adr/0004-binding-module-shape.md`), and generating the Gallery's ~91 entries
from a library-side descriptor would mean inventing roughly 350 slider ranges (min,
max, default, decimal places) for 121 effects with no Gallery entry today — data the
library has no reason to know and the Gallery author is better placed to choose.

## Decision

**No descriptor.** Instead: a checked-in **coverage ledger**
(`Tests/SwiftShadersTests/Support/EffectCoverageLedger.swift`) mapping every one of
the library's 226 public `View` effect methods to `.inGallery(id)`,
`.presetOf(baseMethod)`, or `.deliberatelyAbsent(reason)`, enforced by a ratchet test
that only allows the absent count to fall — never rise. The Gallery's
`EffectCatalog` stays hand-curated. Fidelity is enforced by tests scanning the
source (`PublicViewMethodScanner`), not by generation.

Alongside this, the Gallery catalogue itself became **importable**: `Effect`,
`EffectCatalog` and `SampleElements` moved into a new library target,
`SwiftShadersGalleryCore`, so tests `import` the catalogue and check it structurally
instead of text-parsing the Gallery executable's source. The separate, 30-row
`ShaderCatalog` registry inside the library target was deleted outright — 19 of its
30 ids matched no public `View` method, and one (`gaussianBlur`) matched no Metal
function either; its five genuine `View` methods moved next to their modifiers.

## Consequences

- "Does the Gallery represent the library?" became a question tests can answer:
  zero phantom Gallery entries, and a visible, shrinking-only backlog of 121 methods
  with no entry yet, rather than an untracked, growing gap.
- Full gallery coverage (all 226 methods previewable) is explicitly **not** this
  phase's exit criterion — it is deferred, tracked work, because authoring it means
  hand-tuning ~350 slider ranges, which is real design effort, not a mechanical
  follow-on.
- `GalleryRenderSweepTests` renders all 91 current entries and asserts each differs
  from an unshaded control — a second, independent fidelity check the ledger alone
  doesn't provide (a method can be `.inGallery` and still render inertly).
- The 49 unreferenced stitchable Metal functions (see `CONTEXT.md`, "unbound
  function") are a separate inventory from the coverage ledger — the ledger only
  covers methods that exist in Swift; the unbound-functions list covers Metal
  functions with no Swift binding at all.
- A first version of the ledger's own completeness scanner was itself found to be
  under-scanning (it missed 21 inline-declared params, "agreeing with itself" over
  89% of the file) — recorded as a general lesson in the Phase 6 results box of
  `plans/00-shader-integrity-remediation.md`: a completeness guard that derives its
  yardstick the same way as the thing it guards is not a guard.

## Alternatives considered

| Option | Verdict | Why |
|---|---|---|
| Library-authored descriptor; catalogs derive from it (the original Phase 7a brief) | Rejected | `ShaderBinding.Descriptor` already owns the word inside the binding module; deriving ~91 Gallery entries from it means inventing ~350 slider ranges as library code, which is Gallery-author judgment, not library fact. |
| Exit criterion = full gallery coverage (every method previewable) | Rejected for this phase | Real design work (slider ranges for 121 effects), not a consistency fix; made a tracked, ratcheted backlog instead of a blocking requirement. |
| **Hand-curated catalogue + coverage ledger + ratchet test** | **Chosen** | Matches what a Gallery actually needs (curated slider ranges) while making drift between library and Gallery a test failure instead of a silent, growing gap. |
