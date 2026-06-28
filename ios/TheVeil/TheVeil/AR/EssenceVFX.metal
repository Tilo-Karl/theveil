#include <metal_stdlib>
#include <RealityKit/RealityKit.h>
using namespace metal;

float essenceHash(float3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}

float essenceNoise(float3 p) {
    float3 cell = floor(p);
    float3 local = fract(p);
    local = local * local * (3.0 - 2.0 * local);

    float n000 = essenceHash(cell + float3(0, 0, 0));
    float n100 = essenceHash(cell + float3(1, 0, 0));
    float n010 = essenceHash(cell + float3(0, 1, 0));
    float n110 = essenceHash(cell + float3(1, 1, 0));
    float n001 = essenceHash(cell + float3(0, 0, 1));
    float n101 = essenceHash(cell + float3(1, 0, 1));
    float n011 = essenceHash(cell + float3(0, 1, 1));
    float n111 = essenceHash(cell + float3(1, 1, 1));

    float x00 = mix(n000, n100, local.x);
    float x10 = mix(n010, n110, local.x);
    float x01 = mix(n001, n101, local.x);
    float x11 = mix(n011, n111, local.x);
    return mix(mix(x00, x10, local.y), mix(x01, x11, local.y), local.z);
}

float essenceFBM(float3 p) {
    float value = 0.0;
    float amplitude = 0.52;
    for (int octave = 0; octave < 4; ++octave) {
        value += essenceNoise(p) * amplitude;
        p = p * 2.03 + float3(7.1, 3.7, 5.4);
        amplitude *= 0.48;
    }
    return value;
}

[[visible]]
void essencePlasmaGeometry(realitykit::geometry_parameters params) {
    auto geometry = params.geometry();
    float3 position = geometry.model_position();
    float3 normal = geometry.normal();
    float4 controls = params.uniforms().custom_parameter();
    float time = params.uniforms().time();
    float noise = essenceFBM(position * 35.0 + float3(0, time * 0.24, controls.z * 11.0));
    float pulse = sin(time * 1.3 + controls.z * 6.28) * 0.5 + 0.5;
    float displacement = (noise - 0.48) * controls.x * (0.72 + pulse * 0.28);
    geometry.set_model_position_offset(normal * displacement);
}

[[visible]]
void essencePlasmaSurface(realitykit::surface_parameters params) {
    auto geometry = params.geometry();
    auto surface = params.surface();
    float4 controls = params.uniforms().custom_parameter();
    float time = params.uniforms().time();
    float3 position = geometry.model_position();
    float noiseA = essenceFBM(position * 42.0 + float3(time * 0.16, -time * 0.21, controls.z * 9.0));
    float noiseB = essenceFBM(position * 73.0 + float3(-time * 0.11, controls.z * 13.0, time * 0.19));
    float vein = smoothstep(0.54, 0.84, noiseA * 0.72 + noiseB * 0.46);
    float pulse = 0.82 + sin(time * 1.65 + controls.z * 7.0) * 0.18;
    float3 cyan = float3(0.06, 0.68, 1.0);
    float3 violet = float3(0.4, 0.1, 1.0);
    float phaseVariation = fract(controls.z * 0.159);
    float colorMix = saturate(0.12 + noiseB * 0.32 + phaseVariation * 0.1);
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
    float4 controls = params.uniforms().custom_parameter();
    float time = params.uniforms().time();
    float edgeDistance = 1.0 - abs(uv.y * 2.0 - 1.0);
    float softEdge = smoothstep(0.0, 0.72, edgeDistance);
    float endFade = smoothstep(0.0, 0.1, uv.x) * (1.0 - smoothstep(0.82, 1.0, uv.x));
    float flow = essenceFBM(float3(uv.x * 6.0 - time * 0.32, uv.y * 2.4, controls.z * 8.0));
    float filament = smoothstep(0.28, 0.78, flow);
    float flicker = 0.76 + sin(time * 2.1 + uv.x * 17.0 + controls.z * 5.0) * 0.24;
    float alpha = softEdge * endFade * (0.1 + filament * 0.52) * controls.w;
    float3 cyan = float3(0.08, 0.7, 1.0);
    float3 violet = float3(0.46, 0.12, 1.0);
    float colorMix = saturate(0.1 + uv.x * 0.22 + flow * 0.28);
    float3 color = mix(cyan, violet, colorMix);

    surface.set_emissive_color(half3(color * controls.y * flicker));
    surface.set_opacity(half(alpha));
}
