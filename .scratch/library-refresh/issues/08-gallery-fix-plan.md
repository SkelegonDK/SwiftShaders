# Decide the gallery fix plan

Part of [the Library refresh map](../map.md)
Type: grilling
Status: open
Blocked by: 02, 07, 09–32, 34

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

The answer is thread 2's destination: a fix plan with nothing left to decide
before execution.
