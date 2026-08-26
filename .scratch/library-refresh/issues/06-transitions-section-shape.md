# Decide the transitions section's shape

Part of [the Library refresh map](../map.md)
Type: grilling
Status: open
Blocked by: 04, 05

## Question

Given the prior-art shortlist and the platform mechanics, decide the shape of the
new shader-based view-transitions section: the public API the consumer writes
(e.g. `.transition(.shader(.dissolve))` vs a `ShaderTransition` namespace), the
initial transition set to ship, naming, where it lives in `Sources/SwiftShaders/`
(new `ShaderFamily`? reuse of existing dissolve/pixelate shaders or the 49 unbound
functions?), and how the gallery presents it. Consider a `/prototype` stub if the
API discussion needs something concrete to react to. The answer is the section's
spec — sharp enough that implementation needs no further decisions beyond the
fog items this unblocks (integrity-guard integration, gallery preview shape).
