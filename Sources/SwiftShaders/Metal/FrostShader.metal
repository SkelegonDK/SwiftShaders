// Frost & Ice Effect Shader
// Creates frosted glass and ice crystal effects
// Author: Muhittin Camdali
// License: MIT

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
#include "SwiftShadersCommon.h"
using namespace metal;

// =============================================================================
// ALGORITHM EXPLANATION
// =============================================================================
// Frost effect creates frozen glass appearance by:
// 1. Generating Worley noise for ice crystal patterns
// 2. Distorting UV coordinates based on noise
// 3. Applying blur-like sampling around each pixel
// 4. Adding subtle color tinting (blue/white)
// 5. Creating refraction-like displacement
// =============================================================================

// Worley noise for crystal patterns
static float worley(float2 p, float scale) {
    float2 n = floor(p * scale);
    float2 f = fract(p * scale);
    
    float minDist = 1.0;
    
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            float2 neighbor = float2(x, y);
            float2 point = hashSine2D(n + neighbor) * 0.5 + 0.5;
            float2 diff = neighbor + point - f;
            float dist = length(diff);
            minDist = min(minDist, dist);
        }
    }
    
    return minDist;
}

// =============================================================================
// LAYER EFFECT: Frosted Glass
// =============================================================================
// Parameters:
// - size: View dimensions
// - frostAmount: Frost intensity (0.0-1.0, default: 0.5)
// - crystalScale: Ice crystal pattern scale (default: 10.0)
// - blurAmount: Blur radius (default: 5.0)
// =============================================================================
[[stitchable]] half4 frostedGlass(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float frostAmount,
    float crystalScale,
    float blurAmount
) {
    float2 uv = position / size;
    
    // Generate frost pattern
    float frost = worley(uv, crystalScale);
    float noise = valueNoise2D(uv * crystalScale * 2.0);
    
    // Combine patterns
    float pattern = frost * 0.7 + noise * 0.3;
    
    // Distortion based on frost
    float2 distortion = float2(
        valueNoise2D(uv * crystalScale + 100.0) - 0.5,
        valueNoise2D(uv * crystalScale + 200.0) - 0.5
    ) * frostAmount * blurAmount;
    
    // Sample with distortion (simulated blur)
    half4 color = half4(0.0);
    int samples = 8;
    for (int i = 0; i < samples; i++) {
        float angle = float(i) * 6.28318 / float(samples);
        float2 offset = float2(cos(angle), sin(angle)) * blurAmount * frostAmount;
        offset += distortion;
        color += layer.sample(position + offset);
    }
    color /= half(samples);
    
    // Add frost tint (slight blue)
    half3 frostTint = half3(0.9, 0.95, 1.0);
    color.rgb = mix(color.rgb, color.rgb * frostTint, half(frostAmount * 0.3));
    
    // Add crystal highlights
    float highlight = smoothstep(0.3, 0.0, frost) * frostAmount;
    color.rgb += half3(highlight * 0.2);
    
    return color;
}

// =============================================================================
// COLOR EFFECT: Ice Crystal Overlay
// =============================================================================
[[stitchable]] half4 iceCrystals(
    float2 position,
    half4 color,
    float2 size,
    float time,
    float crystalDensity,
    float shimmerSpeed
) {
    float2 uv = position / size;
    
    // Animated frost pattern
    float frost1 = worley(uv + time * 0.01, crystalDensity);
    float frost2 = worley(uv * 1.5 + time * 0.02, crystalDensity * 0.7);
    
    // Combine patterns
    float pattern = frost1 * 0.6 + frost2 * 0.4;
    
    // Shimmer effect
    float shimmer = sin(time * shimmerSpeed + uv.x * 10.0 + uv.y * 10.0) * 0.5 + 0.5;
    
    // Ice coloring
    half3 iceColor = half3(0.8, 0.9, 1.0);
    half3 result = mix(color.rgb, iceColor, half(pattern * 0.3));
    
    // Add sparkles
    float sparkle = step(0.97, hashSine2D(uv * 100.0 + floor(time * 10.0)));
    result += half3(sparkle * shimmer);
    
    return half4(result, color.a);
}

// =============================================================================
// LAYER EFFECT: Window Frost
// =============================================================================
[[stitchable]] half4 windowFrost(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float coverage,
    float thickness
) {
    float2 uv = position / size;
    
    // Frost grows from edges
    float edgeDist = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
    float edgeFrost = smoothstep(coverage, 0.0, edgeDist);
    
    // Add random frost patterns
    float pattern = worley(uv, 15.0);
    float frostMask = edgeFrost * (1.0 - pattern * 0.5);
    
    // Sample with frost blur
    half4 original = layer.sample(position);
    
    half4 frosted = half4(0.0);
    int samples = 8;
    float radius = thickness * frostMask;
    
    for (int i = 0; i < samples; i++) {
        float angle = float(i) * 6.28318 / float(samples);
        float2 offset = float2(cos(angle), sin(angle)) * radius;
        frosted += layer.sample(position + offset);
    }
    frosted /= half(samples);
    
    // Blend based on frost coverage
    half4 result = mix(original, frosted, half(frostMask));
    
    // Add white frost color
    result.rgb = mix(result.rgb, half3(0.95), half(frostMask * 0.3));
    
    return result;
}

// =============================================================================
// COLOR EFFECT: Breath on Glass
// =============================================================================
[[stitchable]] half4 breathFrost(
    float2 position,
    half4 color,
    float2 size,
    float2 breathCenter,
    float breathSize,
    float fadeAmount
) {
    float2 uv = position / size;
    
    // Distance from breath center
    float dist = length(uv - breathCenter);
    
    // Circular breath mark
    float breath = smoothstep(breathSize, breathSize * 0.3, dist);
    
    // Frost pattern within breath
    float frost = valueNoise2D(uv * 30.0) * 0.5 + 0.5;
    
    // Combine
    float frostAmount = breath * frost * (1.0 - fadeAmount);
    
    // Apply frosting effect
    half3 result = mix(color.rgb, half3(0.9, 0.92, 0.95), half(frostAmount * 0.5));
    
    // Reduce clarity
    result = mix(result, half3(dot(float3(result), float3(0.3, 0.5, 0.2))), half(frostAmount * 0.3));
    
    return half4(result, color.a);
}

// =============================================================================
// COLOR EFFECT: Frozen Surface
// =============================================================================
[[stitchable]] half4 frozenSurface(
    float2 position,
    half4 color,
    float2 size,
    float crackDensity,
    float iceThickness
) {
    float2 uv = position / size;
    
    // Ice cracks using Worley
    float cracks = worley(uv, crackDensity);
    cracks = smoothstep(0.0, 0.1, cracks);
    
    // Ice surface texture
    float surface = valueNoise2D(uv * crackDensity * 2.0);
    
    // Base ice color
    half3 iceBase = half3(0.85, 0.92, 1.0);
    half3 iceDark = half3(0.5, 0.7, 0.9);
    
    // Layer ice colors
    half3 result = mix(iceDark, iceBase, half(surface));
    
    // Add crack lines
    result = mix(result, half3(0.3, 0.5, 0.7), half(1.0 - cracks) * half(iceThickness));
    
    // Blend with original
    result = mix(color.rgb, result, half(iceThickness));
    
    return half4(result, color.a);
}
