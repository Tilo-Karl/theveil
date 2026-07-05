#include <metal_stdlib>
#include <RealityKit/RealityKit.h>
#include "SpectralNoise.metalh"
using namespace metal;

[[visible]]
void essencePlasmaGeometry(realitykit::geometry_parameters params) {
    auto geometry = params.geometry();
    float3 position = geometry.model_position();
    float3 normal = geometry.normal();
    float4 controls = params.uniforms().custom_parameter();
    float time = params.uniforms().time();
    float3 direction = normalize(position);
    float3 phaseAxis = normalize(float3(
        cos(controls.z * 1.7),
        0.45 + sin(controls.z * 2.3),
        sin(controls.z * 1.1)
    ));
    float noise = spectralFBM(position * 35.0 + float3(0, time * 0.24, controls.z * 11.0));
    float lobeNoise = spectralFBM(
        direction * 2.6
            + phaseAxis * 1.9
            + float3(time * 0.09, -time * 0.07, time * 0.05)
    );
    float directionalLobe = sin(
        dot(direction, phaseAxis) * 4.1
            + time * 0.31
            + controls.z * 2.7
    );
    float pulse = sin(time * 1.3 + controls.z * 6.28) * 0.5 + 0.5;
    float outerWeight = 1.0 - smoothstep(0.8, 3.4, controls.y);
    float fineDisplacement = (noise - 0.48) * controls.x * (0.72 + pulse * 0.28);
    float silhouetteDisplacement = (
        (lobeNoise - 0.5) * 1.45 + directionalLobe * 0.34
    ) * controls.x * (0.62 + outerWeight * 0.88);
    float directionalStretch = dot(direction, phaseAxis)
        * controls.x
        * (0.12 + outerWeight * 0.22);
    float displacement = fineDisplacement + silhouetteDisplacement + directionalStretch;
    geometry.set_model_position_offset(normal * displacement);
}

[[visible]]
void essencePlasmaSurface(realitykit::surface_parameters params) {
    auto geometry = params.geometry();
    auto surface = params.surface();
    float4 controls = params.uniforms().custom_parameter();
    float time = params.uniforms().time();
    float3 position = geometry.model_position();
    float noiseA = spectralFBM(position * 42.0 + float3(time * 0.16, -time * 0.21, controls.z * 9.0));
    float noiseB = spectralFBM(position * 73.0 + float3(-time * 0.11, controls.z * 13.0, time * 0.19));
    float vein = smoothstep(0.54, 0.84, noiseA * 0.72 + noiseB * 0.46);
    float pulse = 0.82 + sin(time * 1.65 + controls.z * 7.0) * 0.18;
    float3 cyan = float3(0.06, 0.68, 1.0);
    float3 violet = float3(0.4, 0.1, 1.0);
    float phaseVariation = fract(controls.z * 0.159);
    float outerWeight = 1.0 - smoothstep(0.85, 3.25, controls.y);
    float colorMix = saturate(
        0.1 + noiseB * 0.28 + phaseVariation * 0.08 + outerWeight * 0.52
    );
    float3 color = mix(cyan, violet, colorMix);
    float intensity = controls.y * pulse * (0.62 + vein * 1.7);
    float alpha = saturate((0.055 + vein * 0.31) * controls.w);

    surface.set_emissive_color(half3(color * intensity));
    surface.set_opacity(half(alpha));
}

[[visible]]
void essenceRibbonSurface(realitykit::surface_parameters params) {
    auto geometry = params.geometry();
    auto surface = params.surface();
    float2 uv = geometry.uv0();
    float2 kind = geometry.uv1();
    float4 controls = params.uniforms().custom_parameter();
    float time = params.uniforms().time();
    float edgeDistance = 1.0 - abs(uv.y * 2.0 - 1.0);
    float softEdge = smoothstep(0.0, 0.72, edgeDistance);
    float endFade = smoothstep(0.0, 0.1, uv.x) * (1.0 - smoothstep(0.82, 1.0, uv.x));
    float flow = spectralFBM(float3(uv.x * 6.0 - time * 0.32, uv.y * 2.4, controls.z * 8.0));
    float filament = smoothstep(0.28, 0.78, flow);
    float flicker = 0.76 + sin(time * 2.1 + uv.x * 17.0 + controls.z * 5.0) * 0.24;
    float isWisp = step(0.5, kind.x);
    float isBlueWisp = step(1.5, kind.x);
    float filamentAlpha = softEdge * endFade * (0.14 + filament * 0.58) * controls.w;
    float wispPulse = 0.72 + sin(time * 0.7 + uv.x * 8.0 + kind.y * 9.0) * 0.28;
    float wispTaper = smoothstep(0.0, 0.06, uv.x)
        * (1.0 - smoothstep(0.5, 1.0, uv.x));
    float wispStrand = 0.34 + flow * 0.66;
    float wispAlpha = softEdge * wispTaper * wispStrand * wispPulse * controls.w * 0.42;
    float alpha = mix(filamentAlpha, wispAlpha, isWisp);
    float3 cyan = float3(0.08, 0.7, 1.0);
    float3 violet = float3(0.62, 0.06, 1.0);
    float colorMix = saturate(0.1 + uv.x * 0.22 + flow * 0.28);
    float3 filamentColor = mix(cyan, violet, colorMix);
    float3 violetWispColor = mix(cyan, violet, saturate(0.62 + flow * 0.3));
    float3 blueWispColor = mix(float3(0.02, 0.34, 1.0), cyan, 0.34 + flow * 0.24);
    float3 wispColor = mix(violetWispColor, blueWispColor, isBlueWisp);
    float3 color = mix(filamentColor, wispColor, isWisp);

    float lightStrength = mix(controls.y * flicker, controls.y * 0.55 * wispPulse, isWisp);
    surface.set_emissive_color(half3(color * lightStrength));
    surface.set_opacity(half(alpha));
}
