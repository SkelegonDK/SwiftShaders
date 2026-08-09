# Effects Gallery

An interactive playground for browsing, tweaking and copying the shader effects.

```bash
make gallery
```

That compiles the Metal shaders, builds the app, wraps it in a `.app` bundle and
opens it.

## Where it lives

The app is its own package, `Gallery/`, which depends on the library by path:

```
Gallery/Package.swift                        the app's manifest
Gallery/Sources/SwiftShadersGallery/         @main, ContentView, Pasteboard
```

It is deliberately a *consumer* of SwiftShaders rather than a target inside it, so
building it exercises the library's real external surface — CI runs `swift build
--package-path Gallery` for exactly that reason. To build it without the `.app`
wrapper:

```bash
make shaders                        # default.metallib is a resource of the library
swift build --package-path Gallery
```

`make shaders` first is not optional. The metallib is generated and not committed,
and SwiftPM only *warns* about a declared-but-missing resource, so skipping it gets
you an app that builds and then fails to draw every effect.

The catalogue stays in the root package, as the `SwiftShadersGalleryCore` library —
the test suite imports it, and a package cannot import a target from a package that
depends on it. So an effect is added in the root package (below) and the app picks
it up for free.

## What it does

- **Browse** 91 effects across 9 categories, with a search field.
- **Preview** each one live on a real UI element — card, button, text, icon,
  photo or settings list — so you can see how it behaves on the kind of view
  you'd actually apply it to.
- **Tweak** every parameter with sliders that use each effect's real argument
  ranges. Values are remembered per effect while the app is open.
- **Copy** the exact Swift for the current settings. Animated effects come with
  the `TimelineView` that drives them, so the snippet is ready to paste.

Animated effects show a play/pause button in the toolbar; pausing freezes the
current frame rather than resetting it. The checkerboard toggle helps when
judging effects that alter transparency.

## Adding an effect to the gallery

Everything is driven by one list, `EffectCatalog` in
`Sources/SwiftShadersGalleryCore/EffectCatalog.swift`. One entry adds the sidebar
row, the sliders and the generated code:

```swift
Effect("sepia", "Sepia", .color, "Classic warm monochrome.",
       params: [.init("intensity", 0...1, 1)]) { view, p, _ in
    AnyView(view.sepia(intensity: Float(p[0])))
}
```

The closure receives the sample view, the current parameter values and the
animation time. Pass `animated: true` for effects that take a leading `time:`
argument — the gallery then drives them from a `TimelineView` and includes it in
the generated snippet.

## Working on the shaders

SwiftPM's command-line build has no rule for `.metal` files, so they are
excluded from the Swift target and compiled separately:

```bash
make shaders
```

This links every file in `Sources/SwiftShaders/Metal/` into
`Sources/SwiftShaders/Resources/default.metallib`, which ships as a package
resource. Re-run it after editing any shader.

Because the library lives in a package rather than the host app, every modifier
looks its function up through `ShaderLibrary.swiftShaders` (see
`Core/ShaderLibrary+Bundle.swift`) rather than the bare `ShaderLibrary.name`
shorthand, which would search the main app bundle instead.
