uniform sampler2D BloomSampler;
uniform float HasFx;
uniform float Bloom;
uniform vec4 Flash;     // rgb, strength
uniform vec4 Vignette;  // rgb, strength
uniform vec4 Impact;    // strength, mode, x, y
uniform vec4 Speed;     // strength, x, y
uniform vec4 Zoom;      // strength, x, y
uniform vec4 Grade;     // desaturate, contrast, grain, aberration

vec4 fetch(vec2 uv) {
    uv = clamp(uv, vec2(0.001), vec2(0.999));
    vec4 c = texture(DiffuseSampler, uv);
    if (HasFx < 0.5) c.a = 0.0;
    return c;
}

// Radial streak pattern around a screen point: thin wedges of random width, like hand-drawn speed lines.
float streaks(vec2 uv, vec2 center, float density, float seed) {
    float aspect = OutSize.x / OutSize.y;
    vec2 p = (uv - center) * vec2(aspect, 1.0);
    float r = length(p);
    float a = atan(p.y, p.x) / TAU + 0.5;
    float cells = 220.0;
    float id = floor(a * cells);
    float f = fract(a * cells);
    float h = hash12(vec2(id, seed));
    float on = step(1.0 - density, h);
    float width = 0.12 + 0.3 * hash12(vec2(id + 7.0, seed));
    float wedge = smoothstep(width, width * 0.4, abs(f - 0.5));
    float start = 0.18 + 0.35 * hash12(vec2(id + 3.0, seed));
    return on * wedge * smoothstep(start, start + 0.12, r);
}

void main() {
    vec2 uv = texCoord;
    vec4 c;

    if (Zoom.x > 0.001) {
        vec2 center = Zoom.yz;
        vec4 acc = vec4(0.0);
        for (int i = 0; i < 10; i++) {
            float k = float(i) / 9.0;
            acc += fetch(mix(uv, center, k * Zoom.x * 0.14));
        }
        c = acc / 10.0;
    } else {
        c = fetch(uv);
    }

    if (Grade.w > 0.001) {
        vec2 off = (uv - 0.5) * Grade.w * 0.012;
        c.r = fetch(uv + off).r;
        c.b = fetch(uv - off).b;
    }

    float glow = c.a;
    vec3 col = c.rgb;
    if (Bloom > 0.001) {
        col += texture(BloomSampler, uv).rgb * Bloom;
    }

    // Stopped world: everything goes grey and hard, the effects keep their colour.
    if (Grade.x > 0.001) {
        float g = lum(col);
        vec3 grey = vec3(g) * vec3(0.96, 0.98, 1.04);
        col = mix(col, grey, Grade.x * (1.0 - saturate(glow * 1.6)));
    }
    if (Grade.y > 0.001) {
        col = (col - 0.5) * (1.0 + Grade.y) + 0.5;
    }

    // Speed lines.
    if (Speed.x > 0.001) {
        float seed = floor(GTime * 24.0);
        float s = streaks(uv, Speed.yz, 0.35, seed);
        col = mix(col, vec3(1.0), s * Speed.x * 0.85);
    }

    // Impact frame: the whole picture snaps to two flat inks for a frame or two.
    if (Impact.x > 0.001) {
        float l = lum(texture(SceneSampler, uv).rgb + c.rgb * 0.5) + glow * 0.4;
        float edge = 0.42 + 0.08 * (vnoise2(uv * OutSize / 9.0) - 0.5);
        float bright = step(edge, l);
        vec3 inkA;
        vec3 inkB;
        int mode = int(Impact.y + 0.5);
        if (mode == 2) {
            inkA = vec3(0.0);
            inkB = vec3(0.92, 0.06, 0.1);
        } else if (mode == 3) {
            inkA = vec3(0.0);
            inkB = vec3(1.0);
        } else {
            inkA = vec3(1.0);
            inkB = vec3(0.0);
        }
        vec3 frame = mix(inkA, inkB, bright);
        float lines = streaks(uv, Impact.zw, 0.45, 17.0 + Impact.y);
        frame = mix(frame, mode == 1 ? vec3(0.0) : vec3(1.0), lines * 0.9);
        col = mix(col, frame, saturate(Impact.x));
    }

    if (Flash.w > 0.001) {
        col = mix(col, Flash.rgb, saturate(Flash.w));
    }

    if (Vignette.w > 0.001) {
        vec2 p = (uv - 0.5) * vec2(OutSize.x / OutSize.y, 1.0);
        float v = smoothstep(0.35, 1.05, length(p) * 1.25);
        col = mix(col, Vignette.rgb, v * Vignette.w);
    }

    if (Grade.z > 0.001) {
        col += (hash12(uv * OutSize + fract(GTime * 7.13) * 911.0) - 0.5) * Grade.z * 0.22;
    }

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
