import SwiftUI

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
        content.colorEffect(
            ShaderLibrary.swiftShaders.noise(
                .float(time),
                .float(intensity),
                .float(scale)
            )
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
        content.colorEffect(
            ShaderLibrary.swiftShaders.filmGrain(
                .float(time),
                .float(intensity),
                .float(size)
            )
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
        content.distortionEffect(
            ShaderLibrary.swiftShaders.perlinDistort(
                .float(time),
                .float(intensity),
                .float(scale)
            ),
            maxSampleOffset: CGSize(width: 50, height: 50)
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
        content.colorEffect(
            ShaderLibrary.swiftShaders.fbmNoise(
                .float(time),
                .float(scale),
                .float(octaves),
                .float(lacunarity),
                .float(gain)
            )
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
        content.colorEffect(
            ShaderLibrary.swiftShaders.noiseVoronoi(
                .float(time),
                .float(scale),
                .float(intensity)
            )
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
        content.distortionEffect(
            ShaderLibrary.swiftShaders.turbulence(
                .float(time),
                .float(intensity),
                .float(scale),
                .float(octaves)
            ),
            maxSampleOffset: CGSize(width: 60, height: 60)
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
    
    /// Applies Voronoi noise.
    func voronoiNoise(
        time: Double,
        scale: Double = 10.0,
        intensity: Double = 1.0
    ) -> some View {
        modifier(NoiseVoronoiModifier(time: time, scale: scale, intensity: intensity))
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
