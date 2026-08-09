// swift-tools-version: 5.9

import PackageDescription

// The gallery app shell, as a package of its own. It consumes SwiftShaders the
// way any other project would — through a package dependency — so a build here
// exercises the library's real, external surface. When the shell was a target
// inside the library manifest it shared the library's build graph, and nothing
// checked that the package was usable from outside.
//
// The catalogue stays in the root package: the test target imports
// `SwiftShadersGalleryCore` for the coverage ledger and the render sweep, and a
// package cannot import a target from a package that depends on it.
let package = Package(
    name: "SwiftShadersGallery",
    // macOS only, and only what the shell actually compiles for. `ContentView`
    // uses `HSplitView`, `.searchable(placement: .sidebar)` and
    // `.windowResizability` — all AppKit-backed and macOS-only — so declaring
    // iOS/tvOS/visionOS here would promise a build that has never existed. The
    // library itself remains four-platform; this is a statement about the app.
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "SwiftShadersGallery",
            targets: ["SwiftShadersGallery"]
        ),
    ],
    dependencies: [
        // `name:` is load-bearing, not decoration. Without it SwiftPM derives a
        // path dependency's identity from the *directory basename*, so the
        // `package:` labels below would only resolve in a checkout that happens
        // to sit in a folder called `SwiftShaders` — they fail outright in a git
        // worktree, or in any clone given a different folder name. Naming the
        // dependency pins the identity to the manifest instead of the filesystem.
        .package(name: "SwiftShaders", path: ".."),
    ],
    targets: [
        // The app shell: `@main`, the browsing UI, the pasteboard.
        .executableTarget(
            name: "SwiftShadersGallery",
            dependencies: [
                .product(name: "SwiftShaders", package: "SwiftShaders"),
                .product(name: "SwiftShadersGalleryCore", package: "SwiftShaders"),
            ],
            path: "Sources/SwiftShadersGallery"
        ),
    ]
)
