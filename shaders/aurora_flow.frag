#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uTime;
uniform float uProgress;
uniform vec4 uColor1;
uniform vec4 uColor2;

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
    vec2 shift = vec2(100.0);
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p = p * 2.0 + shift;
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution;

    float t = uTime * 0.15;
    float prog = uProgress;

    vec2 q = vec2(0.0);
    q.x = fbm(uv * 2.5 + vec2(0.0, t * 0.7));
    q.y = fbm(uv * 2.5 + vec2(5.2, t * 0.5));

    vec2 r = vec2(0.0);
    r.x = fbm(uv * 3.0 + 4.0 * q + vec2(1.7, t * 0.3));
    r.y = fbm(uv * 3.0 + 4.0 * q + vec2(8.3, t * 0.4));

    float f = fbm(uv * 2.0 + r * 2.5);

    float dist = length(uv - vec2(0.5)) * 1.4;
    float vignette = 1.0 - smoothstep(0.3, 1.2, dist);

    float blend = f * 0.6 + q.x * 0.2 + r.y * 0.2;
    blend = blend * vignette;

    float progressShift = prog * 0.3;
    vec4 col1 = uColor1;
    vec4 col2 = uColor2;

    vec4 mixed = mix(col1, col2, smoothstep(0.0, 1.0, blend + progressShift));

    float alpha = blend * (0.5 + 0.3 * prog) * vignette;
    alpha = clamp(alpha, 0.0, 0.85);

    fragColor = vec4(mixed.rgb * alpha, alpha);
}
