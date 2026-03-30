#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uTime;
uniform float uIntensity;
uniform float uScrollOffset;
uniform vec4 uColor1;
uniform vec4 uColor2;
uniform vec4 uColor3;

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
    mat2 rot = mat2(cos(0.5), sin(0.5), -sin(0.5), cos(0.5));
    for (int i = 0; i < 6; i++) {
        v += a * noise(p);
        p = rot * p * 2.0 + shift;
        a *= 0.5;
    }
    return v;
}

float voronoi(vec2 p) {
    vec2 n = floor(p);
    vec2 f = fract(p);
    float md = 8.0;
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 g = vec2(float(i), float(j));
            vec2 o = vec2(hash(n + g), hash(n + g + vec2(17.0, 31.0)));
            o = 0.5 + 0.5 * sin(uTime * 0.2 + 6.2831 * o);
            vec2 r = g + o - f;
            float d = dot(r, r);
            md = min(md, d);
        }
    }
    return sqrt(md);
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution;
    float aspect = uResolution.x / uResolution.y;
    vec2 st = uv;
    st.x *= aspect;

    float scroll = uScrollOffset * 0.0005;
    float t = uTime * 0.08;
    float intensity = uIntensity;

    // Domain warping for organic nebula shapes
    vec2 q = vec2(
        fbm(st * 2.0 + vec2(0.0, t * 0.6)),
        fbm(st * 2.0 + vec2(5.2, t * 0.4))
    );

    vec2 r = vec2(
        fbm(st * 2.5 + 4.0 * q + vec2(1.7, t * 0.3)),
        fbm(st * 2.5 + 4.0 * q + vec2(8.3, t * 0.5))
    );

    vec2 s = vec2(
        fbm(st * 3.0 + 3.0 * r + vec2(21.7, t * 0.2)),
        fbm(st * 3.0 + 3.0 * r + vec2(14.3, t * 0.35))
    );

    float f = fbm(st * 1.5 + r * 2.0 + s * 0.5);

    // Voronoi for cosmic dust structure
    float vor = voronoi(st * 4.0 + q * 2.0);
    float cosmicDust = smoothstep(0.0, 0.6, vor) * 0.15;

    // Vignette with vertical parallax
    float dist = length((uv - vec2(0.5)) * vec2(1.0, 1.2) + vec2(0.0, scroll));
    float vignette = 1.0 - smoothstep(0.2, 1.3, dist);

    // Color mixing with three-tone nebula
    float blend = f * 0.5 + q.x * 0.25 + r.y * 0.15 + s.x * 0.1;
    blend = blend * vignette;

    vec3 col1 = uColor1.rgb;
    vec3 col2 = uColor2.rgb;
    vec3 col3 = uColor3.rgb;

    vec3 color = mix(col1, col2, smoothstep(0.0, 0.5, blend));
    color = mix(color, col3, smoothstep(0.3, 0.8, blend + f * 0.2));

    // Ethereal highlights
    float highlight = pow(max(f * 1.2 - 0.3, 0.0), 3.0) * vignette;
    color += vec3(1.0, 0.95, 0.9) * highlight * 0.15 * intensity;

    // Cosmic dust overlay
    color += col2 * cosmicDust * intensity * 0.5;

    float alpha = blend * (0.35 + 0.35 * intensity) * vignette;
    alpha += cosmicDust * intensity * 0.2;
    alpha = clamp(alpha, 0.0, 0.92);

    fragColor = vec4(color * alpha, alpha);
}
