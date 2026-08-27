# Diagnose and decide the fix for Earthquake

Part of [the Library refresh map](../map.md)
Type: task
Status: resolved
Assignee: Manuel Thomsen (session wayfinder-docs-shader-transitions-5dc4e7, 2026-08-27)

## Question

User-reported (2026-08-26): the **Earthquake** entry (`earthquakeDisplacement`) is broken or its
example fails to show the effect. Check the animated flag and default amplitude — a shake effect frozen or too subtle reads as broken. Determine which defect class this is —
shader-logic (D2a: the Metal code is wrong) or presentation (D2b: the catalog
entry's defaults, sample element, or `animated:` flag undersell a correct
shader) — with a reproduction, and decide the fix. Respect the integrity guards
(map Notes): say which guard moves if rendering or signatures change. The answer
feeds [Decide the gallery fix plan](08-gallery-fix-plan.md).

## Resolution (2026-08-27)

**Class: D2b — presentation defect. The shader is correct; the gallery clock
kills the demo.**

The Metal function (`DisplacementShader.metal:699`) is a faithful "decaying
directional shake": high-frequency sin/cos jitter scaled by an envelope
`exp(-time * decay)`. That envelope is a **one-shot**: with the catalog's
default `decay = 0.5`, the shake is effectively gone by ~10 s of clock time and
never returns — and `ShaderClock` (by design, per CONTEXT.md) runs elapsed
seconds from the view's start and never resets. So the entry shakes for a few
seconds after opening, then sits permanently still; moving the magnitude or
frequency sliders changes nothing visible because the envelope has already
collapsed. That is exactly the user's symptom ("broken or fails to show").

Headless reproduction (sum-of-absolute-differences of the default card entry
vs. the unshaded card, `ImageRenderer`, 380×280, the ticket-07 measurement
machinery; scratch test deleted after the run):

| clock t | SAD, decay=0.5 (default) | SAD, decay=0 |
|---|---|---|
| 1.0 s | 2,987,091 | — |
| 1.7 s | 1,170,372 | 2,389,090 |
| 8.0 s | 220,218 | — |
| 10 s | 34,472 | — |
| 20 s | 12,186 | 3,003,704 |
| 60 s | 12,186 (frozen) | 4,488,108 |

The identical 20 s/60 s values show the demo is static from ~20 s on; with
`decay = 0` the shake persists indefinitely, confirming the envelope — not the
shake math, binding, or `animated:` flag — is the whole mechanism.

**Decided fix (catalog-side, entry-local):** re-fire the quake by looping the
clock in the entry's build closure —
`earthquakeDisplacement(time: t.truncatingRemainder(dividingBy: 4), …)` —
so the preview shows a shake that erupts and decays every ~4 s, demonstrating
the effect's actual character including the decay parameter (larger decay →
shorter rumble, visibly). Do **not** change the Metal function or the public
modifier: the one-shot decay is the documented library semantic, and consumers
drive `time` themselves. Do not zero the default decay — that would
mis-demonstrate a "decaying" shake as a perpetual one.

No integrity guard moves: no signature, manifest, count, or binding changes —
this is one line inside the existing `EffectCatalog` closure. One known
tradeoff for [Decide the gallery fix plan](08-gallery-fix-plan.md): the entry's
generated code snippet (`Effect.code`) prints `time: time` and would not show
the modulo, so the snippet and preview diverge slightly; no catalog entry
massages `t` today, so 08 may either accept that or add a small `Effect`
affordance (e.g. a loop period the snippet renderer knows about) if more
decaying effects want the same treatment.
