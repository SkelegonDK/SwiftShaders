# Build and exercise the gallery app headlessly

Part of [the Library refresh map](../map.md)
Type: task
Status: open

## Question

Characterize every defect findable without a human at the screen, so the fix
decision has evidence. AFK: run `make shaders` then `swift build --package-path
Gallery`, run the test suite (`make test`), including `GalleryRenderSweepTests` and
`CatalogConsistencyTests`, and capture compiler/runtime warnings. Record: what
fails, what renders wrong, exact reproduction, and suspected owning component
(binding, catalog entry, clock, app shell). Fold in the already-triaged latent bugs
from `plans/7c-unused-variable-triage.md` (e.g. `directionalChromatic` ignores its
angle, `voronoiShattered`/`voronoiStainedGlass` ignore time, `infiniteGrid` never
draws its grid) so the inventory is complete. The answer is a defect inventory —
fixing anything is a later, separate decision.
