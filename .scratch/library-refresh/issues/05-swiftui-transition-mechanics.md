# Establish the SwiftUI mechanics for shader-driven transitions

Part of [the Library refresh map](../map.md)
Type: research
Status: resolved

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

## Answer

Full findings: `docs/research/swiftui-transition-mechanics.md` on branch
`research/swiftui-transition-mechanics` (commit 1e99acb, local only).

**Recommended mechanism.** The iOS 17 `Transition` protocol (exactly the library's
floor), not `AnyTransition.modifier(active:identity:)` — `body(content:phase:)`
exposes `TransitionPhase` (`.willAppear`/`.identity`/`.didDisappear`, `value` =
−1/0/+1), typed static-member ergonomics, `.animation(_:)` attachment, and
`TransitionProperties` (Reduce Motion falls back to opacity via `hasMotion`).
Progress reaches the shader through a `ViewModifier` conforming to `Animatable`
whose `animatableData` is a single signed progress scalar set to `phase.value`;
the body rebuilds the `Shader` each frame with `.float(progress)` applied via
`visualEffect` → `layerEffect`/`distortionEffect`/`colorEffect`. Insertion animates
−1→0, removal 0→+1; the Metal function reads `abs(progress)` as amount,
`sign(progress)` as direction (direction must live in the animated scalar —
non-animatable modifier properties snap at animation start). Inferno and Pavel Zak
rely on SwiftUI implicitly interpolating plain shader float args; that behavior is
undocumented, so explicit `Animatable` is the robust choice. A complete working
sketch (Metal wipe + modifier + transition + usage) is in the document.

**Constraints a transitions API must respect:**
1. Progress-driven, never clock-driven — `ShaderClock`/`TimelineView` play no role;
   magnitude ≤ 1 sidesteps the float-precision issue behind ADR-0007.
2. The removed view stays alive during removal only while an animatable change is
   in flight — the `Animatable` conformance is the lifeline.
3. Transitions require an animated transaction; a disabled-animation transaction
   snaps and the removal effect never shows.
4. `maxSampleOffset` must be constant and cover the max displacement across the
   whole transition; beyond it content crops and samples read transparent
   (observed, undocumented). UIKit/AppKit-backed subviews render as placeholders
   inside filtered layers.
5. Identity phase stays applied for the view's whole visible lifetime — the shader
   must be an exact no-op at progress 0 and gated `isEnabled: progress != 0`.
6. No identity-affecting changes (`if`/`switch`/`id`) in the transition body —
   asymmetry lives in the shader via `sign(progress)`.
7. Scope: conditional content, `ForEach`, overlays — not NavigationStack push/pop
   on this floor (`navigationTransition` is iOS 18+). Composes with
   `matchedGeometryEffect` (geometry only; size uniforms stay live via proxy).
8. Route transition shaders through the existing `shaderEffect`/`ShaderBinding`
   path (`.viewSize` geometry already implies the `visualEffect` wrapper;
   `SampleRegion` models the `maxSampleOffset` contract) so they stay inside the
   manifest/binding-test net.
