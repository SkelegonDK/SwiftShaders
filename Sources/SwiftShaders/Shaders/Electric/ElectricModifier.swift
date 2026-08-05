import SwiftUI

// MARK: - Bindings

/// The binding contracts for this family's stitchable functions.
enum ElectricShaderBindings: ShaderFamily {
    /// `half4 electricNeon(float2,half4,float4,float,float,float)`
    static let electricNeon = ShaderBinding.Color("electricNeon", geometry: .boundingRect)
    /// `half4 electricField(float2,half4,float4,float,float,float)`
    static let electricField = ShaderBinding.Color("electricField", geometry: .boundingRect)
    /// `half4 staticElectricity(float2,half4,float4,float,float,float)`
    static let staticElectricity = ShaderBinding.Color("staticElectricity", geometry: .boundingRect)
    /// `half4 electricArc(float2,half4,float4,float,float,float,float,float,float)`
    static let electricArc = ShaderBinding.Color("electricArc", geometry: .boundingRect)
    /// `half4 plasma(float2,half4,float4,float,float,float)`
    static let plasma = ShaderBinding.Color("plasma", geometry: .boundingRect)
    /// `half4 lightning(float2,half4,float4,float,float,float,float)`
    static let lightning = ShaderBinding.Color("lightning", geometry: .boundingRect)

    static var bindings: [any AnyShaderBinding] {
        [electricNeon, electricField, staticElectricity, electricArc, plasma, lightning]
    }
}

// MARK: - LightningModifier

/// A view modifier that applies lightning bolt effects.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct LightningModifier: ViewModifier {
    
    public var time: Double
    public var intensity: Double
    public var branchiness: Double
    public var glowRadius: Double
    
    /// Creates a lightning modifier.
    public init(
        time: Double,
        intensity: Double = 1.0,
        branchiness: Double = 1.0,
        glowRadius: Double = 1.0
    ) {
        self.time = time
        self.intensity = intensity
        self.branchiness = branchiness
        self.glowRadius = glowRadius
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            ElectricShaderBindings.lightning,
            .float(time),
            .float(intensity),
            .float(branchiness),
            .float(glowRadius)
        )
    }
}

// MARK: - PlasmaModifier

/// Creates plasma ball effects.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct PlasmaModifier: ViewModifier {
    
    public var time: Double
    public var scale: Double
    public var colorSpeed: Double
    
    /// Creates a plasma modifier.
    public init(
        time: Double,
        scale: Double = 1.0,
        colorSpeed: Double = 1.0
    ) {
        self.time = time
        self.scale = scale
        self.colorSpeed = colorSpeed
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            ElectricShaderBindings.plasma,
            .float(time),
            .float(scale),
            .float(colorSpeed)
        )
    }
}

// MARK: - ElectricArcModifier

/// Creates electric arc between two points.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct ElectricArcModifier: ViewModifier {
    
    public var time: Double
    public var start: CGPoint
    public var end: CGPoint
    public var thickness: Double
    
    /// Creates an electric arc modifier.
    public init(
        time: Double,
        start: CGPoint = CGPoint(x: 0.2, y: 0.2),
        end: CGPoint = CGPoint(x: 0.8, y: 0.8),
        thickness: Double = 0.02
    ) {
        self.time = time
        self.start = start
        self.end = end
        self.thickness = thickness
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            ElectricShaderBindings.electricArc,
            .float(time),
            .float(start.x),
            .float(start.y),
            .float(end.x),
            .float(end.y),
            .float(thickness)
        )
    }
}

// MARK: - StaticElectricityModifier

/// Creates static electricity sparks.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct StaticElectricityModifier: ViewModifier {
    
    public var time: Double
    public var density: Double
    public var sparkSize: Double
    
    /// Creates a static electricity modifier.
    public init(
        time: Double,
        density: Double = 20.0,
        sparkSize: Double = 0.02
    ) {
        self.time = time
        self.density = density
        self.sparkSize = sparkSize
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            ElectricShaderBindings.staticElectricity,
            .float(time),
            .float(density),
            .float(sparkSize)
        )
    }
}

// MARK: - ElectricFieldModifier

/// Creates electric field visualization.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct ElectricFieldModifier: ViewModifier {
    
    public var time: Double
    public var lineCount: Double
    public var flowSpeed: Double
    
    /// Creates an electric field modifier.
    public init(
        time: Double,
        lineCount: Double = 8.0,
        flowSpeed: Double = 2.0
    ) {
        self.time = time
        self.lineCount = lineCount
        self.flowSpeed = flowSpeed
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            ElectricShaderBindings.electricField,
            .float(time),
            .float(lineCount),
            .float(flowSpeed)
        )
    }
}

// MARK: - ElectricNeonModifier

/// Creates neon glow electric effect.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct ElectricNeonModifier: ViewModifier {
    
    public var time: Double
    public var glowIntensity: Double
    public var flickerSpeed: Double
    
    /// Creates a neon electric modifier.
    public init(
        time: Double,
        glowIntensity: Double = 1.0,
        flickerSpeed: Double = 2.0
    ) {
        self.time = time
        self.glowIntensity = glowIntensity
        self.flickerSpeed = flickerSpeed
    }
    
    public func body(content: Content) -> some View {
        content.shaderEffect(
            ElectricShaderBindings.electricNeon,
            .float(time),
            .float(glowIntensity),
            .float(flickerSpeed)
        )
    }
}

// MARK: - View Extension

@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public extension View {
    
    /// Applies lightning effect.
    func lightning(
        time: Double,
        intensity: Double = 1.0,
        branchiness: Double = 1.0,
        glowRadius: Double = 1.0
    ) -> some View {
        modifier(LightningModifier(
            time: time,
            intensity: intensity,
            branchiness: branchiness,
            glowRadius: glowRadius
        ))
    }
    
    /// Applies plasma effect.
    func plasma(
        time: Double,
        scale: Double = 1.0,
        colorSpeed: Double = 1.0
    ) -> some View {
        modifier(PlasmaModifier(time: time, scale: scale, colorSpeed: colorSpeed))
    }
    
    /// Applies electric arc effect.
    func electricArc(
        time: Double,
        start: CGPoint = CGPoint(x: 0.2, y: 0.2),
        end: CGPoint = CGPoint(x: 0.8, y: 0.8),
        thickness: Double = 0.02
    ) -> some View {
        modifier(ElectricArcModifier(
            time: time,
            start: start,
            end: end,
            thickness: thickness
        ))
    }
    
    /// Applies static electricity effect.
    func staticElectricity(
        time: Double,
        density: Double = 20.0,
        sparkSize: Double = 0.02
    ) -> some View {
        modifier(StaticElectricityModifier(
            time: time,
            density: density,
            sparkSize: sparkSize
        ))
    }
    
    /// Applies electric field effect.
    func electricField(
        time: Double,
        lineCount: Double = 8.0,
        flowSpeed: Double = 2.0
    ) -> some View {
        modifier(ElectricFieldModifier(
            time: time,
            lineCount: lineCount,
            flowSpeed: flowSpeed
        ))
    }
    
    /// Applies neon electric effect.
    func neonElectric(
        time: Double,
        glowIntensity: Double = 1.0,
        flickerSpeed: Double = 2.0
    ) -> some View {
        modifier(ElectricNeonModifier(
            time: time,
            glowIntensity: glowIntensity,
            flickerSpeed: flickerSpeed
        ))
    }
}
