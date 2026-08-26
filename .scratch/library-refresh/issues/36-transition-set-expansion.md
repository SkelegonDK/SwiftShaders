# Expand the transition candidate set

Part of [the Library refresh map](../map.md)
Type: research
Status: open
Assignee: research subagent (fired 2026-08-26 from session wayfinder-docs-shader-transitions-5dc4e7)

## Question

User feedback (2026-08-26): "All the transitions look great, see if you can find
or come up with more cool transitions." The prior-art survey
([Survey shader-based view-transition prior art](04-transition-prior-art.md))
produced a tiered shortlist; expand it. Go deeper into the gl-transitions
collection (~70 entries — the survey shortlisted only a first tier), plus any
other credible sources (Shadertoy-style patterns, platform demos), plus original
ideas suited to the library's existing shader families (dissolve, pixelate,
voronoi, the 49 unbound Metal functions). Filter every candidate by the
established mechanics ([Establish the SwiftUI mechanics for shader-driven
transitions](05-swiftui-transition-mechanics.md)): single-layer portability
(samples the incoming view only at raw uv), signed-progress drivable, constant
`maxSampleOffset`. Deliver an expanded candidate list — name, visual description,
source, license, port difficulty, tier — feeding
[Decide the transitions section's shape](06-transitions-section-shape.md).
