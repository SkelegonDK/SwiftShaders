# Scope the documentation update

Part of [the Library refresh map](../map.md)
Type: grilling
Status: resolved
Assignee: Manuel Thomsen (session wayfinder-docs-shader-transitions-5dc4e7)

## Question

"Update the documentation" — to what scope? Grill toward a decided boundary:

- **Audience & surface**: is the target the fork's own users, or is this fork
  publishing as its own library? Does the README keep or drop the upstream
  "2026 Unified Core" banner block?
- **GettingStarted.md** is a one-line stub — write it, or delete it and fold into
  the README?
- **API.md** documents only a fraction of the 226 effect methods, is
  hand-maintained, and has been caught documenting methods that never existed —
  expand it by hand, generate it (from what yardstick — the manifest? the coverage
  ledger?), or replace it with DocC?
- **Which claims get guarded**: `ReadmeClaimsTests` pins the numbers today; do new
  or rewritten docs get the same drift protection?

The answer is a documentation spec: the list of documents, what each becomes, and
what stays untouched.

## Answer

Resolved 2026-08-27 by grilling. **Identity decision (root): the fork documents
itself as its own library** — it has diverged far past a patch set — with the
sharpening that its audience is the user's own iOS projects and the agents working
on them, not a marketing audience. Docs are a working reference, not a pitch.

The documentation spec:

1. **README.md — full rewrite, keeping the guarded skeleton.**
   - Identity: install URL becomes `SkelegonDK/SwiftShaders.git`; drop the
     "2026 Unified Core" banner block, flagship-engine links, and the upstream
     star-history chart. Keep MIT attribution to upstream in the license section.
   - Keep (all currently true and test-asserted): killer-feature paragraph,
     "By the numbers" table, installation, usage examples, license.
   - Drop: the fabricated benchmarks table, unverifiable performance claims
     ("Auto-Scaling" etc.), and the "33 shader modules" indicative-parameter
     tables — replaced by a pointer to the gallery (`make gallery`) and the
     generated API index.
   - Fold in the getting-started path (install → first effect → animated effect
     via `TimelineView`; `make shaders` for package work).
   - Constraint: `ReadmeClaimsTests` parses the "By the numbers" rows and checks
     every effect called in a code fence exists — the rewrite keeps the row
     format and stays under both guards.

2. **GettingStarted.md — deleted.** One-line stub, never existed in practice;
   content folds into the README (whose code fences are guarded). Verified
   nothing links to it; the execution step still does a final link sweep.

3. **API.md — replaced by a generated signature index.** A script emits one
   entry per public effect method (signature + first doc-comment line, grouped
   by shader family), staleness-guarded like `unbound-functions.txt`
   (regeneration must match the checked-in file). Rationale: hand-maintenance
   is disproven (documents `liquidGlass`, which does not exist); DocC is
   heavyweight for an audience that sees doc comments in Xcode anyway; the
   scanner in `EffectCoverageTests` already discovers all 226 methods, so
   extraction machinery half-exists. Hand-expansion was ruled out.

4. **CODE_OF_CONDUCT.md — minimal touch:** the report contact changes from
   upstream's personal email to the fork maintainer's.

5. **Untouched, checked deliberately:** `Documentation/Gallery.md` (verified
   accurate against CONTEXT.md and the build), `CONTRIBUTING.md`, `SECURITY.md`
   (both grep clean of upstream references), `CHANGELOG.md`.

**Guard posture:** guards exist for claims that can drift from code — README
under `ReadmeClaimsTests`, the API index under its staleness check. Prose/process
docs get no guards. No doc-count numbers change, so no standing guard moves.
