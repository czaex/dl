// Battle Mode hand auras and entry rings. P0.x: 1 Blade (rings only), 2 Martial fire, 3 Ki glow, 4 Shadow smoke,
// 5 Thunder sparks, 6 Mirage shards, 7 Celestial (rings only), 8 Cosmic (rings only),
// 10 Abyss (rings only).
// Pts[0..7] = hands (xyz, power), Pts[8..11] = entry rings (feet xyz, age in seconds, <0 = none).

const vec3 FIRE_CORE = vec3(1.0, 0.97, 0.82);
const vec3 FIRE_MID = vec3(1.0, 0.62, 0.12);
const vec3 FIRE_EDGE = vec3(0.85, 0.16, 0.04);
const vec3 KI_CORE = vec3(0.95, 1.0, 1.0);
const vec3 KI_MID = vec3(0.35, 0.82, 1.0);
const vec3 KI_EDGE = vec3(0.08, 0.3, 0.95);
const vec3 INK = vec3(0.03, 0.01, 0.06);
const vec3 DUSK = vec3(0.32, 0.12, 0.55);
const vec3 VIOLET = vec3(0.68, 0.45, 1.0);
const vec3 CRIMSON = vec3(1.0, 0.18, 0.3);
const vec3 VOLT = vec3(0.5, 0.82, 1.0);
const vec3 VOLT_YELLOW = vec3(1.0, 0.88, 0.3);
const vec3 JADE = vec3(0.36, 0.95, 0.78);
const vec3 JADE_DEEP = vec3(0.04, 0.38, 0.32);
const vec3 JADE_PALE = vec3(0.88, 1.0, 0.96);
const vec3 GOLD = vec3(1.0, 0.79, 0.29);
const vec3 NEBULA = vec3(1.0, 0.31, 0.85);
const vec3 ABYSS = vec3(0.69, 0.15, 1.0);

vec3 styleColor(int mode) {
    return mode == 2 ? FIRE_MID : mode == 3 ? KI_MID : mode == 4 ? VIOLET : mode == 5 ? VOLT : mode == 6 ? JADE : mode == 7 ? GOLD : mode == 8 ? NEBULA : mode == 10 ? ABYSS : CRIMSON;
}

void fireHand(inout vec4 c, vec3 rd, float sceneT, vec3 pos, float power, float size) {
    float r = 0.24 * size;
    float tp;
    float d = rayPoint(rd, pos, tp);
    if (tp <= 0.0 || tp > sceneT + r || d > r * 2.4) return;
    vec3 q = rd * tp - pos;
    float n = fbm3(vec3(q.x * 9.0, q.y * 6.0 - GTime * 9.0, q.z * 9.0));
    float i = ((1.0 - d / r) * 1.1 + (n - 0.5) * 1.4 + max(q.y, 0.0) * 1.8) * power;
    float m = celMask(i);
    if (m <= 0.0) return;
    vec3 col = cel(i, FIRE_CORE, FIRE_MID, FIRE_EDGE);
    paint(c, col, m * 0.8);
    emit(c, col * 0.25 * m, m);
}

void kiHand(inout vec4 c, vec3 rd, float sceneT, vec3 pos, float power, float seed, float size) {
    float r = 0.2 * size;
    float tp;
    float d = rayPoint(rd, pos, tp);
    if (tp <= 0.0 || tp > sceneT + r || d > r * 3.0) return;
    float n = vnoise2(vec2(atan(rd.y, rd.x) * 6.0, GTime * 14.0 + seed));
    float i = ((1.0 - d / r) * 0.9 + (n - 0.5) * 0.5) * power;
    float m = celMask(i) * 0.75;
    vec3 col = cel(i, KI_CORE, KI_MID, KI_EDGE);
    paint(c, col, m * 0.7);
    float glow = exp(-max(d - r * 0.6, 0.0) / 0.08) * 0.5 * power;
    emit(c, KI_MID * glow + col * 0.2 * m, max(m, glow));
    // An occasional tiny spark arcing off the hand.
    float flick = step(0.7, hash11(floor(GTime * 12.0) + seed));
    if (flick > 0.0) {
        vec3 dir = normalize(hash31(floor(GTime * 12.0) + seed * 3.0) - 0.5);
        float t, s;
        float ds = raySeg(rd, pos + dir * r * 0.8, pos + dir * r * 2.6, t, s);
        float spark = ink(ds, 0.006, t) * power;
        emit(c, vec3(1.0) * spark, spark);
    }
}

void shadowHand(inout vec4 c, vec3 rd, float sceneT, vec3 pos, float power, float seed, float size) {
    float r = 0.22 * size;
    // Shadow dripping off the hand.
    float t, s;
    float dd = raySeg(rd, pos, pos - vec3(0.0, 0.55 * size, 0.0), t, s);
    if (t > 0.0 && t < sceneT + 0.2) {
        float drip = ink(dd, 0.05 * size * (1.0 - s) * power, t) * (1.0 - s);
        paint(c, INK, drip * 0.85);
    }
    float tp;
    float d = rayPoint(rd, pos, tp);
    if (tp <= 0.0 || tp > sceneT + r || d > r * 2.0) return;
    vec3 q = rd * tp - pos;
    float n = fbm3(q * 10.0 + vec3(0.0, GTime * 2.5, seed));
    float i = ((1.0 - d / r) * 1.1 + (n - 0.5) * 1.2) * power;
    float m = celMask(i);
    if (m <= 0.0) return;
    vec3 col = cel(1.0 - i * 0.6, VIOLET, DUSK, INK);
    paint(c, col, m * 0.85);
    c.a = max(c.a, m * 0.5);
}

// Electricity crackling round the fist: a few jagged arcs that re-roll many times a second, crisp white cores.
void thunderHand(inout vec4 c, vec3 rd, float sceneT, vec3 pos, float power, float seed, float size) {
    float r = 0.22 * size;
    float tp;
    float d = rayPoint(rd, pos, tp);
    if (tp <= 0.0 || tp > sceneT + r * 2.0 || d > r * 3.5) return;
    // A faint charged shell.
    float shell = (1.0 - smoothstep(r * 0.55, r * 0.9, d)) * 0.25 * power;
    emit(c, VOLT * shell, shell);
    for (int a = 0; a < 3; a++) {
        float cell = floor(GTime * 14.0 + float(a) * 0.37);
        float s0 = cell * 5.0 + float(a) * 19.0 + seed * 7.0;
        if (hash11(s0 + 1.0) < 0.3) continue;
        vec3 dir = normalize(hash31(s0) - 0.5);
        vec3 side = normalize(cross(dir, hash31(s0 + 2.0) - 0.5));
        vec3 prev = pos + dir * r * 0.4;
        float len = r * (1.4 + 1.6 * hash11(s0 + 3.0));
        float best = 1e9;
        float bt = 0.0;
        for (int k = 1; k <= 4; k++) {
            float f = float(k) / 4.0;
            vec3 p = pos + dir * (r * 0.4 + len * f) + side * (hash11(s0 + float(k) * 4.1) - 0.5) * r * 0.9;
            float t, s;
            float dk = raySeg(rd, prev, p, t, s);
            if (dk < best) { best = dk; bt = t; }
            prev = p;
        }
        if (bt <= 0.0 || bt > sceneT + r) continue;
        float core = ink(best, 0.007 * size, bt) * power;
        float glow = exp(-best / (0.025 * size)) * 0.5 * power;
        vec3 tint = hash11(s0 + 9.0) > 0.8 ? VOLT_YELLOW : VOLT;
        emit(c, vec3(1.0) * core + tint * glow, max(core, glow));
    }
}

// Three little mirror shards circling the fist, flashing as they turn to the camera.
void mirageHand(inout vec4 c, vec3 rd, float sceneT, vec3 pos, float power, float seed, float size) {
    float r = 0.26 * size;
    float tp;
    float d = rayPoint(rd, pos, tp);
    if (tp <= 0.0 || tp > sceneT + r * 2.0 || d > r * 1.8) return;
    float best = 1e9;
    vec3 col = vec3(0.0);
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float a = GTime * 2.6 + fi * TAU / 3.0 + seed;
        vec3 p = pos + vec3(cos(a), 0.35 * sin(a * 1.7 + fi), sin(a)) * r;
        float s = 0.055 * size * power;
        float spin = GTime * 5.0 + fi * 2.0;
        vec3 n = normalize(vec3(cos(spin), 0.4, sin(spin)));
        vec3 u = normalize(cross(n, vec3(0.0, 1.0, 0.0)));
        vec3 v = cross(n, u);
        // Ray-plane, then a triangle test in the shard's plane.
        float t = rayPlane(rd, p, n);
        if (t <= 0.0 || t > sceneT || t > best) continue;
        vec3 q = rd * t - p;
        vec2 l = vec2(dot(q, u), dot(q, v)) / s;
        float inside = step(-0.5, l.y) * step(l.y, 1.0 - abs(l.x) * 1.7);
        if (inside <= 0.0) continue;
        best = t;
        float facing = abs(dot(n, rd));
        col = cel(facing * 0.7 + pow(facing, 8.0) * 0.5, JADE_PALE, JADE, JADE_DEEP);
    }
    if (best < 1e8) {
        paint(c, col, 0.9);
        c.a = max(c.a, 0.3);
    }
}

// The burst on entering Battle Mode: a ring racing out over the ground and a brief column of light.
void entryRing(inout vec4 c, vec3 rd, float sceneT, vec3 feet, float age, vec3 color) {
    if (age < 0.0 || age > 0.6) return;
    float k = age / 0.6;
    vec3 center = feet + vec3(0.0, 0.06, 0.0);
    float tp = rayPlane(rd, center, vec3(0.0, 1.0, 0.0));
    if (tp > 0.0 && tp < sceneT + 0.3) {
        float r = length(rd * tp - center);
        float rr = 0.3 + 2.8 * sqrt(k);
        float ring = ink(abs(r - rr), 0.05 * (1.0 - k) + 0.01, tp) * (1.0 - k);
        emit(c, (vec3(1.0) * 0.6 + color) * ring, ring);
    }
    if (age < 0.25) {
        float t, s;
        float d = raySeg(rd, feet, feet + vec3(0.0, 3.0, 0.0), t, s);
        if (t < sceneT + 0.5) {
            float w = 0.25 * (1.0 - age / 0.25) * (1.0 - s);
            float core = ink(d, w, t);
            emit(c, mix(color, vec3(1.0), 0.5) * core, core);
        }
    }
}

void main() {
    vec2 uv = texCoord;
    initPixel(uv);
    vec4 c = baseColor(uv);
    vec3 rd = viewDir(uv);
    float sceneT = sceneDist(uv);
    int mode = int(P0.x + 0.5);
    for (int i = 0; i < 8; i++) {
        vec4 h = Pts[i];
        if (h.w <= 0.0) continue;
        bool firstPerson = h.w > 5.0;
        float power = firstPerson ? h.w - 10.0 : h.w;
        float size = firstPerson ? 0.55 : 1.0;
        if (power <= 0.0) continue;
        if (mode == 2) {
            fireHand(c, rd, sceneT, h.xyz, power, size);
        } else if (mode == 3) {
            kiHand(c, rd, sceneT, h.xyz, power, float(i), size);
        } else if (mode == 4) {
            shadowHand(c, rd, sceneT, h.xyz, power, float(i), size);
        } else if (mode == 5) {
            thunderHand(c, rd, sceneT, h.xyz, power, float(i), size);
        } else if (mode == 6) {
            mirageHand(c, rd, sceneT, h.xyz, power, float(i), size);
        }
    }
    for (int i = 8; i < 12; i++) {
        entryRing(c, rd, sceneT, Pts[i].xyz, Pts[i].w, styleColor(mode));
    }
    fragColor = c;
}
