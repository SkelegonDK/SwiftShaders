# Context

Domain vocabulary for SwiftShaders. A glossary, not an essay — each term points at
the code that owns its definition.

## effect

A single visual transformation a `View` can have applied, exposed as one or more
public `View` extension methods (e.g. `sepia(intensity:)`,
`rippleEffect(time:amplitude:frequency:decay:)`). The library has **226** public
effect methods, backed by Metal `[[stitchable]]` functions. Not every effect has a
Gallery entry — see **coverage ledger**.

## effect kind

Which of SwiftUI's three shader-backed modifiers an effect uses — fixed by the Metal
function's signature, not a free choice: `colorEffect` (`half4 name(float2 position,
half4 color, args...)`), `distortionEffect` (`float2 name(float2 position, args...)`),
`layerEffect` (`half4 name(float2 position, SwiftUI::Layer layer, args...)`). Owned by
`ShaderBinding.Kind` in `Sources/SwiftShaders/Core/ShaderBinding.swift`.

## binding

The single declared record of how one Metal function is called from Swift: name,
effect kind, leading geometry convention and sample region. Call sites use
`View.shaderEffect(_:_:)` with a binding and their effect-specific arguments only —
the binding decides the effect method and prepends any geometry argument, rather than
each site restating the convention. Owned by
`Sources/SwiftShaders/Core/ShaderBinding.swift`; declarations live in a `ShaderFamily`
enum next to each modifier, listed in `ShaderBindingRegistry`.
`ShaderBinding.LeadingGeometry` is the `.boundingRect` (Metal declares `float4 bounds`
first) vs `.viewSize` (`float2 size` first) vs `.plain` split — the root cause of the
121 shaders that rendered black before every `.boundingRect` site passed it explicitly.

## manifest

The generated, checked-in record of the compiled Metal library's actual surface:
`Sources/SwiftShaders/Resources/shader-signatures.tsv`, one row per `[[stitchable]]`
function (256 rows). Produced by `Scripts/extract-metal-signatures.py` from `xcrun
metal-objdump --metallib -d`, so it cannot drift from what the metallib contains — the
independent yardstick the binding tests check against, not a hand-maintained list.

## coverage ledger

`Tests/SwiftShadersTests/Support/EffectCoverageLedger.swift`. Every one of the 226
public effect methods, tagged `.inGallery(id)`, `.presetOf(baseMethod)` (a
zero-argument convenience whose base method already has an entry), or
`.deliberatelyAbsent(reason)`. A ratchet test asserts the absent count never rises.
Replaced an attempted single library-authored "descriptor" that every catalog would
derive from — rejected because it would have meant inventing ~350 gallery slider
ranges outside the code that knows sensible defaults. See `docs/adr/0006-coverage-ledger.md`.

## unbound function

A `[[stitchable]]` Metal function with no `ShaderBinding` declaration pointing at it —
reachable from Metal, not from Swift. 49 of them, tracked in the generated,
staleness-guarded `Sources/SwiftShaders/Resources/unbound-functions.txt`. Not a
defect — the cheapest future gallery/binding additions, kept rather than deleted.

## clock

`ShaderClock` (`Sources/SwiftShaders/Core/ShaderClock.swift`) is the library's one time
source for animated effects: it converts a `TimelineView` date into small **elapsed
seconds** from a per-view start instant, never an absolute date.
`Shader.Argument.float` is 32-bit, and `Date.timeIntervalSinceReferenceDate` is large
enough (~7.8×10⁸) that its `Float` ulp is 64 seconds — why the old absolute-date
convention rendered every animated entry point as a frozen frame. Both ends of the
subtraction are injectable via `EnvironmentValues`, so a headless render at a known
instant is exact rather than sleep-based.

## gallery / catalog

`EffectCatalog` (`Sources/SwiftShadersGalleryCore/EffectCatalog.swift`, in the
importable `SwiftShadersGalleryCore` library target) is the hand-curated list of 91
effects the Gallery app previews, pairing each real `View` call with slider metadata.
Deliberately not generated from the manifest or the ledger — those check it stays
faithful, but a human still picks sensible slider ranges. The earlier `ShaderCatalog`
(a separate 30-row registry inside the library target, 19 of whose ids matched no
public method) was deleted; do not recreate a second one.

The *app shell* around it — `@main`, `ContentView`, `Pasteboard` — is a separate
package, `Gallery/`, depending on this one by path. The split is the point: it makes
the app an ordinary external consumer, so CI's `swift build --package-path Gallery`
is the one check that the library is usable from outside its own build graph. The
catalogue cannot follow it, because the test target imports `SwiftShadersGalleryCore`
and a package cannot import a target from a package that depends on it.

## drift check

A test that fails if a generated or hand-maintained artifact no longer matches the
thing it describes: the manifest vs. the metallib it was extracted from (`xcrun
metal-source --extract=raw` must match on-disk `.metal`/`.h`), and the
unbound-functions inventory vs. a fresh regeneration. The yardstick must be an
artifact the checked thing does not itself produce — a completeness guard that
derives its answer the same way as the thing it guards can pass while both are wrong
(happened once, to the coverage ledger's first scanner; see Phase 6 results in
`plans/00-shader-integrity-remediation.md`).
