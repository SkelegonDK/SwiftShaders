# Map: Library refresh — docs, gallery debugging, shader view-transitions

Label: wayfinder:map
Tracker: local markdown (`.scratch/library-refresh/`). GitHub Issues are disabled on
the fork (SkelegonDK/SwiftShaders), so the GitHub tracker was unavailable; enabling
Issues and migrating this map there is the user's call, not a route step.

## Destination

Three threads, each reaching "nothing left to decide before someone executes":
1. A **documentation-update spec** — which documents change, to what scope and depth.
2. A **gallery-app fix plan** — the defects named, diagnosed, and a decided
   approach — plus, added by the user 2026-08-26, specs for three gallery
   enhancements: a custom-photo sample, full-layer effect coverage on control
   samples, and a 3D object sample tab.
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
- [Name the gallery app's defects](issues/01-gallery-defect-symptoms.md) —
  three defect classes from the user's seat: **D1** sidebar truncates effect names
  (mechanism confirmed in `ContentView.swift`), **D2a** shader-logic bugs (the
  already-triaged latent bugs — code wrong, no example can help), **D2b**
  presentation defects (shader correct, gallery entry fails to demonstrate it);
  D2b enumeration delegated to the new catalog-example sweep.
- [Expand the transition candidate set](issues/36-transition-set-expansion.md) —
  all 125 gl-transitions classified from source: ~60% adoptable (35 trivial masks,
  20 moderate self-displacing, 28 honest approximations), everything recommended
  MIT, plus 23 original candidates from existing families and unbound functions
  (unbound `scatterDissolve` already takes `progress` — cheapest win); four
  prior-survey verdicts corrected; full tiered doc on branch
  `research/transition-set-expansion`.
- [Build and exercise the gallery app headlessly](issues/02-gallery-headless-diagnosis.md) —
  the headless surface is green (91/91 tests, 0 compiler warnings in both packages)
  and surfaced nothing new: the complete headless defect inventory is the 12 known
  D2a shader-logic bugs (7c triage + the two time-ignoring voronois + `infiniteGrid`),
  plus two mechanical D2b flags (`colorGrading`/`levels` invisible at defaults,
  `rain` weakest signal in the catalog); the sweep proves the user's 24 named
  entries all render, differ from control, and animate — so those diagnoses are
  about *what* renders, not whether. Catalog is 91 entries, not 100.
- [Scope the documentation update](issues/03-docs-update-scope.md) —
  the fork documents itself as its own library for an audience of the user's own
  projects and agents: README fully rewritten under its existing guards (fork URL,
  upstream marketing/benchmarks dropped, getting-started folded in),
  GettingStarted.md deleted, API.md replaced by a generated staleness-guarded
  signature index, CODE_OF_CONDUCT contact fixed, everything else deliberately
  untouched. This completes destination thread 1 — the docs-update spec.

- [Sweep the catalog for undemonstrative examples](issues/07-catalog-example-sweep.md) —
  the 67 non-user-named entries rendered on the default card stage and judged:
  three **new D2a shader bugs** diagnosed to the line (sepia's transposed matrix,
  invert's premultiplied-alpha white-out, rgbSplit's ±2% no-op approximation),
  ~15 D2b flags (identity/weak defaults: vibrance, softGlow, torchFlame,
  sharpen/unsharpMask, filmGrain; content-burying defaults: dotMatrix,
  mosaicHexagon, stainedGlass; white-on-white: lightning, electricField,
  caustics), plus one systemic mechanism — many shaders paint the sample's
  transparent padding as an opaque slab — covering a dozen entries with a single
  fix-plan decision. Everything else demonstrates cleanly.

- [Diagnose and decide the fix for Earthquake](issues/09-earthquake.md) —
  **D2b**: the shader's one-shot `exp(-time·decay)` envelope is correct, but the
  never-resetting gallery clock kills the shake ~10 s after opening (headless SAD
  frozen at 12,186 from 20 s on); fix by looping the clock in the entry's catalog
  closure (`t % 4`), shader and guards untouched.

## Not yet specified

- **Transitions vs. the integrity guards** — how new transition shaders (if any new
  Metal functions are needed) integrate with the manifest, coverage ledger, unbound-
  functions inventory and drift checks; sharp only after the section's shape is decided.
  The 49 unbound Metal functions may already supply transition material.
- **Previewing transitions in the gallery** — a transition needs insertion/removal to
  demo, which the current slider-driven `EffectCatalog` entry shape may not express;
  depends on the section's decided shape.

## Out of scope

- **Colour-adjustment gallery entries** — ruled not relevant to the gallery by the
  user (2026-08-27) and removed the same day: the Color category trimmed to
  chromaticAberration alone (catalog 91 → 79; ledger, ratchet ceiling 121 → 133,
  README/Gallery.md/CONTEXT.md counts and `knownInvisibleAtDefaults` all moved with
  it, suite green). The effect *methods* stay in the library, ledgered under
  `Absence.ruledOutOfGallery`. Closes
  [Solarize](issues/10-solarize.md), [Posterize](issues/11-posterize.md) and
  [X-Ray](issues/13-xray.md) — their entries no longer exist; the sweep's
  sepia/invert/rgbSplit findings become library concerns, not gallery-fix work.
- **The gallery-entry backlog (now 133)** — pre-existing open work to grow gallery
  coverage of the 226 effects; a separate effort, not part of this refresh.
- **Cutting the 2.0.0 release** — the CHANGELOG's unreleased 2.0.0 stays unreleased by
  this map; releasing is its own effort.
