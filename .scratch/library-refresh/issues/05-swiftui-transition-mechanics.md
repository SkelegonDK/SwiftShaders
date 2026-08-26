# Establish the SwiftUI mechanics for shader-driven transitions

Part of [the Library refresh map](../map.md)
Type: research
Status: claimed

## Question

What does the platform actually offer for driving a Metal shader from a view
transition, on this library's floor of iOS 17 / macOS 14? Pin down: the iOS 17
`Transition` protocol vs `AnyTransition.modifier(active:identity:)`; how transition
progress reaches a `colorEffect`/`distortionEffect`/`layerEffect` argument (and
whether `layerEffect` has sampling limits mid-transition); interaction with
`.animation` and removal timing (does the removed view stay alive for the shader to
run?); NavigationStack/matchedGeometry interplay if any; and what the deprecated-OS
story means for the library's existing `ShaderClock`/`ShaderBinding` conventions.
Deliver: the recommended mechanism with a minimal working code sketch, and the
constraints a transitions API must respect.
