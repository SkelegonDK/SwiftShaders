# Map: Library refresh — docs, gallery debugging, shader view-transitions

Label: wayfinder:map
Tracker: local markdown (`.scratch/library-refresh/`). GitHub Issues are disabled on
the fork (SkelegonDK/SwiftShaders), so the GitHub tracker was unavailable; enabling
Issues and migrating this map there is the user's call, not a route step.

## Destination

Three threads, each reaching "nothing left to decide before someone executes":
1. A **documentation-update spec** — which documents change, to what scope and depth.
2. A **gallery-app fix plan** — the defects named, diagnosed, and a decided approach.
3. A **spec for a shader-based view-transitions section** — API shape, initial
   transition set, and how it appears in the gallery — grounded in prior-art research.

## Notes

- Domain: Swift package of Metal shaders as SwiftUI view modifiers. Read
  [CONTEXT.md](../../CONTEXT.md) first — *effect*, *binding*, *manifest*, *coverage
  ledger*, *clock*, *gallery/catalog*, *drift check* are load-bearing terms.
- Planning-only default applies. The one deliberate exception is the ticket
  [Build and exercise the gallery app headlessly](issues/02-gallery-headless-diagnosis.md)
  — a diagnosis *task* that does rather than decides, because no fix decision can be
  made before the defects are characterized.
- Skills per session: `/grilling` + `/domain-modeling` for grilling tickets,
  `/research` for research tickets, `/prototype` if an API-shape discussion needs a
  concrete stub to react to.
- Standing guardrails from the repo: every public count (226 effects, 91 gallery
  entries, 256 metal functions) is test-asserted (`ReadmeClaimsTests`, coverage
  ledger, manifest drift checks) — any spec that changes these numbers must say which
  guard moves with it. Do not recreate a second catalog (see CONTEXT.md, ADR 0006).

## Decisions so far

<!-- one line per closed ticket: gist + link -->

- [Survey shader-based view-transition prior art](issues/04-transition-prior-art.md) —
  Inferno (MIT) is the only polished prior art and nobody ships iOS 17
  `Transition`-protocol shader transitions — an open niche; a gl-transition ports to
  SwiftUI's single-layer model iff it samples `getToColor` only at raw `uv`; a
  tiered shortlist (trivial wipes/irises → moderate warps → page curl) with licenses
  is on branch `research/transition-prior-art`.
- [Establish the SwiftUI mechanics for shader-driven transitions](issues/05-swiftui-transition-mechanics.md) —
  use the iOS 17 `Transition` protocol with an `Animatable` modifier animating one
  signed progress scalar (−1→0 insert, 0→+1 remove); progress-driven never
  clock-driven, no-op at 0, constant `maxSampleOffset`, routed through the existing
  `ShaderBinding` path; full findings on branch `research/swiftui-transition-mechanics`.

## Not yet specified

- **Gallery fix plan detail** — can't be phrased until
  [Name the gallery app's defects](issues/01-gallery-defect-symptoms.md) and the
  headless diagnosis say what is actually broken; may graduate into several fix-decision
  tickets or none.
- **Docs-update spec detail** — which sections of README/API.md/GettingStarted change
  and how far, pending the scope grilling. Known raw material: `GettingStarted.md` is a
  one-line stub; `API.md` documents only a fraction of the 226 effect methods; the
  README carries upstream "2026 Unified Core" fork-marketing that may not fit this fork.
- **Transitions vs. the integrity guards** — how new transition shaders (if any new
  Metal functions are needed) integrate with the manifest, coverage ledger, unbound-
  functions inventory and drift checks; sharp only after the section's shape is decided.
  The 49 unbound Metal functions may already supply transition material.
- **Previewing transitions in the gallery** — a transition needs insertion/removal to
  demo, which the current slider-driven `EffectCatalog` entry shape may not express;
  depends on the section's decided shape.

## Out of scope

- **The 121-entry gallery backlog** — pre-existing open work to grow gallery coverage
  of the 226 effects; a separate effort, not part of this refresh.
- **Cutting the 2.0.0 release** — the CHANGELOG's unreleased 2.0.0 stays unreleased by
  this map; releasing is its own effort.
