# Expand the transition candidate set

Part of [the Library refresh map](../map.md)
Type: research
Status: resolved
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

## Answer

Full findings: `docs/research/transition-set-expansion.md` on branch
`research/transition-set-expansion` (commit e4f0ed4).

**Coverage.** The full gl-transitions repo is 125 `.glsl` files (not the ~70
assumed); every file was classified from source against the ticket-05 rule, with
license headers checked. Roughly **60% of the catalog is adoptable** — vs the
prior survey's 16-row shortlist: ~35 fully portable pure masks (colorEffect,
trivial), ~20 fully portable self-displacing (layerEffect/distortionEffect,
moderate), ~28 honest per-side approximations, ~12 genuinely not portable, ~8
redundant slides. Plus **23 original candidates** built on existing shader
families and the unbound Metal functions. Everything recommended is MIT; the
only non-MIT files anywhere in the catalog are InvertedPageCurl (BSD-3) and
StereoViewer (BSD-2, skipped).

**Corrections to the prior survey.** (1) The portability rule is
direction-symmetric — `getFromColor`-at-raw-`uv` shaders are valid *insertion*
transitions, rescuing the In/Out paired families (Slides, splitSlide*,
SimpleZoom/Out). (2) Raw-`uv` is necessary but not sufficient: HSVfade /
ColourDistance / multiply_blend mix colours from both textures — mechanically
safe, visually unfaithful. (3) Four verdicts corrected: perlin is a plain
portable mask; ripple and Rolls are fully portable; CrossZoom stays non-portable
but only via a helper parameter *named* `uv` — a trap for mechanical audits.
(4) The unbound `scatterDissolve` already takes a `progress` parameter — the
single cheapest new transition in the package.

**Top recommendations** (doc has a tiered E1/E2/E3 ordering + explicit skip
list): scatter dissolve (bind the unbound fn), luminance_melt,
DoomScreenTransition + gravityDrip melts, fragment/Voronoi shatter, the Mark
Craig rotation set (RotateScaleVanish, Rolls, Slides), WaterDrop/ripple +
shockwave reveal, Bounce, an original CRT power-off (proposed marquee
transition, fully original), the glitch-out set, and a dozen-entry mask pack
from one shared pattern.

Feeds [Decide the transitions section's shape](06-transitions-section-shape.md),
which is now unblocked.
