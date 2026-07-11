#include <metal_stdlib>
#include <RealityKit/RealityKit.h>
#include "SpectralNoise.metalh"
using namespace metal;

// Authored field channels:
// R = soft spectral matter/silhouette
// G = crisp structural highlights from the actual reference art
// B = irregular cavities: eye sockets, nostrils and maw
//
// This shader does not recreate the face with ellipses or cookie-cutter primitives.
// It deforms and animates the authored field extracted from the reference.

float2 fieldWarp(float2 uv, float time, float phase, float amount) {
    float2 p = uv * 2.0 - 1.0;
    float3 qA = float3(p * 2.2, time * 0.16 + phase);
    float3 qB = float3(p * 3.1 + float2(5.7, 1.9), -time * 0.13 + phase * 1.7);

    float2 w = float2(
        spectralFBM(qA),
        spectralFBM(qB)
    ) - 0.5;

    return uv + w * amount;
}

float ridged(float3 p) {
    float n = spectralFBM(p);
    return 1.0 - abs(n * 2.0 - 1.0);
}

[[visible]]
void specterGeometry(realitykit::geometry_parameters params) {
    auto geometry = params.geometry();
    float4 controls = params.uniforms().custom_parameter();
    float time = params.uniforms().time();
    float phase = controls.x;
    float layer = controls.y;

    float2 uv = geometry.uv0();
    float2 p = uv * 2.0 - 1.0;

    float envelope = smoothstep(0.0, 0.85, 1.0 - length(p * float2(0.82, 0.70)));
    float wave = spectralFBM(float3(p * 2.8, time * 0.22 + phase));

    float3 offset = float3(
        0.0,
        (wave - 0.5) * 0.008 * envelope,
        (wave - 0.5) * 0.025 * envelope
    );

    offset *= layer < 0.5 ? 1.0 : 0.25;
    geometry.set_model_position_offset(offset);
}

[[visible]]
void specterSurface(realitykit::surface_parameters params) {
    auto surface = params.surface();
    auto geometry = params.geometry();

    float4 controls = params.uniforms().custom_parameter();
    float time = params.uniforms().time();
    float phase = controls.x;
    float layer = controls.y;

    // Temporary auto-formation cycle. Replace with a Swift-driven formation value later.
    float cycle = 0.5 + 0.5 * sin(time * 0.55 + phase);
    float formation = smoothstep(0.18, 0.88, cycle);

    float2 uv = geometry.uv0();

    // Idle: stronger deformation and less readable structure.
    // Attack: face converges toward the authored reference.
    float warpAmount = mix(0.038, 0.006, formation);
    float2 warpedUV = fieldWarp(uv, time, phase, warpAmount);

    // Texture supplied by Swift as custom.texture.
    auto faceTexture = params.textures().custom();
    constexpr sampler linearSampler(
        filter::linear,
        address::clamp_to_zero
    );

    float3 field = faceTexture.sample(linearSampler, warpedUV).rgb;
    float matter = field.r;
    float authoredHighlights = field.g;
    float cavities = field.b;

    // Fine motion breaks up the outer energy without destroying the authored anatomy.
    float2 p = warpedUV * 2.0 - 1.0;
    float turbulence = spectralFBM(float3(p * 5.2, time * 0.22 + phase * 2.1));
    float crackle = ridged(float3(p * 13.0, time * 0.95 + phase * 4.0));

    // Structural highlights become crisp only as the attack forms.
    float highlightGate = mix(0.12, 1.0, formation);
    float hardHighlight = authoredHighlights * highlightGate;
    float whiteCore = pow(saturate(hardHighlight), 2.25);
    float violetBody = pow(saturate(hardHighlight), 1.20);

    // Preserve cavities while allowing their borders to glow.
    float cavityDark = cavities * mix(0.52, 1.0, formation);

    // Approximate a cavity-edge band by sampling nearby authored cavity values.
    float2 texel = float2(1.0 / 1024.0);
    float cL = faceTexture.sample(linearSampler, warpedUV - float2(texel.x, 0)).b;
    float cR = faceTexture.sample(linearSampler, warpedUV + float2(texel.x, 0)).b;
    float cU = faceTexture.sample(linearSampler, warpedUV + float2(0, texel.y)).b;
    float cD = faceTexture.sample(linearSampler, warpedUV - float2(0, texel.y)).b;
    float cavityEdge = saturate(abs(cR - cL) + abs(cU - cD)) * formation;

    // The broad aura stays subordinate to the sharp authored face.
    float diffuseMatter = matter * (0.38 + turbulence * 0.34);
    float filamentBreakup = mix(0.48, 1.0, crackle);
    hardHighlight *= filamentBreakup;
    whiteCore *= filamentBreakup;

    float3 obsidian = float3(0.003, 0.000, 0.010);
    float3 deepPurple = float3(0.11, 0.004, 0.27);
    float3 violet = float3(0.48, 0.018, 0.92);
    float3 hotViolet = float3(0.88, 0.12, 1.00);
    float3 whiteHot = float3(1.00, 0.96, 1.00);

    float3 color = obsidian;
    color += deepPurple * diffuseMatter * mix(0.72, 0.34, formation);
    color += violet * violetBody * 0.90;
    color += hotViolet * cavityEdge * 0.58;
    color += whiteHot * whiteCore * 1.45;

    // Dark sockets, nostrils and maw remain authored irregular voids.
    color = mix(color, obsidian, cavityDark * (1.0 - whiteCore * 0.35));

    if (layer < 0.5) {
        float auraAlpha = (
            diffuseMatter * mix(0.42, 0.22, formation)
            + cavityEdge * 0.10
        );

        surface.set_emissive_color(half3(color * controls.z));
        surface.set_opacity(half(saturate(auraAlpha * controls.w)));
        return;
    }

    float faceAlpha = (
        matter * mix(0.16, 0.34, formation)
        + hardHighlight * 0.76
        + whiteCore * 0.92
        + cavityEdge * 0.30
    );

    surface.set_emissive_color(half3(color * controls.z));
    surface.set_opacity(half(saturate(faceAlpha * controls.w)));
}
