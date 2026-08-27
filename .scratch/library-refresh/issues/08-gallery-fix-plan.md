# Decide the gallery fix plan

Part of [the Library refresh map](../map.md)
Type: grilling
Status: open
Blocked by: 02, 07, 09–32 (10/11/13 closed out of scope), 34

## Question

With the defect inventory complete — user-visible symptoms
([Name the gallery app's defects](01-gallery-defect-symptoms.md)), headless
findings ([Build and exercise the gallery app headlessly](02-gallery-headless-diagnosis.md)),
the presentation sweep
([Sweep the catalog for undemonstrative examples](07-catalog-example-sweep.md)),
the 24 per-shader diagnoses the user requested (tickets 09–32), and the
control-layer coverage decision
([Decide how effects cover all layers of control samples](34-control-layer-coverage.md)) —
assemble the fix plan: for each defect, fix now or defer, and the approach.
This ticket aggregates and sequences; the per-defect decisions live in their own
tickets.
Known decision points already visible:

- **D1 sidebar truncation** — two-line wrapping vs. wider column vs. shorter
  display names.
- **D2a shader-logic bugs** — which of the triaged latent bugs get fixed in this
  effort; several are blocked by the signature manifest (`electricNeon`,
  `polaroid`) or require an effect-kind change (`chromaticAberration`,
  `scatterDissolve` need `layerEffect`), so "fix" may mean "document as known
  limitation". Rendering changes may move `ShaderRenderingTests` baselines — the
  plan must say which guards move.
- **D2b presentation defects** — new defaults/samples per flagged entry.

**Update 2026-08-27 (from the resolved sweep):** the D2a inventory grew by
three — sepia (transposed matrix), invert (premultiplied-alpha white-out),
rgbSplit (no-op approximation, layerEffect-class like chromaticAberration) —
and the sweep surfaced one *systemic* decision: many shaders paint the sample's
transparent padding as an opaque slab (mask by source alpha vs. document as
field behaviour), which resolves a dozen per-entry flags at once. See
[the sweep's answer](07-catalog-example-sweep.md) for the full flagged list.

**Update 2026-08-27 (colour entries removed):** the user removed the gallery's
colour-adjustment entries (Color category → chromaticAberration only), so the
sweep's colour-entry flags — sepia, invert, rgbSplit (D2a), vibrance,
colorGrading, levels (D2b) — are no longer gallery-fix work. The D2a bugs still
exist in the *library's* shaders; whether to fix them there is a library-side
decision this plan may note but does not own. Tickets 10/11/13 closed out of
scope with the same ruling.

The answer is thread 2's destination: a fix plan with nothing left to decide
before execution.
