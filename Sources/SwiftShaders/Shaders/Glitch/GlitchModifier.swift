import SwiftUI

// MARK: - Bindings

/// The binding contracts for this family's stitchable functions.
enum GlitchShaderBindings: ShaderFamily {
    /// `half4 signalInterference(float2,half4,float4,float,float,float)`
    static let signalInterference = ShaderBinding.Color("signalInterference", geometry: .boundingRect)
    /// `half4 digitalCorruption(float2,half4,float4,float,float,float,float)`
    static let digitalCorruption = ShaderBinding.Color("digitalCorruption", geometry: .boundingRect)
    /// `half4 vhsGlitch(float2,half4,float4,float,float,float)`
    static let vhsGlitch = ShaderBinding.Color("vhsGlitch", geometry: .boundingRect)
    /// `half4 glitchColor(float2,half4,float4,float,float)`
    static let glitchColor = ShaderBinding.Color("glitchColor", geometry: .boundingRect)
    /// `float2 glitch(float2,float4,float,float,float)`
    static let glitch = ShaderBinding.Distortion("glitch", geometry: .boundingRect, sampling: .fixed(width: 100, height: 10))

    static var bindings: [any AnyShaderBinding] {
        [signalInterference, digitalCorruption, vhsGlitch, glitchColor, glitch]
    }
}

// MARK: - GlitchModifier

/// A view modifier that applies digital glitch effects.
///
/// Creates various digital artifact effects including horizontal displacement,
/// color channel separation, and block corruption.
///
/// ## Overview
///
/// ```swift
/// Image("photo")
///     .modifier(GlitchModifier(
///         time: animationTime,
///         intensity: 0.5,
///         blockSize: 0.1
///     ))
/// ```
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct GlitchModifier: ViewModifier {
    
    // MARK: - Properties
    
    /// Animation time for the glitch effect.
    public var time: Double
    
    /// Intensity of the glitch effect (0.0 - 1.0).
    public var intensity: Double
    
    /// Size of glitch blocks as a fraction of height.
    public var blockSize: Double
    
    // MARK: - Initialization
    
    /// Creates a glitch modifier.
    /// - Parameters:
    ///   - time: Animation time.
    ///   - intensity: Effect strength (default: 0.5).
    ///   - blockSize: Block size fraction (default: 0.1).
    public init(
        time: Double,
        intensity: Double = 0.5,
        blockSize: Double = 0.1
    ) {
        self.time = time
        self.intensity = intensity
        self.blockSize = blockSize
    }
    
    // MARK: - Body
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            GlitchShaderBindings.glitch,
            .float(time),
            .float(intensity),
            .float(blockSize)
        )
    }
}

// MARK: - GlitchColorModifier

/// Applies color-only glitch effects without position distortion.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct GlitchColorModifier: ViewModifier {
    
    public var time: Double
    public var intensity: Double
    
    /// Creates a color glitch modifier.
    /// - Parameters:
    ///   - time: Animation time.
    ///   - intensity: Effect strength.
    public init(time: Double, intensity: Double = 0.5) {
        self.time = time
        self.intensity = intensity
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            GlitchShaderBindings.glitchColor,
            .float(time),
            .float(intensity)
        )
    }
}

// MARK: - VHSGlitchModifier

/// Applies VHS-style tape glitch effects.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct VHSGlitchModifier: ViewModifier {
    
    public var time: Double
    public var intensity: Double
    public var noiseAmount: Double
    
    /// Creates a VHS glitch modifier.
    /// - Parameters:
    ///   - time: Animation time.
    ///   - intensity: Effect strength.
    ///   - noiseAmount: Amount of noise overlay.
    public init(
        time: Double,
        intensity: Double = 0.5,
        noiseAmount: Double = 0.1
    ) {
        self.time = time
        self.intensity = intensity
        self.noiseAmount = noiseAmount
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            GlitchShaderBindings.vhsGlitch,
            .float(time),
            .float(intensity),
            .float(noiseAmount)
        )
    }
}

// MARK: - DigitalCorruptionModifier

/// Applies block-based digital corruption effects.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct DigitalCorruptionModifier: ViewModifier {
    
    public var time: Double
    public var intensity: Double
    public var blockWidth: Double
    public var blockHeight: Double
    
    /// Creates a digital corruption modifier.
    /// - Parameters:
    ///   - time: Animation time.
    ///   - intensity: Effect strength.
    ///   - blockWidth: Corruption block width.
    ///   - blockHeight: Corruption block height.
    public init(
        time: Double,
        intensity: Double = 0.3,
        blockWidth: Double = 0.05,
        blockHeight: Double = 0.05
    ) {
        self.time = time
        self.intensity = intensity
        self.blockWidth = blockWidth
        self.blockHeight = blockHeight
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            GlitchShaderBindings.digitalCorruption,
            .float(time),
            .float(intensity),
            .float(blockWidth),
            .float(blockHeight)
        )
    }
}

// MARK: - SignalInterferenceModifier

/// Applies signal interference and rolling bar effects.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct SignalInterferenceModifier: ViewModifier {
    
    public var time: Double
    public var intensity: Double
    public var frequency: Double
    
    /// Creates a signal interference modifier.
    /// - Parameters:
    ///   - time: Animation time.
    ///   - intensity: Effect strength.
    ///   - frequency: Interference frequency.
    public init(
        time: Double,
        intensity: Double = 0.5,
        frequency: Double = 1.0
    ) {
        self.time = time
        self.intensity = intensity
        self.frequency = frequency
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            GlitchShaderBindings.signalInterference,
            .float(time),
            .float(intensity),
            .float(frequency)
        )
    }
}

// MARK: - View Extension

@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public extension View {

    /// Applies a glitch effect to the view.
    /// - Parameters:
    ///   - time: Animation time for the glitch.
    ///   - intensity: Strength of the glitch effect.
    ///   - blockSize: Size of glitch blocks.
    /// - Returns: A view with the glitch effect applied.
    func glitchEffect(
        time: Double,
        intensity: Double = 0.5,
        blockSize: Double = 0.1
    ) -> some View {
        modifier(GlitchModifier(time: time, intensity: intensity, blockSize: blockSize))
    }

    /// Applies color-only glitch effect.
    /// - Parameters:
    ///   - time: Animation time.
    ///   - intensity: Effect strength.
    /// - Returns: A view with glitch color effect.
    func glitchColor(
        time: Double,
        intensity: Double = 0.5
    ) -> some View {
        modifier(GlitchColorModifier(time: time, intensity: intensity))
    }
    
    /// Applies VHS-style glitch effect.
    /// - Parameters:
    ///   - time: Animation time.
    ///   - intensity: Effect strength.
    ///   - noiseAmount: Noise overlay amount.
    /// - Returns: A view with VHS glitch effect.
    func vhsGlitch(
        time: Double,
        intensity: Double = 0.5,
        noiseAmount: Double = 0.1
    ) -> some View {
        modifier(VHSGlitchModifier(
            time: time,
            intensity: intensity,
            noiseAmount: noiseAmount
        ))
    }
    
    /// Applies digital corruption effect.
    /// - Parameters:
    ///   - time: Animation time.
    ///   - intensity: Effect strength.
    ///   - blockWidth: Block width.
    ///   - blockHeight: Block height.
    /// - Returns: A view with corruption effect.
    func digitalCorruption(
        time: Double,
        intensity: Double = 0.3,
        blockWidth: Double = 0.05,
        blockHeight: Double = 0.05
    ) -> some View {
        modifier(DigitalCorruptionModifier(
            time: time,
            intensity: intensity,
            blockWidth: blockWidth,
            blockHeight: blockHeight
        ))
    }
    
    /// Applies signal interference effect.
    /// - Parameters:
    ///   - time: Animation time.
    ///   - intensity: Effect strength.
    ///   - frequency: Interference frequency.
    /// - Returns: A view with signal interference.
    func signalInterference(
        time: Double,
        intensity: Double = 0.5,
        frequency: Double = 1.0
    ) -> some View {
        modifier(SignalInterferenceModifier(
            time: time,
            intensity: intensity,
            frequency: frequency
        ))
    }
}
