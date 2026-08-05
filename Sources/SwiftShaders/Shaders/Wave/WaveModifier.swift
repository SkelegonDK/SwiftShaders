import SwiftUI

// MARK: - Bindings

/// The binding contracts for this family's stitchable functions.
enum WaveShaderBindings: ShaderFamily {
    /// `float2 jellyWave(float2,float4,float,float,float,float)`
    static let jellyWave = ShaderBinding.Distortion("jellyWave", geometry: .boundingRect, sampling: .fixed(width: 40, height: 40))
    /// `float2 liquidWave(float2,float4,float,float,float,float)`
    static let liquidWave = ShaderBinding.Distortion("liquidWave", geometry: .boundingRect, sampling: .fixed(width: 30, height: 30))
    /// `float2 waveFlag(float2,float4,float,float,float,float)`
    static let waveFlag = ShaderBinding.Distortion("waveFlag", geometry: .boundingRect, sampling: .fixed(width: 10, height: 60))
    /// `float2 radialWave(float2,float4,float,float,float,float,float)`
    static let radialWave = ShaderBinding.Distortion("radialWave", geometry: .boundingRect, sampling: .fixed(width: 50, height: 50))
    /// `float2 multiWave(float2,float4,float,float,float,float,float,float)`
    static let multiWave = ShaderBinding.Distortion("multiWave", geometry: .boundingRect, sampling: .fixed(width: 40, height: 40))
    /// `float2 wave(float2,float4,float,float,float,float)`
    static let wave = ShaderBinding.Distortion("wave", geometry: .boundingRect, sampling: .fixed(width: 30, height: 30))

    static var bindings: [any AnyShaderBinding] {
        [jellyWave, liquidWave, waveFlag, radialWave, multiWave, wave]
    }
}

// MARK: - WaveModifier

/// A view modifier that applies wave distortion effects.
///
/// Creates smooth, periodic wave patterns that can animate horizontally
/// or vertically through the view.
///
/// ## Overview
///
/// ```swift
/// Image("photo")
///     .modifier(WaveModifier(
///         time: animationTime,
///         amplitude: 0.02,
///         frequency: 10.0,
///         direction: 0.0
///     ))
/// ```
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct WaveModifier: ViewModifier {
    
    // MARK: - Properties
    
    /// Animation time.
    public var time: Double
    
    /// Wave height/strength.
    public var amplitude: Double
    
    /// Number of wave cycles.
    public var frequency: Double
    
    /// Wave direction (0 = horizontal, 1 = vertical).
    public var direction: Double
    
    // MARK: - Initialization
    
    /// Creates a wave modifier.
    /// - Parameters:
    ///   - time: Animation time.
    ///   - amplitude: Wave strength (default: 0.02).
    ///   - frequency: Wave frequency (default: 10.0).
    ///   - direction: 0 for horizontal, 1 for vertical (default: 0).
    public init(
        time: Double,
        amplitude: Double = 0.02,
        frequency: Double = 10.0,
        direction: Double = 0.0
    ) {
        self.time = time
        self.amplitude = amplitude
        self.frequency = frequency
        self.direction = direction
    }
    
    // MARK: - Body
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            WaveShaderBindings.wave,
            .float(time),
            .float(amplitude),
            .float(frequency),
            .float(direction)
        )
    }
}

// MARK: - MultiWaveModifier

/// Combines horizontal and vertical waves.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct MultiWaveModifier: ViewModifier {
    
    public var time: Double
    public var amplitudeX: Double
    public var amplitudeY: Double
    public var frequencyX: Double
    public var frequencyY: Double
    public var speed: Double
    
    /// Creates a multi-wave modifier.
    public init(
        time: Double,
        amplitudeX: Double = 0.02,
        amplitudeY: Double = 0.02,
        frequencyX: Double = 8.0,
        frequencyY: Double = 6.0,
        speed: Double = 3.0
    ) {
        self.time = time
        self.amplitudeX = amplitudeX
        self.amplitudeY = amplitudeY
        self.frequencyX = frequencyX
        self.frequencyY = frequencyY
        self.speed = speed
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            WaveShaderBindings.multiWave,
            .float(time),
            .float(amplitudeX),
            .float(amplitudeY),
            .float(frequencyX),
            .float(frequencyY),
            .float(speed)
        )
    }
}

// MARK: - RadialWaveModifier

/// Creates circular waves from a center point.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct RadialWaveModifier: ViewModifier {
    
    public var time: Double
    public var amplitude: Double
    public var frequency: Double
    public var center: CGPoint
    
    /// Creates a radial wave modifier.
    public init(
        time: Double,
        amplitude: Double = 0.5,
        frequency: Double = 1.0,
        center: CGPoint = CGPoint(x: 0.5, y: 0.5)
    ) {
        self.time = time
        self.amplitude = amplitude
        self.frequency = frequency
        self.center = center
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            WaveShaderBindings.radialWave,
            .float(time),
            .float(amplitude),
            .float(frequency),
            .float(center.x),
            .float(center.y)
        )
    }
}

// MARK: - WaveFlagModifier

/// Simulates flag/cloth waving in wind.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct WaveFlagModifier: ViewModifier {
    
    public var time: Double
    public var amplitude: Double
    public var frequency: Double
    public var windSpeed: Double
    
    /// Creates a flag wave modifier.
    public init(
        time: Double,
        amplitude: Double = 0.03,
        frequency: Double = 2.0,
        windSpeed: Double = 5.0
    ) {
        self.time = time
        self.amplitude = amplitude
        self.frequency = frequency
        self.windSpeed = windSpeed
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            WaveShaderBindings.waveFlag,
            .float(time),
            .float(amplitude),
            .float(frequency),
            .float(windSpeed)
        )
    }
}

// MARK: - LiquidWaveModifier

/// Simulates liquid surface distortion.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct LiquidWaveModifier: ViewModifier {
    
    public var time: Double
    public var amplitude: Double
    public var turbulence: Double
    public var viscosity: Double
    
    /// Creates a liquid wave modifier.
    public init(
        time: Double,
        amplitude: Double = 0.3,
        turbulence: Double = 0.1,
        viscosity: Double = 0.5
    ) {
        self.time = time
        self.amplitude = amplitude
        self.turbulence = turbulence
        self.viscosity = viscosity
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            WaveShaderBindings.liquidWave,
            .float(time),
            .float(amplitude),
            .float(turbulence),
            .float(viscosity)
        )
    }
}

// MARK: - JellyWaveModifier

/// Creates jelly/gelatin wobble effect.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct JellyWaveModifier: ViewModifier {
    
    public var time: Double
    public var amplitude: Double
    public var stiffness: Double
    public var damping: Double
    
    /// Creates a jelly wave modifier.
    public init(
        time: Double,
        amplitude: Double = 0.1,
        stiffness: Double = 2.0,
        damping: Double = 0.5
    ) {
        self.time = time
        self.amplitude = amplitude
        self.stiffness = stiffness
        self.damping = damping
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            WaveShaderBindings.jellyWave,
            .float(time),
            .float(amplitude),
            .float(stiffness),
            .float(damping)
        )
    }
}

// MARK: - View Extension

@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public extension View {

    /// Applies a wave distortion to the view.
    /// - Parameters:
    ///   - time: Animation time for the wave.
    ///   - amplitude: Height of the waves.
    ///   - frequency: Number of waves.
    ///   - direction: Wave direction (0 = horizontal, 1 = vertical).
    /// - Returns: A view with wave distortion applied.
    func waveEffect(
        time: Double,
        amplitude: Double = 0.02,
        frequency: Double = 10.0,
        direction: Double = 0.0
    ) -> some View {
        modifier(WaveModifier(time: time, amplitude: amplitude, frequency: frequency, direction: direction))
    }

    /// Applies multi-directional wave effect.
    func multiWave(
        time: Double,
        amplitudeX: Double = 0.02,
        amplitudeY: Double = 0.02,
        frequencyX: Double = 8.0,
        frequencyY: Double = 6.0,
        speed: Double = 3.0
    ) -> some View {
        modifier(MultiWaveModifier(
            time: time,
            amplitudeX: amplitudeX,
            amplitudeY: amplitudeY,
            frequencyX: frequencyX,
            frequencyY: frequencyY,
            speed: speed
        ))
    }
    
    /// Applies radial wave effect.
    func radialWave(
        time: Double,
        amplitude: Double = 0.5,
        frequency: Double = 1.0,
        center: CGPoint = CGPoint(x: 0.5, y: 0.5)
    ) -> some View {
        modifier(RadialWaveModifier(
            time: time,
            amplitude: amplitude,
            frequency: frequency,
            center: center
        ))
    }
    
    /// Applies the wind-driven flag wave effect.
    ///
    /// Named `waveFlag` rather than `flagWave` so it does not collide with
    /// `Displacement`'s `flagWave(time:amplitude:frequency:propagation:)`,
    /// which differs only in its final defaulted argument.
    func waveFlag(
        time: Double,
        amplitude: Double = 0.03,
        frequency: Double = 2.0,
        windSpeed: Double = 5.0
    ) -> some View {
        modifier(WaveFlagModifier(
            time: time,
            amplitude: amplitude,
            frequency: frequency,
            windSpeed: windSpeed
        ))
    }
    
    /// Applies liquid wave effect.
    func liquidWave(
        time: Double,
        amplitude: Double = 0.3,
        turbulence: Double = 0.1,
        viscosity: Double = 0.5
    ) -> some View {
        modifier(LiquidWaveModifier(
            time: time,
            amplitude: amplitude,
            turbulence: turbulence,
            viscosity: viscosity
        ))
    }
    
    /// Applies jelly wobble effect.
    func jellyWave(
        time: Double,
        amplitude: Double = 0.1,
        stiffness: Double = 2.0,
        damping: Double = 0.5
    ) -> some View {
        modifier(JellyWaveModifier(
            time: time,
            amplitude: amplitude,
            stiffness: stiffness,
            damping: damping
        ))
    }
}
