import SwiftUI

// MARK: - Bindings

/// The binding contracts for this family's stitchable functions.
enum NoiseShaderBindings: ShaderFamily {
    /// `float2 turbulence(float2,float4,float,float,float,float)`
    static let turbulence = ShaderBinding.Distortion("turbulence", geometry: .boundingRect, sampling: .fixed(width: 60, height: 60))
    /// `half4 noiseVoronoi(float2,half4,float4,float,float,float)`
    static let noiseVoronoi = ShaderBinding.Color("noiseVoronoi", geometry: .boundingRect)
    /// `half4 fbmNoise(float2,half4,float4,float,float,float,float,float)`
    static let fbmNoise = ShaderBinding.Color("fbmNoise", geometry: .boundingRect)
    /// `float2 perlinDistort(float2,float4,float,float,float)`
    static let perlinDistort = ShaderBinding.Distortion("perlinDistort", geometry: .boundingRect, sampling: .fixed(width: 50, height: 50))
    /// `half4 filmGrain(float2,half4,float4,float,float,float)`
    static let filmGrain = ShaderBinding.Color("filmGrain", geometry: .boundingRect)
    /// `half4 noise(float2,half4,float4,float,float,float)`
    static let noise = ShaderBinding.Color("noise", geometry: .boundingRect)

    static var bindings: [any AnyShaderBinding] {
        [turbulence, noiseVoronoi, fbmNoise, perlinDistort, filmGrain, noise]
    }
}

// MARK: - NoiseModifier

/// A view modifier that applies procedural noise effects.
///
/// Adds various types of noise to create texture, grain, or distortion effects.
///
/// ## Overview
///
/// ```swift
/// Image("photo")
///     .modifier(NoiseModifier(
///         time: animationTime,
///         intensity: 0.1,
///         scale: 5.0
///     ))
/// ```
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct NoiseModifier: ViewModifier {
    
    // MARK: - Properties
    
    /// Animation time for animated noise.
    public var time: Double
    
    /// Noise intensity.
    public var intensity: Double
    
    /// Noise scale/frequency.
    public var scale: Double
    
    // MARK: - Initialization
    
    /// Creates a noise modifier.
    /// - Parameters:
    ///   - time: Animation time.
    ///   - intensity: Noise strength (default: 0.1).
    ///   - scale: Noise scale (default: 5.0).
    public init(
        time: Double,
        intensity: Double = 0.1,
        scale: Double = 5.0
    ) {
        self.time = time
        self.intensity = intensity
        self.scale = scale
    }
    
    // MARK: - Body
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            NoiseShaderBindings.noise,
            .float(time),
            .float(intensity),
            .float(scale)
        )
    }
}

// MARK: - FilmGrainModifier

/// Applies cinematic film grain effect.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct FilmGrainModifier: ViewModifier {
    
    public var time: Double
    public var intensity: Double
    public var size: Double
    
    /// Creates a film grain modifier.
    /// - Parameters:
    ///   - time: Animation time.
    ///   - intensity: Grain strength.
    ///   - size: Grain size.
    public init(
        time: Double,
        intensity: Double = 0.15,
        size: Double = 500.0
    ) {
        self.time = time
        self.intensity = intensity
        self.size = size
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            NoiseShaderBindings.filmGrain,
            .float(time),
            .float(intensity),
            .float(size)
        )
    }
}

// MARK: - PerlinDistortModifier

/// Applies Perlin noise-based distortion.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct PerlinDistortModifier: ViewModifier {
    
    public var time: Double
    public var intensity: Double
    public var scale: Double
    
    /// Creates a Perlin distortion modifier.
    public init(
        time: Double,
        intensity: Double = 0.5,
        scale: Double = 3.0
    ) {
        self.time = time
        self.intensity = intensity
        self.scale = scale
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            NoiseShaderBindings.perlinDistort,
            .float(time),
            .float(intensity),
            .float(scale)
        )
    }
}

// MARK: - FBMNoiseModifier

/// Applies fractal Brownian motion noise.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct FBMNoiseModifier: ViewModifier {
    
    public var time: Double
    public var scale: Double
    public var octaves: Double
    public var lacunarity: Double
    public var gain: Double
    
    /// Creates an FBM noise modifier.
    public init(
        time: Double,
        scale: Double = 5.0,
        octaves: Double = 6.0,
        lacunarity: Double = 2.0,
        gain: Double = 0.5
    ) {
        self.time = time
        self.scale = scale
        self.octaves = octaves
        self.lacunarity = lacunarity
        self.gain = gain
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            NoiseShaderBindings.fbmNoise,
            .float(time),
            .float(scale),
            .float(octaves),
            .float(lacunarity),
            .float(gain)
        )
    }
}

// MARK: - NoiseVoronoiModifier

/// Applies Voronoi/cellular noise pattern.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct NoiseVoronoiModifier: ViewModifier {
    
    public var time: Double
    public var scale: Double
    public var intensity: Double
    
    /// Creates a Voronoi noise modifier.
    public init(
        time: Double,
        scale: Double = 10.0,
        intensity: Double = 1.0
    ) {
        self.time = time
        self.scale = scale
        self.intensity = intensity
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            NoiseShaderBindings.noiseVoronoi,
            .float(time),
            .float(scale),
            .float(intensity)
        )
    }
}

// MARK: - TurbulenceModifier

/// Applies turbulence distortion effect.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct TurbulenceModifier: ViewModifier {
    
    public var time: Double
    public var intensity: Double
    public var scale: Double
    public var octaves: Double
    
    /// Creates a turbulence modifier.
    public init(
        time: Double,
        intensity: Double = 1.0,
        scale: Double = 3.0,
        octaves: Double = 4.0
    ) {
        self.time = time
        self.intensity = intensity
        self.scale = scale
        self.octaves = octaves
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            NoiseShaderBindings.turbulence,
            .float(time),
            .float(intensity),
            .float(scale),
            .float(octaves)
        )
    }
}

// MARK: - View Extension

@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public extension View {
    
    /// Applies noise effect.
    func noiseEffect(
        time: Double,
        intensity: Double = 0.1,
        scale: Double = 5.0
    ) -> some View {
        modifier(NoiseModifier(time: time, intensity: intensity, scale: scale))
    }
    
    /// Applies film grain effect.
    func filmGrain(
        time: Double,
        intensity: Double = 0.15,
        size: Double = 500.0
    ) -> some View {
        modifier(FilmGrainModifier(time: time, intensity: intensity, size: size))
    }
    
    /// Applies Perlin distortion.
    func perlinDistort(
        time: Double,
        intensity: Double = 0.5,
        scale: Double = 3.0
    ) -> some View {
        modifier(PerlinDistortModifier(time: time, intensity: intensity, scale: scale))
    }
    
    /// Applies FBM noise.
    func fbmNoise(
        time: Double,
        scale: Double = 5.0,
        octaves: Double = 6.0,
        lacunarity: Double = 2.0,
        gain: Double = 0.5
    ) -> some View {
        modifier(FBMNoiseModifier(
            time: time,
            scale: scale,
            octaves: octaves,
            lacunarity: lacunarity,
            gain: gain
        ))
    }
    
    /// Darkens the view with a cellular (Worley) noise field.
    ///
    /// The shader computes the distance to the nearest of nine jittered cell
    /// points and multiplies the existing colour by `1 - distance * intensity`,
    /// so the content shows through, shaded cell by cell. It is *not* the
    /// Voronoi module's `voronoiNoise(time:scale:jitter:edgeWidth:)`, which draws
    /// cell edges from an F2−F1 difference and takes no `intensity`.
    ///
    /// - Parameters:
    ///   - time: Animation time; drifts the cell points.
    ///   - scale: Cell density — higher means more, smaller cells.
    ///   - intensity: How dark the cell shading gets.
    /// - Returns: A view shaded by cellular noise.
    func cellularNoise(
        time: Double,
        scale: Double = 10.0,
        intensity: Double = 1.0
    ) -> some View {
        modifier(NoiseVoronoiModifier(time: time, scale: scale, intensity: intensity))
    }

    /// - Warning: Renamed to ``cellularNoise(time:scale:intensity:)`` in 2.0.0.
    ///
    /// This name was declared twice, in two different files, bound to two
    /// different Metal functions. Both spellings accepted `(time:)` and
    /// `(time:scale:)`, and Swift's fewest-defaults tiebreaker silently resolved
    /// those to *this* one — so a caller asking for Voronoi cells got cellular
    /// shading instead, with no diagnostic. The shim keeps the old call
    /// compiling; it deliberately declares no default values, so the shortened
    /// forms now go to `Voronoi`'s `voronoiNoise` where they always read as if
    /// they did.
    @available(*, deprecated, renamed: "cellularNoise(time:scale:intensity:)")
    func voronoiNoise(
        time: Double,
        scale: Double,
        intensity: Double
    ) -> some View {
        cellularNoise(time: time, scale: scale, intensity: intensity)
    }
    
    /// Applies turbulence distortion.
    func turbulence(
        time: Double,
        intensity: Double = 1.0,
        scale: Double = 3.0,
        octaves: Double = 4.0
    ) -> some View {
        modifier(TurbulenceModifier(
            time: time,
            intensity: intensity,
            scale: scale,
            octaves: octaves
        ))
    }
}
