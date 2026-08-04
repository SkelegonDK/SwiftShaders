.PHONY: gallery app shaders build test clean

# Open the effects gallery (compiles shaders, builds, packages and launches).
gallery: app
	open "$$(swift build --show-bin-path)/SwiftShadersGallery.app"

# Package the gallery as a double-clickable .app.
app:
	./Scripts/make-app.sh

# Compile Sources/SwiftShaders/Metal/*.metal into Resources/default.metallib.
# Required after editing any .metal file: SwiftPM's CLI has no Metal build rule.
shaders:
	./Scripts/build-shaders.sh

# Always go through `make build` / `make test`, never bare `swift build`.
# SwiftPM only *warns* about a declared-but-missing resource, so a bare
# `swift build` with no default.metallib succeeds and ships a package whose
# every effect fails at draw time. ShaderLibraryIntegrityTests is the backstop.
build: shaders
	swift build

test: shaders
	swift test

# Removes the generated metallib along with the build products. Both are
# artifacts; neither is committed. Follow with `make build`, not `swift build`.
clean:
	swift package clean
	rm -f Sources/SwiftShaders/Resources/*.metallib
