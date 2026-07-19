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

struct EctoSourcePaintSample {
    float3 color;
    float coverage;
};

float ectoBodyX(float3 position) {
    return saturate((position.x + 0.50025) / 1.00049);
}

float ectoBodyY(float3 position) {
    return saturate(1.0 - ((position.y + 0.46409) / 0.91372));
}

float ectoBodyZ(float3 position) {
    return saturate((position.z + 0.36228) / 0.72269);
}

float2 ectoAtlasTileUV(float2 localUV, float2 tile, float4 contentRect) {
    float2 rectMin = contentRect.xy + float2(0.002);
    float2 rectMax = contentRect.zw - float2(0.002);
    float2 tileUV = mix(rectMin, rectMax, saturate(localUV));
    return (tile + tileUV) / float2(3.0, 2.0);
}

float4 ectoSamplePaintTile(
    texture2d<half, access::sample> sourceAtlas,
    float2 localUV,
    float2 tile,
    float4 contentRect
) {
    constexpr sampler paintSampler(filter::linear, address::clamp_to_edge);
    return float4(sourceAtlas.sample(paintSampler, ectoAtlasTileUV(localUV, tile, contentRect)));
}

EctoSourcePaintSample ectoSourcePaint(
    texture2d<half, access::sample> sourceAtlas,
    float3 position,
    float3 normal,
    float2 uv
) {
    float x = ectoBodyX(position);
    float y = ectoBodyY(position);
    float z = ectoBodyZ(position);

    float4 front = ectoSamplePaintTile(
        sourceAtlas,
        float2(x, y),
        float2(0.0, 0.0),
        float4(0.0877, 0.0861, 0.9115, 0.8931)
    );
    float4 right = ectoSamplePaintTile(
        sourceAtlas,
        float2(1.0 - z, y),
        float2(1.0, 0.0),
        float4(0.0750, 0.0702, 0.9011, 0.9211)
    );
    float4 back = ectoSamplePaintTile(
        sourceAtlas,
        float2(1.0 - x, y),
        float2(2.0, 0.0),
        float4(0.0885, 0.0694, 0.9027, 0.9091)
    );
    float4 left = ectoSamplePaintTile(
        sourceAtlas,
        float2(z, y),
        float2(0.0, 1.0),
        float4(0.0997, 0.0718, 0.9051, 0.9187)
    );
    float4 fallback = ectoSamplePaintTile(
        sourceAtlas,
        saturate(uv),
        float2(1.0, 1.0),
        float4(0.0, 0.0, 0.9992, 0.9992)
    );

    float3 n = normalize(normal);
    float frontView = pow(saturate(n.z), 1.45);
    float backView = pow(saturate(-n.z), 1.45);
    float rightView = pow(saturate(n.x), 1.35);
    float leftView = pow(saturate(-n.x), 1.35);

    float frontRegion = smoothstep(-0.24, 0.18, position.z);
    float backRegion = smoothstep(-0.24, 0.18, -position.z);
    float rightRegion = smoothstep(0.16, 0.43, position.x);
    float leftRegion = smoothstep(0.16, 0.43, -position.x);

    float frontWeight = max(frontView, frontRegion * 0.34) * smoothstep(0.18, 0.82, front.a);
    float rightWeight = max(rightView, rightRegion * 0.62) * smoothstep(0.18, 0.82, right.a);
    float backWeight = max(backView, backRegion * 0.30) * smoothstep(0.18, 0.82, back.a);
    float leftWeight = max(leftView, leftRegion * 0.62) * smoothstep(0.18, 0.82, left.a);

    float sourceWeight = frontWeight + rightWeight + backWeight + leftWeight;
    float3 sourceColor = (
        front.rgb * frontWeight
        + right.rgb * rightWeight
        + back.rgb * backWeight
        + left.rgb * leftWeight
    ) / max(sourceWeight, 0.0001);

    float fallbackCoverage = smoothstep(0.015, 0.12, max(max(fallback.r, fallback.g), fallback.b));
    float fallbackBlend = 1.0 - smoothstep(0.08, 0.34, sourceWeight);
    float3 color = mix(sourceColor, fallback.rgb, fallbackBlend);
    float coverage = saturate(sourceWeight + fallbackCoverage * fallbackBlend * 0.55);

    EctoSourcePaintSample paint;
    paint.color = max(color, float3(0.0));
    paint.coverage = coverage;
    return paint;
}

float ectoMaxChannel(float3 color) {
    return max(max(color.r, color.g), color.b);
}

float ectoMinChannel(float3 color) {
    return min(min(color.r, color.g), color.b);
}

float ectoColorSaturation(float3 color) {
    return ectoMaxChannel(color) - ectoMinChannel(color);
}

float ectoSourceWhiteMask(float3 color) {
    float maxChannel = ectoMaxChannel(color);
    float saturation = ectoColorSaturation(color);
    return smoothstep(0.72, 0.98, maxChannel)
        * (1.0 - smoothstep(0.035, 0.20, saturation));
}

float3 ectoProjectedPaintColor(float3 sourceColor) {
    float maxChannel = ectoMaxChannel(sourceColor);
    float whiteMask = ectoSourceWhiteMask(sourceColor);
    float3 gelatinHighlightTint = float3(0.70, 1.02, 0.32) * max(maxChannel, 0.10);
    return max(mix(sourceColor, gelatinHighlightTint, whiteMask * 0.86), float3(0.0));
}

float ectoProjectedCoverage(float3 sourceColor) {
    return smoothstep(0.015, 0.10, ectoMaxChannel(sourceColor));
}

float ectoProjectedYellowGlow(float3 paintColor) {
    float warmYellow = min(paintColor.r * 0.92, paintColor.g) - paintColor.b * 0.34;
    return smoothstep(0.20, 0.78, warmYellow)
        * smoothstep(0.16, 0.88, ectoMaxChannel(paintColor));
}

float ectoProjectedCyanMask(float3 paintColor) {
    return smoothstep(0.10, 0.48, paintColor.b)
        * smoothstep(0.14, 0.66, paintColor.g)
        * (1.0 - smoothstep(0.52, 0.94, paintColor.r));
}

float ectoProjectedDarkGreen(float3 paintColor) {
    float maxChannel = ectoMaxChannel(paintColor);
    float greenBias = paintColor.g - max(paintColor.r, paintColor.b) * 0.42;
    return smoothstep(0.05, 0.40, greenBias)
        * (1.0 - smoothstep(0.56, 0.96, maxChannel));
}

float ectoProjectedDensity(float3 paintColor) {
    float maxChannel = ectoMaxChannel(paintColor);
    float saturation = ectoColorSaturation(paintColor);
    float yellowGlow = ectoProjectedYellowGlow(paintColor);
    float darkGreen = ectoProjectedDarkGreen(paintColor);
    return saturate(maxChannel * 0.44 + saturation * 0.22 + yellowGlow * 0.16 + darkGreen * 0.28);
}

float ectoSoftNoise(float3 p) {
    float value = spectralNoise(p) * 0.68;
    value += spectralNoise(p * 1.86 + float3(9.2, 4.7, 2.1)) * 0.24;
    value += spectralNoise(p * 2.72 + float3(1.6, 8.4, 5.8)) * 0.08;
    return value;
}

float ectoLowerWeight(float2 p) {
    return 1.0 - smoothstep(-0.90, 0.18, p.y);
}

float ectoCenterMass(float2 p) {
    return 1.0 - smoothstep(0.10, 0.88, length(p * float2(0.78, 0.72)));
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
    float3 modelPosition = geometry.model_position();
    auto sourceAtlas = params.textures().custom();
    EctoSourcePaintSample sourcePaint = ectoSourcePaint(sourceAtlas, modelPosition, normal, uv);
    float3 sourceColor = sourcePaint.color;
    float3 paintColor = ectoProjectedPaintColor(sourceColor);
    float sourceCoverage = sourcePaint.coverage;
    float paintDensity = ectoProjectedDensity(paintColor);
    float yellowGlow = ectoProjectedYellowGlow(paintColor);
    float cyanMask = ectoProjectedCyanMask(paintColor);

    float3 shellTint = mix(ectoArtworkGelGreen(), ectoVariantBody(variant), 0.08);
    float3 cyanReflection = float3(0.08, 0.70, 0.65);
    float3 cleanReflection = float3(0.96, 1.00, 0.90);
    float3 glowSource = ectoArtworkGlowSource();

    float fresnel = saturate(1.0 - abs(dot(normal, viewDirection)));
    float edge = pow(fresnel, 2.2);

    float mainReflection = ectoDirectionalReflection(normal, viewDirection, float3(-0.42, 0.64, 0.58), 92.0);
    float streakReflection = ectoDirectionalReflection(normal, viewDirection, float3(-0.74, 0.22, 0.58), 46.0);
    float cyanReflectionHit = ectoDirectionalReflection(normal, viewDirection, float3(0.36, 0.58, 0.73), 42.0);
    float reflectionGate = ectoGrazingReflectionGate(fresnel, 0.10, 0.70);
    float directionalWhite = (mainReflection * 1.25 + streakReflection * 0.42)
        * reflectionGate
        * (0.38 + sourceCoverage * 0.22 + yellowGlow * 0.18);
    float directionalCyan = cyanReflectionHit * reflectionGate * (0.22 + cyanMask * 0.62);

    float2 gradient = ectoFlowGradient(p, time, phase, 0.72, 0.010);
    gradient += float2(
        sin(time * 0.58 + p.y * 2.1 + phase) * 0.010,
        cos(time * 0.52 + p.x * 1.8 - phase) * 0.009
    );
    float3 tangentNormal = normalize(float3(gradient * (0.014 + reactivity * 0.010), 1.0));

    float3 baseColor = shellTint * (0.0015 + edge * 0.0025);
    baseColor += paintColor * (0.004 + paintDensity * 0.010 + sourceCoverage * 0.003);
    baseColor += cyanReflection * (directionalCyan * 0.070 + cyanMask * 0.010);
    baseColor += cleanReflection * directionalWhite * 0.090;

    float opacity = 0.0018
        + paintDensity * 0.0070
        + sourceCoverage * 0.0025
        + edge * 0.0028
        + directionalWhite * 0.0045
        + directionalCyan * 0.0028
        + reactivity * 0.0012;
    opacity *= visibility * (0.70 + sourceCoverage * 0.30);

    float3 emissive = paintColor * (yellowGlow * 0.016 + paintDensity * 0.004);
    emissive += cyanReflection * directionalCyan * 0.012;
    emissive += glowSource * yellowGlow * 0.026;
    emissive += cleanReflection * directionalWhite * 0.006;
    emissive *= visibility * (0.94 + reactivity * 0.16);

    surface.set_base_color(half3(baseColor));
    surface.set_normal(tangentNormal);
    surface.set_roughness(half(0.045));
    surface.set_metallic(half(0.0));
    surface.set_clearcoat(half(0.28));
    surface.set_clearcoat_roughness(half(0.020));
    surface.set_clearcoat_normal(half3(tangentNormal));
    surface.set_opacity(half(opacity));
    surface.set_emissive_color(half3(emissive));
}

void ectoReflectiveLayerSurface(realitykit::surface_parameters params) {
    auto geometry = params.geometry();
    auto surface = params.surface();

    surface.set_base_color(half3(0.0));
    surface.set_normal(normalize(geometry.normal()));
    surface.set_roughness(half(1.0));
    surface.set_metallic(half(0.0));
    surface.set_clearcoat(half(0.0));
    surface.set_clearcoat_roughness(half(1.0));
    surface.set_clearcoat_normal(half3(normalize(geometry.normal())));
    surface.set_opacity(half(0.0));
    surface.set_emissive_color(half3(0.0));
}

[[visible]]
void ectoLobeMembraneSurface(realitykit::surface_parameters params) {
    ectoReflectiveLayerSurface(params);
}

[[visible]]
void ectoBubbleSurface(realitykit::surface_parameters params) {
    ectoReflectiveLayerSurface(params);
}

[[visible]]
void ectoCorneaSurface(realitykit::surface_parameters params) {
    ectoReflectiveLayerSurface(params);
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
    float3 modelPosition = geometry.model_position();
    auto sourceAtlas = params.textures().custom();
    EctoSourcePaintSample sourcePaint = ectoSourcePaint(sourceAtlas, modelPosition, normal, uv);
    float3 sourceColor = sourcePaint.color;
    float3 paintColor = ectoProjectedPaintColor(sourceColor);
    float sourceCoverage = sourcePaint.coverage;
    float paintDensity = ectoProjectedDensity(paintColor);
    float yellowGlow = ectoProjectedYellowGlow(paintColor);
    float cyanMask = ectoProjectedCyanMask(paintColor);
    float darkGreen = ectoProjectedDarkGreen(paintColor);

    float3 deepAbsorption = float3(0.0008, 0.010, 0.003);
    float3 clearGelTint = float3(0.004, 0.016, 0.004);
    float3 glowSource = ectoArtworkGlowSource();
    float3 glowHot = ectoArtworkGlowHot();
    float3 cyanGreen = float3(0.08, 0.70, 0.65);

    float shellDistance = length(p * float2(0.80, 0.70));
    float shapeRim = smoothstep(0.50, 1.08, shellDistance);
    float fresnel = saturate(1.0 - abs(dot(normal, viewDirection)));
    float lowerWeight = ectoLowerWeight(p);
    float centerMass = ectoCenterMass(p);

    float staticSpeckSeed = spectralNoise(float3(uv * 72.0 + float2(variant * 1.7, variant * 3.1), variant * 4.6));
    float fineSpecks = smoothstep(0.986, 0.998, staticSpeckSeed)
        * sourceCoverage
        * (0.24 + yellowGlow * 0.76);
    float pulse = 1.0 + sin(time * 1.18 + phase) * 0.022 * (0.35 + reactivity);

    float2 gradient = ectoFlowGradient(p, time, phase + 1.9, 0.70, 0.010);
    gradient += float2(
        sin(time * 0.52 + p.y * 2.0 + phase) * 0.008,
        cos(time * 0.47 + p.x * 1.7 - phase) * 0.007
    );
    float3 tangentNormal = normalize(float3(gradient * (0.016 + reactivity * 0.012), 1.0));

    float3 paintedGel = paintColor * (0.34 + paintDensity * 0.26 + yellowGlow * 0.16);
    paintedGel = mix(paintedGel, deepAbsorption + paintColor * 0.16, darkGreen * 0.42);
    paintedGel += clearGelTint * (1.0 - sourceCoverage) * 0.012;
    paintedGel += glowSource * yellowGlow * 0.060;
    paintedGel += glowHot * yellowGlow * centerMass * 0.030;
    paintedGel += cyanGreen * cyanMask * (0.075 + fresnel * 0.030);
    paintedGel += paintColor * fineSpecks * 0.070;

    float edgeLightEscape = pow(saturate(1.0 - centerMass), 1.3) * (0.20 + shapeRim * 0.46);
    float3 color = paintedGel * pulse;
    color += glowSource * yellowGlow * edgeLightEscape * 0.040;
    color *= 1.0 + reactivity * 0.06;

    float opacity = 0.0035
        + sourceCoverage * 0.012
        + paintDensity * 0.088
        + darkGreen * 0.048
        + yellowGlow * 0.030
        + cyanMask * 0.014
        + lowerWeight * 0.010
        + centerMass * 0.006
        + fineSpecks * 0.004
        + reactivity * 0.004;
    opacity *= 0.90 + lowerWeight * 0.12 + darkGreen * 0.10;
    opacity = saturate(opacity) * visibility;

    float roughness = 0.085 + paintDensity * 0.035 - yellowGlow * 0.020 + reactivity * 0.010;
    float3 emissive = paintColor * (yellowGlow * 0.36 + paintDensity * 0.035);
    emissive += glowSource * (yellowGlow * 0.46 + fineSpecks * 0.16);
    emissive += glowHot * yellowGlow * centerMass * 0.14;
    emissive += cyanGreen * cyanMask * 0.070;
    emissive += ectoVariantCore(variant) * yellowGlow * 0.035;
    emissive *= visibility * pulse * (0.62 + reactivity * 0.26);

    surface.set_base_color(half3(color));
    surface.set_normal(tangentNormal);
    surface.set_roughness(half(saturate(roughness)));
    surface.set_metallic(half(0.0));
    surface.set_opacity(half(opacity));
    surface.set_emissive_color(half3(emissive));
}
