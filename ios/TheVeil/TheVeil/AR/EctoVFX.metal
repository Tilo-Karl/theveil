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

float2 ectoCenteredUV(float2 uv) {
    return float2(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0);
}

float ectoSoftNoise(float3 p) {
    float value = spectralNoise(p) * 0.68;
    value += spectralNoise(p * 1.86 + float3(9.2, 4.7, 2.1)) * 0.24;
    value += spectralNoise(p * 2.72 + float3(1.6, 8.4, 5.8)) * 0.08;
    return value;
}

float ectoRidgedSoft(float3 p) {
    float n = ectoSoftNoise(p);
    return 1.0 - abs(n * 2.0 - 1.0);
}

float ectoLowerWeight(float2 p) {
    return 1.0 - smoothstep(-0.90, 0.18, p.y);
}

float ectoCenterMass(float2 p) {
    return 1.0 - smoothstep(0.10, 0.88, length(p * float2(0.78, 0.72)));
}

float ectoSoftRim(float2 p) {
    return smoothstep(0.50, 1.08, length(p * float2(0.82, 0.72)));
}

float ectoFresnel(float3 normal, float3 viewDirection, float power) {
    return pow(saturate(1.0 - abs(dot(normal, viewDirection))), power);
}

float ectoBroadFlow(float2 p, float time, float phase) {
    float2 drift = float2(
        sin(time * 0.07 + phase) * 0.18,
        cos(time * 0.055 + phase * 0.7) * 0.14
    );
    float cloudA = ectoSoftNoise(float3(p * 1.12 + drift, time * 0.035 + phase * 0.17));
    float cloudB = ectoSoftNoise(float3(
        p * 1.92 - drift * 0.62 + float2(2.2, 5.1),
        -time * 0.048 + phase * 0.31
    ));
    return cloudA * 0.66 + cloudB * 0.34;
}

float ectoSparseBubbles(float2 p, float time, float phase) {
    float2 drift = float2(
        sin(time * 0.045 + phase * 1.3) * 0.16,
        cos(time * 0.038 - phase) * 0.12
    );
    float bubbleSeed = ectoRidgedSoft(float3(p * 5.4 + drift, time * 0.024 + phase * 0.41));
    float roundness = ectoRidgedSoft(float3(p * 8.2 - drift * 0.7, phase * 0.9 - time * 0.018));
    float bodyMask = 1.0 - smoothstep(0.26, 0.96, length(p * float2(0.92, 0.82)));
    return smoothstep(0.93, 0.992, bubbleSeed)
        * smoothstep(0.44, 0.86, roundness)
        * bodyMask;
}

float2 ectoFlowGradient(float2 p, float time, float phase, float scale, float speed) {
    float2 drift = float2(
        sin(time * 0.052 + phase) * 0.22,
        cos(time * 0.047 - phase * 0.6) * 0.18
    );
    float2 q = p * scale + drift;
    float epsilon = 0.035;
    float xA = ectoSoftNoise(float3(q + float2(epsilon, 0.0), time * speed + phase * 0.11));
    float xB = ectoSoftNoise(float3(q - float2(epsilon, 0.0), time * speed + phase * 0.11));
    float yA = ectoSoftNoise(float3(q + float2(0.0, epsilon), -time * speed + phase * 0.17));
    float yB = ectoSoftNoise(float3(q - float2(0.0, epsilon), -time * speed + phase * 0.17));
    return float2(xA - xB, yA - yB) / (epsilon * 2.0);
}

float3 ectoGeometryOffset(float2 uv, float time, float phase, float reactivity, float strength) {
    float2 p = ectoCenteredUV(uv);
    float envelope = 1.0 - smoothstep(0.20, 1.34, length(p * float2(0.70, 0.84)));
    float lowerSag = ectoLowerWeight(p);
    float broadWobble = ectoBroadFlow(p, time, phase) - 0.5;
    float rollingWobble = ectoSoftNoise(float3(
        p * 2.5 + float2(1.7, 4.1),
        -time * 0.115 + phase * 0.42
    )) - 0.5;
    float membraneRipple = (broadWobble * 0.016 + rollingWobble * 0.006)
        * (1.0 + reactivity * 0.70)
        * strength;

    return float3(
        sin(time * 0.86 + p.y * 3.8 + phase) * 0.0042 * envelope * strength,
        -lowerSag * 0.014 * strength + membraneRipple * 0.26,
        membraneRipple
    );
}

[[visible]]
void ectoOuterShellGeometry(realitykit::geometry_parameters params) {
    auto geometry = params.geometry();
    float4 controls = params.uniforms().custom_parameter();
    float3 offset = ectoGeometryOffset(
        geometry.uv0(),
        params.uniforms().time(),
        controls.x,
        controls.z,
        1.0
    );
    geometry.set_model_position_offset(offset);
}

[[visible]]
void ectoInnerGelGeometry(realitykit::geometry_parameters params) {
    auto geometry = params.geometry();
    float4 controls = params.uniforms().custom_parameter();
    float3 offset = ectoGeometryOffset(
        geometry.uv0(),
        params.uniforms().time(),
        controls.x + 1.7,
        controls.z * 0.72,
        0.58
    );
    geometry.set_model_position_offset(offset);
}

[[visible]]
void ectoOuterShellSurface(realitykit::surface_parameters params) {
    auto geometry = params.geometry();
    auto surface = params.surface();
    float4 controls = params.uniforms().custom_parameter();
    float time = params.uniforms().time();
    float phase = controls.x;
    float visibility = controls.y;
    float reactivity = controls.z;
    float variant = controls.w;

    float2 p = ectoCenteredUV(geometry.uv0());
    float3 normal = normalize(geometry.normal());
    float3 viewDirection = normalize(geometry.view_direction());

    float3 shellTint = mix(ectoVariantBody(variant), float3(0.30, 1.00, 0.58), 0.54);
    float3 paleGel = mix(float3(0.84, 1.00, 0.91), shellTint, 0.46);
    float rim = ectoSoftRim(p);
    float fresnel = ectoFresnel(normal, viewDirection, 2.15);
    float edgeDensity = saturate(rim * 0.58 + fresnel * 0.72);
    float lowerDensity = ectoLowerWeight(p);
    float broadFlow = ectoBroadFlow(p, time, phase);
    float bubbles = ectoSparseBubbles(p, time, phase);
    float flowingBand = smoothstep(0.62, 0.92, broadFlow + rim * 0.12)
        * (0.22 + edgeDensity * 0.78);

    float2 gradient = ectoFlowGradient(p, time, phase, 1.22, 0.042);
    gradient += float2(
        sin(time * 0.11 + p.y * 2.4 + phase) * 0.16,
        cos(time * 0.09 + p.x * 2.1 - phase) * 0.12
    );
    float3 tangentNormal = normalize(float3(gradient * 0.13, 1.0));

    float3 baseColor = paleGel * (0.22 + edgeDensity * 0.24 + flowingBand * 0.08);
    baseColor += shellTint * (bubbles * 0.18 + lowerDensity * 0.035);

    float opacity = 0.060
        + edgeDensity * 0.205
        + rim * 0.090
        + lowerDensity * 0.030
        + flowingBand * 0.034
        + bubbles * 0.085
        + reactivity * 0.028;
    opacity *= visibility;

    float roughness = 0.052 + broadFlow * 0.026 + bubbles * 0.022 + reactivity * 0.018;
    float clearcoat = 0.86 + edgeDensity * 0.12 + reactivity * 0.06;
    float clearcoatRoughness = 0.022 + (1.0 - flowingBand) * 0.026 + bubbles * 0.018;

    float3 emissive = shellTint * (edgeDensity * 0.026 + bubbles * 0.030 + reactivity * 0.018);
    emissive += float3(0.90, 1.00, 0.86) * flowingBand * 0.020;

    surface.set_base_color(half3(baseColor));
    surface.set_normal(tangentNormal);
    surface.set_roughness(half(saturate(roughness)));
    surface.set_metallic(half(0.0));
    surface.set_clearcoat(half(saturate(clearcoat)));
    surface.set_clearcoat_roughness(half(saturate(clearcoatRoughness)));
    surface.set_clearcoat_normal(half3(tangentNormal));
    surface.set_opacity(half(saturate(opacity)));
    surface.set_emissive_color(half3(emissive * visibility));
}

[[visible]]
void ectoInnerGelSurface(realitykit::surface_parameters params) {
    auto geometry = params.geometry();
    auto surface = params.surface();
    float4 controls = params.uniforms().custom_parameter();
    float time = params.uniforms().time();
    float phase = controls.x;
    float visibility = controls.y;
    float reactivity = controls.z;
    float variant = controls.w;

    float2 p = ectoCenteredUV(geometry.uv0());
    float3 normal = normalize(geometry.normal());
    float3 viewDirection = normalize(geometry.view_direction());

    float3 gelTint = mix(ectoVariantBody(variant), float3(0.20, 0.98, 0.44), 0.68);
    float3 deepGel = mix(float3(0.015, 0.20, 0.085), gelTint * 0.38, 0.54);
    float3 coreTint = ectoVariantCore(variant);

    float lowerDensity = ectoLowerWeight(p);
    float centerDensity = ectoCenterMass(p);
    float upperLightness = smoothstep(0.20, 0.95, p.y);
    float cloudA = ectoBroadFlow(p * 0.92 + float2(0.08, -0.04), time * 0.82, phase + 2.4);
    float cloudB = ectoSoftNoise(float3(
        p * 1.55 + float2(-1.2, 0.7),
        -time * 0.030 + phase * 0.29
    ));
    float clouds = smoothstep(0.28, 0.86, cloudA * 0.68 + cloudB * 0.32);
    float weightedClouds = clouds * (0.60 + lowerDensity * 0.22 + centerDensity * 0.18);
    float density = saturate(
        centerDensity * 0.34
            + lowerDensity * 0.42
            + weightedClouds * 0.30
            + reactivity * 0.06
    );
    density *= 1.0 - upperLightness * 0.30;

    float coreRegion = exp(-length((p - float2(0.0, -0.38)) / float2(0.22, 0.18)) * 2.85);
    float particles = smoothstep(0.945, 0.996, ectoRidgedSoft(float3(
        p * 7.0 + float2(sin(time * 0.035 + phase), cos(time * 0.031 - phase)) * 0.18,
        phase * 0.37 - time * 0.020
    ))) * (0.52 + lowerDensity * 0.48);

    float fresnel = ectoFresnel(normal, viewDirection, 2.7);
    float2 gradient = ectoFlowGradient(p, time, phase + 1.9, 0.88, 0.030);
    float3 tangentNormal = normalize(float3(gradient * 0.052, 1.0));

    float3 baseColor = mix(deepGel, gelTint, 0.38 + density * 0.46);
    baseColor += gelTint * weightedClouds * 0.12;
    baseColor += coreTint * coreRegion * 0.080;
    baseColor += float3(0.84, 1.00, 0.72) * particles * 0.045;

    float opacity = 0.250
        + density * 0.355
        + lowerDensity * 0.105
        + centerDensity * 0.085
        + particles * 0.030
        + fresnel * 0.045;
    opacity *= 1.0 - upperLightness * 0.16;
    opacity *= visibility;

    float roughness = 0.38 + weightedClouds * 0.18 + lowerDensity * 0.08;
    float3 emissive = coreTint * coreRegion * 0.135;
    emissive += gelTint * particles * 0.020;
    emissive *= visibility * (0.84 + reactivity * 0.34);

    surface.set_base_color(half3(baseColor));
    surface.set_normal(tangentNormal);
    surface.set_roughness(half(saturate(roughness)));
    surface.set_metallic(half(0.0));
    surface.set_opacity(half(saturate(opacity)));
    surface.set_emissive_color(half3(emissive));
}
