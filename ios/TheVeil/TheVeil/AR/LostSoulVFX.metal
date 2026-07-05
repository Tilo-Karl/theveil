#include <metal_stdlib>
#include <RealityKit/RealityKit.h>
#include "SpectralNoise.metalh"
using namespace metal;

float3 lostSoulRotateY(float3 point, float angle, float3 pivot) {
    float sine = sin(angle);
    float cosine = cos(angle);
    float3 local = point - pivot;
    float3 rotated = float3(
        local.x * cosine + local.z * sine,
        local.y,
        -local.x * sine + local.z * cosine
    );
    return rotated + pivot;
}

float3 lostSoulRotateZ(float3 point, float angle, float3 pivot) {
    float sine = sin(angle);
    float cosine = cos(angle);
    float3 local = point - pivot;
    float3 rotated = float3(
        local.x * cosine - local.y * sine,
        local.x * sine + local.y * cosine,
        local.z
    );
    return rotated + pivot;
}

[[visible]]
void lostSoulGeometry(realitykit::geometry_parameters params) {
    auto geometry = params.geometry();
    float3 position = geometry.model_position();
    float3 normal = geometry.normal();
    float4 controls = params.uniforms().custom_parameter();
    float time = params.uniforms().time();
    float phase = controls.x;

    float3 transformed = position;
    transformed.x += sin(time * 0.31 + phase)
        * 0.012
        * smoothstep(-0.65, 0.55, position.y);

    float headMask = smoothstep(0.39, 0.51, position.y);
    float headTurn = sin(time * 0.23 + phase * 1.7) * 0.18;
    transformed = mix(
        transformed,
        lostSoulRotateY(transformed, headTurn, float3(0, 0.41, 0)),
        headMask
    );
    float headTilt = -0.055 + sin(time * 0.17 + phase * 0.8) * 0.045;
    transformed = mix(
        transformed,
        lostSoulRotateZ(transformed, headTilt, float3(0, 0.45, 0)),
        headMask
    );

    float armMask = smoothstep(0.135, 0.22, abs(position.x))
        * (1.0 - smoothstep(0.31, 0.43, position.y));
    transformed.z += sin(time * 0.27 + phase + sign(position.x) * 1.4)
        * 0.019
        * armMask;
    transformed.y += cos(time * 0.19 + phase * 0.7) * 0.009 * armMask;

    float lowerWeight = 1.0 - smoothstep(-0.58, -0.16, position.y);
    float coarseNoise = spectralFBM(
        position * float3(7.0, 4.2, 7.0)
            + float3(time * 0.08, -time * 0.12, phase * 8.0)
    );
    float fineNoise = spectralFBM(
        position * 21.0 + float3(-time * 0.15, time * 0.09, phase * 13.0)
    );
    float displacement = (coarseNoise - 0.5) * (0.012 + lowerWeight * 0.048)
        + (fineNoise - 0.5) * 0.006;
    transformed += normal * displacement;
    transformed.x += sin(time * 0.42 + position.y * 19.0 + phase)
        * lowerWeight
        * 0.026;
    transformed.z += cos(time * 0.35 + position.y * 16.0 + phase)
        * lowerWeight
        * 0.022;

    geometry.set_model_position_offset(transformed - position);
}

[[visible]]
void lostSoulSurface(realitykit::surface_parameters params) {
    auto geometry = params.geometry();
    auto surface = params.surface();
    float4 controls = params.uniforms().custom_parameter();
    float time = params.uniforms().time();
    float3 position = geometry.model_position();
    float3 normal = normalize(geometry.normal());
    float3 viewDirection = normalize(geometry.view_direction());
    float phase = controls.x;
    float layer = controls.y;

    float fresnel = pow(saturate(1.0 - abs(dot(normal, viewDirection))), 1.9);
    float cloud = spectralFBM(
        position * 9.5 + float3(time * 0.07, -time * 0.12, phase * 9.0)
    );
    float veinNoise = spectralFBM(
        position * 27.0 + float3(-time * 0.13, time * 0.08, phase * 17.0)
    );
    float edgeNoise = spectralFBM(
        position * 17.0 + float3(time * 0.11, time * 0.06, phase * 14.0)
    );
    float filaments = smoothstep(0.59, 0.84, cloud * 0.52 + veinNoise * 0.62);
    float lowerWeight = 1.0 - smoothstep(-0.5, -0.16, position.y);
    float lowerBreakup = smoothstep(0.5, 0.78, cloud * 0.72 + veinNoise * 0.44);
    float bottomFade = smoothstep(-0.77, -0.56, position.y);
    float presence = mix(1.0, lowerBreakup, lowerWeight) * bottomFade;
    float edgeBreakup = mix(
        0.42,
        1.0,
        smoothstep(0.34, 0.74, edgeNoise + fresnel * 0.28)
    );
    float pulse = 0.9 + sin(time * 1.07 + phase * 5.0) * 0.1;

    float outerLayer = 1.0 - step(0.5, layer);
    float innerLayer = step(0.5, layer) * (1.0 - step(1.5, layer));

    float3 cyanWhite = float3(0.68, 0.97, 1.0);
    float3 softBlue = float3(0.045, 0.42, 0.68);
    float3 veilMist = float3(0.14, 0.68, 0.88);
    float3 color = mix(
        softBlue,
        cyanWhite,
        saturate(fresnel * 0.82 + filaments * 0.62)
    );
    color = mix(color, veilMist, cloud * 0.16);

    float frontMask = smoothstep(0.035, 0.085, -position.z)
        * smoothstep(0.45, 0.51, position.y);
    float eyeBand = exp(-pow((position.y - 0.575) / 0.018, 2.0));
    float leftEye = exp(-pow((position.x + 0.035) / 0.018, 2.0));
    float rightEye = exp(-pow((position.x - 0.035) / 0.018, 2.0));
    float eyeShadow = saturate((leftEye + rightEye) * eyeBand * frontMask);
    float noseTrace = exp(
        -pow(position.x / 0.014, 2.0)
        -pow((position.y - 0.545) / 0.052, 2.0)
    ) * frontMask;

    float outerAlpha = (
        0.012 + fresnel * 0.29 + filaments * 0.075
    ) * presence * edgeBreakup;
    float innerAlpha = (
        0.04 + cloud * 0.072 + filaments * 0.12
    ) * presence;
    float alpha = (
        outerAlpha * outerLayer
            + innerAlpha * innerLayer
    ) * controls.w;

    float intensity = (
        (0.34 + fresnel * 3.15 + filaments * 1.45) * outerLayer
            + (0.52 + cloud * 0.86 + filaments * 2.05) * innerLayer
    ) * controls.z * pulse;
    intensity *= 1.0 - eyeShadow * 0.38;
    intensity += noseTrace * 0.28;

    surface.set_emissive_color(half3(color * intensity));
    surface.set_opacity(half(saturate(alpha)));
}
