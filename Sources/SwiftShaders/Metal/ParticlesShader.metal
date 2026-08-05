// Particles Effect Shader
// Creates procedural particle and spark effects
// Author: Muhittin Camdali
// License: MIT

#include <metal_stdlib>
#include "SwiftShadersCommon.h"
using namespace metal;

// =============================================================================
// ALGORITHM EXPLANATION
// =============================================================================
// Particle effects create animated point/spark overlays by:
// 1. Generating pseudo-random particle positions
// 2. Animating particles over time
// 3. Applying various shapes (dots, stars, snowflakes)
// 4. Blending with underlying content
// =============================================================================

// =============================================================================
// COLOR EFFECT: Sparkle Particles
// =============================================================================
// Parameters:
// - size: View dimensions
// - time: Animation time
// - density: Particle density (10-100, default: 50)
// - sparkleColor: Sparkle color
// - intensity: Brightness (0.0-2.0)
// =============================================================================
[[stitchable]] half4 particlesSparkle(
    float2 position,
    half4 color,
    float2 size,
    float time,
    float density,
    float3 sparkleColor,
    float intensity
) {
    float2 uv = position / size;
    
    // Grid for sparkles
    float2 gridSize = float2(density);
    float2 cell = floor(uv * gridSize);
    float2 cellUV = fract(uv * gridSize);
    
    // Random position within cell
    float2 sparklePos = hashSine2DTo2D(cell) * 0.6 + 0.2;
    float dist = length(cellUV - sparklePos);
    
    // Animated twinkle
    float twinkle = sin(time * (hashSine2D(cell) * 5.0 + 2.0) + hashSine2D(cell + 100.0) * 6.28) * 0.5 + 0.5;
    twinkle = pow(twinkle, 3.0);
    
    // Sparkle shape
    float sparkle = smoothstep(0.1, 0.0, dist) * twinkle * intensity;
    
    // Add to color
    half3 result = color.rgb + half3(sparkleColor) * half(sparkle);
    
    return half4(result, color.a);
}

// =============================================================================
// COLOR EFFECT: Falling Particles (Snow/Rain)
// =============================================================================
[[stitchable]] half4 particlesFalling(
    float2 position,
    half4 color,
    float2 size,
    float time,
    float speed,
    float density,
    float particleSize,
    float3 particleColor
) {
    float2 uv = position / size;
    half3 result = color.rgb;
    
    // Multiple layers for depth
    for (int layer = 0; layer < 3; layer++) {
        float layerSpeed = speed * (0.5 + float(layer) * 0.3);
        float layerDensity = density * (1.0 - float(layer) * 0.2);
        float layerSize = particleSize * (1.0 - float(layer) * 0.3);
        
        // Grid with vertical scroll
        float2 gridSize = float2(layerDensity, layerDensity * 0.5);
        float2 scrolledUV = float2(uv.x, fmod(uv.y + time * layerSpeed, 1.0));
        
        float2 cell = floor(scrolledUV * gridSize);
        float2 cellUV = fract(scrolledUV * gridSize);
        
        // Random position with horizontal drift
        float2 particlePos = hashSine2DTo2D(cell + float(layer) * 100.0);
        particlePos.x += sin(time * 0.5 + particlePos.y * 10.0) * 0.1; // Drift
        
        float dist = length(cellUV - particlePos);
        float particle = smoothstep(layerSize, 0.0, dist);
        
        // Alpha based on layer depth
        float alpha = 1.0 - float(layer) * 0.3;
        result += half3(particleColor) * half(particle * alpha);
    }
    
    return half4(result, color.a);
}

// =============================================================================
// COLOR EFFECT: Rising Particles (Bubbles/Embers)
// =============================================================================
[[stitchable]] half4 particlesRising(
    float2 position,
    half4 color,
    float2 size,
    float time,
    float speed,
    float density,
    float particleSize,
    float3 particleColor
) {
    float2 uv = position / size;
    half3 result = color.rgb;
    
    for (int layer = 0; layer < 3; layer++) {
        float layerSpeed = speed * (0.5 + float(layer) * 0.25);
        
        // Grid with upward scroll
        float2 gridSize = float2(density, density * 0.7);
        float2 scrolledUV = float2(uv.x, fmod(uv.y - time * layerSpeed + 10.0, 1.0));
        
        float2 cell = floor(scrolledUV * gridSize);
        float2 cellUV = fract(scrolledUV * gridSize);
        
        float2 particlePos = hashSine2DTo2D(cell + float(layer) * 50.0);
        
        // Wobble
        particlePos.x += sin(time + particlePos.y * 5.0) * 0.15;
        
        float dist = length(cellUV - particlePos);
        float particle = smoothstep(particleSize, 0.0, dist);
        
        result += half3(particleColor) * half(particle * (1.0 - float(layer) * 0.25));
    }
    
    return half4(result, color.a);
}

// =============================================================================
// COLOR EFFECT: Star Field
// =============================================================================
[[stitchable]] half4 particlesStarField(
    float2 position,
    half4 color,
    float2 size,
    float time,
    float density,
    float travelSpeed
) {
    float2 uv = (position / size - 0.5) * 2.0;
    half3 result = color.rgb;
    
    // Multiple star layers
    for (int layer = 0; layer < 4; layer++) {
        float depth = 1.0 + float(layer) * 0.5;
        float layerDensity = density * (1.0 + float(layer) * 0.3);
        
        // Stars move outward from center
        float2 scaledUV = uv * depth;
        float2 movement = scaledUV * time * travelSpeed * (1.0 / depth);
        
        float2 starUV = fract(scaledUV * layerDensity + movement);
        float2 cell = floor(scaledUV * layerDensity + movement);
        
        float2 starPos = hashSine2DTo2D(cell) * 0.7 + 0.15;
        float dist = length(starUV - starPos);
        
        // Twinkle
        float twinkle = sin(time * (hashSine2D(cell) * 3.0 + 1.0)) * 0.5 + 0.5;
        
        float star = smoothstep(0.05, 0.0, dist) * twinkle;
        
        // Brightness varies with depth
        float brightness = 1.0 - float(layer) * 0.2;
        result += half3(star * brightness);
    }
    
    return half4(result, color.a);
}

// =============================================================================
// COLOR EFFECT: Confetti
// =============================================================================
[[stitchable]] half4 particlesConfetti(
    float2 position,
    half4 color,
    float2 size,
    float time,
    float density,
    float fallSpeed
) {
    float2 uv = position / size;
    half3 result = color.rgb;
    
    float2 gridSize = float2(density);
    
    for (int i = 0; i < 3; i++) {
        float layer = float(i);
        float speed = fallSpeed * (0.5 + layer * 0.3);
        
        float2 scrolledUV = float2(uv.x, fmod(uv.y + time * speed, 1.0));
        float2 cell = floor(scrolledUV * gridSize);
        float2 cellUV = fract(scrolledUV * gridSize);
        
        float2 confettiPos = hashSine2DTo2D(cell + layer * 100.0) * 0.6 + 0.2;
        
        // Rotation
        float angle = time * (hashSine2D(cell) - 0.5) * 5.0;
        float2 rotated = cellUV - confettiPos;
        float c = cos(angle);
        float s = sin(angle);
        rotated = float2(rotated.x * c - rotated.y * s, rotated.x * s + rotated.y * c);
        
        // Rectangle shape
        float2 d = abs(rotated) - float2(0.08, 0.04);
        float confetti = 1.0 - step(0.0, max(d.x, d.y));
        
        // Random bright color
        half3 confettiColor = half3(
            hashSine2D(cell),
            hashSine2D(cell + 50.0),
            hashSine2D(cell + 100.0)
        );
        confettiColor = mix(confettiColor, half3(1.0), half(0.3)); // Brighter
        
        result += confettiColor * half(confetti);
    }
    
    return half4(result, color.a);
}

// =============================================================================
// COLOR EFFECT: Fireflies
// =============================================================================
[[stitchable]] half4 particlesFireflies(
    float2 position,
    half4 color,
    float2 size,
    float time,
    float count,
    float3 glowColor,
    float glowSize
) {
    float2 uv = position / size;
    half3 result = color.rgb;
    
    for (float i = 0.0; i < count; i++) {
        // Random starting position
        float2 basePos = hashSine2DTo2D(float2(i, i * 1.5));
        
        // Wandering movement
        float2 wanderPos = float2(
            basePos.x + sin(time * 0.5 + i) * 0.1 + sin(time * 0.3 + i * 2.0) * 0.05,
            basePos.y + cos(time * 0.4 + i * 1.5) * 0.1 + cos(time * 0.2 + i * 3.0) * 0.05
        );
        
        // Wrap position
        wanderPos = fract(wanderPos);
        
        float dist = length(uv - wanderPos);
        
        // Pulsing glow
        float pulse = sin(time * (2.0 + hashSine2D(float2(i, 0.0)))) * 0.5 + 0.5;
        pulse = pow(pulse, 2.0);
        
        float glow = smoothstep(glowSize, 0.0, dist) * pulse;
        
        result += half3(glowColor) * half(glow);
    }
    
    return half4(result, color.a);
}

// =============================================================================
// COLOR EFFECT: Dust Motes
// =============================================================================
[[stitchable]] half4 particlesDust(
    float2 position,
    half4 color,
    float2 size,
    float time,
    float density,
    float drift,
    float3 dustColor
) {
    float2 uv = position / size;
    half3 result = color.rgb;
    
    float2 gridSize = float2(density);
    float2 cell = floor(uv * gridSize);
    float2 cellUV = fract(uv * gridSize);
    
    // Multiple dust particles per cell
    for (int i = 0; i < 3; i++) {
        float2 dustPos = hashSine2DTo2D(cell + float(i) * 33.0);
        
        // Slow drifting motion
        dustPos.x += sin(time * 0.2 + dustPos.y * 10.0) * drift;
        dustPos.y += cos(time * 0.15 + dustPos.x * 10.0) * drift * 0.5;
        dustPos = fract(dustPos);
        
        float dist = length(cellUV - dustPos);
        float dust = smoothstep(0.05, 0.0, dist);
        
        // Vary brightness
        float brightness = hashSine2D(cell + float(i) * 50.0) * 0.5 + 0.5;
        
        result += half3(dustColor) * half(dust * brightness * 0.3);
    }
    
    return half4(result, color.a);
}
