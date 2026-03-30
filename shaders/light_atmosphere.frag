#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uTime;
uniform float uIntensity;
uniform float uScrollOffset;

out vec4 fragColor;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    mat2 rot = mat2(cos(0.5), sin(0.5), -sin(0.5), cos(0.5));
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p = rot * p * 2.0 + vec2(100.0);
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution;
    float aspect = uResolution.x / uResolution.y;
    vec2 st = uv;
    st.x *= aspect;

    float t = uTime * 0.05;
    float scroll = uScrollOffset * 0.0003;
    float intensity = uIntensity;

    // Soft layered organic motion
    vec2 q = vec2(
        fbm(st * 1.8 + vec2(t * 0.3, 0.0)),
        fbm(st * 1.8 + vec2(0.0, t * 0.25))
    );

    vec2 r = vec2(
        fbm(st * 2.2 + 3.0 * q + vec2(1.7, t * 0.15)),
        fbm(st * 2.2 + 3.0 * q + vec2(8.3, t * 0.2))
    );

    float f = fbm(st * 1.5 + r * 1.5);

    // Warm gradient base (peach → lavender → cream)
    vec3 warmBase = vec3(0.98, 0.96, 0.93);
    vec3 peach = vec3(0.99, 0.92, 0.88);
    vec3 lavender = vec3(0.94, 0.91, 0.97);
    vec3 cream = vec3(0.98, 0.97, 0.93);

    // Vertical gradient: warm top, cool bottom
    vec3 bgColor = mix(peach, lavender, uv.y * 0.8 + scroll);
    bgColor = mix(bgColor, cream, f * 0.3);

    // Soft organic light patches
    float patch1 = fbm(st * 2.5 + q * 2.0 + vec2(t * 0.1));
    float patch2 = fbm(st * 3.0 + r * 1.5 + vec2(t * 0.15, 3.0));

    vec3 lightPatch = vec3(0.98, 0.94, 0.89) * patch1 * 0.08 * intensity;
    vec3 coolPatch = vec3(0.90, 0.91, 0.98) * patch2 * 0.06 * intensity;

    bgColor += lightPatch + coolPatch;

    // Subtle sun glow from top-right
    float sunDist = length((uv - vec2(0.75, 0.08)) * vec2(1.0, 1.5));
    float sunGlow = exp(-sunDist * 3.0) * 0.06 * intensity;
    bgColor += vec3(1.0, 0.95, 0.85) * sunGlow;

    // Vignette — very subtle
    float dist = length(uv - 0.5);
    float vig = 1.0 - smoothstep(0.5, 1.4, dist) * 0.08;
    bgColor *= vig;

    bgColor = clamp(bgColor, 0.0, 1.0);

    float alpha = 0.6 + 0.3 * intensity;
    alpha = clamp(alpha, 0.0, 0.95);

    fragColor = vec4(bgColor * alpha, alpha);
}
