// Shadow effects. P0.x picks the skill: 1 Shadow Step, 2 Shadow Bind, 3 Eclipse Barrage.

const vec3 INK = vec3(0.03, 0.01, 0.06);
const vec3 DUSK = vec3(0.32, 0.12, 0.55);
const vec3 VIOLET = vec3(0.68, 0.45, 1.0);
const vec3 PALE = vec3(0.92, 0.84, 1.0);

float window2(float t, float in0, float in1, float out0, float out1) {
    return saturate((t - in0) / max(in1 - in0, 0.001)) * (1.0 - saturate((t - out0) / max(out1 - out0, 0.001)));
}

vec3 camRight() { return normalize((InvView * vec4(1.0, 0.0, 0.0, 0.0)).xyz); }
vec3 camUp() { return normalize((InvView * vec4(0.0, 1.0, 0.0, 0.0)).xyz); }

// A billow of cel-shaded shadow smoke: black core, violet edge.
void smoke(inout vec4 c, vec3 rd, float sceneT, vec3 pos, float radius, float age, float life) {
    if (age < 0.0 || age > life) return;
    float k = age / life;
    float r = radius * (0.5 + 0.8 * sqrt(k));
    if (length(pos) < r + 0.4) return;
    float tp;
    float d = rayPoint(rd, pos, tp);
    if (tp <= 0.0 || tp > sceneT + r || d > r * 1.5) return;
    vec3 q = rd * tp - pos;
    float n = fbm3(q * 2.2 + vec3(0.0, age * 3.0, 0.0));
    float i = ((1.0 - d / r) * 1.1 + (n - 0.5) * 1.2) * (1.0 - k * k);
    float m = celMask(i);
    if (m <= 0.0) return;
    vec3 col = cel(1.0 - i * 0.7, VIOLET, DUSK, INK);
    paint(c, col, m * 0.92);
    c.a = max(c.a, m * 0.6);
}

// Expanding ring with ink spikes, camera-facing (a hit).
void spark(inout vec4 c, vec3 rd, float sceneT, vec3 pos, float k, float size, float seed) {
    if (k < 0.0 || k > 0.3) return;
    float tp;
    float d = rayPoint(rd, pos, tp);
    if (tp > sceneT + 1.0) return;
    float u = k / 0.3;
    float rr = size * (0.25 + 1.2 * sqrt(u));
    float ring = ink(abs(d - rr), 0.03 * (1.0 - u) + 0.004, tp);
    vec3 v = rd * tp - pos;
    float ang = atan(dot(v, camUp()), dot(v, camRight()));
    float spikes = pow(max(cos(ang * 4.0 + seed * 5.0), 0.0), 50.0) + pow(max(cos(ang * 3.0 + seed * 11.0 + 0.7), 0.0), 70.0);
    float spike = spikes * smoothstep(rr * 1.8, rr * 0.4, d) * step(rr * 0.25, d) * (1.0 - u);
    float flash = exp(-d / (size * 0.18)) * exp(-k * 18.0);
    emit(c, PALE * (ring + spike) + VIOLET * flash, saturate(ring + spike + flash));
}

// A dark streak with a violet rim (a teleport path or a kick).
void streak(inout vec4 c, vec3 rd, float sceneT, vec3 a, vec3 b, float width, float alpha) {
    if (alpha <= 0.001) return;
    float t, s;
    float d = raySeg(rd, a, b, t, s);
    if (t <= 0.0 || t > sceneT + 0.5) return;
    float w = width * sqrt(max(sin(PI * s), 0.0));
    float core = ink(d, w, t);
    float rim = ink(d, w * 1.8 + 0.01, t) - core;
    paint(c, INK, core * alpha);
    emit(c, VIOLET * rim * alpha, rim * alpha);
}

// A tendril: a tapering, wavering spike of shadow from base up to height h (bending toward 'lean').
void tendril(inout vec4 c, vec3 rd, float sceneT, vec3 base, float h, vec3 lean, float seed, float time) {
    if (h <= 0.05) return;
    vec3 prev = base;
    for (int k = 1; k <= 4; k++) {
        float f = float(k) / 4.0;
        vec3 p = base + vec3(0.0, h * f, 0.0) + lean * f * f
            + vec3(sin(seed * 3.0 + f * 5.0 + time * 4.0), 0.0, cos(seed * 5.0 + f * 4.0 + time * 3.0)) * 0.18 * f;
        float t, s;
        float d = raySeg(rd, prev, p, t, s);
        if (t > 0.0 && t < sceneT + 0.3) {
            float w = mix(0.16, 0.02, mix(f - 0.25, f, s));
            float core = ink(d, w, t);
            float rim = ink(d, w + 0.035, t) - core;
            paint(c, INK, core);
            emit(c, VIOLET * rim * 1.2, rim);
        }
        prev = p;
    }
}

// Violet cracks and a darkened scorch on the ground round an impact.
void shadowGround(inout vec4 c, vec3 surface, vec3 center, float k, float radius, float seed) {
    vec3 q = surface - center;
    if (abs(q.y) > 3.0) return;
    float r = length(q.xz);
    float vertical = 1.0 - smoothstep(1.5, 3.0, abs(q.y));
    float rr = radius * 1.6 * (1.0 - pow(1.0 - saturate(k / 0.4), 3.0));
    float ring = (1.0 - smoothstep(0.1, 0.4, abs(r - rr))) * (1.0 - smoothstep(0.3, 0.7, k)) * vertical;
    emit(c, VIOLET * ring * 1.2, ring);
    float spread = radius * smoothstep(0.0, 0.25, k);
    if (r < spread) {
        float cd = crackDist(q.xz * 0.6, seed);
        float line = 1.0 - smoothstep(0.015, 0.05, cd);
        float fade = 1.0 - smoothstep(radius * 0.5, radius, r);
        float life = 1.0 - smoothstep(2.0, 3.5, k);
        c.rgb = mix(c.rgb, c.rgb * 0.35, fade * vertical * 0.8);
        paint(c, mix(DUSK, PALE, 0.4) , line * fade * vertical * life);
        c.a = max(c.a, line * fade * life * 0.6);
    }
}

void shadowStep(inout vec4 c, vec3 rd, float sceneT) {
    float t = P0.y;
    float appear = P0.z;
    float kick = P0.w;
    smoke(c, rd, sceneT, Origin + vec3(0.0, 1.0, 0.0), 1.0, t, 0.7);
    smoke(c, rd, sceneT, Target + vec3(0.0, 1.0, 0.0), 0.9, t - appear, 0.6);
    // The path through the dark between the two puffs.
    float pathA = (1.0 - smoothstep(appear, appear + 0.35, t)) * step(1.6, length(Origin + vec3(0.0, 1.0, 0.0)));
    streak(c, rd, sceneT, Origin + vec3(0.0, 1.0, 0.0), Target + vec3(0.0, 1.0, 0.0), 0.05, pathA * step(0.02, t));
    // The spinning back-kick: a violet arc sweeping round at hip height.
    float k = t - kick;
    if (k > -0.05 && k < 0.35) {
        float sweep = saturate((k + 0.05) / 0.12);
        float alpha = 1.0 - smoothstep(0.15, 0.35, k);
        vec3 hub = Target + vec3(0.0, 1.0, 0.0);
        float tp = rayPlane(rd, hub, vec3(0.0, 1.0, 0.0));
        if (tp > 0.0 && tp < sceneT + 0.3) {
            vec3 p = rd * tp - hub;
            float r = length(p.xz);
            float ang = atan(p.z, p.x) / TAU + 0.5;
            float arc = step(ang, sweep) * (1.0 - smoothstep(0.0, 0.2, abs(r - 1.3))) * smoothstep(0.0, 0.25, ang);
            float core = arc * (1.0 - smoothstep(0.0, 0.06, abs(r - 1.3)));
            emit(c, (PALE * core + VIOLET * arc * 0.6) * alpha, arc * alpha);
        }
        spark(c, rd, sceneT, P1.xyz, k, 1.0, 3.0);
    }
}

void bind(inout vec4 c, vec3 rd, float sceneT, vec3 surface, bool sky) {
    float t = P0.y;
    float rise = P0.z;
    float squeeze = P0.w;
    float R = P1.x;
    float k = t - rise;
    // The shadow pool and its ring.
    if (!sky && t > 0.0) {
        vec3 q = surface - Target;
        float r = length(q.xz);
        float open = saturate(t / 0.3) * (1.0 - smoothstep(squeeze + 0.2, squeeze + 0.9, t));
        float vertical = 1.0 - smoothstep(1.5, 3.0, abs(q.y));
        float pool = (1.0 - smoothstep(R * 0.85, R, r)) * open * vertical;
        c.rgb = mix(c.rgb, INK * 2.0, pool * 0.65);
        float ring = (1.0 - smoothstep(0.04, 0.14, abs(r - R))) * open * vertical;
        float ang = atan(q.z, q.x);
        float runes = step(0.6, fract(ang / TAU * 36.0 + t * 0.2)) * (1.0 - smoothstep(0.05, 0.12, abs(r - R * 0.9))) * open * vertical;
        emit(c, VIOLET * (ring * 1.2 + runes * 0.8), max(ring, runes));
    }
    if (k < 0.0) return;
    float grow = 1.0 - pow(1.0 - saturate(k / 0.25), 3.0);
    float retract = 1.0 - smoothstep(squeeze, squeeze + 0.45, t);
    float tighten = smoothstep(squeeze - 0.15, squeeze, t) * (1.0 - smoothstep(squeeze, squeeze + 0.2, t));
    // Loose tendrils across the pool.
    for (int i = 0; i < 9; i++) {
        float fi = float(i);
        vec2 h = hash22(vec2(fi, 7.0)) * 2.0 - 1.0;
        vec3 base = Target + vec3(h.x, 0.0, h.y) * R * 0.8;
        tendril(c, rd, sceneT, base, (1.2 + 1.4 * hash11(fi * 3.1)) * grow * retract, vec3(0.0), fi, t);
    }
    // Four tendrils coiling round each bound enemy.
    for (int i = 0; i < 12; i++) {
        vec4 v = Pts[i];
        if (v.w <= 0.0) continue;
        for (int j = 0; j < 4; j++) {
            float a = float(j) / 4.0 * TAU + float(i);
            vec3 off = vec3(cos(a), 0.0, sin(a)) * (0.75 - 0.3 * tighten);
            tendril(c, rd, sceneT, v.xyz + off, v.w * 0.95 * grow * retract, -off * (0.9 + 0.5 * tighten), float(i * 4 + j), t);
        }
    }
}

void eclipse(inout vec4 c, vec3 rd, float sceneT, vec3 surface, bool sky) {
    float tick = P0.y;
    float seed = P0.z;
    vec3 chest = Target;
    // Shadow gathering round the caster before it steps out.
    if (tick < P2.x) {
        smoke(c, rd, sceneT, Caster + vec3(0.0, 0.5 + 0.2 * sin(tick), 0.0), 0.9, mod(tick, 10.0) / 20.0, 0.5);
    }
    // The black sun behind the target while it hangs in the sky.
    float sunA = P1.w;
    if (sunA > 0.001) {
        vec3 center = chest + normalize(chest) * 9.0 + vec3(0.0, 1.5, 0.0);
        float tp;
        float d = rayPoint(rd, center, tp);
        float R = 4.2;
        if (tp > 0.0 && tp < sceneT) {
            float corona = exp(-max(d - R, 0.0) / 0.9) * step(R * 0.96, d);
            float flare = pow(max(cos(atan(dot(rd * tp - center, camUp()), dot(rd * tp - center, camRight())) * 6.0 + tick * 0.05), 0.0), 30.0)
                * exp(-max(d - R, 0.0) / 3.0) * step(R, d);
            float disc = 1.0 - smoothstep(R * 0.97, R, d);
            paint(c, INK, disc * sunA);
            emit(c, (PALE * corona + VIOLET * flare * 0.8) * sunA, max(corona, disc) * sunA);
        }
    }
    // The launching kick.
    spark(c, rd, sceneT, P3.xyz, (tick - P3.w) / 20.0, 1.6, 1.0);
    // Teleport streaks and hits round the target.
    for (int k = 0; k < 8; k++) {
        vec4 s = Pts[k];
        float age = (tick / 20.0) - s.w;
        if (age < -0.05 || age > 0.5) continue;
        vec3 from = k == 0 ? Pts[8].xyz : Pts[k - 1].xyz;
        streak(c, rd, sceneT, from, s.xyz, 0.06, 1.0 - smoothstep(0.1, 0.4, age));
        smoke(c, rd, sceneT, s.xyz, 0.6, age, 0.4);
        spark(c, rd, sceneT, mix(s.xyz, chest, 0.75), age, 1.1, float(k));
    }
    // The axe kick dropping the target back down.
    float dropA = window2(tick, P2.y, P2.y + 1.0, P2.z, P2.z + 3.0);
    if (dropA > 0.0) {
        streak(c, rd, sceneT, chest + vec3(0.0, 4.0, 0.0), chest, 0.25, dropA);
    }
    float k = (tick - P2.z) / 20.0;
    if (k >= 0.0) {
        if (!sky) shadowGround(c, surface, P2.w > 0.0 ? Pts[9].xyz : chest, k, 5.0, seed);
        smoke(c, rd, sceneT, Pts[9].xyz + vec3(0.0, 0.6, 0.0), 2.6, k, 1.2);
        float tp;
        float d = rayPoint(rd, Pts[9].xyz + vec3(0.0, 0.5, 0.0), tp);
        float flash = exp(-k * 10.0) * exp(-d / 1.0);
        if (tp < sceneT + 2.0) emit(c, PALE * flash, flash);
    }
}

void main() {
    vec2 uv = texCoord;
    initPixel(uv);
    vec4 c = baseColor(uv);
    vec3 rd = viewDir(uv);
    float sceneT = sceneDist(uv);
    bool sky = sceneT >= FAR;
    vec3 surface = sky ? vec3(0.0) : rd * sceneT;
    int mode = int(P0.x + 0.5);
    if (mode == 1) {
        shadowStep(c, rd, sceneT);
    } else if (mode == 2) {
        bind(c, rd, sceneT, surface, sky);
    } else if (mode == 3) {
        eclipse(c, rd, sceneT, surface, sky);
    }
    fragColor = c;
}
