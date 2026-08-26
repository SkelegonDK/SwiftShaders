# Name the gallery app's defects

Part of [the Library refresh map](../map.md)
Type: grilling
Status: resolved
Assignee: Manuel Thomsen (session wayfinder-docs-shader-transitions-5dc4e7)

## Question

"Debug the library app" names no symptom. What is actually wrong with the gallery
app (`Gallery/` package, launched via `make gallery`) from the user's seat — crashes,
effects rendering wrong or black, UI/UX problems, build failures, performance? On
which OS and hardware, and since when? Grill until each defect is a concrete,
reproducible statement. Cross-check against whatever
[Build and exercise the gallery app headlessly](02-gallery-headless-diagnosis.md)
turned up, so user-visible symptoms and headless findings land in one defect list.

## Answer

The user named the defects (2026-08-26 invocation): *"Sidebar cuts off shader
names"* and *"Some shaders are broken or don't have proper examples that show the
effect of the shader even though the code might be correct."* Sharpened against the
code, that is one concrete UI defect and two distinct defect classes:

**D1 — Sidebar truncates effect names.** Reproducible: launch `make gallery` at the
default window size; long names ellipsize in the sidebar. Mechanism confirmed in
`Gallery/Sources/SwiftShadersGallery/ContentView.swift:50-73`: each row is a
single-line `Label(item.name, systemImage:)` with no wrapping, inside a column
constrained to `.navigationSplitViewColumnWidth(min: 210, ideal: 240)`. The longest
display names ("Chromatic Aberration" 20 chars, "Data Corruption", "Soft
Threshold"…) don't fit at ideal width once the icon and list insets are paid.
Owning component: app shell (sidebar view). Fix candidates (for the fix-plan
ticket, not decided here): allow two-line wrapping, raise the column width, or
shorten display names.

**D2a — Shader-logic defects: the code itself is wrong, so no example can show the
effect.** Already triaged, user report corroborates:
- Nine latent bugs in `plans/7c-unused-variable-triage.md` — `directionalChromatic`
  ignores `angle` (not directional at all), `deboss` never applies its light angle,
  `chromaticAberration` computes and discards its sample offset (colour-shift
  approximation only), `lensChromatic` leaves green undistorted, `scatterDissolve`
  never scatters (fades only), `electricNeon` ignores view geometry, `polaroid`
  ignores `size` (no vignette), `neonOutline` and `sketchCharcoal` don't scale
  offsets by resolution.
- From `plans/00-shader-integrity-remediation.md`: `voronoiShattered` /
  `voronoiStainedGlass` accept `time` and ignore it, `infiniteGrid` never draws its
  grid.

**D2b — Presentation defects: the shader is correct but the gallery entry fails to
demonstrate it.** Candidate mechanisms in the catalog
(`Sources/SwiftShadersGalleryCore/EffectCatalog.swift`, 100 entries): default
parameter values that render near-invisibly, a sample element ill-suited to the
effect, a missing `animated:` flag freezing a time-driven effect at t=0, or an
effect needing the checkerboard backdrop to read. **Enumeration is deliberately not
done here** — the user said "some" without naming instances, and inventing the list
would fake their half of the grilling. The mechanical part (renders black/no-op)
falls out of [the headless diagnosis](02-gallery-headless-diagnosis.md); the visual
judgment part is graduated to
[Sweep the catalog for undemonstrative examples](07-catalog-example-sweep.md).
Any entries the user can name from memory should be appended to that sweep ticket
as priority cases.

Open residuals for the user (optional enrichment, not blocking): which entries they
personally saw failing, and whether "broken" meant black/no-op rendering or merely
an unconvincing demo.
