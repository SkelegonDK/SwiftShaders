import SwiftUI

// MARK: - ShaderBinding

/// Namespace for the package's shader binding contracts.
///
/// A binding states, once per stitchable function, everything a call site
/// used to restate by hand: the function name, the leading geometry
/// convention, and — for distortion and layer effects — the sampling
/// region. Call sites apply a binding with `View.shaderEffect(_:_:)` and
/// pass only the effect-specific arguments; the effect method is selected
/// by the binding's type, and the geometry prefix (`.boundingRect` or the
/// live view size) is prepended by the module.
///
/// Declarations live in a `ShaderFamily` enum next to the modifiers that
/// use them and are listed in `ShaderBindingRegistry`, which the binding
/// tests iterate: every declaration is cross-checked against
/// `shader-signatures.tsv` (name, kind, geometry) and compiled through
/// `Shader.compile(as:)` using the same argument-assembly path the
/// appliers use at render time.
enum ShaderBinding {

    /// The effect kind, mirroring the Metal declaration. Raw values match
    /// the `kind` column of `shader-signatures.tsv`.
    enum Kind: String {
        case colorEffect
        case distortionEffect
        case layerEffect
    }

    /// The leading geometry parameter the Metal function declares, and
    /// therefore the argument the module prepends before the call site's
    /// own arguments.
    ///
    /// The library-wide convention, enforced by the binding tests: a first
    /// explicit parameter of `float4` is always a bounding rect and one of
    /// `float2` is always the view size. Do not declare a stitchable
    /// function whose first explicit parameter is a non-geometry `float4`
    /// or `float2`.
    enum LeadingGeometry {
        /// Metal declares `float4 bounds` first; the module prepends
        /// `.boundingRect`, which SwiftUI fills at draw time.
        case boundingRect
        /// Metal declares `float2 size` first; the module wraps the
        /// application in `.visualEffect` and prepends the live view size.
        case viewSize
        /// No leading geometry parameter; nothing is prepended.
        case plain
    }

    /// Where a distortion or layer effect may sample from, expressed as
    /// SwiftUI's `maxSampleOffset`.
    enum SampleRegion {
        /// A constant offset, part of the shader's contract.
        case fixed(width: Double, height: Double)
        /// The live view size; implies a `.visualEffect` wrapper.
        case viewSize
        /// The offset depends on the effect's own parameter values, so
        /// every application site must pass `maxSampleOffset:` explicitly.
        case perSite
    }

    /// The value-level mirror of a binding that the tests enumerate.
    struct Descriptor {
        let name: String
        let kind: Kind
        let geometry: LeadingGeometry
        let sampling: SampleRegion?
        let declarationFile: StaticString
        let declarationLine: UInt
    }

    /// A binding to a `colorEffect` function:
    /// `[[stitchable]] half4 f(float2 pos, half4 color, args...)`.
    struct Color: AnyShaderBinding {
        let descriptor: Descriptor

        init(
            _ name: String,
            geometry: LeadingGeometry,
            file: StaticString = #fileID,
            line: UInt = #line
        ) {
            descriptor = Descriptor(
                name: name, kind: .colorEffect, geometry: geometry,
                sampling: nil, declarationFile: file, declarationLine: line
            )
        }
    }

    /// A binding to a `distortionEffect` function:
    /// `[[stitchable]] float2 f(float2 pos, args...)`.
    struct Distortion: AnyShaderBinding {
        let descriptor: Descriptor

        init(
            _ name: String,
            geometry: LeadingGeometry,
            sampling: SampleRegion,
            file: StaticString = #fileID,
            line: UInt = #line
        ) {
            descriptor = Descriptor(
                name: name, kind: .distortionEffect, geometry: geometry,
                sampling: sampling, declarationFile: file, declarationLine: line
            )
        }
    }

    /// A binding to a `layerEffect` function:
    /// `[[stitchable]] half4 f(float2 pos, SwiftUI::Layer layer, args...)`.
    struct Layer: AnyShaderBinding {
        let descriptor: Descriptor

        init(
            _ name: String,
            geometry: LeadingGeometry,
            sampling: SampleRegion,
            file: StaticString = #fileID,
            line: UInt = #line
        ) {
            descriptor = Descriptor(
                name: name, kind: .layerEffect, geometry: geometry,
                sampling: sampling, declarationFile: file, declarationLine: line
            )
        }
    }
}

// MARK: - AnyShaderBinding

/// Type-erased view of a binding, for the registry and the tests.
protocol AnyShaderBinding: Sendable {
    var descriptor: ShaderBinding.Descriptor { get }
}

extension AnyShaderBinding {

    /// Builds exactly the `Shader` the appliers build at render time —
    /// including the module-supplied geometry prefix — so the test oracle
    /// exercises the production argument list rather than a re-derivation.
    /// `proxySize` is consulted only by `.viewSize` geometry.
    func makeShader(arguments: [Shader.Argument], proxySize: CGSize) -> Shader {
        let function = ShaderLibrary.swiftShaders[dynamicMember: descriptor.name]
        var all: [Shader.Argument] = []
        switch descriptor.geometry {
        case .boundingRect: all.append(.boundingRect)
        case .viewSize: all.append(.float2(proxySize))
        case .plain: break
        }
        all.append(contentsOf: arguments)
        return function.dynamicallyCall(withArguments: all)
    }

    /// Whether applying this binding needs a `.visualEffect` wrapper to
    /// reach the live view size. `override` is a site-supplied
    /// `maxSampleOffset`, which removes the sampling-side need for one.
    fileprivate func needsProxy(override: CGSize?) -> Bool {
        if case .viewSize = descriptor.geometry { return true }
        if override == nil, case .viewSize = descriptor.sampling { return true }
        return false
    }

    /// Resolves the `maxSampleOffset` for one application.
    fileprivate func sampleOffset(override: CGSize?, proxySize: CGSize) -> CGSize {
        if let override { return override }
        switch descriptor.sampling {
        case .fixed(let width, let height):
            return CGSize(width: width, height: height)
        case .viewSize:
            return proxySize
        case .perSite, nil:
            assertionFailure("""
                \(descriptor.name) declares .perSite sampling; every \
                application must pass maxSampleOffset: explicitly \
                (declared at \(descriptor.declarationFile):\(descriptor.declarationLine))
                """)
            return .zero
        }
    }
}

// MARK: - ShaderFamily / ShaderBindingRegistry

/// One conformance per shader family file. Keeps the binding list next to
/// the declarations it lists.
protocol ShaderFamily {
    static var bindings: [any AnyShaderBinding] { get }
}

/// The registry the binding tests iterate. `families` is the only
/// hand-maintained global list — one line per family file. A test guards
/// it against drift by counting binding declarations in the source.
enum ShaderBindingRegistry {
    static let families: [any ShaderFamily.Type] = [
        BlurShaderBindings.self,
        CRTShaderBindings.self,
        ChromaticAberrationShaderBindings.self,
        ColorGradingShaderBindings.self,
        DisplacementShaderBindings.self,
        DissolveShaderBindings.self,
        DistortionShaderBindings.self,
        ElectricShaderBindings.self,
        EmbossShaderBindings.self,
        FireShaderBindings.self,
        FrostShaderBindings.self,
        GlitchShaderBindings.self,
        HologramShaderBindings.self,
        InvertShaderBindings.self,
        KaleidoscopeShaderBindings.self,
        MosaicShaderBindings.self,
        NeonShaderBindings.self,
        NoiseShaderBindings.self,
        ParticlesShaderBindings.self,
        PixelateShaderBindings.self,
        PosterizeShaderBindings.self,
        RaymarchingShaderBindings.self,
        RippleShaderBindings.self,
        ScanlinesShaderBindings.self,
        SepiaShaderBindings.self,
        SharpenShaderBindings.self,
        SketchShaderBindings.self,
        SwirlShaderBindings.self,
        ThresholdShaderBindings.self,
        VignetteShaderBindings.self,
        VoronoiShaderBindings.self,
        WaterShaderBindings.self,
        WaveShaderBindings.self,
    ]

    static var all: [any AnyShaderBinding] {
        families.flatMap { $0.bindings }
    }
}

// MARK: - Application

@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
extension View {

    /// Applies a color-effect binding. The module supplies the geometry
    /// prefix; the caller passes only the effect-specific arguments, in
    /// Metal declaration order.
    @ViewBuilder
    func shaderEffect(
        _ binding: ShaderBinding.Color,
        _ arguments: Shader.Argument...
    ) -> some View {
        if binding.needsProxy(override: nil) {
            visualEffect { view, proxy in
                view.colorEffect(binding.makeShader(arguments: arguments, proxySize: proxy.size))
            }
        } else {
            colorEffect(binding.makeShader(arguments: arguments, proxySize: .zero))
        }
    }

    /// Applies a distortion-effect binding. `maxSampleOffset` overrides the
    /// binding's declared sampling region; bindings declared `.perSite`
    /// require it.
    @ViewBuilder
    func shaderEffect(
        _ binding: ShaderBinding.Distortion,
        _ arguments: Shader.Argument...,
        maxSampleOffset: CGSize? = nil
    ) -> some View {
        if binding.needsProxy(override: maxSampleOffset) {
            visualEffect { view, proxy in
                view.distortionEffect(
                    binding.makeShader(arguments: arguments, proxySize: proxy.size),
                    maxSampleOffset: binding.sampleOffset(override: maxSampleOffset, proxySize: proxy.size)
                )
            }
        } else {
            distortionEffect(
                binding.makeShader(arguments: arguments, proxySize: .zero),
                maxSampleOffset: binding.sampleOffset(override: maxSampleOffset, proxySize: .zero)
            )
        }
    }

    /// Applies a layer-effect binding. `maxSampleOffset` overrides the
    /// binding's declared sampling region; bindings declared `.perSite`
    /// require it.
    @ViewBuilder
    func shaderEffect(
        _ binding: ShaderBinding.Layer,
        _ arguments: Shader.Argument...,
        maxSampleOffset: CGSize? = nil
    ) -> some View {
        if binding.needsProxy(override: maxSampleOffset) {
            visualEffect { view, proxy in
                view.layerEffect(
                    binding.makeShader(arguments: arguments, proxySize: proxy.size),
                    maxSampleOffset: binding.sampleOffset(override: maxSampleOffset, proxySize: proxy.size)
                )
            }
        } else {
            layerEffect(
                binding.makeShader(arguments: arguments, proxySize: .zero),
                maxSampleOffset: binding.sampleOffset(override: maxSampleOffset, proxySize: .zero)
            )
        }
    }
}
