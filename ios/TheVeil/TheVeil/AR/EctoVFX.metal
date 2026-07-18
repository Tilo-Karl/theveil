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

float ridgedEcto(float3 p) {
    float n = spectralFBM(p);
    return 1.0 - abs(n * 2.0 - 1.0);
}

float bubbleField(float2 p, float time, float phase) {
    float drift = spectralFBM(float3(p * 2.2, time * 0.16 + phase));
    float fine = ridgedEcto(float3(p * 13.5 + drift * 0.7, time * 0.72 - phase));
    return smoothstep(0.58, 0.98, fine);
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

float ectoVolumeNoise(float2 p, float time, float phase, float scale, float zOffset, float speed) {
    float2 drift = float2(
        sin(time * speed * 1.2 + phase + zOffset * 2.1) * 0.16,
        cos(time * speed * 0.9 - phase * 0.7 + zOffset * 1.7) * 0.13
    );
    return ectoSoftNoise(float3(
        p * scale + drift + float2(zOffset * 0.37, -zOffset * 0.29),
        zOffset + time * speed + phase * 0.23
    ));
}

float ectoInteriorMask(float2 p) {
    return 1.0 - smoothstep(0.78, 1.08, length(p * float2(0.82, 0.72)));
}

float ectoEllipseMask(float2 p, float2 center, float2 radius, float softness) {
    float d = length((p - center) / max(radius, float2(0.001)));
    return 1.0 - smoothstep(1.0 - softness, 1.0, d);
}

float2 ectoLargeWarp(float2 p, float time, float phase) {
    float wx = ectoSoftNoise(float3(p * 0.34 + float2(phase * 0.11, -0.31), time * 0.012 + phase * 0.07));
    float wy = ectoSoftNoise(float3(p * 0.38 + float2(-0.47, phase * 0.09), -time * 0.010 + phase * 0.13));
    return (float2(wx, wy) - 0.5) * 0.36;
}

float ectoLargeCloud(float2 p, float time, float phase, float scale, float speed, float offset) {
    float2 drift = float2(
        cos(phase + offset) * 0.17 + sin(time * speed + offset) * 0.045,
        sin(phase * 0.7 + offset) * 0.13 + cos(time * speed * 0.8 - offset) * 0.040
    );
    return ectoSoftNoise(float3(p * scale + drift, time * speed + phase * 0.19 + offset));
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

    float3 variantGreen = ectoVariantBody(variant);
    float3 shellTint = mix(variantGreen, float3(0.18, 0.92, 0.32), 0.18);
    float3 cyanReflection = float3(0.08, 0.70, 0.65);
    float3 cleanReflection = float3(0.94, 1.00, 0.92);
    float3 yellowGreen = float3(0.70, 1.00, 0.18);

    float shellDistance = length(p * float2(0.80, 0.70));
    float shapeRim = smoothstep(0.50, 1.08, shellDistance);
    float fresnel = saturate(1.0 - abs(dot(normal, viewDirection)));
    float edgeThickness = pow(fresnel, 1.5);
    float thicknessRim = saturate(shapeRim * 0.55 + edgeThickness * 0.65);
    float lowerDensity = ectoLowerWeight(p);
    float broadFlow = ectoBroadFlow(p, time, phase);
    float bubbles = ectoSparseBubbles(p, time, phase) * 0.16;

    float upperLeftCyan = ectoEllipseMask(p, float2(-0.34, 0.38), float2(0.36, 0.092), 0.58)
        * (0.28 + thicknessRim * 0.72);
    float upperRightWhite = ectoEllipseMask(p, float2(0.31, 0.18), float2(0.20, 0.054), 0.42)
        * (0.42 + edgeThickness * 0.58);
    float lowerGreen = ectoEllipseMask(p, float2(-0.18, -0.58), float2(0.34, 0.068), 0.52)
        * (0.22 + lowerDensity * 0.58 + thicknessRim * 0.20);
    float flowingHighlight = saturate(upperLeftCyan * 0.58 + upperRightWhite * 0.72 + lowerGreen * 0.36);

    float2 gradient = ectoFlowGradient(p, time, phase, 1.20, 0.038);
    gradient += float2(
        sin(time * 0.075 + p.y * 2.1 + phase) * 0.055,
        cos(time * 0.068 + p.x * 1.8 - phase) * 0.045
    );
    float3 tangentNormal = normalize(float3(gradient * 0.058, 1.0));

    float3 baseColor = shellTint * (
        thicknessRim * 0.24 +
        shapeRim * 0.038 +
        broadFlow * 0.026 +
        lowerDensity * 0.012 +
        bubbles * 0.025
    );
    baseColor += cyanReflection * upperLeftCyan * 0.12;
    baseColor += cleanReflection * upperRightWhite * 0.090;
    baseColor += yellowGreen * lowerGreen * 0.075;

    float opacity = 0.026
        + thicknessRim * 0.155
        + shapeRim * 0.030
        + broadFlow * 0.014
        + flowingHighlight * 0.012
        + lowerDensity * 0.010
        + bubbles * 0.016
        + reactivity * 0.012;
    opacity *= visibility;

    float roughness = 0.030 + broadFlow * 0.018 + bubbles * 0.012 + reactivity * 0.010 - flowingHighlight * 0.010;
    float clearcoat = 0.88 + thicknessRim * 0.10 + upperRightWhite * 0.04;
    float clearcoatRoughness = 0.016 + broadFlow * 0.016 + bubbles * 0.008 - flowingHighlight * 0.006;

    float3 emissive = shellTint * (thicknessRim * 0.040 + lowerDensity * 0.010 + bubbles * 0.014);
    emissive += cyanReflection * upperLeftCyan * 0.018;
    emissive += cleanReflection * upperRightWhite * 0.020;
    emissive += yellowGreen * lowerGreen * 0.016;
    emissive *= visibility * (0.86 + reactivity * 0.18);

    surface.set_base_color(half3(baseColor));
    surface.set_normal(tangentNormal);
    surface.set_roughness(half(saturate(roughness)));
    surface.set_metallic(half(0.0));
    surface.set_clearcoat(half(saturate(clearcoat)));
    surface.set_clearcoat_roughness(half(saturate(clearcoatRoughness)));
    surface.set_clearcoat_normal(half3(tangentNormal));
    surface.set_opacity(half(saturate(opacity)));
    surface.set_emissive_color(half3(emissive));
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

    float3 deepGreen = float3(0.02, 0.18, 0.06);
    float3 bodyGreen = mix(float3(0.18, 0.85, 0.30), ectoVariantBody(variant), 0.20);
    float3 luminousGreen = float3(0.70, 1.00, 0.18);
    float3 cyanGreen = float3(0.08, 0.70, 0.65);
    float3 cleanReflection = float3(0.94, 1.00, 0.92);

    float shellDistance = length(p * float2(0.80, 0.70));
    float shapeRim = smoothstep(0.50, 1.08, shellDistance);
    float fresnel = saturate(1.0 - abs(dot(normal, viewDirection)));
    float thicknessRim = saturate(shapeRim * 0.55 + pow(fresnel, 1.5) * 0.65);
    float lowerWeight = ectoLowerWeight(p);
    float centerMass = ectoCenterMass(p);
    float interior = ectoInteriorMask(p);

    float2 warpedP = p + ectoLargeWarp(p, time, phase);
    float layerA = ectoLargeCloud(warpedP, time, phase + 0.13, 0.65, 0.012, 0.0);
    float layerB = ectoLargeCloud(warpedP + float2(0.34, -0.18), time, phase + 1.10, 1.05, 0.020, 2.4);
    float layerC = ectoLargeCloud(warpedP - float2(0.21, 0.32), time, phase - 0.70, 1.55, 0.026, 4.8);
    float largeDensity = layerA * 0.52 + layerB * 0.30 + layerC * 0.18;
    float thickPatch = smoothstep(0.46, 0.72, largeDensity);

    float clearNoise = ectoLargeCloud(warpedP + float2(-0.44, 0.25), time, phase + 2.60, 0.82, 0.018, 7.1);
    float clearPatch = smoothstep(0.58, 0.82, clearNoise) * interior * (1.0 - lowerWeight * 0.25);

    float darkMassMask = smoothstep(0.52, 0.78, ectoLargeCloud(warpedP + float2(0.18, -0.34), time, phase + 0.70, 0.90, 0.014, 1.6))
        * (0.50 + thickPatch * 0.50)
        * (0.72 + lowerWeight * 0.28);
    float brightMassMask = smoothstep(0.50, 0.76, ectoLargeCloud(warpedP - float2(0.27, 0.20), time, phase + 1.90, 1.22, 0.020, 3.3))
        * (0.36 + thickPatch * 0.34 + centerMass * 0.30);
    float cyanMassMask = smoothstep(0.55, 0.80, ectoLargeCloud(warpedP + float2(0.10, 0.44), time, phase - 1.30, 0.78, 0.016, 5.6))
        * (0.42 + (1.0 - lowerWeight) * 0.30 + thicknessRim * 0.28);

    float broadGlow = exp(-length((p - float2(0.0, -0.12)) / float2(0.75, 0.88)) * 1.35);
    float hotGlow = exp(-length((p - float2(0.0, -0.38)) / float2(0.24, 0.20)) * 2.5);
    float distributedGlow = broadGlow * 0.55 + hotGlow * 0.45;
    float scatteredGlow = distributedGlow * (0.35 + thickPatch * 0.45 + brightMassMask * 0.40);
    scatteredGlow *= 1.0 - clearPatch * 0.25;

    float lobeA = ectoEllipseMask(p + float2(sin(time * 0.018 + phase) * 0.025, cos(time * 0.015) * 0.018), float2(-0.30, 0.12), float2(0.24, 0.38), 0.34);
    float lobeB = ectoEllipseMask(p + float2(cos(time * 0.014 + phase) * 0.020, -sin(time * 0.017) * 0.015), float2(0.25, -0.04), float2(0.22, 0.34), 0.36);
    float lobeC = ectoEllipseMask(p, float2(-0.04, -0.35), float2(0.34, 0.26), 0.42);
    float lobeD = ectoEllipseMask(p, float2(0.09, 0.36), float2(0.30, 0.22), 0.40);
    float gelLobes = saturate(lobeA * 0.36 + lobeB * 0.32 + lobeC * 0.42 + lobeD * 0.24);

    float leftEyeGlow = ectoEllipseMask(p, float2(-0.34, 0.30), float2(0.18, 0.13), 0.48);
    float rightEyeGlow = ectoEllipseMask(p, float2(0.34, 0.30), float2(0.18, 0.13), 0.48);
    float mouthGlow = ectoEllipseMask(p, float2(0.0, -0.06), float2(0.26, 0.10), 0.55);
    float faceGlowMask = saturate((leftEyeGlow + rightEyeGlow) * 0.42 + mouthGlow * 0.36)
        * (0.55 + thicknessRim * 0.45);

    float2 causticP = warpedP + float2(
        sin(warpedP.y * 2.4 + time * 0.055 + phase) * 0.16,
        cos(warpedP.x * 2.0 - time * 0.046 + phase * 0.4) * 0.12
    );
    float causticBase = ridgedEcto(float3(
        causticP.x * 7.0 + causticP.y * 0.85,
        causticP.y * 5.2 - time * 0.060,
        phase * 0.31
    ));
    float causticMask = smoothstep(0.78, 0.96, causticBase)
        * (0.28 + thickPatch * 0.32 + lowerWeight * 0.22 + thicknessRim * 0.30 + faceGlowMask * 0.26)
        * (1.0 - clearPatch * 0.55)
        * (0.42 + interior * 0.58);

    float speckA = spectralNoise(float3(warpedP * 17.5 + float2(0.7, 4.2), time * 0.040 + phase * 0.23));
    float speckB = spectralNoise(float3(warpedP * 29.0 + float2(6.1, 1.8), -time * 0.033 + phase * 0.47));
    float commonSpecks = smoothstep(0.965, 0.997, speckA * 0.72 + speckB * 0.28) * interior;
    float brightSpecks = smoothstep(0.988, 0.999, speckB) * interior;

    float shaderBubbles = bubbleField(p * 0.92 + float2(0.11, -0.07), time * 0.16, phase)
        * (0.28 + interior * 0.54)
        * (1.0 - leftEyeGlow * 0.70)
        * (1.0 - rightEyeGlow * 0.70);

    float upperLeftCyan = ectoEllipseMask(p, float2(-0.34, 0.38), float2(0.32, 0.088), 0.55)
        * (0.20 + thicknessRim * 0.52);
    float upperRightWhite = ectoEllipseMask(p, float2(0.32, 0.18), float2(0.17, 0.050), 0.40)
        * (0.32 + fresnel * 0.44);
    float lowerGreenHighlight = ectoEllipseMask(p, float2(-0.12, -0.60), float2(0.34, 0.070), 0.52)
        * (0.22 + lowerWeight * 0.54);

    float density = centerMass * 0.10
        + lowerWeight * 0.16
        + thickPatch * 0.30
        + darkMassMask * 0.10
        + brightMassMask * 0.070
        + gelLobes * 0.14
        + causticMask * 0.035
        + scatteredGlow * 0.040
        - clearPatch * 0.25
        + reactivity * 0.020;
    density = saturate(density);

    float2 gradient = ectoFlowGradient(p, time, phase + 1.9, 0.92, 0.028);
    gradient += float2(causticMask - 0.5, thickPatch - clearPatch) * 0.030;
    float3 tangentNormal = normalize(float3(gradient * 0.044, 1.0));

    float3 color = deepGreen * (0.18 + darkMassMask * 0.84 + lowerWeight * 0.25);
    color += bodyGreen * (0.30 + density * 0.56 + thickPatch * 0.22 + gelLobes * 0.18);
    color += luminousGreen * (brightMassMask * 0.34 + scatteredGlow * 0.18 + causticMask * 0.16 + lowerGreenHighlight * 0.08);
    color += cyanGreen * (cyanMassMask * 0.30 + upperLeftCyan * 0.16);
    color += cleanReflection * upperRightWhite * 0.10;
    color = mix(color, bodyGreen * 0.16 + cyanGreen * 0.025, clearPatch * 0.46);
    color *= 1.0 + reactivity * 0.18;

    float opacity = 0.18
        + density * 0.34
        + thickPatch * 0.12
        + gelLobes * 0.075
        + lowerWeight * 0.070
        + thicknessRim * 0.12
        + causticMask * 0.018
        + shaderBubbles * 0.010
        + commonSpecks * 0.006
        - clearPatch * 0.24;
    opacity = saturate(opacity) * visibility;

    float roughness = 0.22 + thickPatch * 0.080 + clearPatch * 0.040 + shaderBubbles * 0.030 - upperRightWhite * 0.040;
    float3 emissive = bodyGreen * (scatteredGlow * 0.16 + thicknessRim * 0.038 + faceGlowMask * 0.070);
    emissive += luminousGreen * (scatteredGlow * 0.30 + causticMask * 0.28 + brightMassMask * 0.060 + commonSpecks * 0.16 + brightSpecks * 0.72);
    emissive += cyanGreen * (cyanMassMask * 0.044 + upperLeftCyan * 0.038);
    emissive += cleanReflection * upperRightWhite * 0.030;
    emissive *= visibility * (0.84 + reactivity * 0.22);

    surface.set_base_color(half3(color * 0.74));
    surface.set_normal(tangentNormal);
    surface.set_roughness(half(saturate(roughness)));
    surface.set_metallic(half(0.0));
    surface.set_opacity(half(opacity));
    surface.set_emissive_color(half3(emissive));
}
