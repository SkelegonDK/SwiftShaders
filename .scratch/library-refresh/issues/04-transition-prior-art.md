# Survey shader-based view-transition prior art

Part of [the Library refresh map](../map.md)
Type: research
Status: claimed

## Question

What do existing libraries and repos do for shader-driven view transitions, and
which of their transitions are worth adopting? Survey at minimum: twostraws/Inferno
(SwiftUI Metal shaders, its transitions if any), movingparts/Pow (its
transitions/effects API shape), the gl-transitions collection (the canonical
catalog of ~70 GLSL transitions — which port cleanly to a SwiftUI
`colorEffect`/`layerEffect` world), and any notable SwiftUI + Metal transition
demos/repos. For each: the API the consumer writes, how transition progress drives
the shader, and license compatibility with MIT. Deliver a shortlist of candidate
transitions (name, visual, source, port difficulty) and the API patterns observed.
