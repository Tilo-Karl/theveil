#include <metal_stdlib>
using namespace metal;

float veilNoise(float2 position, float time) {
    float value = sin(dot(position + time, float2(12.9898, 78.233))) * 43758.5453;
    return fract(value) - 0.5;
}

float3 veilBloomSample(
    texture2d<float, access::read> source,
    int2 position
) {
    int2 maximum = int2(source.get_width() - 1, source.get_height() - 1);
    uint2 coordinate = uint2(clamp(position, int2(0), maximum));
    float3 color = source.read(coordinate).rgb;
    float brightness = max(color.r, max(color.g, color.b));
    return color * smoothstep(0.62, 1.35, brightness);
}

kernel void veilColorGrade(
    texture2d<float, access::read> source [[texture(0)]],
    texture2d<float, access::write> target [[texture(1)]],
    constant float &time [[buffer(0)]],
    constant uint &effectCount [[buffer(1)]],
    constant float4 *effects [[buffer(2)]],
    uint2 id [[thread_position_in_grid]]
) {
    if (id.x >= target.get_width() || id.y >= target.get_height()) {
        return;
    }

    float2 size = float2(target.get_width(), target.get_height());
    float2 uv = (float2(id) + 0.5) / size;
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
    uint2 displacedID = uint2(displacedUV * size);
    float4 sample = source.read(displacedID);
    float3 color = sample.rgb;

    int2 coordinate = int2(displacedID);
    float3 bloom = float3(0);
    bloom += veilBloomSample(source, coordinate + int2(3, 0));
    bloom += veilBloomSample(source, coordinate + int2(-3, 0));
    bloom += veilBloomSample(source, coordinate + int2(0, 3));
    bloom += veilBloomSample(source, coordinate + int2(0, -3));
    bloom += veilBloomSample(source, coordinate + int2(7, 0));
    bloom += veilBloomSample(source, coordinate + int2(-7, 0));
    bloom += veilBloomSample(source, coordinate + int2(0, 7));
    bloom += veilBloomSample(source, coordinate + int2(0, -7));
    bloom += veilBloomSample(source, coordinate + int2(5, 5));
    bloom += veilBloomSample(source, coordinate + int2(-5, 5));
    bloom += veilBloomSample(source, coordinate + int2(5, -5));
    bloom += veilBloomSample(source, coordinate + int2(-5, -5));
    bloom /= 12.0;

    float luminance = dot(color, float3(0.2126, 0.7152, 0.0722));
    color = mix(float3(luminance), color, 0.86);
    color = (color - 0.5) * 1.22 + 0.5;
    color *= 0.76;
    color *= float3(0.8, 0.92, 1.12);
    color += float3(0.018, 0.012, 0.055);
    color += bloom * float3(0.62, 0.86, 1.3) * 0.62;
    color += float3(0.035, 0.13, 0.3) * localVeilEnergy;

    float2 centered = (uv - 0.5) * float2(size.x / size.y, 1.0);
    float vignette = smoothstep(0.25, 0.82, length(centered));
    color *= mix(1.0, 0.58, vignette);

    float grain = veilNoise(float2(id), time * 43.0) * 0.035;
    color += grain;

    target.write(float4(saturate(color), sample.a), id);
}
