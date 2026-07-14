#include <metal_stdlib>
#include <RealityKit/RealityKit.h>
#include "SpectralNoise.metalh"
using namespace metal;

// Uses the existing authored mask:
// R = spectral matter, G = hard facial highlights, B = cavities.
// The face remains stable; only the purple plasma and electrical reinforcement move.

float ridgedNoise(float3 p) {
    float n = spectralFBM(p);
    return 1.0 - abs(n * 2.0 - 1.0);
}

float2 lowWarp(float2 uv, float time, float phase, float amount) {
    float2 p = uv * 2.0 - 1.0;
    float2 w = float2(
        spectralFBM(float3(p * 2.1, time * 0.14 + phase)),
        spectralFBM(float3(p * 2.6 + float2(6.1, 2.7), -time * 0.11 + phase * 1.8))
    ) - 0.5;
    return uv + w * amount;
}

float fieldEdge(texture2d<float, access::sample> tex, sampler s, float2 uv, int channel) {
    float2 t = float2(1.0 / 1024.0);
    float4 l = tex.sample(s, uv - float2(t.x, 0));
    float4 r = tex.sample(s, uv + float2(t.x, 0));
    float4 u = tex.sample(s, uv + float2(0, t.y));
    float4 d = tex.sample(s, uv - float2(0, t.y));

    float lv = channel == 0 ? l.r : (channel == 1 ? l.g : l.b);
    float rv = channel == 0 ? r.r : (channel == 1 ? r.g : r.b);
    float uvv = channel == 0 ? u.r : (channel == 1 ? u.g : u.b);
    float dv = channel == 0 ? d.r : (channel == 1 ? d.g : d.b);

    return saturate(abs(rv - lv) + abs(uvv - dv));
}

float directionalFilament(float2 p, float time, float phase, float frequency, float sharpness) {
    float2 q = p;
    q.x += sin(q.y * 5.0 + time * 0.35 + phase) * 0.08;
    q.y += sin(q.x * 3.0 - time * 0.22 + phase * 0.7) * 0.05;

    float n = ridgedNoise(float3(
        q.x * frequency,
        q.y * frequency * 1.9,
        time * 0.42 + phase
    ));
    return smoothstep(sharpness, 1.0, n);
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

    float envelope = smoothstep(0.0, 0.85, 1.0 - length(p * float2(0.84, 0.72)));
    float wave = spectralFBM(float3(p * 2.8, time * 0.22 + phase));

    float3 offset = float3(
        0.0,
        (wave - 0.5) * 0.007 * envelope,
        (wave - 0.5) * 0.022 * envelope
    );

    offset *= layer < 0.5 ? 1.0 : 0.22;
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

    float cycle = 0.5 + 0.5 * sin(time * 0.50 + phase);
    float formation = smoothstep(0.18, 0.90, cycle);

    float2 uv = geometry.uv0();
    float2 warpedUV = lowWarp(uv, time, phase, mix(0.022, 0.004, formation));

    auto faceTexture = params.textures().custom();
    constexpr sampler s(filter::linear, address::clamp_to_zero);

    float3 field = faceTexture.sample(s, warpedUV).rgb;
    float matter = field.r;
    float authoredHighlights = field.g;
    float cavities = field.b;

    float2 p = warpedUV * 2.0 - 1.0;

    float broadNoise = spectralFBM(float3(p * 3.2, time * 0.18 + phase * 2.0));
    float mediumNoise = spectralFBM(float3(p * 6.4, -time * 0.27 + phase * 3.7));

    float broadMatter = matter * (0.30 + broadNoise * 0.34 + mediumNoise * 0.16);

    float filamentsA = directionalFilament(p, time, phase + 1.1, 5.6, 0.72);
    float filamentsB = directionalFilament(p + float2(0.13, -0.07), time, phase + 4.3, 7.4, 0.76);
    float fineFilaments = max(filamentsA, filamentsB) * saturate(matter * 1.35);

    float hardHighlight = pow(saturate(authoredHighlights), mix(1.55, 1.10, formation));
    float whiteCore = pow(saturate(authoredHighlights), mix(2.50, 1.65, formation));

    float matterEdge = fieldEdge(faceTexture, s, warpedUV, 0);
    float highlightEdge = fieldEdge(faceTexture, s, warpedUV, 1);
    float cavityEdge = fieldEdge(faceTexture, s, warpedUV, 2);

    float reinforcement = saturate(
        hardHighlight * 0.85 +
        highlightEdge * 0.80 +
        cavityEdge * 0.60 +
        matterEdge * 0.22
    );

    float flicker = mix(
        0.52,
        1.0,
        ridgedNoise(float3(p * 14.0, time * 0.88 + phase * 5.0))
    );
    reinforcement *= flicker;

    float attackPulse = smoothstep(0.70, 0.98, formation);
    float movingCurrent = saturate(
        fineFilaments * 0.55 +
        reinforcement * mix(0.38, 1.0, formation)
    );

    float cavityDark = cavities * mix(0.48, 1.0, formation);
    float cavityBorderFlare = cavityEdge * (0.20 + attackPulse * 0.85);
    float facialCore = whiteCore * (0.70 + attackPulse * 0.75);

    float3 obsidian = float3(0.003, 0.000, 0.010);
    float3 deepPurple = float3(0.10, 0.003, 0.24);
    float3 violet = float3(0.45, 0.015, 0.90);
    float3 hotViolet = float3(0.82, 0.10, 1.00);
    float3 whiteHot = float3(1.00, 0.97, 1.00);

    float3 color = obsidian;
    color += deepPurple * broadMatter * 0.88 * mix(0.95, 1.18, formation);
    color += violet * movingCurrent * 0.82;
    color += hotViolet * reinforcement * 0.68;
    color += violet * hardHighlight * 0.64;
    color += whiteHot * facialCore * 1.30;
    color += hotViolet * cavityBorderFlare * 0.54;

    color = mix(color, obsidian, cavityDark * (1.0 - facialCore * 0.28));

    if (layer < 0.5) {
        float auraAlpha = broadMatter * 0.34 + fineFilaments * 0.16 + matterEdge * 0.06;
        surface.set_emissive_color(half3(color * controls.z));
        surface.set_opacity(half(saturate(auraAlpha * controls.w)));
        return;
    }

    float faceAlpha =
        matter * 0.20 +
        hardHighlight * 0.62 +
        facialCore * 0.90 +
        reinforcement * 0.38 +
        cavityBorderFlare * 0.26;

    surface.set_emissive_color(half3(color * controls.z));
    surface.set_opacity(half(saturate(faceAlpha * controls.w)));
}
