import SwiftUI

// MARK: - Package Shader Lookup

@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public extension ShaderLibrary {

    /// The Metal library shipped inside this package.
    ///
    /// SwiftUI's `ShaderLibrary.<name>` shorthand looks the function up in the
    /// *main* bundle, which is the host app — not this package. Every shader
    /// resolution in SwiftShaders therefore goes through this property so the
    /// lookup targets the package's own `default.metallib`. Since Phase 5 the
    /// only caller is `ShaderBinding.makeShader` — modifiers declare a
    /// `ShaderBinding` and apply it with `View.shaderEffect` instead of
    /// touching the library directly.
    static var swiftShaders: ShaderLibrary {
        .bundle(.module)
    }
}
