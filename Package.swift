// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SwiftShaders",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "SwiftShaders",
            targets: ["SwiftShaders"]
        ),
        .executable(
            name: "SwiftShadersGallery",
            targets: ["SwiftShadersGallery"]
        ),
    ],
    targets: [
        // The `.metal` sources live in `Metal/` and are excluded from the Swift
        // build: SwiftPM's command-line build has no Metal rule. `Scripts/build-shaders.sh`
        // compiles them into `Resources/default.metallib`, which ships as a resource
        // and is reached at runtime via `ShaderLibrary.bundle(.module)`.
        //
        // Earlier this target declared the shader *directories* as `.process`
        // resources, which made SwiftPM treat the sibling `.swift` files as
        // resource data too and silently dropped most modifiers from the build.
        .target(
            name: "SwiftShaders",
            path: "Sources/SwiftShaders",
            exclude: ["Metal"],
            resources: [.copy("Resources/default.metallib")]
        ),
        .executableTarget(
            name: "SwiftShadersGallery",
            dependencies: ["SwiftShaders"],
            path: "Sources/SwiftShadersGallery"
        ),
        .testTarget(
            name: "SwiftShadersTests",
            dependencies: ["SwiftShaders"]
        ),
    ]
)
