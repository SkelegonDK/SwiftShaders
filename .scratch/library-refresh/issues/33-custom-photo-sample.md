# Decide the custom-photo sample

Part of [the Library refresh map](../map.md)
Type: grilling
Status: open

## Question

User request (2026-08-26): in the Photo tab, "let me choose my own photo". Today
`SamplePhoto` (`Sources/SwiftShadersGalleryCore/SampleElements.swift`) is a
synthetic gradient stand-in, not an image at all. Decide the spec: picker
mechanism (`PhotosPicker` vs. `fileImporter` on macOS), whether the chosen photo
persists across launches (and where), whether the synthetic stand-in remains the
default, and whether `GalleryRenderSweepTests` — which render sample elements
deterministically — keep using the stand-in so baselines stay stable. The answer
is a spec for the picker; implementation belongs to execution.
