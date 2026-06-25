#version 460 core
#include <flutter/runtime_effect.glsl>

uniform sampler2D u_texture;
uniform vec2 u_size;
uniform float time;
uniform float refractionStrength;
uniform float chromaticAberration;
uniform float noiseStrength;

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

void main() {
    vec2 uv = FlutterFragCoord().xy / u_size;

    float n = noise(uv * 8.0 + time * 0.4) * 2.0 - 1.0;
    vec2 distortion = vec2(
        sin(uv.y * 10.0 + time * 0.7),
        cos(uv.x * 9.0 + time * 0.6)
    );
    distortion = (distortion + n) * refractionStrength;

    vec2 baseUV = uv + distortion;
    float ca = chromaticAberration / max(u_size.x, u_size.y);

    float r = texture(u_texture, baseUV + vec2(ca, 0.0)).r;
    float g = texture(u_texture, baseUV).g;
    float b = texture(u_texture, baseUV - vec2(ca, 0.0)).b;

    vec3 color = vec3(r, g, b);
    float grain = (hash(uv * u_size + time) - 0.5) * noiseStrength;
    color += grain;

    fragColor = vec4(color, 1.0);
}
