#include <metal_stdlib>
using namespace metal;

float veilNoise(float2 position, float time) {
    float value = sin(dot(position + time, float2(12.9898, 78.233))) * 43758.5453;
    return fract(value) - 0.5;
}

float veilValueNoise(float2 position) {
    float2 cell = floor(position);
    float2 local = fract(position);
    local = local * local * (3.0 - 2.0 * local);

    float a = fract(sin(dot(cell, float2(127.1, 311.7))) * 43758.5453);
    float b = fract(sin(dot(cell + float2(1, 0), float2(127.1, 311.7))) * 43758.5453);
    float c = fract(sin(dot(cell + float2(0, 1), float2(127.1, 311.7))) * 43758.5453);
    float d = fract(sin(dot(cell + float2(1, 1), float2(127.1, 311.7))) * 43758.5453);
    return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}

float veilFBM(float2 position) {
    float value = 0.0;
    float amplitude = 0.55;
    for (int octave = 0; octave < 4; ++octave) {
        value += veilValueNoise(position) * amplitude;
        position = position * 2.03 + float2(4.7, 8.3);
        amplitude *= 0.46;
    }
    return value;
}

constexpr sampler veilCameraSampler(
    coord::normalized,
    address::clamp_to_edge,
    filter::linear
);

float2 veilImageCoordinate(
    float2 viewCoordinate,
    float4 transform,
    float2 translation
) {
    return float2(
        transform.x * viewCoordinate.x + transform.z * viewCoordinate.y + translation.x,
        transform.y * viewCoordinate.x + transform.w * viewCoordinate.y + translation.y
    );
}

float3 veilCameraSample(
    texture2d<float, access::sample> luminanceTexture,
    texture2d<float, access::sample> chromaTexture,
    float2 viewCoordinate,
    float4 transform,
    float2 translation
) {
    float2 imageCoordinate = veilImageCoordinate(viewCoordinate, transform, translation);
    float y = luminanceTexture.sample(veilCameraSampler, imageCoordinate).r;
    float2 chroma = chromaTexture.sample(veilCameraSampler, imageCoordinate).rg - 0.5;

    return saturate(float3(
        y + 1.402 * chroma.y,
        y - 0.344136 * chroma.x - 0.714136 * chroma.y,
        y + 1.772 * chroma.x
    ));
}

float3 veilBloomSample(
    texture2d<float, access::sample> luminanceTexture,
    texture2d<float, access::sample> chromaTexture,
    float2 viewCoordinate,
    float4 transform,
    float2 translation
) {
    float3 color = veilCameraSample(
        luminanceTexture,
        chromaTexture,
        viewCoordinate,
        transform,
        translation
    );
    float brightness = max(color.r, max(color.g, color.b));
    return color * smoothstep(0.62, 1.35, brightness);
}

kernel void veilCameraColorGrade(
    texture2d<float, access::sample> luminanceTexture [[texture(0)]],
    texture2d<float, access::sample> chromaTexture [[texture(1)]],
    texture2d<float, access::write> target [[texture(2)]],
    constant float &time [[buffer(0)]],
    constant uint &effectCount [[buffer(1)]],
    constant float4 *effects [[buffer(2)]],
    constant float4 &viewToImageTransform [[buffer(3)]],
    constant float2 &viewToImageTranslation [[buffer(4)]],
    constant float &lensIntensity [[buffer(5)]],
    uint2 id [[thread_position_in_grid]]
) {
    if (id.x >= target.get_width() || id.y >= target.get_height()) {
        return;
    }

    float2 size = float2(target.get_width(), target.get_height());
    float2 uv = (float2(id) + 0.5) / size;
    float3 unprocessedColor = veilCameraSample(
        luminanceTexture,
        chromaTexture,
        uv,
        viewToImageTransform,
        viewToImageTranslation
    );
    float aspect = size.x / size.y;
    float2 displacedUV = uv;
    float localVeilEnergy = 0.0;

    for (uint index = 0; index < min(effectCount, 5u); ++index) {
        float4 effect = effects[index];
        float2 delta = uv - effect.xy;
        float2 aspectDelta = delta * float2(aspect, 1.0);
        float distance = length(aspectDelta);
        float falloff = 1.0 - smoothstep(effect.z * 0.18, effect.z, distance);
        float safeDistance = max(distance, 0.0001);
        float2 radial = aspectDelta / safeDistance;
        float2 tangent = float2(-radial.y, radial.x);
        float turbulence = veilNoise(uv * size * 0.035 + float(index) * 19.0, time * 0.7);
        float ripple = sin(distance * 86.0 - time * 2.4 + float(index)) * 0.5 + 0.5;
        float2 distortion = (radial * (ripple - 0.5) + tangent * turbulence)
            * falloff
            * effect.w
            * 0.006;
        displacedUV += float2(distortion.x / aspect, distortion.y);
        localVeilEnergy += falloff * falloff * effect.w * (0.72 + turbulence * 0.28);
    }

    displacedUV = clamp(displacedUV, float2(0), float2(0.99999));
    float3 color = veilCameraSample(
        luminanceTexture,
        chromaTexture,
        displacedUV,
        viewToImageTransform,
        viewToImageTranslation
    );

    float2 pixelStep = 1.0 / size;
    float3 bloom = float3(0);
    bloom += veilBloomSample(luminanceTexture, chromaTexture, displacedUV + float2(3, 0) * pixelStep, viewToImageTransform, viewToImageTranslation);
    bloom += veilBloomSample(luminanceTexture, chromaTexture, displacedUV + float2(-3, 0) * pixelStep, viewToImageTransform, viewToImageTranslation);
    bloom += veilBloomSample(luminanceTexture, chromaTexture, displacedUV + float2(0, 3) * pixelStep, viewToImageTransform, viewToImageTranslation);
    bloom += veilBloomSample(luminanceTexture, chromaTexture, displacedUV + float2(0, -3) * pixelStep, viewToImageTransform, viewToImageTranslation);
    bloom += veilBloomSample(luminanceTexture, chromaTexture, displacedUV + float2(7, 0) * pixelStep, viewToImageTransform, viewToImageTranslation);
    bloom += veilBloomSample(luminanceTexture, chromaTexture, displacedUV + float2(-7, 0) * pixelStep, viewToImageTransform, viewToImageTranslation);
    bloom += veilBloomSample(luminanceTexture, chromaTexture, displacedUV + float2(0, 7) * pixelStep, viewToImageTransform, viewToImageTranslation);
    bloom += veilBloomSample(luminanceTexture, chromaTexture, displacedUV + float2(0, -7) * pixelStep, viewToImageTransform, viewToImageTranslation);
    bloom += veilBloomSample(luminanceTexture, chromaTexture, displacedUV + float2(5, 5) * pixelStep, viewToImageTransform, viewToImageTranslation);
    bloom += veilBloomSample(luminanceTexture, chromaTexture, displacedUV + float2(-5, 5) * pixelStep, viewToImageTransform, viewToImageTranslation);
    bloom += veilBloomSample(luminanceTexture, chromaTexture, displacedUV + float2(5, -5) * pixelStep, viewToImageTransform, viewToImageTranslation);
    bloom += veilBloomSample(luminanceTexture, chromaTexture, displacedUV + float2(-5, -5) * pixelStep, viewToImageTransform, viewToImageTranslation);
    bloom /= 12.0;

    float luminance = dot(color, float3(0.2126, 0.7152, 0.0722));
    float shadowWeight = 1.0 - smoothstep(0.12, 0.72, luminance);
    float highlightWeight = smoothstep(0.56, 1.0, luminance);

    color = mix(float3(luminance), color, 0.72);
    color *= 0.5;
    color = (color - 0.18) * 1.24 + 0.18;
    color *= float3(0.62, 0.78, 1.08);
    color += shadowWeight * float3(0.008, 0.018, 0.075);
    color += highlightWeight * float3(0.018, 0.004, 0.045);
    color += bloom * float3(0.62, 0.86, 1.3) * 0.62;
    color += float3(0.035, 0.13, 0.3) * localVeilEnergy;

    float fogA = veilFBM(uv * float2(3.1, 5.4) + float2(time * 0.025, -time * 0.04));
    float fogB = veilFBM(uv * float2(6.7, 2.6) + float2(-time * 0.018, time * 0.022));
    float fog = smoothstep(0.55, 0.96, fogA * 0.68 + fogB * 0.32);
    color = mix(
        color,
        color * 0.86 + float3(0.012, 0.035, 0.09),
        fog * 0.18
    );

    float2 centered = (uv - 0.5) * float2(size.x / size.y, 1.0);
    float vignette = smoothstep(0.25, 0.82, length(centered));
    color *= mix(1.0, 0.58, vignette);

    float grain = veilNoise(float2(id), time * 43.0) * 0.035;
    color += grain;

    float engagement = smoothstep(0.0, 1.0, lensIntensity);
    float3 outputColor = mix(unprocessedColor, saturate(color), engagement);
    target.write(float4(outputColor, 1), id);
}
