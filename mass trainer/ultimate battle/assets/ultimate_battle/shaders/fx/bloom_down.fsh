uniform vec2 TexelSize;
uniform float Prefilter;

// 13-tap downsample. The first level only keeps light the effects emitted (alpha mask), so the plain
// world never blooms.
vec4 tap(vec2 uv) {
    vec4 c = texture(DiffuseSampler, uv);
    if (Prefilter > 0.5) {
        vec3 hot = max(c.rgb - 0.75, 0.0) / 0.25;
        c.rgb = hot * c.a;
    }
    return c;
}

void main() {
    vec2 d = TexelSize;
    vec2 uv = texCoord;
    vec4 a = tap(uv + d * vec2(-2.0, 2.0));
    vec4 b = tap(uv + d * vec2(0.0, 2.0));
    vec4 c = tap(uv + d * vec2(2.0, 2.0));
    vec4 e = tap(uv + d * vec2(-2.0, 0.0));
    vec4 f = tap(uv);
    vec4 g = tap(uv + d * vec2(2.0, 0.0));
    vec4 h = tap(uv + d * vec2(-2.0, -2.0));
    vec4 i = tap(uv + d * vec2(0.0, -2.0));
    vec4 j = tap(uv + d * vec2(2.0, -2.0));
    vec4 k = tap(uv + d * vec2(-1.0, 1.0));
    vec4 l = tap(uv + d * vec2(1.0, 1.0));
    vec4 m = tap(uv + d * vec2(-1.0, -1.0));
    vec4 n = tap(uv + d * vec2(1.0, -1.0));
    vec4 o = f * 0.125 + (a + c + h + j) * 0.03125 + (b + e + g + i) * 0.0625 + (k + l + m + n) * 0.125;
    fragColor = vec4(o.rgb, 1.0);
}
