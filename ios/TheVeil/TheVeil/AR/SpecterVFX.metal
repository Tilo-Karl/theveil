#include <metal_stdlib>
#include <RealityKit/RealityKit.h>
#include "SpectralNoise.metalh"
using namespace metal;

// Existing custom texture:
// R = authored spectral matter
// G = authored hard facial highlights
// B = authored cavities
//
// This shader keeps the authored face stable and renders a separate,
// independently animated purple-plasma layer behind and around it.
//
// Darker tuning:
// - reduces plasma brightness and rear-layer opacity
// - preserves more black/deep-purple negative space
// - strengthens authored facial cores slightly
// - darkens sockets, nostrils, and maw
// - reduces full-plane "glowing sheet" appearance

float ridgedNoise(float3 p) {
    float n = spectralFBM(p);
    return 1.0 - abs(n * 2.0 - 1.0);
}

float2 warpField(float2 p, float time, float phase, float amount) {
    float2 w = float2(
        spectralFBM(float3(p * 1.9, time * 0.15 + phase)),
        spectralFBM(float3(p * 2.4 + float2(5.1, 2.7), -time * 0.12 + phase * 1.7))
    ) - 0.5;
    return p + w * amount;
}

float sampleChannel(texture2d<half, access::sample> tex,
                    sampler s,
                    float2 uv,
                    int channel) {
    half4 v = tex.sample(s, uv);
    if (channel == 0) {
        return float(v.r);
    }
    if (channel == 1) {
        return float(v.g);
    }
    return float(v.b);
}

float fieldEdge(texture2d<half, access::sample> tex,
                sampler s,
                float2 uv,
                int channel) {
    float2 t = float2(1.0 / 1024.0);
    float l = sampleChannel(tex, s, uv - float2(t.x, 0), channel);
    float r = sampleChannel(tex, s, uv + float2(t.x, 0), channel);
    float u = sampleChannel(tex, s, uv + float2(0, t.y), channel);
    float d = sampleChannel(tex, s, uv - float2(0, t.y), channel);
    return saturate(abs(r - l) + abs(u - d));
}

float dilatedMatter(texture2d<half, access::sample> tex,
                    sampler s,
                    float2 uv) {
    float2 t = float2(1.0 / 1024.0);
    float m = sampleChannel(tex, s, uv, 0);
    m = max(m, sampleChannel(tex, s, uv + float2( 12,  0) * t, 0));
    m = max(m, sampleChannel(tex, s, uv + float2(-12,  0) * t, 0));
    m = max(m, sampleChannel(tex, s, uv + float2(  0, 12) * t, 0));
    m = max(m, sampleChannel(tex, s, uv + float2(  0,-12) * t, 0));
    m = max(m, sampleChannel(tex, s, uv + float2(  9,  9) * t, 0));
    m = max(m, sampleChannel(tex, s, uv + float2( -9,  9) * t, 0));
    m = max(m, sampleChannel(tex, s, uv + float2(  9, -9) * t, 0));
    m = max(m, sampleChannel(tex, s, uv + float2( -9, -9) * t, 0));
    return saturate(m);
}

float verticalCurrent(float2 p,
                      float time,
                      float phase,
                      float frequency,
                      float threshold) {
    float2 q = p;
    q.x += sin(q.y * 4.6 + time * 0.34 + phase) * 0.075;
    q.x += sin(q.y * 9.2 - time * 0.21 + phase * 1.4) * 0.028;
    q.y += sin(q.x * 2.5 + time * 0.18 + phase * 0.6) * 0.035;

    float n = ridgedNoise(float3(
        q.x * frequency,
        q.y * frequency * 1.85,
        time * 0.48 + phase
    ));

    return smoothstep(threshold, 1.0, n);
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

    float envelope = smoothstep(
        0.0, 0.86,
        1.0 - length(p * float2(0.84, 0.72))
    );

    float wave = spectralFBM(float3(p * 2.5, time * 0.20 + phase));

    float3 offset = float3(
        0.0,
        (wave - 0.5) * 0.005 * envelope,
        (wave - 0.5) * 0.018 * envelope
    );

    offset *= layer < 0.5 ? 1.0 : 0.16;
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

    float cycle = 0.5 + 0.5 * sin(time * 0.48 + phase);
    float formation = smoothstep(0.18, 0.90, cycle);

    float2 uv = geometry.uv0();
    float2 p = uv * 2.0 - 1.0;

    auto faceTexture = params.textures().custom();
    constexpr sampler s(filter::linear, address::clamp_to_zero);

    // Stable face coordinates.
    float2 faceP = warpField(p, time, phase, mix(0.020, 0.004, formation));
    float2 faceUV = faceP * 0.5 + 0.5;
    float3 faceField = float3(faceTexture.sample(s, faceUV).rgb);

    float faceMatter = saturate(faceField.r);
    float faceHighlights = saturate(faceField.g);
    float cavities = saturate(faceField.b);

    float highlightEdge = fieldEdge(faceTexture, s, faceUV, 1);
    float cavityEdge = fieldEdge(faceTexture, s, faceUV, 2);

    // Independent plasma coordinates.
    float2 plasmaP = warpField(
        p,
        time * 1.25,
        phase + 7.0,
        mix(0.11, 0.065, formation)
    );
    float2 plasmaUV = plasmaP * 0.5 + 0.5;

    float envelope = dilatedMatter(faceTexture, s, plasmaUV);
    float radial = smoothstep(
        1.08, 0.18,
        length(plasmaP * float2(0.82, 0.70))
    );

    // Reduced spread so the aura no longer fills the entire plane.
    envelope = saturate(envelope * 0.70 + radial * 0.20);

    float lowFlow = spectralFBM(float3(
        plasmaP * 2.4,
        time * 0.16 + phase * 2.0
    ));
    float midFlow = spectralFBM(float3(
        plasmaP * 5.2,
        -time * 0.29 + phase * 3.4
    ));
    float turbulence = ridgedNoise(float3(
        plasmaP * 11.0,
        time * 0.66 + phase * 5.1
    ));

    // Higher threshold + explicit reduction preserves dark gaps.
    float plasmaMass = smoothstep(
        0.32, 0.86,
        lowFlow * 0.52 +
        midFlow * 0.28 +
        turbulence * 0.15
    ) * envelope;

    plasmaMass *= 0.55;

    float currentA = verticalCurrent(plasmaP, time, phase + 1.2, 5.2, 0.73);
    float currentB = verticalCurrent(plasmaP + float2(0.16, -0.04), time, phase + 3.9, 7.3, 0.78);
    float currentC = verticalCurrent(plasmaP + float2(-0.12, 0.08), time, phase + 6.4, 9.1, 0.82);

    float longCurrents = max(currentA, max(currentB, currentC)) * envelope;
    longCurrents *= 0.62;

    float currentCore = pow(saturate(longCurrents), 3.3);
    float currentBody = pow(saturate(longCurrents), 1.55);
    float currentHalo = pow(saturate(longCurrents), 0.70);

    float hardFace = pow(faceHighlights, mix(1.50, 1.08, formation));
    float whiteFaceCore = pow(faceHighlights, mix(2.45, 1.62, formation));

    // Slightly strengthen the authored hard detail.
    whiteFaceCore *= 1.15;

    float reinforcement = saturate(
        hardFace * 0.90 +
        highlightEdge * 0.74 +
        cavityEdge * (0.22 + formation * 0.62)
    );

    reinforcement *= mix(
        0.64, 1.0,
        ridgedNoise(float3(faceP * 13.5, time * 0.90 + phase * 4.5))
    );

    float attackPulse = smoothstep(0.72, 0.98, formation);

    // Stronger cavity absorption.
    float cavityDark = saturate(
        cavities * mix(0.74, 1.00, formation) * 1.18
    );

    float cavityRim = cavityEdge * (0.16 + attackPulse * 0.64);

    float3 obsidian = float3(0.003, 0.000, 0.010);
    float3 deepPurple = float3(0.060, 0.001, 0.165);
    float3 violet = float3(0.360, 0.010, 0.760);
    float3 hotViolet = float3(0.730, 0.075, 0.920);
    float3 whiteHot = float3(1.000, 0.970, 1.000);

    float3 color = obsidian;

    // Independent plasma — deliberately darker and less dominant.
    color += deepPurple * plasmaMass * 0.72;
    color += deepPurple * currentHalo * 0.28;
    color += violet * currentBody * 0.48;
    color += hotViolet * currentCore * 0.36;
    color += whiteHot * currentCore * 0.46;

    // Stable authored face — remains the visual priority.
    color += deepPurple * faceMatter * 0.18;
    color += violet * hardFace * 0.56;
    color += hotViolet * reinforcement * 0.66;
    color += whiteHot * whiteFaceCore * (0.96 + attackPulse * 0.34);
    color += hotViolet * cavityRim * 0.48;

    color = mix(
        color,
        obsidian,
        cavityDark * (
            1.0 -
            whiteFaceCore * 0.18 -
            cavityRim * 0.22
        )
    );

    if (layer < 0.5) {
        // Rear plasma opacity reduced to avoid the glowing billboard effect.
        float auraAlpha =
            plasmaMass * 0.30 +
            currentHalo * 0.075 +
            currentBody * 0.045;

        auraAlpha *= 0.60;

        surface.set_emissive_color(half3(color * controls.z));
        surface.set_opacity(half(saturate(auraAlpha * controls.w)));
        return;
    }

    float faceAlpha =
        faceMatter * 0.20 +
        hardFace * 0.60 +
        whiteFaceCore * 0.92 +
        reinforcement * 0.30 +
        cavityRim * 0.18 +
        currentCore * 0.045;

    surface.set_emissive_color(half3(color * controls.z));
    surface.set_opacity(half(saturate(faceAlpha * controls.w)));
}
