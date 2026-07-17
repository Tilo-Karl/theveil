#include <metal_stdlib>
#include <RealityKit/RealityKit.h>
#include "SpectralNoise.metalh"
using namespace metal;

float3 ectoVariantBody(float index) {
    if (index < 0.5) {
        return float3(0.18, 0.98, 0.46);
    }
    if (index < 1.5) {
        return float3(0.12, 0.92, 1.00);
    }
    if (index < 2.5) {
        return float3(0.58, 0.34, 1.00);
    }
    if (index < 3.5) {
        return float3(0.48, 0.98, 0.48);
    }
    return float3(0.38, 1.00, 0.58);
}

float3 ectoVariantCore(float index) {
    if (index < 0.5) {
        return float3(0.78, 1.00, 0.42);
    }
    if (index < 1.5) {
        return float3(0.72, 1.00, 1.00);
    }
    if (index < 2.5) {
        return float3(0.98, 0.56, 1.00);
    }
    if (index < 3.5) {
        return float3(0.82, 1.00, 0.36);
    }
    return float3(0.82, 1.00, 0.42);
}

float ridgedEcto(float3 p) {
    float n = spectralFBM(p);
    return 1.0 - abs(n * 2.0 - 1.0);
}

float bubbleField(float2 p, float time, float phase) {
    float drift = spectralFBM(float3(p * 2.2, time * 0.16 + phase));
    float fine = ridgedEcto(float3(p * 13.5 + drift * 0.7, time * 0.72 - phase));
    return smoothstep(0.58, 0.98, fine);
}

[[visible]]
void ectoGeometry(realitykit::geometry_parameters params) {
    auto geometry = params.geometry();
    float4 controls = params.uniforms().custom_parameter();
    float time = params.uniforms().time();
    float phase = controls.x;
    float reactivity = controls.z;

    float2 uv = geometry.uv0();
    float2 p = float2(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0);

    float envelope = 1.0 - smoothstep(0.18, 1.32, length(p * float2(0.70, 0.84)));
    float lowerSag = 1.0 - smoothstep(-0.90, 0.08, p.y);
    float wobbleA = spectralFBM(float3(p * 2.4, time * 0.28 + phase));
    float wobbleB = spectralFBM(float3(p * 6.2 + float2(1.7, 4.1), -time * 0.43 + phase));
    float ripple = (wobbleA - 0.5) * 0.020 + (wobbleB - 0.5) * 0.009;
    ripple *= 1.0 + reactivity * 0.95;

    float3 offset = float3(
        sin(time * 1.7 + p.y * 5.0 + phase) * 0.004 * envelope,
        -lowerSag * 0.018 + ripple * 0.28,
        ripple
    );

    geometry.set_model_position_offset(offset);
}

[[visible]]
void ectoSurface(realitykit::surface_parameters params) {
    auto geometry = params.geometry();
    auto surface = params.surface();
    float4 controls = params.uniforms().custom_parameter();
    float time = params.uniforms().time();
    float phase = controls.x;
    float visibility = controls.y;
    float reactivity = controls.z;
    float variant = controls.w;

    float2 uv = geometry.uv0();
    float2 p = float2(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0);

    float3 body = ectoVariantBody(variant);
    body = mix(body, float3(0.42, 1.00, 0.70), 0.56);
    float3 core = ectoVariantCore(variant);
    float3 deep = body * 0.018 + float3(0.00, 0.010, 0.012);
    float3 whiteHot = float3(0.94, 1.00, 0.92);

    float lowerDensity = 1.0 - smoothstep(-0.92, 0.16, p.y);
    float shellDistance = length(p * float2(0.80, 0.70));
    float rim = smoothstep(0.48, 1.10, shellDistance);
    float outerRim = smoothstep(0.76, 1.16, shellDistance);
    float clearWindow = 1.0 - smoothstep(0.06, 0.76, shellDistance);

    float lowFlow = spectralFBM(float3(p * 1.8, time * 0.12 + phase));
    float midFlow = spectralFBM(float3(p * 4.8 + float2(2.2, 5.7), -time * 0.30 + phase * 1.6));
    float fineBubbles = bubbleField(p, time, phase);
    float causticNoise = ridgedEcto(float3(
        p.x * 9.0 + sin(p.y * 4.0 + time * 0.25 + phase) * 0.65,
        p.y * 14.0 - time * 0.44,
        phase
    ));
    float floatingSpecs = ridgedEcto(float3(
        p.x * 18.0 - time * 0.09,
        p.y * 16.0 + time * 0.20,
        phase * 1.7
    ));

    float caustics = smoothstep(0.72, 0.98, causticNoise) * (0.22 + lowerDensity * 0.42);
    float suspendedBubbles = smoothstep(0.86, 0.995, floatingSpecs) * (0.26 + lowerDensity * 0.42);
    float milkyMass = smoothstep(0.66, 0.98, lowFlow * 0.50 + midFlow * 0.32 + fineBubbles * 0.12);
    milkyMass *= 1.0 - clearWindow * 0.82;

    float verticalCore = exp(-length((p - float2(0.0, -0.44)) / float2(0.17, 0.14)) * 2.75);
    float hotCore = smoothstep(0.30, 0.96, verticalCore + fineBubbles * 0.10);

    float glossA = exp(-length((p - float2(-0.34, 0.36)) / float2(0.18, 0.052)) * 4.0);
    float glossB = exp(-length((p - float2(0.28, 0.16)) / float2(0.12, 0.038)) * 4.8);
    float glossC = exp(-length((p - float2(-0.16, -0.60)) / float2(0.24, 0.046)) * 3.2);
    float gloss = (glossA + glossB * 0.55 + glossC * 0.38) * (0.45 + rim * 0.55);

    float3 color = deep;
    color += body * (outerRim * 0.46 + rim * 0.11 + milkyMass * 0.065 + lowerDensity * 0.036);
    color += core * (hotCore * 1.10 + caustics * 0.36 + suspendedBubbles * 0.15 + outerRim * 0.56);
    color += whiteHot * (gloss * 0.66 + hotCore * 0.40 + caustics * 0.18);
    color *= 1.0 + reactivity * 0.34;

    float alpha =
        0.012 +
        outerRim * 0.36 +
        rim * 0.10 +
        lowerDensity * 0.032 +
        milkyMass * 0.032 +
        caustics * 0.056 +
        hotCore * 0.022 +
        gloss * 0.084;
    alpha *= 1.0 - clearWindow * 0.68;
    alpha += reactivity * 0.040;
    alpha *= visibility;

    surface.set_emissive_color(half3(color * (1.05 + outerRim * 0.42 + hotCore * 0.34 + gloss * 0.28)));
    surface.set_opacity(half(saturate(alpha)));
}
