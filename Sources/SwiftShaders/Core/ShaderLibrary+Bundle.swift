import SwiftUI

// MARK: - Package Shader Lookup

@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public extension ShaderLibrary {

    /// The Metal library shipped inside this package.
    ///
    /// SwiftUI's `ShaderLibrary.<name>` shorthand looks the function up in the
    /// *main* bundle, which is the host app — not this package. Every modifier
    /// in SwiftShaders therefore goes through this property so the lookup
    /// targets the package's own `default.metallib`.
    ///
    /// ```swift
    /// content.colorEffect(ShaderLibrary.swiftShaders.sepia(.float(intensity)))
    /// ```
    static var swiftShaders: ShaderLibrary {
        .bundle(.module)
    }
}
