#include <metal_stdlib>
#include <RealityKit/RealityKit.h>
#include "SpectralNoise.metalh"
using namespace metal;

// Explode-proof glow engine: abs(d) guarantees the exponent cannot go positive.
float safeGlow(float d, float intensity, float falloff) {
    return intensity * exp(-abs(d) * falloff);
}

// Ridged multifractal noise for sharp lightning filaments.
float electricalNoise(float3 p) {
    float n = spectralFBM(p);
    return 1.0 - abs(n - 0.5) * 2.0;
}

// Controlled domain warping that deforms organically without ripping the canvas apart.
float2 organicWarp(float2 p, float time, float phase) {
    float3 coord = float3(p * 2.2, time * 0.4 + phase);
    float2 shift = float2(
        spectralFBM(coord),
        spectralFBM(coord + float3(1.4, 3.8, 2.1))
    ) - 0.5;
    return p + shift * 0.09;
}

float sdSegment(float2 p, float2 a, float2 b) {
    float2 pa = p - a;
    float2 ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.00001), 0.0, 1.0);
    return length(pa - ba * h);
}

float ellipseMetric(float2 p, float2 center, float2 radius) {
    return length((p - center) / radius);
}

[[visible]]
void specterGeometry(realitykit::geometry_parameters params) {
    auto geometry = params.geometry();
    float4 controls = params.uniforms().custom_parameter();
    float time = params.uniforms().time();
    float phase = controls.x;
    float layer = controls.y;

    float2 uv = geometry.uv0();
    // Keep orientation upright.
    float2 p = float2(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0);
    p.x *= 0.72;

    float edgeMask = smoothstep(0.1, 0.85, 1.0 - length(p * float2(0.9, 0.7)));

    // Smooth vertex waving animated upwards.
    float wave = spectralFBM(float3(p * 3.5, time * 0.5 - p.y * 2.0 + phase));
    float3 offset = float3(0.0, 0.0, (wave - 0.5) * 0.045 * edgeMask);

    offset *= layer < 0.5 ? 1.2 : 0.35;
    geometry.set_model_position_offset(offset);
}

[[visible]]
void specterSurface(realitykit::surface_parameters params) {
    auto geometry = params.geometry();
    auto surface = params.surface();
    float4 controls = params.uniforms().custom_parameter();
    float time = params.uniforms().time();
    float phase = controls.x;
    float layer = controls.y;

    float2 uv = geometry.uv0();
    float2 baseP = float2(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0);
    baseP.x *= 0.72;

    // 1. HARD EDGE PROTECTION: clean fadeout to prevent bounding box panels.
    float canvasBoundary = smoothstep(0.0, 0.35, 1.0 - length(baseP * float2(0.85, 0.62)));

    // 2. BACKGROUND COSMIC SMOKE: animated upward like the reference shot.
    float3 smokeCoord = float3(baseP * 2.8, time * 0.6 - baseP.y * 1.5);
    float smokeNoise = spectralFBM(smokeCoord);
    float smokeShroud = smoothstep(0.25, 0.8, 1.0 - length(baseP * float2(0.95, 0.72))) * canvasBoundary;

    // 3. FACIAL GEOMETRY WITH ORGANIC DEFORMATION.
    float2 faceP = organicWarp(baseP, time * 0.8, phase);
    faceP.y += 0.05;

    // Skull and jaw contours.
    float skullRing = abs(ellipseMetric(faceP, float2(0.0, 0.15), float2(0.44, 0.68)) - 1.0);
    float skullEnergy = safeGlow(skullRing, 1.0, 24.0);

    float leftCheek = safeGlow(sdSegment(faceP, float2(-0.40, 0.18), float2(-0.22, -0.32)), 0.9, 20.0);
    float rightCheek = safeGlow(sdSegment(faceP, float2(0.40, 0.18), float2(0.22, -0.32)), 0.9, 20.0);
    float leftJaw = safeGlow(sdSegment(faceP, float2(-0.22, -0.32), float2(-0.08, -0.58)), 0.9, 22.0);
    float rightJaw = safeGlow(sdSegment(faceP, float2(0.22, -0.32), float2(0.08, -0.58)), 0.9, 22.0);

    float angryBrow = max(
        safeGlow(sdSegment(faceP, float2(-0.32, 0.35), float2(-0.04, 0.22)), 1.3, 16.0),
        safeGlow(sdSegment(faceP, float2(0.04, 0.22), float2(0.32, 0.35)), 1.3, 16.0)
    );

    // Blinding eye orbs.
    float2 leftEyeCenter = faceP + float2(0.18, -0.22);
    float2 rightEyeCenter = faceP + float2(-0.18, -0.22);
    float leftEyeDist = length(leftEyeCenter * float2(1.0, 1.25));
    float rightEyeDist = length(rightEyeCenter * float2(1.0, 1.25));

    float eyeCores = safeGlow(leftEyeDist, 3.5, 40.0) + safeGlow(rightEyeDist, 3.5, 40.0);
    float eyeHalos = safeGlow(leftEyeDist, 1.5, 10.0) + safeGlow(rightEyeDist, 1.5, 10.0);

    // Nasal cavity.
    float noseL = safeGlow(sdSegment(faceP, float2(0.0, 0.15), float2(-0.05, -0.02)), 0.9, 24.0);
    float noseR = safeGlow(sdSegment(faceP, float2(0.0, 0.15), float2(0.05, -0.02)), 0.9, 24.0);
    float noseB = safeGlow(sdSegment(faceP, float2(-0.05, -0.02), float2(0.05, -0.02)), 0.9, 24.0);
    float noseCavity = max(max(noseL, noseR), noseB);

    // 4. THE MENACING MOUTH VOID AND SHARP FANGS.
    float mouthMetric = ellipseMetric(faceP, float2(0.0, -0.32), float2(0.18, 0.28));
    float mouthVoidMask = 1.0 - smoothstep(0.85, 1.05, mouthMetric);
    float mouthOutline = safeGlow(abs(mouthMetric - 1.0), 1.2, 18.0);

    // Jagged procedural fang patterns modulated safely inside the mouth void.
    float upperFangs = smoothstep(-0.12, -0.32, faceP.y) * abs(sin(faceP.x * 34.0 + smokeNoise * 2.0));
    float lowerFangs = smoothstep(-0.54, -0.36, faceP.y) * abs(sin(faceP.x * 28.0 - smokeNoise * 2.0));
    float fangGlow = safeGlow(1.0 - max(upperFangs, lowerFangs), 1.3, 15.0) * mouthVoidMask;

    // 5. INTENSE ELECTRIC ARCS: lightning filaments tracing down the center.
    float3 electricCoord = float3(baseP * 6.5, time * 1.4);
    float electricFilaments = smoothstep(0.72, 0.96, electricalNoise(electricCoord)) * smokeShroud;

    // Combine features safely into a structured intensity curve.
    float structuralFeatures =
        skullEnergy * 0.35
        + max(leftCheek, rightCheek) * 0.75
        + max(leftJaw, rightJaw) * 0.75
        + angryBrow * 1.2
        + noseCavity * 0.85
        + mouthOutline * 1.0
        + fangGlow * 1.1;

    // 6. OBSIDIAN NIGHTMARE COLOR PALETTE.
    float3 obsidianVoid = float3(0.015, 0.002, 0.035);
    float3 darkSpecterPurp = float3(0.16, 0.01, 0.36);
    float3 ionizedViolet = float3(0.52, 0.04, 0.92);
    float3 plasmaCyan = float3(0.00, 0.78, 1.00);
    float3 whiteHotCore = float3(0.96, 0.92, 1.00);

    // Color assembly.
    float3 finalColor = mix(obsidianVoid, darkSpecterPurp, smokeNoise * smokeShroud);
    finalColor = mix(finalColor, ionizedViolet, structuralFeatures * 0.45);

    // Inject cyan only into active lightning arcs and secondary hot halos.
    finalColor = mix(finalColor, plasmaCyan, (electricFilaments * 1.4 + eyeHalos * 0.45 + structuralFeatures * 0.25));

    // Blinding white-hot core highlights.
    finalColor = mix(finalColor, whiteHotCore, (eyeCores * 0.85 + electricFilaments * structuralFeatures * 0.4));

    // Lock the back of the throat to pitch blackness, retaining only the glowing teeth.
    finalColor = mix(finalColor, obsidianVoid * 0.1, mouthVoidMask * (1.0 - fangGlow * 0.65));

    // 7. COMPOSITING COMPONENT ROLES.
    if (layer < 0.5) {
        // Back shroud layer.
        float auraAlpha = (smokeNoise * 0.38 + electricFilaments * 0.3) * smokeShroud;
        surface.set_emissive_color(half3(finalColor * (0.8 + smokeNoise * 1.2) * controls.z));
        surface.set_opacity(half(saturate(auraAlpha * controls.w)));
        return;
    }

    // Front main feature layer.
    float faceAlpha = saturate(structuralFeatures * 0.65 + eyeCores * 0.95 + electricFilaments * 0.4 + smokeNoise * 0.1);
    faceAlpha *= canvasBoundary;

    surface.set_emissive_color(half3(finalColor * (1.2 + eyeCores * 2.0) * controls.z));
    surface.set_opacity(half(saturate(faceAlpha * controls.w)));
}
