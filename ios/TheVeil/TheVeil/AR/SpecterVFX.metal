#include <metal_stdlib>
#include <RealityKit/RealityKit.h>
#include "SpectralNoise.metalh"
using namespace metal;

[[visible]]
void specterGeometry(realitykit::geometry_parameters params) {
    auto geometry = params.geometry();
    float3 position = geometry.model_position();
    float3 normal = geometry.normal();
    float4 controls = params.uniforms().custom_parameter();
    float time = params.uniforms().time();
    float phase = controls.x;

    float3 transformed = position;

    float noiseA = spectralFBM(position * 3.2 + float3(time * 0.19, -time * 0.15, phase * 5.0));
    float noiseB = spectralFBM(position * 7.8 + float3(-time * 0.22, time * 0.13, phase * 8.0));
    float noiseC = spectralFBM(position * 15.0 + float3(time * 0.18, time * 0.11, phase * 12.0));

    float billowStrength = (noiseA - 0.5) * 0.08 + (noiseB - 0.5) * 0.12;
    transformed += normal * billowStrength;

    float upTendril = smoothstep(-0.3, 0.2, position.y) * (noiseB - 0.5) * 0.045;
    float downTendril = smoothstep(0.3, -0.3, position.y) * (noiseC - 0.5) * 0.04;
    transformed.y += upTendril + downTendril;

    float angle = atan2(position.z, position.x);
    float radius = length(position.xz);
    float spiralShift = sin(angle + time * 0.27 + phase) * radius * 0.025;
    transformed.x += cos(angle) * spiralShift;
    transformed.z += sin(angle) * spiralShift;

    float outerWeight = smoothstep(0.3, 0.48, length(position));
    transformed += normal * (noiseC - 0.5) * 0.035 * outerWeight;

    float coreWeight = smoothstep(0.15, 0.0, length(position));
    transformed += normal * sin(time * 0.89 + phase * 3.0) * 0.012 * coreWeight;

    geometry.set_model_position_offset(transformed - position);
}

[[visible]]
void specterSurface(realitykit::surface_parameters params) {
    auto geometry = params.geometry();
    auto surface = params.surface();
    float4 controls = params.uniforms().custom_parameter();
    float time = params.uniforms().time();
    float3 position = geometry.model_position();
    float3 normal = normalize(geometry.normal());
    float3 viewDirection = normalize(geometry.view_direction());
    float phase = controls.x;
    float attackCharge = saturate(controls.y);

    float distFromCenter = length(position);
    float fresnel = pow(saturate(1.0 - abs(dot(normal, viewDirection))), 1.6);

    float plasmaA = spectralFBM(position * 4.0 + float3(time * 0.12, -time * 0.16, phase * 6.0));
    float plasmaB = spectralFBM(position * 12.0 + float3(-time * 0.18, time * 0.14, phase * 10.0));
    float plasmaC = spectralFBM(position * 28.0 + float3(time * 0.22, time * 0.09, phase * 18.0));
    float plasmaD = spectralFBM(position * 7.5 + float3(-time * 0.13, time * 0.11, phase * 7.5));

    float turbulence = plasmaA * 0.4 + plasmaB * 0.3 + plasmaC * 0.2 + plasmaD * 0.1;
    float instability = smoothstep(0.35, 0.78, turbulence);
    float vortexPattern = sin(plasmaB * 6.28 + plasmaA * 3.14) * 0.5 + 0.5;

    float3 cameraDir = normalize(viewDirection);
    float3 posDir = normalize(position);
    float frontFace = dot(posDir, cameraDir);
    float frontMask = smoothstep(0.15, 0.45, frontFace);
    float faceMask = frontMask * smoothstep(0.25, 0.35, distFromCenter);

    float3 up = abs(cameraDir.y) > 0.9 ? float3(1, 0, 0) : float3(0, 1, 0);
    float3 right = normalize(cross(up, cameraDir));
    float3 faceUp = normalize(cross(cameraDir, right));

    float projX = dot(position, right);
    float projY = dot(position, faceUp);

    float leftEyeX = abs(projX + 0.15);
    float leftEyeY = abs(projY - 0.08);
    float leftEye = exp(-(leftEyeX * leftEyeX / 0.008 + leftEyeY * leftEyeY / 0.01));

    float rightEyeX = abs(projX - 0.15);
    float rightEyeY = abs(projY - 0.08);
    float rightEye = exp(-(rightEyeX * rightEyeX / 0.008 + rightEyeY * rightEyeY / 0.01));

    float eyeFlicker = 0.4 + 0.6 * sin(time * 2.3 + phase * 4.0);
    float eyePresence = (leftEye + rightEye) * eyeFlicker * faceMask;

    float mouthX = abs(projX) * 1.5;
    float mouthY = abs(projY + 0.12);
    float mouthOpening = exp(-(mouthX * mouthX / 0.018 + mouthY * mouthY / 0.035));

    float mouthPulse = 0.5 + 0.5 * sin(time * 1.8 + phase * 3.5);
    float mouthPresence = mouthOpening * mouthPulse * faceMask;

    float ambientFace = smoothstep(0.3, 0.7, instability)
        * (sin(time * 0.45 + phase * 2.0) * 0.3 + 0.7);
    float faceEmergence = max(ambientFace, smoothstep(0.12, 0.78, attackCharge));

    float3 darkPurple = float3(0.25, 0.08, 0.42);
    float3 vibrantPurple = float3(0.68, 0.15, 0.85);
    float3 brightViolet = float3(0.82, 0.2, 0.95);
    float3 cyanHighlight = float3(0.0, 0.95, 1.0);
    float3 whiteCore = float3(1.0, 1.0, 1.0);
    float3 eyeGlow = float3(0.3, 0.9, 1.0);
    float3 mouthDark = float3(0.15, 0.02, 0.25);

    float3 color = mix(darkPurple, vibrantPurple, plasmaA * 0.6 + vortexPattern * 0.3);
    color = mix(color, brightViolet, fresnel * 0.4 + instability * 0.3);
    color = mix(color, cyanHighlight, instability * 0.15 + (fresnel * 0.08));

    float coreIntensity = smoothstep(0.15, 0.0, distFromCenter);
    color = mix(color, whiteCore, coreIntensity * 0.6);

    color = mix(color, eyeGlow, eyePresence * faceEmergence * 0.8);
    color = mix(color, mouthDark, mouthPresence * faceEmergence * 0.7);

    float coreGlow = (0.8 + sin(time * 1.15 + phase * 4.0) * 0.2) * coreIntensity;
    float plasmaGlow = (0.35 + instability * 0.65 + fresnel * 0.55) * vortexPattern;
    float faceIntensity = eyePresence * 2.8 + mouthPresence * 0.3;

    float intensity = coreGlow + plasmaGlow + faceIntensity + attackCharge * 0.85;
    intensity *= controls.z;

    float coreAlpha = 0.25 * coreIntensity;
    float plasmaAlpha = (0.08 + instability * 0.22 + fresnel * 0.18) * vortexPattern;
    float faceAlpha = eyePresence * 0.25 + mouthPresence * 0.15;
    float outerFade = smoothstep(0.5, 0.35, distFromCenter);

    float alpha = (coreAlpha + plasmaAlpha + faceAlpha + attackCharge * 0.08)
        * outerFade * controls.w;

    surface.set_emissive_color(half3(color * intensity));
    surface.set_opacity(half(saturate(alpha)));
}
