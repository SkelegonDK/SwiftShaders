# 0007 — One `ShaderClock`, measuring elapsed time, not absolute dates

**Status:** Accepted · **Date:** 2026-08-05 · **Phase:** 7b of `plans/00-shader-integrity-remediation.md`

## Context

The library had two unrelated time conventions roughly 7.8×10⁸ seconds apart.
Twenty-two modifiers already used the correct pattern: `@State private var startTime
= Date.now`, then `startTime.distance(to: timeline.date)` inside a `TimelineView`,
producing small elapsed seconds. A second set of entry points — `ShaderView`'s
animated branch, `ShaderPreview`, `AnimatedShaderView`/`PulsingShaderView`/
`SequencedShaderView`, `ShaderTimeline`, and `RippleModifier`'s animated form — instead
fed `timeline.date.timeIntervalSinceReferenceDate` directly into a
`Shader.Argument.float`.

That is a rendering bug, not a style inconsistency: `Shader.Argument.float` is
32-bit, and at `~7.8×10⁸` a `Float`'s ulp is 64 seconds — `Float(7.8e8) ==
Float(7.8e8 + 1.0/60.0)`. A shader driven by that value does not animate slowly; it
receives an unchanging number, frame after frame. Measured directly by rendering
`ripple` across a range of times: the effect still responded at `t=1e5` and
`t=2e6`, and went fully inert from `t=4e6` upward, because Metal's `sin()` has no
argument-reduction range left at that magnitude either. Separately,
`ShaderView.animationTime` and `ShaderPreview.time` were `@State` properties nothing
ever wrote, so their "non-animated" branches silently rendered at `t=0` forever. A
468-line `ShaderAnimator` (`CADisplayLink`/`Timer`-driven, with `start()`/`pause()`/
`stop()`/`reset()`/`seek(to:)`) existed alongside both conventions with zero call
sites anywhere in the library, the Gallery, `Examples`, the tests, or the docs.

## Decision

**One `ShaderClock`, `TimelineView`-backed, converting a date into elapsed seconds
from a per-view start instant, with both ends of the subtraction injectable for
tests.** Every animated entry point in the library — the five broken ones and, for
consistency, the 21 already-correct `startTime`-based modifiers — now goes through
it (`Sources/SwiftShaders/Core/ShaderClock.swift`). `ShaderAnimator` is deleted
outright rather than kept behind the same interface.

## Consequences

- `grep -rn timeIntervalSinceReferenceDate Sources/` → 1: the sole remaining
  occurrence is the explanatory doc comment inside `ShaderClock.swift` itself.
- A red-then-green acceptance test (`ShaderClockTests`) proves the fix: an
  `ImageRenderer` comparison at two pinned instants goes from 0 differing pixels
  (frozen) to a fully animated frame, using `ShaderClock`'s injectable
  `shaderClockStart`/`shaderClockNow` environment values rather than a sleep-based
  test.
- `ShaderView.animationTime` and `ShaderPreview.time`, which nothing ever wrote, are
  removed along with the dead branches that read them; the non-animated paths now
  pass a literal `0`, which is what "not animated" actually means.
- **Breaking change**: `ShaderAnimator` and its full public surface (`time`,
  `progress`, `isRunning`, `speed`, `duration`, `loops`, `loopCount`, `autoReverse`,
  `init()`, `init(speed:duration:loops:autoReverse:)`, `start()`, `pause()`,
  `stop()`, `reset()`, `seek(to:)`) is removed — recorded in `CHANGELOG.md`. Next
  release is 2.0.0. Migration: drive a `TimelineView` through `ShaderClock` directly,
  or use `AnimatedShaderView`/`ShaderTimeline`, which already do.
- Moving the 21 already-correct modifiers onto `ShaderClock` too was a mechanical,
  behavior-preserving change (same `Date.now` start point, same subtraction) —
  verified by an asserting script over all 21 declarations and 21 uses — done so
  that any future change to what "elapsed time" means (pause, speed, a global
  scrub) is one edit instead of twenty-two.

## Alternatives considered

| Option | Verdict | Why |
|---|---|---|
| Leave both conventions in place, document which to use | Rejected | Documentation cannot fix a rendering bug that fails silently; new code would keep copying whichever example it found first, including the broken one. |
| Move `ShaderAnimator` behind the new clock interface instead of deleting it | Rejected | Zero call sites anywhere in the tree; keeping a second, unused timing engine "because it's public" is a maintenance cost with no consumer to justify it. |
| **One `ShaderClock`, all entry points migrated, `ShaderAnimator` deleted** | **Chosen** | Fixes the silent rendering bug at its root (the value fed to the shader, not just the call sites that were already broken) and removes the dead second engine in the same pass. |
