// swiftlint:disable file_length — one file per shader family; this family has 21 effects
import SwiftUI

// MARK: - Bindings

/// The binding contracts for this family's stitchable functions.
enum DisplacementShaderBindings: ShaderFamily {
    /// `float2 magneticDisplacement(float2,float4,float,float,float,float)`
    static let magneticDisplacement = ShaderBinding.Distortion("magneticDisplacement", geometry: .boundingRect, sampling: .fixed(width: 50, height: 50))
    /// `float2 earthquakeDisplacement(float2,float4,float,float,float,float)`
    static let earthquakeDisplacement = ShaderBinding.Distortion("earthquakeDisplacement", geometry: .boundingRect, sampling: .fixed(width: 30, height: 30))
    /// `float2 windDisplacement(float2,float4,float,float,float,float)`
    static let windDisplacement = ShaderBinding.Distortion("windDisplacement", geometry: .boundingRect, sampling: .fixed(width: 40, height: 40))
    /// `float2 scanlineJitter(float2,float4,float,float,float,float)`
    static let scanlineJitter = ShaderBinding.Distortion("scanlineJitter", geometry: .boundingRect, sampling: .fixed(width: 50, height: 5))
    /// `float2 blockDisplacement(float2,float4,float,float,float,float)`
    static let blockDisplacement = ShaderBinding.Distortion("blockDisplacement", geometry: .boundingRect, sampling: .fixed(width: 50, height: 50))
    /// `float2 breathingDisplacement(float2,float4,float,float,float,float,float)`
    static let breathingDisplacement = ShaderBinding.Distortion("breathingDisplacement", geometry: .boundingRect, sampling: .fixed(width: 50, height: 50))
    /// `float2 blobDisplacement(float2,float4,float,float,float,float)`
    static let blobDisplacement = ShaderBinding.Distortion("blobDisplacement", geometry: .boundingRect, sampling: .fixed(width: 60, height: 60))
    /// `float2 zigzag(float2,float4,float,float,float,float)`
    static let zigzag = ShaderBinding.Distortion("zigzag", geometry: .boundingRect, sampling: .fixed(width: 50, height: 50))
    /// `float2 pinch(float2,float4,float,float,float,float,float)`
    static let pinch = ShaderBinding.Distortion("pinch", geometry: .boundingRect, sampling: .fixed(width: 100, height: 100))
    /// `float2 twirl(float2,float4,float,float,float,float,float)`
    static let twirl = ShaderBinding.Distortion("twirl", geometry: .boundingRect, sampling: .fixed(width: 100, height: 100))
    /// `float2 spherize(float2,float4,float,float,float,float,float)`
    static let spherize = ShaderBinding.Distortion("spherize", geometry: .boundingRect, sampling: .fixed(width: 100, height: 100))
    /// `float2 flagWave(float2,float4,float,float,float,float)`
    static let flagWave = ShaderBinding.Distortion("flagWave", geometry: .boundingRect, sampling: .fixed(width: 30, height: 80))
    /// `float2 lensDistortion(float2,float4,float,float,float,float,float)`
    static let lensDistortion = ShaderBinding.Distortion("lensDistortion", geometry: .boundingRect, sampling: .fixed(width: 100, height: 100))
    /// `float2 shockwaveDisplacement(float2,float4,float,float,float,float,float)`
    static let shockwaveDisplacement = ShaderBinding.Distortion("shockwaveDisplacement", geometry: .boundingRect, sampling: .fixed(width: 50, height: 50))
    /// `float2 underwaterDisplacement(float2,float4,float,float,float,float)`
    static let underwaterDisplacement = ShaderBinding.Distortion("underwaterDisplacement", geometry: .boundingRect, sampling: .fixed(width: 30, height: 30))
    /// `float2 heatDistortion(float2,float4,float,float,float,float)`
    static let heatDistortion = ShaderBinding.Distortion("heatDistortion", geometry: .boundingRect, sampling: .fixed(width: 30, height: 5))
    /// `float2 spiralDisplacement(float2,float4,float,float,float,float,float)`
    static let spiralDisplacement = ShaderBinding.Distortion("spiralDisplacement", geometry: .boundingRect, sampling: .fixed(width: 100, height: 100))
    /// `float2 radialDisplacement(float2,float4,float,float,float,float,float)`
    static let radialDisplacement = ShaderBinding.Distortion("radialDisplacement", geometry: .boundingRect, sampling: .fixed(width: 50, height: 50))
    /// `float2 fbmDisplacement(float2,float4,float,float,float,float)`
    static let fbmDisplacement = ShaderBinding.Distortion("fbmDisplacement", geometry: .boundingRect, sampling: .fixed(width: 60, height: 60))
    /// `float2 noiseDisplacement(float2,float4,float,float,float,float)`
    static let noiseDisplacement = ShaderBinding.Distortion("noiseDisplacement", geometry: .boundingRect, sampling: .fixed(width: 50, height: 50))
    /// `float2 sineDisplacement(float2,float4,float,float,float,float,float)`
    static let sineDisplacement = ShaderBinding.Distortion("sineDisplacement", geometry: .boundingRect, sampling: .fixed(width: 50, height: 50))

    static var bindings: [any AnyShaderBinding] {
        [
            magneticDisplacement,
            earthquakeDisplacement,
            windDisplacement,
            scanlineJitter,
            blockDisplacement,
            breathingDisplacement,
            blobDisplacement,
            zigzag,
            pinch,
            twirl,
            spherize,
            flagWave,
            lensDistortion,
            shockwaveDisplacement,
            underwaterDisplacement,
            heatDistortion,
            spiralDisplacement,
            radialDisplacement,
            fbmDisplacement,
            noiseDisplacement,
            sineDisplacement,
        ]
    }
}

// MARK: - SineDisplacementModifier

/// A view modifier that applies sine wave displacement.
///
/// Creates smooth, wave-like distortions using sine functions
/// for both horizontal and vertical displacement.
///
/// ## Overview
///
/// ```swift
/// Image("photo")
///     .modifier(SineDisplacementModifier(
///         time: animationTime,
///         amplitudeX: 0.02,
///         amplitudeY: 0.01,
///         frequencyX: 3.0,
///         frequencyY: 2.0
///     ))
/// ```
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct SineDisplacementModifier: ViewModifier {
    
    // MARK: - Properties
    
    /// Animation time.
    public var time: Double
    
    /// Horizontal wave amplitude.
    public var amplitudeX: Double
    
    /// Vertical wave amplitude.
    public var amplitudeY: Double
    
    /// Horizontal wave frequency.
    public var frequencyX: Double
    
    /// Vertical wave frequency.
    public var frequencyY: Double
    
    // MARK: - Initialization
    
    /// Creates a sine displacement modifier.
    /// - Parameters:
    ///   - time: Animation time.
    ///   - amplitudeX: Horizontal amplitude (default: 0.02).
    ///   - amplitudeY: Vertical amplitude (default: 0.01).
    ///   - frequencyX: Horizontal frequency (default: 3.0).
    ///   - frequencyY: Vertical frequency (default: 2.0).
    public init(
        time: Double,
        amplitudeX: Double = 0.02,
        amplitudeY: Double = 0.01,
        frequencyX: Double = 3.0,
        frequencyY: Double = 2.0
    ) {
        self.time = time
        self.amplitudeX = amplitudeX
        self.amplitudeY = amplitudeY
        self.frequencyX = frequencyX
        self.frequencyY = frequencyY
    }
    
    // MARK: - Body
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            DisplacementShaderBindings.sineDisplacement,
            .float(time),
            .float(amplitudeX),
            .float(amplitudeY),
            .float(frequencyX),
            .float(frequencyY)
        )
    }
}

// MARK: - NoiseDisplacementModifier

/// Applies noise-based displacement for organic distortion.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct NoiseDisplacementModifier: ViewModifier {
    
    public var time: Double
    public var scale: Double
    public var amount: Double
    public var speed: Double
    
    /// Creates a noise displacement modifier.
    /// - Parameters:
    ///   - time: Animation time.
    ///   - scale: Noise scale.
    ///   - amount: Displacement amount.
    ///   - speed: Animation speed.
    public init(
        time: Double,
        scale: Double = 5.0,
        amount: Double = 0.05,
        speed: Double = 0.3
    ) {
        self.time = time
        self.scale = scale
        self.amount = amount
        self.speed = speed
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            DisplacementShaderBindings.noiseDisplacement,
            .float(time),
            .float(scale),
            .float(amount),
            .float(speed)
        )
    }
}

// MARK: - FBMDisplacementModifier

/// Applies Fractal Brownian Motion displacement for complex patterns.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct FBMDisplacementModifier: ViewModifier {
    
    public var time: Double
    public var scale: Double
    public var amount: Double
    public var octaves: Int
    
    /// Creates an FBM displacement modifier.
    /// - Parameters:
    ///   - time: Animation time.
    ///   - scale: Noise scale.
    ///   - amount: Displacement amount.
    ///   - octaves: Number of noise octaves (1-8).
    public init(
        time: Double,
        scale: Double = 3.0,
        amount: Double = 0.05,
        octaves: Int = 4
    ) {
        self.time = time
        self.scale = scale
        self.amount = amount
        self.octaves = octaves
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            DisplacementShaderBindings.fbmDisplacement,
            .float(time),
            .float(scale),
            .float(amount),
            .float(Double(octaves))
        )
    }
}

// MARK: - RadialDisplacementModifier

/// Applies radial wave displacement from a center point.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct RadialDisplacementModifier: ViewModifier {
    
    public var time: Double
    public var amount: Double
    public var frequency: Double
    public var center: CGPoint
    
    /// Creates a radial displacement modifier.
    /// - Parameters:
    ///   - time: Animation time.
    ///   - amount: Wave amplitude.
    ///   - frequency: Wave frequency.
    ///   - center: Center point (normalized 0-1).
    public init(
        time: Double,
        amount: Double = 0.03,
        frequency: Double = 2.0,
        center: CGPoint = CGPoint(x: 0.5, y: 0.5)
    ) {
        self.time = time
        self.amount = amount
        self.frequency = frequency
        self.center = center
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            DisplacementShaderBindings.radialDisplacement,
            .float(time),
            .float(amount),
            .float(frequency),
            .float(center.x),
            .float(center.y)
        )
    }
}

// MARK: - SpiralDisplacementModifier

/// Applies spiral displacement around a center point.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct SpiralDisplacementModifier: ViewModifier {
    
    public var time: Double
    public var amount: Double
    public var tightness: Double
    public var center: CGPoint
    
    /// Creates a spiral displacement modifier.
    /// - Parameters:
    ///   - time: Animation time.
    ///   - amount: Spiral intensity.
    ///   - tightness: How tight the spiral is.
    ///   - center: Spiral center (normalized 0-1).
    public init(
        time: Double,
        amount: Double = 0.5,
        tightness: Double = 1.0,
        center: CGPoint = CGPoint(x: 0.5, y: 0.5)
    ) {
        self.time = time
        self.amount = amount
        self.tightness = tightness
        self.center = center
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            DisplacementShaderBindings.spiralDisplacement,
            .float(time),
            .float(amount),
            .float(tightness),
            .float(center.x),
            .float(center.y)
        )
    }
}

// MARK: - HeatDistortionModifier

/// Creates a heat shimmer/mirage effect.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct HeatDistortionModifier: ViewModifier {
    
    public var time: Double
    public var intensity: Double
    public var riseFactor: Double
    public var turbulence: Double
    
    /// Creates a heat distortion modifier.
    /// - Parameters:
    ///   - time: Animation time.
    ///   - intensity: Distortion intensity.
    ///   - riseFactor: How fast heat rises.
    ///   - turbulence: Turbulence amount.
    public init(
        time: Double,
        intensity: Double = 1.0,
        riseFactor: Double = 0.5,
        turbulence: Double = 3.0
    ) {
        self.time = time
        self.intensity = intensity
        self.riseFactor = riseFactor
        self.turbulence = turbulence
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            DisplacementShaderBindings.heatDistortion,
            .float(time),
            .float(intensity),
            .float(riseFactor),
            .float(turbulence)
        )
    }
}

// MARK: - UnderwaterDisplacementModifier

/// Creates an underwater caustic distortion effect.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct UnderwaterDisplacementModifier: ViewModifier {
    
    public var time: Double
    public var waveScale: Double
    public var waveAmount: Double
    public var depthFactor: Double
    
    /// Creates an underwater displacement modifier.
    /// - Parameters:
    ///   - time: Animation time.
    ///   - waveScale: Wave pattern scale.
    ///   - waveAmount: Distortion amount.
    ///   - depthFactor: Depth influence.
    public init(
        time: Double,
        waveScale: Double = 1.0,
        waveAmount: Double = 1.0,
        depthFactor: Double = 1.0
    ) {
        self.time = time
        self.waveScale = waveScale
        self.waveAmount = waveAmount
        self.depthFactor = depthFactor
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            DisplacementShaderBindings.underwaterDisplacement,
            .float(time),
            .float(waveScale),
            .float(waveAmount),
            .float(depthFactor)
        )
    }
}

// MARK: - ShockwaveDisplacementModifier

/// Creates an expanding shockwave distortion.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct ShockwaveDisplacementModifier: ViewModifier {
    
    public var time: Double
    public var center: CGPoint
    public var waveWidth: Double
    public var amplitude: Double
    
    /// Creates a shockwave displacement modifier.
    /// - Parameters:
    ///   - time: Animation time.
    ///   - center: Shockwave origin (normalized 0-1).
    ///   - waveWidth: Width of the wave ring.
    ///   - amplitude: Wave amplitude.
    public init(
        time: Double,
        center: CGPoint = CGPoint(x: 0.5, y: 0.5),
        waveWidth: Double = 0.1,
        amplitude: Double = 0.05
    ) {
        self.time = time
        self.center = center
        self.waveWidth = waveWidth
        self.amplitude = amplitude
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            DisplacementShaderBindings.shockwaveDisplacement,
            .float(time),
            .float(center.x),
            .float(center.y),
            .float(waveWidth),
            .float(amplitude)
        )
    }
}

// MARK: - LensDistortionModifier

/// Applies lens barrel/pincushion distortion.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct LensDistortionModifier: ViewModifier {
    
    public var time: Double
    public var k1: Double
    public var k2: Double
    public var center: CGPoint
    
    /// Creates a lens distortion modifier.
    /// - Parameters:
    ///   - time: Animation time.
    ///   - k1: First distortion coefficient (positive = barrel, negative = pincushion).
    ///   - k2: Second distortion coefficient.
    ///   - center: Distortion center (normalized 0-1).
    public init(
        time: Double,
        k1: Double = 0.3,
        k2: Double = 0.0,
        center: CGPoint = CGPoint(x: 0.5, y: 0.5)
    ) {
        self.time = time
        self.k1 = k1
        self.k2 = k2
        self.center = center
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            DisplacementShaderBindings.lensDistortion,
            .float(time),
            .float(k1),
            .float(k2),
            .float(center.x),
            .float(center.y)
        )
    }
}

// MARK: - FlagWaveModifier

/// Creates a waving flag effect.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct FlagWaveModifier: ViewModifier {
    
    public var time: Double
    public var amplitude: Double
    public var frequency: Double
    public var propagation: Double
    
    /// Creates a flag wave modifier.
    /// - Parameters:
    ///   - time: Animation time.
    ///   - amplitude: Wave amplitude.
    ///   - frequency: Wave frequency.
    ///   - propagation: Wave propagation speed.
    public init(
        time: Double,
        amplitude: Double = 0.5,
        frequency: Double = 3.0,
        propagation: Double = 5.0
    ) {
        self.time = time
        self.amplitude = amplitude
        self.frequency = frequency
        self.propagation = propagation
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            DisplacementShaderBindings.flagWave,
            .float(time),
            .float(amplitude),
            .float(frequency),
            .float(propagation)
        )
    }
}

// MARK: - SpherizeModifier

/// Creates a spherical bulge effect.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct SpherizeModifier: ViewModifier {
    
    public var time: Double
    public var amount: Double
    public var radius: Double
    public var center: CGPoint
    
    /// Creates a spherize modifier.
    /// - Parameters:
    ///   - time: Animation time.
    ///   - amount: Bulge amount.
    ///   - radius: Effect radius.
    ///   - center: Bulge center (normalized 0-1).
    public init(
        time: Double,
        amount: Double = 0.5,
        radius: Double = 0.5,
        center: CGPoint = CGPoint(x: 0.5, y: 0.5)
    ) {
        self.time = time
        self.amount = amount
        self.radius = radius
        self.center = center
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            DisplacementShaderBindings.spherize,
            .float(time),
            .float(amount),
            .float(radius),
            .float(center.x),
            .float(center.y)
        )
    }
}

// MARK: - TwirlModifier

/// Creates a twirl/twist effect.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct TwirlModifier: ViewModifier {
    
    public var time: Double
    public var angle: Double
    public var radius: Double
    public var center: CGPoint
    
    /// Creates a twirl modifier.
    /// - Parameters:
    ///   - time: Animation time.
    ///   - angle: Twist angle in radians.
    ///   - radius: Effect radius.
    ///   - center: Twirl center (normalized 0-1).
    public init(
        time: Double,
        angle: Double = 2.0,
        radius: Double = 0.5,
        center: CGPoint = CGPoint(x: 0.5, y: 0.5)
    ) {
        self.time = time
        self.angle = angle
        self.radius = radius
        self.center = center
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            DisplacementShaderBindings.twirl,
            .float(time),
            .float(angle),
            .float(radius),
            .float(center.x),
            .float(center.y)
        )
    }
}

// MARK: - PinchModifier

/// Creates a pinch effect toward a center point.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct PinchModifier: ViewModifier {
    
    public var time: Double
    public var amount: Double
    public var radius: Double
    public var center: CGPoint
    
    /// Creates a pinch modifier.
    /// - Parameters:
    ///   - time: Animation time.
    ///   - amount: Pinch strength.
    ///   - radius: Effect radius.
    ///   - center: Pinch center (normalized 0-1).
    public init(
        time: Double,
        amount: Double = 0.5,
        radius: Double = 0.5,
        center: CGPoint = CGPoint(x: 0.5, y: 0.5)
    ) {
        self.time = time
        self.amount = amount
        self.radius = radius
        self.center = center
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            DisplacementShaderBindings.pinch,
            .float(time),
            .float(amount),
            .float(radius),
            .float(center.x),
            .float(center.y)
        )
    }
}

// MARK: - ZigzagModifier

/// Creates a zigzag displacement pattern.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct ZigzagModifier: ViewModifier {
    
    public var time: Double
    public var amplitude: Double
    public var frequency: Double
    public var angle: Double
    
    /// Creates a zigzag modifier.
    /// - Parameters:
    ///   - time: Animation time.
    ///   - amplitude: Wave amplitude.
    ///   - frequency: Wave frequency.
    ///   - angle: Pattern angle in radians.
    public init(
        time: Double,
        amplitude: Double = 0.3,
        frequency: Double = 10.0,
        angle: Double = 0.0
    ) {
        self.time = time
        self.amplitude = amplitude
        self.frequency = frequency
        self.angle = angle
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            DisplacementShaderBindings.zigzag,
            .float(time),
            .float(amplitude),
            .float(frequency),
            .float(angle)
        )
    }
}

// MARK: - BlobDisplacementModifier

/// Creates organic blob-like displacement.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct BlobDisplacementModifier: ViewModifier {
    
    public var time: Double
    public var scale: Double
    public var amount: Double
    public var smoothness: Double
    
    /// Creates a blob displacement modifier.
    /// - Parameters:
    ///   - time: Animation time.
    ///   - scale: Pattern scale.
    ///   - amount: Displacement amount.
    ///   - smoothness: Smoothness factor.
    public init(
        time: Double,
        scale: Double = 3.0,
        amount: Double = 0.3,
        smoothness: Double = 0.8
    ) {
        self.time = time
        self.scale = scale
        self.amount = amount
        self.smoothness = smoothness
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            DisplacementShaderBindings.blobDisplacement,
            .float(time),
            .float(scale),
            .float(amount),
            .float(smoothness)
        )
    }
}

// MARK: - BreathingDisplacementModifier

/// Creates a breathing/pulsing expansion effect.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct BreathingDisplacementModifier: ViewModifier {
    
    public var time: Double
    public var amount: Double
    public var speed: Double
    public var center: CGPoint
    
    /// Creates a breathing displacement modifier.
    /// - Parameters:
    ///   - time: Animation time.
    ///   - amount: Expansion amount.
    ///   - speed: Breathing speed.
    ///   - center: Expansion center (normalized 0-1).
    public init(
        time: Double,
        amount: Double = 0.1,
        speed: Double = 1.5,
        center: CGPoint = CGPoint(x: 0.5, y: 0.5)
    ) {
        self.time = time
        self.amount = amount
        self.speed = speed
        self.center = center
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            DisplacementShaderBindings.breathingDisplacement,
            .float(time),
            .float(amount),
            .float(speed),
            .float(center.x),
            .float(center.y)
        )
    }
}

// MARK: - BlockDisplacementModifier

/// Creates digital block-based displacement glitch.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct BlockDisplacementModifier: ViewModifier {
    
    public var time: Double
    public var blockSize: Double
    public var amount: Double
    public var probability: Double
    
    /// Creates a block displacement modifier.
    /// - Parameters:
    ///   - time: Animation time.
    ///   - blockSize: Size of displacement blocks.
    ///   - amount: Displacement amount.
    ///   - probability: Probability of block displacement.
    public init(
        time: Double,
        blockSize: Double = 0.05,
        amount: Double = 0.5,
        probability: Double = 0.3
    ) {
        self.time = time
        self.blockSize = blockSize
        self.amount = amount
        self.probability = probability
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            DisplacementShaderBindings.blockDisplacement,
            .float(time),
            .float(blockSize),
            .float(amount),
            .float(probability)
        )
    }
}

// MARK: - ScanlineJitterModifier

/// Creates scanline-based horizontal jitter.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct ScanlineJitterModifier: ViewModifier {
    
    public var time: Double
    public var lineHeight: Double
    public var jitterAmount: Double
    public var probability: Double
    
    /// Creates a scanline jitter modifier.
    /// - Parameters:
    ///   - time: Animation time.
    ///   - lineHeight: Height of scan lines.
    ///   - jitterAmount: Jitter intensity.
    ///   - probability: Probability of jitter per line.
    public init(
        time: Double,
        lineHeight: Double = 0.01,
        jitterAmount: Double = 0.1,
        probability: Double = 0.2
    ) {
        self.time = time
        self.lineHeight = lineHeight
        self.jitterAmount = jitterAmount
        self.probability = probability
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            DisplacementShaderBindings.scanlineJitter,
            .float(time),
            .float(lineHeight),
            .float(jitterAmount),
            .float(probability)
        )
    }
}

// MARK: - WindDisplacementModifier

/// Creates a wind effect displacement.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct WindDisplacementModifier: ViewModifier {
    
    public var time: Double
    public var strength: Double
    public var gustiness: Double
    public var direction: Double
    
    /// Creates a wind displacement modifier.
    /// - Parameters:
    ///   - time: Animation time.
    ///   - strength: Wind strength.
    ///   - gustiness: Gust frequency.
    ///   - direction: Wind direction in radians.
    public init(
        time: Double,
        strength: Double = 0.5,
        gustiness: Double = 1.0,
        direction: Double = 0.0
    ) {
        self.time = time
        self.strength = strength
        self.gustiness = gustiness
        self.direction = direction
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            DisplacementShaderBindings.windDisplacement,
            .float(time),
            .float(strength),
            .float(gustiness),
            .float(direction)
        )
    }
}

// MARK: - EarthquakeDisplacementModifier

/// Creates an earthquake/shake effect.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct EarthquakeDisplacementModifier: ViewModifier {
    
    public var time: Double
    public var magnitude: Double
    public var frequency: Double
    public var decay: Double
    
    /// Creates an earthquake displacement modifier.
    /// - Parameters:
    ///   - time: Animation time.
    ///   - magnitude: Shake magnitude.
    ///   - frequency: Shake frequency.
    ///   - decay: Decay rate.
    public init(
        time: Double,
        magnitude: Double = 1.0,
        frequency: Double = 1.0,
        decay: Double = 0.5
    ) {
        self.time = time
        self.magnitude = magnitude
        self.frequency = frequency
        self.decay = decay
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            DisplacementShaderBindings.earthquakeDisplacement,
            .float(time),
            .float(magnitude),
            .float(frequency),
            .float(decay)
        )
    }
}

// MARK: - MagneticDisplacementModifier

/// Creates a magnetic field-like displacement.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct MagneticDisplacementModifier: ViewModifier {
    
    public var time: Double
    public var strength: Double
    public var pole: CGPoint
    
    /// Creates a magnetic displacement modifier.
    /// - Parameters:
    ///   - time: Animation time.
    ///   - strength: Field strength.
    ///   - pole: Magnetic pole position (normalized 0-1).
    public init(
        time: Double,
        strength: Double = 0.5,
        pole: CGPoint = CGPoint(x: 0.5, y: 0.5)
    ) {
        self.time = time
        self.strength = strength
        self.pole = pole
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            DisplacementShaderBindings.magneticDisplacement,
            .float(time),
            .float(strength),
            .float(pole.x),
            .float(pole.y)
        )
    }
}

// MARK: - View Extension

@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public extension View {
    
    /// Applies sine wave displacement.
    func sineDisplacement(
        time: Double,
        amplitudeX: Double = 0.02,
        amplitudeY: Double = 0.01,
        frequencyX: Double = 3.0,
        frequencyY: Double = 2.0
    ) -> some View {
        modifier(SineDisplacementModifier(
            time: time,
            amplitudeX: amplitudeX,
            amplitudeY: amplitudeY,
            frequencyX: frequencyX,
            frequencyY: frequencyY
        ))
    }
    
    /// Applies noise-based displacement.
    func noiseDisplacement(
        time: Double,
        scale: Double = 5.0,
        amount: Double = 0.05,
        speed: Double = 0.3
    ) -> some View {
        modifier(NoiseDisplacementModifier(
            time: time,
            scale: scale,
            amount: amount,
            speed: speed
        ))
    }
    
    /// Applies FBM displacement.
    func fbmDisplacement(
        time: Double,
        scale: Double = 3.0,
        amount: Double = 0.05,
        octaves: Int = 4
    ) -> some View {
        modifier(FBMDisplacementModifier(
            time: time,
            scale: scale,
            amount: amount,
            octaves: octaves
        ))
    }
    
    /// Applies radial wave displacement.
    func radialDisplacement(
        time: Double,
        amount: Double = 0.03,
        frequency: Double = 2.0,
        center: CGPoint = CGPoint(x: 0.5, y: 0.5)
    ) -> some View {
        modifier(RadialDisplacementModifier(
            time: time,
            amount: amount,
            frequency: frequency,
            center: center
        ))
    }
    
    /// Applies spiral displacement.
    func spiralDisplacement(
        time: Double,
        amount: Double = 0.5,
        tightness: Double = 1.0,
        center: CGPoint = CGPoint(x: 0.5, y: 0.5)
    ) -> some View {
        modifier(SpiralDisplacementModifier(
            time: time,
            amount: amount,
            tightness: tightness,
            center: center
        ))
    }
    
    /// Applies heat distortion effect.
    func heatDistortion(
        time: Double,
        intensity: Double = 1.0,
        riseFactor: Double = 0.5,
        turbulence: Double = 3.0
    ) -> some View {
        modifier(HeatDistortionModifier(
            time: time,
            intensity: intensity,
            riseFactor: riseFactor,
            turbulence: turbulence
        ))
    }
    
    /// Applies underwater displacement.
    func underwaterDisplacement(
        time: Double,
        waveScale: Double = 1.0,
        waveAmount: Double = 1.0,
        depthFactor: Double = 1.0
    ) -> some View {
        modifier(UnderwaterDisplacementModifier(
            time: time,
            waveScale: waveScale,
            waveAmount: waveAmount,
            depthFactor: depthFactor
        ))
    }
    
    /// Applies shockwave displacement.
    func shockwaveDisplacement(
        time: Double,
        center: CGPoint = CGPoint(x: 0.5, y: 0.5),
        waveWidth: Double = 0.1,
        amplitude: Double = 0.05
    ) -> some View {
        modifier(ShockwaveDisplacementModifier(
            time: time,
            center: center,
            waveWidth: waveWidth,
            amplitude: amplitude
        ))
    }
    
    /// Applies lens distortion.
    func lensDistortion(
        time: Double,
        k1: Double = 0.3,
        k2: Double = 0.0,
        center: CGPoint = CGPoint(x: 0.5, y: 0.5)
    ) -> some View {
        modifier(LensDistortionModifier(
            time: time,
            k1: k1,
            k2: k2,
            center: center
        ))
    }
    
    /// Applies flag wave effect.
    func flagWave(
        time: Double,
        amplitude: Double = 0.5,
        frequency: Double = 3.0,
        propagation: Double = 5.0
    ) -> some View {
        modifier(FlagWaveModifier(
            time: time,
            amplitude: amplitude,
            frequency: frequency,
            propagation: propagation
        ))
    }
    
    /// Applies spherize effect.
    func spherize(
        time: Double,
        amount: Double = 0.5,
        radius: Double = 0.5,
        center: CGPoint = CGPoint(x: 0.5, y: 0.5)
    ) -> some View {
        modifier(SpherizeModifier(
            time: time,
            amount: amount,
            radius: radius,
            center: center
        ))
    }
    
    /// Applies twirl effect.
    func twirl(
        time: Double,
        angle: Double = 2.0,
        radius: Double = 0.5,
        center: CGPoint = CGPoint(x: 0.5, y: 0.5)
    ) -> some View {
        modifier(TwirlModifier(
            time: time,
            angle: angle,
            radius: radius,
            center: center
        ))
    }
    
    /// Applies pinch effect.
    func pinch(
        time: Double,
        amount: Double = 0.5,
        radius: Double = 0.5,
        center: CGPoint = CGPoint(x: 0.5, y: 0.5)
    ) -> some View {
        modifier(PinchModifier(
            time: time,
            amount: amount,
            radius: radius,
            center: center
        ))
    }
    
    /// Applies zigzag displacement.
    func zigzag(
        time: Double,
        amplitude: Double = 0.3,
        frequency: Double = 10.0,
        angle: Double = 0.0
    ) -> some View {
        modifier(ZigzagModifier(
            time: time,
            amplitude: amplitude,
            frequency: frequency,
            angle: angle
        ))
    }
    
    /// Applies blob displacement.
    func blobDisplacement(
        time: Double,
        scale: Double = 3.0,
        amount: Double = 0.3,
        smoothness: Double = 0.8
    ) -> some View {
        modifier(BlobDisplacementModifier(
            time: time,
            scale: scale,
            amount: amount,
            smoothness: smoothness
        ))
    }
    
    /// Applies breathing effect.
    func breathingDisplacement(
        time: Double,
        amount: Double = 0.1,
        speed: Double = 1.5,
        center: CGPoint = CGPoint(x: 0.5, y: 0.5)
    ) -> some View {
        modifier(BreathingDisplacementModifier(
            time: time,
            amount: amount,
            speed: speed,
            center: center
        ))
    }
    
    /// Applies block displacement glitch.
    func blockDisplacement(
        time: Double,
        blockSize: Double = 0.05,
        amount: Double = 0.5,
        probability: Double = 0.3
    ) -> some View {
        modifier(BlockDisplacementModifier(
            time: time,
            blockSize: blockSize,
            amount: amount,
            probability: probability
        ))
    }
    
    /// Applies scanline jitter.
    func scanlineJitter(
        time: Double,
        lineHeight: Double = 0.01,
        jitterAmount: Double = 0.1,
        probability: Double = 0.2
    ) -> some View {
        modifier(ScanlineJitterModifier(
            time: time,
            lineHeight: lineHeight,
            jitterAmount: jitterAmount,
            probability: probability
        ))
    }
    
    /// Applies wind displacement.
    func windDisplacement(
        time: Double,
        strength: Double = 0.5,
        gustiness: Double = 1.0,
        direction: Double = 0.0
    ) -> some View {
        modifier(WindDisplacementModifier(
            time: time,
            strength: strength,
            gustiness: gustiness,
            direction: direction
        ))
    }
    
    /// Applies earthquake shake.
    func earthquakeDisplacement(
        time: Double,
        magnitude: Double = 1.0,
        frequency: Double = 1.0,
        decay: Double = 0.5
    ) -> some View {
        modifier(EarthquakeDisplacementModifier(
            time: time,
            magnitude: magnitude,
            frequency: frequency,
            decay: decay
        ))
    }
    
    /// Applies magnetic field displacement.
    func magneticDisplacement(
        time: Double,
        strength: Double = 0.5,
        pole: CGPoint = CGPoint(x: 0.5, y: 0.5)
    ) -> some View {
        modifier(MagneticDisplacementModifier(
            time: time,
            strength: strength,
            pole: pole
        ))
    }
}
