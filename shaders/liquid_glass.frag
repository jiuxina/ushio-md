#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 resolution;
uniform float time;
uniform vec4 color;

out vec4 fragColor;

// Smooth noise helper — produces organic-looking variation
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    // Cubic Hermite interpolation for smoothness
    f = f * f * (3.0 - 2.0 * f);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void main() {
    vec2 uv = FlutterFragCoord().xy / resolution;

    // ── 1. Multi-layered wave distortion ──────────────────────────
    // Layer 1: Large slow wave — viscous bulk motion
    float wave1 = sin(uv.x * 6.2832 + time * 0.8) * 0.008;
    wave1 += cos(uv.y * 4.7124 + time * 0.6) * 0.006;

    // Layer 2: Medium ripple — surface tension undulation
    float wave2 = sin((uv.x + uv.y) * 9.4248 + time * 1.2) * 0.004;
    wave2 += cos((uv.x - uv.y) * 7.8540 + time * 0.9) * 0.003;

    // Layer 3: Fine detail — capillary waves
    float wave3 = sin(uv.x * 18.8496 + time * 2.0) * cos(uv.y * 15.7080 + time * 1.5) * 0.002;

    // Layer 4: Organic noise-based distortion for natural feel
    float n = noise(uv * 8.0 + time * 0.3) * 2.0 - 1.0;
    float distort = wave1 + wave2 + wave3 + n * 0.005;

    // Apply distortion to UV
    vec2 distortedUV = uv + vec2(distort, distort * 0.7);

    // ── 2. Surface normals estimation ─────────────────────────────
    // Compute gradient of distortion field for lighting
    float eps = 0.001;
    float dx = sin((distortedUV.x + eps) * 6.2832 + time * 0.8) * 0.008
             + cos((distortedUV.y) * 4.7124 + time * 0.6) * 0.006
             + sin(((distortedUV.x + eps) + distortedUV.y) * 9.4248 + time * 1.2) * 0.004
             - distort;
    float dy = sin(distortedUV.x * 6.2832 + time * 0.8) * 0.008
             + cos((distortedUV.y + eps) * 4.7124 + time * 0.6) * 0.006
             + sin((distortedUV.x + (distortedUV.y + eps)) * 9.4248 + time * 1.2) * 0.004
             - distort;

    vec2 normal = normalize(vec2(dx, dy));

    // ── 3. Specular highlights ────────────────────────────────────
    // Light source moves slowly for natural caustic-like shimmer
    vec2 lightDir = normalize(vec2(
        cos(time * 0.5) * 0.7,
        sin(time * 0.3) * 0.5 + 0.5
    ));

    // Simulate reflection: dot product of distorted normal with light
    float spec = dot(normal, lightDir);
    spec = pow(max(spec, 0.0), 10.0) * 0.75;

    // Secondary highlight — sharper, offset angle
    vec2 lightDir2 = normalize(vec2(
        cos(time * 0.7 + 2.0) * 0.5,
        sin(time * 0.4 + 1.0) * 0.6 - 0.3
    ));
    float spec2 = pow(max(dot(normal, lightDir2), 0.0), 20.0) * 0.45;

    // Animated specular sweep across the surface
    float sweep = sin((distortedUV.x + distortedUV.y) * 3.14159 - time * 0.8);
    float specSweep = pow(max(sweep, 0.0), 18.0) * 0.6;

    float highlights = spec + spec2 + specSweep;

    // ── 4. Edge glow (Fresnel-like rim) ──────────────────────────
    // Distance from center creates brighter edges — simulates glass surface tension
    vec2 center = uv - 0.5;
    float dist = length(center);

    // Squared distance for softer falloff
    float edgeFactor = smoothstep(0.25, 0.75, dist);
    float edgeGlow = edgeFactor * 0.35;

    // ── 5. Compose final color ───────────────────────────────────
    // Base glass: semi-transparent with slight internal luminosity
    float baseLuminance = 0.85 + noise(distortedUV * 4.0 + time * 0.1) * 0.15;

    // Tint from uniform color
    vec3 glassColor = color.rgb * baseLuminance;

    // Add highlights as white/specular spots
    glassColor += vec3(1.0) * highlights;

    // Add edge glow
    glassColor += color.rgb * edgeGlow * 0.5;

    // Internal refraction bands — subtle color separation
    float refract = sin(distortedUV.x * 12.0 + distortedUV.y * 8.0 + time) * 0.04;
    glassColor.r += refract;
    glassColor.b -= refract;

    // Alpha: semi-transparent base, boosted by highlights and edges
    float alpha = color.a * 0.4;
    alpha += highlights * 0.5;
    alpha += edgeGlow * 0.4;
    alpha = clamp(alpha, 0.05, 0.95);

    // Slight desaturation at edges for realism
    float gray = dot(glassColor, vec3(0.299, 0.587, 0.114));
    glassColor = mix(vec3(gray), glassColor, 0.85 + edgeFactor * 0.15);

    fragColor = vec4(glassColor, alpha);
}
