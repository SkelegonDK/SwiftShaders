# Decide the 3D object sample tab

Part of [the Library refresh map](../map.md)
Type: grilling
Status: open

## Question

User request (2026-08-26): "Add a 3D object tab to show how it looks on top of a
cube or a sphere." Decide the spec: rendering technology (SceneKit `SceneView`,
RealityKit, or a shader-drawn fake 3D primitive), whether SwiftUI shader effects
(colorEffect/layerEffect/distortionEffect) even apply over the chosen 3D view's
rendering surface — a technical unknown to verify before committing — plus which
primitives ship (cube, sphere, both), lighting/rotation defaults, and whether the
new `SampleElement` case joins `GalleryRenderSweepTests` deterministically. If the
platform question needs legwork, split a research ticket out rather than guessing.
The answer is the tab's spec.
