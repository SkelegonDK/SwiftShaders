import SwiftUI

// MARK: - ShaderTimeline

/// A view that provides time-based animation for shader effects.
///
/// ## Overview
///
/// ```swift
/// ShaderTimeline { time in
///     Image("photo")
///         .rippleEffect(time: time)
/// }
/// ```
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct ShaderTimeline<Content: View>: View {
    
    private let speed: Double
    private let content: (Double) -> Content

    private var clock = ShaderClock()

    /// Creates a shader timeline.
    /// - Parameters:
    ///   - speed: Animation speed multiplier.
    ///   - content: Content builder receiving animation time.
    public init(
        speed: Double = 1.0,
        @ViewBuilder content: @escaping (Double) -> Content
    ) {
        self.speed = speed
        self.content = content
    }
    
    public var body: some View {
        TimelineView(.animation) { timeline in
            let time = clock.elapsed(to: timeline.date, speed: speed)
            content(time)
        }
    }
}

// MARK: - ShaderTransition

/// A transition view that animates between two states using shaders.
///
/// ## Overview
///
/// ```swift
/// ShaderTransition(progress: transitionProgress) { progress in
///     Image("photo")
///         .dissolveEffect(progress: progress)
/// }
/// ```
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct ShaderTransition<Content: View>: View {
    
    @State private var animatedProgress: Double = 0
    
    private let progress: Double
    private let animation: Animation?
    private let content: (Double) -> Content
    
    /// Creates a shader transition.
    /// - Parameters:
    ///   - progress: Transition progress (0-1).
    ///   - animation: Optional animation for progress changes.
    ///   - content: Content builder receiving progress.
    public init(
        progress: Double,
        animation: Animation? = .easeInOut(duration: 0.5),
        @ViewBuilder content: @escaping (Double) -> Content
    ) {
        self.progress = progress
        self.animation = animation
        self.content = content
    }
    
    public var body: some View {
        content(animatedProgress)
            .onChange(of: progress) { _, newValue in
                if let animation {
                    withAnimation(animation) {
                        animatedProgress = newValue
                    }
                } else {
                    animatedProgress = newValue
                }
            }
            .onAppear {
                animatedProgress = progress
            }
    }
}

// MARK: - Easing Functions

/// Collection of easing functions for shader animations.
public enum ShaderEasing {
    
    /// Linear interpolation.
    public static func linear(_ t: Double) -> Double { t }
    
    /// Quadratic ease in.
    public static func easeInQuad(_ t: Double) -> Double { t * t }
    
    /// Quadratic ease out.
    public static func easeOutQuad(_ t: Double) -> Double { 1 - (1 - t) * (1 - t) }
    
    /// Quadratic ease in-out.
    public static func easeInOutQuad(_ t: Double) -> Double {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }
    
    /// Cubic ease in.
    public static func easeInCubic(_ t: Double) -> Double { t * t * t }
    
    /// Cubic ease out.
    public static func easeOutCubic(_ t: Double) -> Double { 1 - pow(1 - t, 3) }
    
    /// Cubic ease in-out.
    public static func easeInOutCubic(_ t: Double) -> Double {
        t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
    }
    
    /// Sine ease in.
    public static func easeInSine(_ t: Double) -> Double {
        1 - cos(t * .pi / 2)
    }
    
    /// Sine ease out.
    public static func easeOutSine(_ t: Double) -> Double {
        sin(t * .pi / 2)
    }
    
    /// Sine ease in-out.
    public static func easeInOutSine(_ t: Double) -> Double {
        -(cos(.pi * t) - 1) / 2
    }
    
    /// Exponential ease in.
    public static func easeInExpo(_ t: Double) -> Double {
        t == 0 ? 0 : pow(2, 10 * t - 10)
    }
    
    /// Exponential ease out.
    public static func easeOutExpo(_ t: Double) -> Double {
        t == 1 ? 1 : 1 - pow(2, -10 * t)
    }
    
    /// Elastic ease out.
    public static func easeOutElastic(_ t: Double) -> Double {
        let c4 = (2 * Double.pi) / 3
        return t == 0 ? 0 : t == 1 ? 1 : pow(2, -10 * t) * sin((t * 10 - 0.75) * c4) + 1
    }
    
    /// Bounce ease out.
    public static func easeOutBounce(_ t: Double) -> Double {
        let n1 = 7.5625
        let d1 = 2.75
        var t = t
        
        if t < 1 / d1 {
            return n1 * t * t
        } else if t < 2 / d1 {
            t -= 1.5 / d1
            return n1 * t * t + 0.75
        } else if t < 2.5 / d1 {
            t -= 2.25 / d1
            return n1 * t * t + 0.9375
        } else {
            t -= 2.625 / d1
            return n1 * t * t + 0.984375
        }
    }
    
    /// Back ease out (overshoot).
    public static func easeOutBack(_ t: Double) -> Double {
        let c1 = 1.70158
        let c3 = c1 + 1
        return 1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2)
    }
}

// MARK: - AnimationKeyframe

/// Represents a keyframe for shader animation.
public struct ShaderKeyframe<Value> {
    /// The time of this keyframe (0-1 normalized).
    public let time: Double
    /// The value at this keyframe.
    public let value: Value
    /// The easing function to the next keyframe.
    public let easing: (Double) -> Double
    
    /// Creates a shader keyframe.
    public init(
        time: Double,
        value: Value,
        easing: @escaping (Double) -> Double = ShaderEasing.linear
    ) {
        self.time = time
        self.value = value
        self.easing = easing
    }
}

// MARK: - KeyframeAnimator

/// Animates between keyframes for shader parameters.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *)
public struct KeyframeAnimator {
    
    /// Interpolates between Double keyframes.
    /// - Parameters:
    ///   - keyframes: Array of keyframes.
    ///   - progress: Current progress (0-1).
    /// - Returns: Interpolated value.
    public static func interpolate(
        keyframes: [ShaderKeyframe<Double>],
        at progress: Double
    ) -> Double {
        guard !keyframes.isEmpty else { return 0 }
        guard keyframes.count > 1 else { return keyframes[0].value }
        
        let sorted = keyframes.sorted { $0.time < $1.time }
        
        // Find surrounding keyframes
        var fromIndex = 0
        for (index, keyframe) in sorted.enumerated() {
            if keyframe.time <= progress {
                fromIndex = index
            }
        }
        
        let toIndex = min(fromIndex + 1, sorted.count - 1)
        
        if fromIndex == toIndex {
            return sorted[fromIndex].value
        }
        
        let from = sorted[fromIndex]
        let to = sorted[toIndex]
        
        let localProgress = (progress - from.time) / (to.time - from.time)
        let easedProgress = from.easing(localProgress)
        
        return from.value + (to.value - from.value) * easedProgress
    }
}
