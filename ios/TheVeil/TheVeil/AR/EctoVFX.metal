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

float3 ectoArtworkGelGreen() {
    return float3(0.42, 1.00, 0.10);
}

float3 ectoArtworkGlowSource() {
    return float3(1.00, 1.78, 0.06);
}

float3 ectoArtworkGlowHot() {
    return float3(1.00, 2.20, 0.35);
}

float2 ectoCenteredUV(float2 uv) {
    return float2(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0);
}

float3 ectoBakedBodyColor(texture2d<half, access::sample> bodyTexture, float2 uv) {
    constexpr sampler bakedSampler(filter::linear, address::repeat);
    return float3(bodyTexture.sample(bakedSampler, uv).rgb);
}

float3 ectoBakedGelTint(float3 bakedColor) {
    float maxChannel = max(max(bakedColor.r, bakedColor.g), bakedColor.b);
    float minChannel = min(min(bakedColor.r, bakedColor.g), bakedColor.b);
    float saturation = maxChannel - minChannel;
    float whiteFragment = smoothstep(0.74, 0.98, maxChannel)
        * (1.0 - smoothstep(0.04, 0.20, saturation));
    float3 chroma = bakedColor / max(maxChannel, 0.001);
    float3 gelBiasedChroma = mix(ectoArtworkGelGreen(), chroma, 0.70);
    float3 colorTint = gelBiasedChroma * mix(0.42, 1.18, smoothstep(0.05, 0.95, maxChannel));
    float3 highlightTint = float3(0.78, 1.06, 0.42);
    return max(mix(colorTint, highlightTint, whiteFragment), float3(0.018, 0.026, 0.010));
}

float ectoBakedDensity(float3 bakedColor) {
    float maxChannel = max(max(bakedColor.r, bakedColor.g), bakedColor.b);
    float minChannel = min(min(bakedColor.r, bakedColor.g), bakedColor.b);
    float saturation = maxChannel - minChannel;
    float whiteFragment = smoothstep(0.74, 0.98, maxChannel)
        * (1.0 - smoothstep(0.04, 0.20, saturation));
    float density = saturate(maxChannel * 1.16 + saturation * 0.34);
    return mix(density, 0.35, whiteFragment);
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

float ectoViewVolumeThickness(float shapeRim, float3 normal, float3 viewDirection) {
    float viewFacingDepth = saturate(abs(dot(normal, viewDirection)));
    return saturate((1.0 - shapeRim) * viewFacingDepth);
}

float ectoDirectionalReflection(float3 normal, float3 viewDirection, float3 sourceDirection, float power) {
    float3 reflectedView = normalize(reflect(-viewDirection, normal));
    return pow(saturate(dot(reflectedView, normalize(sourceDirection))), power);
}

float ectoGrazingReflectionGate(float fresnel, float minValue, float maxValue) {
    return smoothstep(minValue, maxValue, fresnel);
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

    float2 uv = geometry.uv0();
    float2 p = ectoCenteredUV(uv);
    float3 normal = normalize(geometry.normal());
    float3 viewDirection = normalize(geometry.view_direction());
    auto bakedTexture = params.textures().custom();
    float3 bakedColor = ectoBakedBodyColor(bakedTexture, uv);
    float3 bakedTint = ectoBakedGelTint(bakedColor);
    float bakedDensity = ectoBakedDensity(bakedColor);

    float3 variantGreen = ectoVariantBody(variant);
    float3 shellTint = mix(variantGreen, ectoArtworkGelGreen(), 0.68);
    float3 deepAbsorbingGreen = float3(0.006, 0.055, 0.020);
    float3 cyanReflection = float3(0.08, 0.70, 0.65);
    float3 cleanReflection = float3(0.96, 1.00, 0.90);
    float3 yellowGreen = ectoArtworkGelGreen();
    float3 glowSource = ectoArtworkGlowSource();

    float shellDistance = length(p * float2(0.80, 0.70));
    float shapeRim = smoothstep(0.50, 1.08, shellDistance);
    float volumeThickness = ectoViewVolumeThickness(shapeRim, normal, viewDirection);
    float volumeAbsorption = pow(volumeThickness, 2.0);
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
    float3 absorptionColor = mix(yellowGreen, deepAbsorbingGreen, pow(volumeThickness, 1.5));
    float edgeScatter = pow(1.0 - volumeThickness, 3.0) * (0.25 + shapeRim * 0.75);
    float mainReflection = ectoDirectionalReflection(normal, viewDirection, float3(-0.42, 0.64, 0.58), 92.0);
    float streakReflection = ectoDirectionalReflection(normal, viewDirection, float3(-0.74, 0.22, 0.58), 34.0);
    float cyanReflectionHit = ectoDirectionalReflection(normal, viewDirection, float3(0.36, 0.58, 0.73), 42.0);
    float reflectionGate = ectoGrazingReflectionGate(fresnel, 0.06, 0.52);
    float directionalWhite = (mainReflection * 1.15 + streakReflection * upperRightWhite * 0.46)
        * reflectionGate
        * (0.34 + flowingHighlight * 0.26 + upperRightWhite * 0.40);
    float directionalCyan = cyanReflectionHit * reflectionGate * (0.28 + upperLeftCyan * 0.72);

    float2 gradient = ectoFlowGradient(p, time, phase, 1.20, 0.038);
    gradient += float2(
        sin(time * 0.075 + p.y * 2.1 + phase) * 0.055,
        cos(time * 0.068 + p.x * 1.8 - phase) * 0.045
    );
    float3 tangentNormal = normalize(float3(gradient * 0.058, 1.0));

    float3 baseColor = shellTint * (
        thicknessRim * 0.026 +
        shapeRim * 0.008 +
        broadFlow * 0.006 +
        lowerDensity * 0.003 +
        bubbles * 0.004
    );
    baseColor += cyanReflection * (upperLeftCyan * 0.08 + directionalCyan * 0.12);
    baseColor += yellowGreen * lowerGreen * 0.034;
    baseColor = mix(
        baseColor,
        absorptionColor * (0.026 + volumeAbsorption * 0.022) + shellTint * 0.006,
        0.12
    );
    baseColor += cleanReflection * directionalWhite * 0.12;
    baseColor *= bakedTint;
    baseColor += bakedTint * (flowingHighlight * 0.006 + bubbles * 0.010);

    float opacity = 0.004
        + volumeAbsorption * 0.010
        + edgeThickness * 0.008
        + broadFlow * 0.0015
        + flowingHighlight * 0.0015
        + reactivity * 0.0015;
    opacity *= mix(0.52, 1.18, bakedDensity);
    opacity *= visibility;

    float3 emissive = shellTint * (thicknessRim * 0.004 + lowerDensity * 0.002 + bubbles * 0.003);
    emissive += cyanReflection * upperLeftCyan * 0.012;
    emissive += glowSource * lowerGreen * 0.060;
    emissive += glowSource * edgeScatter * 0.18;
    emissive *= mix(bakedTint, bakedTint * 1.35, 0.74);
    emissive *= visibility * (0.94 + reactivity * 0.16);

    surface.set_base_color(half3(baseColor));
    surface.set_normal(tangentNormal);
    surface.set_roughness(half(1.0));
    surface.set_metallic(half(0.0));
    surface.set_clearcoat(half(0.0));
    surface.set_clearcoat_roughness(half(1.0));
    surface.set_clearcoat_normal(half3(tangentNormal));
    surface.set_opacity(half(opacity));
    surface.set_emissive_color(half3(emissive));
}

void ectoReflectiveLayerSurface(realitykit::surface_parameters params, float role) {
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

    float3 gelGreen = mix(ectoVariantBody(variant), ectoArtworkGelGreen(), 0.74);
    float3 glowSource = ectoArtworkGlowSource();
    float3 cyanReflection = float3(0.08, 0.70, 0.65);
    float3 cleanReflection = float3(0.96, 1.00, 0.90);

    float shellDistance = length(p * float2(0.80, 0.70));
    float shapeRim = smoothstep(0.50, 1.08, shellDistance);
    float fresnel = saturate(1.0 - abs(dot(normal, viewDirection)));
    float edge = pow(fresnel, 1.7);
    float flow = ectoBroadFlow(p, time, phase);
    float sparseDetail = ectoSparseBubbles(p, time, phase);

    float lobeRole = 1.0 - step(0.5, role);
    float bubbleRole = step(0.5, role) * (1.0 - step(1.5, role));
    float corneaRole = step(1.5, role);

    float mainReflection = ectoDirectionalReflection(normal, viewDirection, float3(-0.42, 0.64, 0.58), 80.0);
    float broadReflection = ectoDirectionalReflection(normal, viewDirection, float3(-0.66, 0.18, 0.72), 26.0);
    float cyanHit = ectoDirectionalReflection(normal, viewDirection, float3(0.34, 0.56, 0.76), 34.0);
    float reflectionGate = ectoGrazingReflectionGate(fresnel, 0.05, 0.55);

    float lobeWhite = (mainReflection * 0.26 + broadReflection * 0.08) * reflectionGate;
    float bubbleWhite = (mainReflection * 1.10 + broadReflection * 0.32) * reflectionGate;
    float corneaWhite = (mainReflection * 1.42 + broadReflection * 0.18) * smoothstep(0.0, 0.38, fresnel);
    float whiteHighlight = lobeWhite * lobeRole + bubbleWhite * bubbleRole + corneaWhite * corneaRole;
    float cyanHighlight = cyanHit * reflectionGate * (0.18 + edge * 0.82);

    float roleTint = lobeRole * 0.040 + bubbleRole * 0.010 + corneaRole * 0.006;
    float roleEdge = lobeRole * 0.018 + bubbleRole * 0.012 + corneaRole * 0.006;
    float roleOpacity = lobeRole * 0.020 + bubbleRole * 0.006 + corneaRole * 0.010;

    float3 baseColor = gelGreen * (roleTint + edge * roleEdge + flow * 0.004);
    baseColor += cyanReflection * (cyanHighlight * (0.08 + bubbleRole * 0.08) + sparseDetail * bubbleRole * 0.010);
    baseColor += cleanReflection * whiteHighlight * (0.05 + bubbleRole * 0.10 + corneaRole * 0.16);

    float opacity = roleOpacity
        + edge * (lobeRole * 0.026 + bubbleRole * 0.030 + corneaRole * 0.012)
        + whiteHighlight * (lobeRole * 0.020 + bubbleRole * 0.16 + corneaRole * 0.24)
        + sparseDetail * bubbleRole * 0.018
        + shapeRim * lobeRole * 0.006
        + reactivity * 0.003;
    opacity *= visibility;

    float2 gradient = ectoFlowGradient(p, time, phase, 1.05 + bubbleRole * 0.80, 0.032);
    float3 tangentNormal = normalize(float3(gradient * (0.022 + lobeRole * 0.018), 1.0));

    float3 emissive = glowSource * edge * (lobeRole * 0.016 + bubbleRole * 0.008);
    emissive += cyanReflection * cyanHighlight * (lobeRole * 0.012 + bubbleRole * 0.010);
    emissive *= visibility * (0.70 + reactivity * 0.16);

    surface.set_base_color(half3(0.0));
    surface.set_normal(tangentNormal);
    surface.set_roughness(half(1.0));
    surface.set_metallic(half(0.0));
    surface.set_clearcoat(half(0.0));
    surface.set_clearcoat_roughness(half(1.0));
    surface.set_clearcoat_normal(half3(tangentNormal));
    surface.set_opacity(half(0.0));
    surface.set_emissive_color(half3(0.0));
}

[[visible]]
void ectoLobeMembraneSurface(realitykit::surface_parameters params) {
    ectoReflectiveLayerSurface(params, 0.0);
}

[[visible]]
void ectoBubbleSurface(realitykit::surface_parameters params) {
    ectoReflectiveLayerSurface(params, 1.0);
}

[[visible]]
void ectoCorneaSurface(realitykit::surface_parameters params) {
    ectoReflectiveLayerSurface(params, 2.0);
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

    float2 uv = geometry.uv0();
    float2 p = ectoCenteredUV(uv);
    float3 normal = normalize(geometry.normal());
    float3 viewDirection = normalize(geometry.view_direction());
    auto bakedTexture = params.textures().custom();
    float3 bakedColor = ectoBakedBodyColor(bakedTexture, uv);
    float3 bakedTint = ectoBakedGelTint(bakedColor);
    float bakedDensity = ectoBakedDensity(bakedColor);

    float3 deepGreen = float3(0.0015, 0.012, 0.004);
    float3 bodyGreen = float3(0.010, 0.048, 0.006);
    float3 luminousGreen = ectoArtworkGelGreen();
    float3 glowSource = ectoArtworkGlowSource();
    float3 glowHot = ectoArtworkGlowHot();
    float3 cyanGreen = float3(0.08, 0.70, 0.65);
    float3 coreGlowColor = mix(glowSource, ectoVariantCore(variant), step(0.5, variant) * 0.35);

    float shellDistance = length(p * float2(0.80, 0.70));
    float shapeRim = smoothstep(0.50, 1.08, shellDistance);
    float volumeThickness = ectoViewVolumeThickness(shapeRim, normal, viewDirection);
    float volumeAbsorption = pow(volumeThickness, 2.0);
    float fresnel = saturate(1.0 - abs(dot(normal, viewDirection)));
    float thicknessRim = saturate(shapeRim * 0.55 + pow(fresnel, 1.5) * 0.65);
    float lowerWeight = ectoLowerWeight(p);
    float centerMass = ectoCenterMass(p);
    float interior = ectoInteriorMask(p);

    float2 warpedP = p + ectoLargeWarp(p, time, phase);
    float internalDensityPattern = ectoLargeCloud(warpedP, time, phase, 0.85, 0.015, 0.0);
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

    float hotGlow = exp(-length((p - float2(0.0, -0.36)) / float2(0.42, 0.34)) * 1.42);

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
    float causticMask = smoothstep(0.72, 0.92, causticBase)
        * (0.40 + thickPatch * 0.36 + lowerWeight * 0.22 + thicknessRim * 0.36 + faceGlowMask * 0.44)
        * (1.0 - clearPatch * 0.38)
        * (0.42 + interior * 0.58);
    float causticVeins = smoothstep(0.84, 0.972, causticBase)
        * (0.36 + thicknessRim * 0.36 + lowerWeight * 0.18 + faceGlowMask * 0.42)
        * (1.0 - clearPatch * 0.24)
        * interior;

    float speckA = spectralNoise(float3(warpedP * 17.5 + float2(0.7, 4.2), time * 0.040 + phase * 0.23));
    float speckB = spectralNoise(float3(warpedP * 29.0 + float2(6.1, 1.8), -time * 0.033 + phase * 0.47));
    float commonSpecks = smoothstep(0.926, 0.992, speckA * 0.70 + speckB * 0.30) * interior;
    float brightSpecks = smoothstep(0.970, 0.998, speckB) * interior;

    float upperLeftCyan = ectoEllipseMask(p, float2(-0.34, 0.38), float2(0.32, 0.088), 0.55)
        * (0.20 + thicknessRim * 0.52);
    float upperRightWhite = ectoEllipseMask(p, float2(0.32, 0.18), float2(0.17, 0.050), 0.40)
        * (0.32 + fresnel * 0.44);
    float lowerGreenHighlight = ectoEllipseMask(p, float2(-0.12, -0.60), float2(0.34, 0.070), 0.52)
        * (0.22 + lowerWeight * 0.54);

    float hugeThickness = volumeAbsorption * 0.38
        + lowerWeight * 0.18
        + centerMass * 0.12
        + thickPatch * 0.18
        + darkMassMask * 0.24
        + gelLobes * 0.060
        + internalDensityPattern * 0.035
        - clearPatch * 0.42
        + reactivity * 0.012;
    hugeThickness = saturate(hugeThickness);
    float darkDepth = saturate(hugeThickness * 0.82 + darkMassMask * 0.32 + lowerWeight * 0.10);
    float brightStructure = saturate(causticVeins + causticMask * 0.24 + brightMassMask * 0.20);
    float particleField = saturate(commonSpecks * 0.55 + brightSpecks);

    float2 gradient = ectoFlowGradient(p, time, phase + 1.9, 0.92, 0.028);
    gradient += float2(causticVeins - 0.5, hugeThickness - clearPatch) * 0.030;
    float3 tangentNormal = normalize(float3(gradient * 0.044, 1.0));

    float edgeScatter = pow(1.0 - volumeThickness, 3.0) * (0.30 + shapeRim * 0.70);
    float lightEscape = pow(saturate(1.0 - volumeThickness), 1.70);
    float localScatter = saturate(hotGlow * 0.58 + faceGlowMask * 0.26 + lowerGreenHighlight * 0.18);
    localScatter *= 0.34 + brightStructure * 0.42 + edgeScatter * 0.20;

    float3 color = bodyGreen;
    color += deepGreen * (darkDepth * 0.48 + hugeThickness * 0.24);
    color += luminousGreen * (causticVeins * 0.18 + causticMask * 0.032 + lowerGreenHighlight * 0.020);
    color += glowSource * (localScatter * 0.14 + brightStructure * 0.045 + particleField * 0.020);
    color += glowHot * (hotGlow * 0.050 + brightSpecks * 0.040) * (0.40 + brightStructure * 0.60);
    color += cyanGreen * (cyanMassMask * 0.10 + upperLeftCyan * 0.26 + upperRightWhite * 0.010);
    color = mix(color, bodyGreen + cyanGreen * 0.018, clearPatch * 0.78);
    color += coreGlowColor * localScatter * 0.050 * lightEscape;
    color *= bakedTint;
    color += bakedTint * (brightStructure * 0.030 + causticVeins * 0.024 + particleField * 0.012);
    color *= 1.0 + reactivity * 0.08;

    float opacity = 0.006
        + hugeThickness * 0.072
        + darkMassMask * 0.012
        + lowerWeight * 0.010
        + centerMass * 0.006
        + gelLobes * 0.006
        + causticVeins * 0.006
        + particleField * 0.002
        - clearPatch * 0.052;
    opacity *= mix(0.58, 1.16, bakedDensity);
    opacity = saturate(opacity) * visibility;

    float roughness = 0.095 + hugeThickness * 0.026 + clearPatch * 0.014 - upperRightWhite * 0.026;
    float3 emissive = glowSource * (
        localScatter * 1.08
        + causticVeins * 1.42
        + causticMask * 0.22
        + edgeScatter * 0.26
        + commonSpecks * 0.22
        + brightSpecks * 1.36
    );
    emissive += glowHot * (hotGlow * 0.84 + brightSpecks * 0.82 + faceGlowMask * 0.16);
    emissive += luminousGreen * (brightMassMask * 0.080 + lowerGreenHighlight * 0.10);
    emissive += cyanGreen * (upperLeftCyan * 0.048 + cyanMassMask * 0.024);
    emissive *= mix(bakedTint, bakedTint * 1.36, 0.78);
    emissive += bakedTint * (causticVeins * 0.16 + brightSpecks * 0.18) * visibility;
    emissive *= visibility * (0.98 + reactivity * 0.28);

    surface.set_base_color(half3(color));
    surface.set_normal(tangentNormal);
    surface.set_roughness(half(saturate(roughness)));
    surface.set_metallic(half(0.0));
    surface.set_opacity(half(opacity));
    surface.set_emissive_color(half3(emissive));
}
