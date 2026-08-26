# Decide how effects cover all layers of control samples

Part of [the Library refresh map](../map.md)
Type: grilling
Status: open

## Question

User request (2026-08-26): "Effects on buttons and lists need to apply to all
layers of the component, not just backgrounds and shapes." Diagnose first: in
`SampleButton` / `SampleList` (`Sources/SwiftShadersGalleryCore/SampleElements.swift`)
and in how `Effect.build` wraps the sample, which layers escape the shader —
is the effect applied to a sub-layer of the sample, or does SwiftUI's
colorEffect/layerEffect rasterization skip some content (e.g. text drawn by the
control, `drawingGroup` boundaries)? Then decide the approach: restructure the
sample views, apply the modifier at a different level, or force rasterization —
and whether the fix is per-sample or in the shared build path. The answer is the
decided approach; it feeds [Decide the gallery fix plan](08-gallery-fix-plan.md).
