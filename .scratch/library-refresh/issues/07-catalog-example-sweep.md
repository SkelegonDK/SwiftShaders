# Sweep the catalog for undemonstrative examples

Part of [the Library refresh map](../map.md)
Type: task
Status: open

## Question

[Name the gallery app's defects](01-gallery-defect-symptoms.md) established defect
class **D2b**: catalog entries whose shader is correct but whose gallery example
fails to show the effect. Enumerate them. AFK where possible: render each of the
100 `EffectCatalog` entries at its default parameter values against its default
sample element (reuse the `GalleryRenderSweepTests` harness for offscreen
rendering) and flag entries where the before/after difference is invisible or
unrepresentative — checking specifically for: default parameter values that render
near-invisibly, a sample element ill-suited to the effect, a time-driven effect not
marked `animated:` (frozen at t=0), and effects that only read against the
checkerboard backdrop. Exclude the known shader-logic bugs (class D2a — those are
code defects, inventoried by
[the headless diagnosis](02-gallery-headless-diagnosis.md)). User-named priority
cases may be appended here as they arrive. The answer is the flagged-entry list
with the suspected presentation mechanism per entry — choosing new defaults or
samples is the fix plan's decision, not this sweep's.

**Scope narrowed 2026-08-26:** the user named 24 entries, each now carrying its
own diagnosis ticket (09–32). This sweep covers only the *remaining* ~76 catalog
entries — its job is catching what the user didn't happen to notice.
