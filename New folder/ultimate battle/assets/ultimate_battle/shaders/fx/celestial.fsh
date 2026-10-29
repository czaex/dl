// Celestial effects. P0.x picks the skill: 1 Flying Sword, 2 Eight Trigram Array, 3 Celestial Attack.
// The swords themselves are real Celestial Jian item models drawn by the game; this pass adds what is round them:
// golden flight trails, hit sparks, the bagua seal on the ground, the halo of the ultimate, the clouds of heaven
// opening above the target, the light of the forge and the blow of the colossal sword. Lines stay crisp.

const vec3 GOLD = vec3(1.0, 0.79, 0.29);
const vec3 GOLD_PALE = vec3(1.0, 0.95, 0.78);
const vec3 GOLD_DEEP = vec3(0.55, 0.3, 0.05);
const vec3 VERMILION = vec3(1.0, 0.33, 0.22);
const vec3 CLOUD_DARK = vec3(0.09, 0.07, 0.14);
const vec3 CLOUD_MID = vec3(0.27, 0.19, 0.27);
const vec3 CLOUD_LIT = vec3(0.62, 0.42, 0.30);

float window2(float t, float in0, float in1, float out0, float out1) {
    return saturate((t - in0) / max(in1 - in0, 0.001)) * (1.0 - saturate((t - out0) / max(out1 - out0, 0.001)));
}

vec3 camRight() { return normalize((InvView * vec4(1.0, 0.0, 0.0, 0.0)).xyz); }
vec3 camUp() { return normalize((InvView * vec4(0.0, 1.0, 0.0, 0.0)).xyz); }

// Paints over the scene without raising the glow mask (solid things, not light).
void solid(inout vec4 c, vec3 col, float a) {
    c.rgb = mix(c.rgb, col, saturate(a));
}

vec2 turn2(vec2 v, float a) {
    float cs = cos(a), sn = sin(a);
    return vec2(v.x * cs - v.y * sn, v.x * sn + v.y * cs);
}

// Ray from the camera along rd against triangle a-b-c: ray distance or -1, barycentrics in bc.
float rayTri(vec3 rd, vec3 a, vec3 b, vec3 c, out vec3 bc) {
    vec3 e1 = b - a;
    vec3 e2 = c - a;
    vec3 p = cross(rd, e2);
    float det = dot(e1, p);
    if (abs(det) < 1e-7) return -1.0;
    float inv = 1.0 / det;
    vec3 s = -a;
    float u = dot(s, p) * inv;
    if (u < 0.0 || u > 1.0) return -1.0;
    vec3 q = cross(s, e1);
    float v = dot(rd, q) * inv;
    if (v < 0.0 || u + v > 1.0) return -1.0;
    bc = vec3(1.0 - u - v, u, v);
    return dot(e2, q) * inv;
}

// A golden streak: pale core, gold body, thin vermilion fringe, tapering at both ends.
void streak(inout vec4 c, vec3 rd, float sceneT, vec3 a, vec3 b, float width, float alpha) {
    if (alpha <= 0.001) return;
    float t, s;
    float d = raySeg(rd, a, b, t, s);
    if (t <= 0.0 || t > sceneT + 0.5) return;
    float w = width * sqrt(max(sin(PI * s), 0.0));
    float core = ink(d, w * 0.35, t);
    float body = ink(d, w, t) - core;
    float fringe = ink(d, w * 1.5, t) - core - body;
    emit(c, (GOLD_PALE * core + GOLD * body * 0.85 + VERMILION * fringe * 0.4) * alpha, max(core, body * 0.7) * alpha);
}

// A hit: an expanding gold ring with four sharp spikes, camera-facing. k in seconds.
void spark(inout vec4 c, vec3 rd, float sceneT, vec3 pos, float k, float size, float seed) {
    if (k < 0.0 || k > 0.3) return;
    float tp;
    float d = rayPoint(rd, pos, tp);
    if (tp > sceneT + 1.0 || d > size * 2.5) return;
    float u = k / 0.3;
    float rr = size * (0.25 + 1.2 * sqrt(u));
    float ring = ink(abs(d - rr), 0.03 * (1.0 - u) + 0.004, tp);
    vec3 v = rd * tp - pos;
    float ang = atan(dot(v, camUp()), dot(v, camRight())) + seed;
    float spikes = pow(max(cos(ang * 2.0), 0.0), 60.0) + pow(max(cos(ang * 2.0 + PI * 0.5), 0.0), 60.0) * 0.6;
    float spike = spikes * smoothstep(rr * 1.9, rr * 0.3, d) * step(rr * 0.2, d) * (1.0 - u);
    float flash = exp(-d / (size * 0.12)) * exp(-k * 22.0);
    emit(c, GOLD_PALE * (ring + spike) + GOLD * flash, saturate(ring + spike + flash));
}

// Golden petals flung from a point: flat tumbling triangles, bright when they turn to the camera. age in seconds.
void petals(inout vec4 c, vec3 rd, float sceneT, vec3 pos, float age, float seed, float speed, float size) {
    if (age < 0.0 || age > 1.0) return;
    float life = age;
    float reach = speed * 1.3 * age + 3.0 * age * age + size * 1.5;
    float tp;
    float dc = rayPoint(rd, pos, tp);
    if (dc > reach + 0.3 || tp - reach > sceneT) return;
    float best = 1e9;
    vec3 col = vec3(0.0);
    float edge = 0.0;
    for (int i = 0; i < 12; i++) {
        float fi = float(i) + seed * 17.0;
        vec3 h = hash31(fi * 1.37 + 0.5);
        vec3 h2 = hash31(fi * 2.71 + 9.0);
        vec3 dir = normalize(h * 2.0 - 1.0 + vec3(0.0, 0.5, 0.0));
        vec3 p = pos + dir * speed * (0.45 + 0.85 * h2.x) * age - vec3(0.0, 2.5 * age * age, 0.0);
        float s = size * (0.55 + 0.9 * h2.y) * (1.0 - 0.5 * life);
        float spin = age * (7.0 + 10.0 * h2.z) + fi;
        vec3 ax = normalize(cross(dir, normalize(h2 - 0.5 + vec3(0.01, 0.02, 0.0))));
        vec3 ay = cross(dir, ax);
        vec3 n = normalize(dir * cos(spin) + ax * sin(spin));
        vec3 u = normalize(cross(n, ay + dir * 0.3));
        vec3 v = cross(n, u);
        vec3 a = p + u * s;
        vec3 b = p + (-0.5 * u + 0.6 * v) * s;
        vec3 d = p + (-0.5 * u - 0.6 * v) * s;
        vec3 bc;
        float t = rayTri(rd, a, b, d, bc);
        if (t > 0.0 && t < sceneT && t < best) {
            best = t;
            float facing = abs(dot(n, rd));
            col = cel(facing * 0.75 + pow(facing, 8.0) * 0.4, GOLD_PALE, GOLD, GOLD_DEEP);
            float e = min(bc.x, min(bc.y, bc.z)) * s * 1.6;
            edge = 1.0 - smoothstep(gPix * t * 0.8, gPix * t * 2.0, e);
        }
    }
    if (best < 1e8) {
        float fade = 1.0 - smoothstep(0.7, 1.0, life);
        paint(c, mix(col, GOLD_PALE, edge), 0.92 * fade);
        c.a = max(c.a, 0.3 * fade);
    }
}

// A crisp camera-facing talisman ring (the seal a sword is flung from). alpha 0..1.
void talisman(inout vec4 c, vec3 rd, float sceneT, vec3 pos, float radius, float alpha, float spin) {
    if (alpha <= 0.001) return;
    float tp;
    float d = rayPoint(rd, pos, tp);
    if (tp > sceneT + 0.5 || d > radius * 1.5) return;
    vec3 v = rd * tp - pos;
    float ang = atan(dot(v, camUp()), dot(v, camRight())) + spin;
    float ring = ink(abs(d - radius), 0.012, tp) + ink(abs(d - radius * 0.78), 0.007, tp);
    float ticks = step(abs(fract(ang * 8.0 / TAU + 0.5) - 0.5), 0.06) * step(radius * 0.8, d) * step(d, radius * 0.98);
    float line = saturate(ring + ticks);
    emit(c, (GOLD_PALE * line) * alpha, line * alpha);
}

// ---------------------------------------------------------------- bagua

// The trigram of sector k (Fu Xi order): bit i set = solid bar i (inner to outer), clear = broken bar.
int trigram(int k) {
    int[8] t = int[8](7, 3, 5, 1, 0, 4, 2, 6);
    return t[k];
}

// Bars of the eight trigrams round a centre, in a 2D plane: p in the plane, radius = where the middle bar sits,
// size = the bars' length. Returns coverage 0..1 (antialiased by aa, world units per pixel).
float trigramBars(vec2 p, float radius, float size, float aa) {
    float ang = atan(p.y, p.x);
    float sector = floor(ang / (TAU / 8.0) + 0.5);
    int k = int(mod(sector, 8.0));
    vec2 q = turn2(p, -sector * TAU / 8.0);
    int bits = trigram(k);
    float thick = size * 0.05;
    float gap = size * 0.1;
    float cover = 0.0;
    for (int i = 0; i < 3; i++) {
        float x = radius + (float(i) - 1.0) * size * 0.28;
        float d = max(abs(q.x - x) - thick, abs(q.y) - size * 0.5);
        bool solidBar = ((bits >> i) & 1) == 1;
        if (!solidBar) d = max(d, gap - abs(q.y));
        cover = max(cover, smoothstep(aa, -aa, d));
    }
    return cover;
}

// Taiji in line art: its circle, the S between the halves and the two eyes. p in the plane, r = its radius.
float taiji(vec2 p, float r, float w) {
    float d = abs(length(p) - r);
    vec2 up = p - vec2(0.0, r * 0.5);
    vec2 dn = p + vec2(0.0, r * 0.5);
    if (p.x < 0.0) d = min(d, abs(length(up) - r * 0.5));
    if (p.x > 0.0) d = min(d, abs(length(dn) - r * 0.5));
    d = min(d, max(length(up) - r * 0.12, 0.0));
    d = min(d, abs(length(dn) - r * 0.12));
    return d - w;
}

// The bagua seal painted on the ground round 'center': rings, octagon, eight trigrams, taiji, spokes.
// draw = 0..1 how much is drawn on, rot = its turn (radians), boost = extra brightness.
void baguaSeal(inout vec4 c, vec3 surface, vec3 center, vec3 facing, float radius, float draw, float alpha, float rot, float boost) {
    if (alpha <= 0.001 || draw <= 0.0) return;
    vec3 q = surface - center;
    if (abs(q.y) > 0.35) return;
    vec3 right = normalize(vec3(-facing.z, 0.0, facing.x));
    vec2 p = turn2(vec2(dot(q, right), dot(q, facing)), rot);
    float r = length(p);
    if (r > radius * 1.08) return;
    float tp = length(surface);
    float aa = gPix * tp;
    float ang = atan(p.y, p.x);
    float sweep = fract((ang + PI * 0.5) / TAU);
    float on = step(sweep, draw);
    float w = 0.018;
    float line = 0.0;
    line = max(line, on * ink(abs(r - radius), w * 1.4, tp));
    line = max(line, on * ink(abs(r - radius * 0.92), w * 0.6, tp));
    float af = mod(ang + PI / 8.0, PI / 4.0) - PI / 8.0;
    line = max(line, on * ink(abs(r * cos(af) - radius * 0.83), w, tp));
    line = max(line, trigramBars(p, radius * 0.62, radius * 0.26, aa) * smoothstep(0.3, 0.9, draw) * 0.7);
    float tj = taiji(p, radius * 0.24, w * 0.6);
    line = max(line, smoothstep(aa, -aa, tj) * smoothstep(0.5, 1.0, draw));
    float spokes = abs(fract(ang * 8.0 / TAU) - 0.5) * TAU / 8.0 * r;
    line = max(line, ink(spokes, w * 0.4, tp) * step(radius * 0.28, r) * step(r, radius * 0.44) * smoothstep(0.6, 1.0, draw));
    line *= alpha;
    emit(c, (GOLD * 0.55 + GOLD_PALE * 0.45 * boost) * line, line * 0.45);
}

// ---------------------------------------------------------------- Flying Sword
// P0 = (1, tick, LAUNCH, CATCH), P1 = (seed, locked). Pts[0..11] the flight path from now back in time (w = valid),
// Pts[12..14] the three piercing points (w = tick, < 0 none), Pts[15] the hand (launch), Pts[16] the hand (catch).
void flyingSword(inout vec4 c, vec3 rd, float sceneT) {
    float t = P0.y;
    float launch = P0.z;
    float caught = P0.w;
    float seed = P1.x;
    float best = 1e9;
    float bestT = 0.0;
    float bestK = 0.0;
    for (int k = 0; k < 11; k++) {
        if (Pts[k].w < 0.5 || Pts[k + 1].w < 0.5) continue;
        float tt, s;
        float d = raySeg(rd, Pts[k].xyz, Pts[k + 1].xyz, tt, s);
        if (tt > 0.0 && tt < sceneT + 0.3 && d < best) {
            best = d;
            bestT = tt;
            bestK = float(k) + s;
        }
    }
    if (best < 1e8) {
        float taper = 1.0 - bestK / 11.0;
        float w = 0.1 * taper;
        float core = ink(best, w * 0.35, bestT);
        float body = ink(best, w, bestT) - core;
        float fringe = ink(best, w * 1.5, bestT) - core - body;
        float a = smoothstep(0.0, 0.25, taper);
        emit(c, (GOLD_PALE * core + GOLD * body * 0.85 + VERMILION * fringe * 0.35) * a, max(core, body * 0.7) * a);
    }
    for (int i = 12; i < 15; i++) {
        if (Pts[i].w < 0.0) continue;
        spark(c, rd, sceneT, Pts[i].xyz, (t - Pts[i].w) / 20.0, 0.9, float(i) + seed);
    }
    talisman(c, rd, sceneT, Pts[15].xyz, 0.32, window2(t, launch - 4.0, launch - 2.0, launch + 1.0, launch + 4.0), t * 0.2);
    spark(c, rd, sceneT, Pts[16].xyz, (t - caught) / 20.0, 0.5, seed + 3.0);
}

// ---------------------------------------------------------------- Eight Trigram Array
// P0 = (2, tick, SEAL, BURST), P1 = (RING, seed, spin (rad), SPIN). Origin = caster feet, Facing = forward.
// Pts[0..7] sword k's place at launch (w = launch tick), Pts[8..15] the point it flies through (w = strike tick),
// Pts[16..23] its point in the ground (w = 1 once stuck).
void trigramArray(inout vec4 c, vec3 rd, float sceneT, vec3 surface, bool sky) {
    float t = P0.y;
    float seal = P0.z;
    float burst = P0.w;
    float ring = P1.x;
    float seed = P1.y;
    float spin = P1.z;
    vec3 right = normalize(vec3(-Facing.z, 0.0, Facing.x));
    if (!sky) {
        float draw = smoothstep(0.0, seal, t);
        float alpha = window2(t, 0.0, 1.0, burst + 2.0, burst + 12.0);
        float boost = exp(-max(t - burst, 0.0) * 0.3) * step(burst, t) + 0.3 * exp(-abs(t - seal) * 0.5);
        baguaSeal(c, surface, Origin, Facing, 3.6, draw, alpha, -spin * 0.12, boost);
        // Where each sword rises out of the seal: a small ring opening on the ground.
        for (int k = 0; k < 8; k++) {
            float rise = 6.0 + float(k);
            float u = (t - rise) / 7.0;
            if (u < 0.0 || u > 1.0) continue;
            float a = radians(22.5 + 45.0 * float(k));
            vec2 dir2 = vec2(cos(a), sin(a));
            vec3 spoke = Facing * dir2.x + right * dir2.y;
            vec3 q = surface - (Origin + spoke * ring);
            if (abs(q.y) > 0.35) continue;
            float rr = 0.2 + 0.8 * (1.0 - pow(1.0 - u, 3.0));
            float l = ink(abs(length(q.xz) - rr), 0.025 * (1.0 - u) + 0.006, length(surface));
            emit(c, GOLD_PALE * l * (1.0 - u), l * (1.0 - u));
        }
    }
    for (int k = 0; k < 8; k++) {
        float launch = Pts[k].w;
        float strike = Pts[k + 8].w;
        streak(c, rd, sceneT, Pts[k].xyz, Pts[k + 8].xyz, 0.06, window2(t, launch, launch + 0.5, strike + 1.0, strike + 5.0));
        streak(c, rd, sceneT, Pts[k + 8].xyz, Pts[k + 16].xyz, 0.05, window2(t, strike, strike + 0.5, strike + 2.0, strike + 6.0));
        spark(c, rd, sceneT, Pts[k + 8].xyz, (t - strike) / 20.0, 0.8, float(k) + seed);
        float age = (t - burst) / 20.0;
        if (Pts[k + 16].w > 0.5 && age >= 0.0) {
            vec3 at = Pts[k + 16].xyz + vec3(0.0, 0.6, 0.0);
            spark(c, rd, sceneT, at, age, 1.0, float(k) * 3.0 + seed);
            petals(c, rd, sceneT, at, age, seed + float(k), 3.5, 0.12);
            streak(c, rd, sceneT, Pts[k + 16].xyz, Pts[k + 16].xyz + vec3(0.0, 3.0, 0.0), 0.08, (1.0 - smoothstep(0.0, 0.3, age)));
        }
    }
}

// ---------------------------------------------------------------- Celestial Attack
// P0 = (3, tick, seed), P1 = (SUMMON, LOCK, FIRE, FORGE), P2 = (SWING, IMPACT, FADE, giant length),
// P3 = (GIANT_IN, GIANT_FULL, SKY, RAISE). Origin = halo centre, Facing = caster to target (flat),
// Target = target's feet, Caster = caster's feet. Pts[0..15] eight streaks (tail, head; head.w = alpha),
// Pts[16..21] recent landings (w = tick, < 0 none), Pts[22] colossal sword point (w = its scale), Pts[23] target chest.

const float CLOUD_UP = 40.0;

// The colossal sword's point (height over the target's feet) at tick t, as in CelestialMoves.giantTip.
float giantTipY(float t, float sky, float giantFull, float swing, float impact) {
    float w = saturate((t - giantFull) / (swing - giantFull));
    float top = sky + 2.0 * w * w * (3.0 - 2.0 * w);
    float u = saturate((t - swing) / (impact - swing));
    return top + (-3.5 - top) * pow(u, 2.5);
}

// The clouds of heaven: a slow spiral of dark storm cloud with gilded edges over the target, its eye opening.
void heaven(inout vec4 c, vec3 rd, float sceneT, vec3 center, float alpha, float eye, float t) {
    if (alpha <= 0.001) return;
    float tp = rayPlane(rd, center, vec3(0.0, 1.0, 0.0));
    if (tp <= 0.0 || tp > sceneT) return;
    vec3 q = rd * tp - center;
    float r = length(q.xz);
    float cover = smoothstep(90.0, 45.0, r) * alpha;
    if (cover <= 0.001) return;
    float ang = atan(q.z, q.x);
    float swirl = ang + log(r + 2.0) * 1.7 - t * 0.012;
    vec2 sp = vec2(cos(swirl), sin(swirl)) * (r * 0.06 + 1.0);
    float dens = fbm3(vec3(sp * 1.4, t * 0.004)) + 0.18 * sin(swirl * 3.0);
    float hole = smoothstep(eye, eye + 6.0, r);
    dens *= hole;
    float aa = gPix * tp * 0.06 + 0.01;
    float body = smoothstep(0.42 - aa, 0.42 + aa, dens);
    float shade = smoothstep(0.55, 0.62, dens);
    vec3 col = mix(CLOUD_MID, CLOUD_DARK, shade);
    // Lit undersides near the eye, gilded rims where the cloud edges run.
    col = mix(col, CLOUD_LIT, smoothstep(eye + 14.0, eye, r) * 0.6);
    float rim = (1.0 - smoothstep(0.0, aa * 2.5 + 0.012, abs(dens - 0.42))) * hole;
    solid(c, col, body * cover * 0.92);
    emit(c, GOLD * rim * cover * 0.8, rim * cover * 0.5);
    // The rim of the eye: one crisp golden circle.
    float eyeLine = ink(abs(r - (eye + 3.0)), 0.25, tp) * step(1.0, eye);
    emit(c, GOLD_PALE * eyeLine * cover, eyeLine * cover);
}

// A shaft of light straight down from the sky: crisp edges, a soft inside.
void column(inout vec4 c, vec3 rd, float sceneT, vec3 top, vec3 bottom, float radius, float alpha) {
    if (alpha <= 0.001) return;
    float t, s;
    float d = raySeg(rd, bottom, top, t, s);
    if (t <= 0.0 || t > sceneT + radius) return;
    float inside = smoothstep(radius, radius * 0.4, d);
    float edge = ink(abs(d - radius), 0.04, t);
    float core = ink(d, radius * 0.18, t);
    float fade = smoothstep(0.0, 0.08, s) * smoothstep(1.0, 0.85, s);
    emit(c, (GOLD * inside * 0.08 + GOLD_PALE * edge * 0.5 + GOLD * core * 0.4) * alpha * fade, (edge + core) * 0.5 * alpha * fade);
}

// The halo behind the caster, in the plane facing the target: rings with tick marks, the eight trigrams, a taiji
// in the middle, faint spokes and a ripple where each sword slides out.
void haloRing(inout vec4 c, vec3 rd, float sceneT, float t) {
    float summon = P1.x;
    float lock = P1.y;
    float forge = P1.w;
    float raise = P3.w;
    float alpha = window2(t, raise, raise + 4.0, forge, forge + 10.0);
    if (alpha <= 0.001) return;
    vec3 right = normalize(vec3(-Facing.z, 0.0, Facing.x));
    float tp = rayPlane(rd, Origin, Facing);
    if (tp <= 0.0 || tp > sceneT + 0.2) return;
    // Seen edge-on the plane's lines would stretch into streaks across the screen: fade it out instead.
    alpha *= smoothstep(0.08, 0.3, abs(dot(rd, Facing)));
    if (alpha <= 0.001) return;
    vec3 q = rd * tp - Origin;
    vec2 p = vec2(dot(q, right), q.y);
    float r = length(p);
    if (r > 9.2) return;
    float aa = gPix * tp;
    float ang = atan(p.y, p.x);
    float draw = smoothstep(raise, raise + 12.0, t);
    float from = abs(mod(ang - PI * 0.5 + PI, TAU) - PI) / PI;
    float on = step(from, draw);
    float line = 0.0;
    line = max(line, on * ink(abs(r - 7.0), 0.05, tp));
    line = max(line, on * ink(abs(r - 7.35), 0.025, tp));
    float tick = abs(fract(ang * 72.0 / TAU + 0.5) - 0.5) * TAU / 72.0 * r;
    line = max(line, on * ink(tick, 0.012, tp) * step(7.0, r) * step(r, 7.35));
    vec2 pr = turn2(p, t * 0.004);
    line = max(line, trigramBars(pr, 8.05, 1.1, aa) * smoothstep(0.5, 1.0, draw));
    float af = mod(atan(pr.y, pr.x) + PI / 8.0, PI / 4.0) - PI / 8.0;
    line = max(line, on * ink(abs(r * cos(af) - 8.75), 0.03, tp));
    vec2 pt = turn2(p, -t * 0.03);
    line = max(line, smoothstep(aa, -aa, taiji(pt, 1.25, 0.035)) * smoothstep(0.2, 0.6, draw));
    line = max(line, ink(abs(r - 1.45), 0.02, tp) * smoothstep(0.2, 0.6, draw));
    float spoke = abs(fract(ang * 24.0 / TAU + 0.5) - 0.5) * TAU / 24.0 * r;
    line = max(line, ink(spoke, 0.01, tp) * step(1.45, r) * step(r, 7.0) * 0.35 * on);
    // The lock: a wave of light running out across the halo as every sword turns.
    float wave = (t - lock) * 0.75 + 1.4;
    line = max(line, ink(abs(r - wave), 0.06, tp) * window2(t, lock, lock + 0.5, lock + 8.0, lock + 10.0) * 1.5);
    line *= alpha;
    emit(c, GOLD * 0.6 * line + GOLD_PALE * 0.15 * line, line * 0.45);
    // Ripples where the swords come out.
    float ripple = 0.0;
    int idx = 0;
    for (int j = 0; j < 4; j++) {
        int n = j == 0 ? 12 : j == 1 ? 18 : j == 2 ? 24 : 30;
        float rad = 2.4 + 1.2 * float(j);
        if (abs(r - rad) > 1.0) continue;
        for (int s = 0; s < 30; s++) {
            if (s >= n) break;
            float deg = -30.0 + 240.0 * (float(s) + 0.5) / float(n);
            float appear = summon + 28.0 * abs(deg - 90.0) / 120.0 + 1.5 * float(j);
            float u = (t - appear + 1.0) / 7.0;
            if (u < 0.0 || u > 1.0) continue;
            vec2 h = vec2(cos(radians(deg)), sin(radians(deg))) * rad;
            float rr = 0.15 + 0.7 * (1.0 - pow(1.0 - u, 3.0));
            ripple = max(ripple, ink(abs(length(p - h) - rr), 0.03 * (1.0 - u) + 0.006, tp) * (1.0 - u));
        }
    }
    emit(c, GOLD_PALE * ripple * 0.7 * alpha, ripple * 0.6 * alpha);
}

void celestialAttack(inout vec4 c, vec3 rd, float sceneT, vec3 surface, bool sky) {
    float t = P0.y;
    float seed = P0.z;
    float summon = P1.x;
    float lock = P1.y;
    float fire = P1.z;
    float forge = P1.w;
    float swing = P2.x;
    float impact = P2.y;
    float fade = P2.z;
    float giantIn = P3.x;
    float giantFull = P3.y;
    float raise = P3.w;
    vec3 deck = vec3(mix(Caster.x, Target.x, 0.6), Target.y + CLOUD_UP, mix(Caster.z, Target.z, 0.6));

    // Heaven opens: the clouds close in over the fight, their eye widening for the forge.
    float sky1 = window2(t, 0.0, 14.0, fade + 4.0, fade + 24.0);
    float eye = 2.0 + 10.0 * smoothstep(forge - 4.0, giantFull, t) + 6.0 * smoothstep(impact, impact + 10.0, t);
    heaven(c, rd, sceneT, deck, sky1, eye, t);
    // A thread of light from the eye to the raised jian as the summoning begins.
    vec3 jianTip = Caster + vec3(0.0, 3.0, 0.0);
    column(c, rd, sceneT, vec3(jianTip.x, deck.y, jianTip.z), jianTip, 0.12, window2(t, raise - 3.0, raise, raise + 6.0, raise + 16.0));

    haloRing(c, rd, sceneT, t);

    for (int k = 0; k < 8; k++) {
        vec4 tail = Pts[k * 2];
        vec4 head = Pts[k * 2 + 1];
        streak(c, rd, sceneT, tail.xyz, head.xyz, 0.06, head.w);
    }
    for (int i = 16; i < 22; i++) {
        if (Pts[i].w < 0.0) continue;
        spark(c, rd, sceneT, Pts[i].xyz, (t - Pts[i].w) / 20.0, 0.7, float(i) + seed);
    }

    // The forge: a column of light from the eye down onto the colossal sword, following it as it falls.
    vec4 giant = Pts[22];
    float forgeA = window2(t, forge, forge + 6.0, impact, impact + 4.0);
    column(c, rd, sceneT, vec3(Target.x, deck.y, Target.z), giant.xyz, 2.2, forgeA * 0.8);
    // The fall: a long wake above it, and a sonic ring torn off the air every other tick on the way down.
    float fallA = window2(t, swing, swing + 1.0, impact, impact + 2.0);
    streak(c, rd, sceneT, giant.xyz + vec3(0.0, P2.w + 14.0, 0.0), giant.xyz + vec3(0.0, P2.w, 0.0), 0.7, fallA);
    for (int i = 0; i < 6; i++) {
        float born = swing + 1.0 + float(i) * 2.0;
        float age = t - born;
        if (born >= impact || age < 0.0 || age > 8.0) continue;
        vec3 at = Target + vec3(0.0, giantTipY(born, P3.z, P3.y, swing, impact) + 0.4 * P2.w, 0.0);
        float tp2 = rayPlane(rd, at, vec3(0.0, 1.0, 0.0));
        if (tp2 <= 0.0 || tp2 > sceneT) continue;
        float r2 = length((rd * tp2 - at).xz);
        float rr = 1.6 + age * 1.3;
        float l = ink(abs(r2 - rr), 0.09 * (1.0 - age / 8.0) + 0.02, tp2) * (1.0 - age / 8.0);
        emit(c, GOLD_PALE * l, l);
    }
    // The ground marked where it will land: a golden circle closing in on the target.
    float mark = window2(t, swing - 2.0, swing, impact, impact + 0.5);
    if (!sky && mark > 0.0) {
        vec3 q = surface - Target;
        if (abs(q.y) < 0.6) {
            float r = length(q.xz);
            float u = saturate((t - swing) / (impact - swing));
            float rr = mix(10.0, 1.2, u * u);
            float l = ink(abs(r - rr), 0.07, length(surface)) + 0.6 * ink(abs(r - rr * 0.62), 0.035, length(surface));
            float ang = atan(q.z, q.x);
            float spokes = abs(fract(ang * 8.0 / TAU + 0.5) - 0.5) * TAU / 8.0 * r;
            l += ink(spokes, 0.03, length(surface)) * step(rr * 0.62, r) * step(r, rr) * 0.7;
            emit(c, GOLD_PALE * l * mark, l * mark);
        }
    }

    // The blow.
    float k = (t - impact) / 20.0;
    if (k >= 0.0) {
        vec3 at = Target;
        if (!sky) {
            vec3 q = surface - at;
            if (abs(q.y) < 0.6) {
                float r = length(q.xz);
                // Two crisp shock rings racing out, then the golden cracks left behind.
                float rr = 22.0 * (1.0 - pow(1.0 - saturate(k / 0.6), 3.0));
                float ring = ink(abs(r - rr), 0.12 * (1.0 - saturate(k / 0.8)) + 0.02, length(surface)) * (1.0 - smoothstep(0.4, 0.9, k));
                float rr2 = 10.0 * (1.0 - pow(1.0 - saturate(k / 0.45), 3.0));
                ring += ink(abs(r - rr2), 0.05, length(surface)) * (1.0 - smoothstep(0.2, 0.5, k));
                emit(c, GOLD_PALE * ring, ring);
                float spread = 12.0 * smoothstep(0.0, 0.25, k);
                if (r < spread) {
                    float cd = crackDist(q.xz * 0.55, seed);
                    float l = 1.0 - smoothstep(0.015, 0.05, cd);
                    float f = (1.0 - smoothstep(6.0, 12.0, r)) * (1.0 - smoothstep((fade - impact) / 20.0, (fade - impact) / 20.0 + 1.5, k));
                    emit(c, mix(GOLD, VERMILION, 0.25) * l * f, l * f);
                }
            }
        }
        // A pillar of light where it lands, gone in a blink.
        column(c, rd, sceneT, at + vec3(0.0, 45.0, 0.0), at, 4.0 * (1.0 - saturate(k / 0.4)), 1.0 - smoothstep(0.1, 0.45, k));
        spark(c, rd, sceneT, at + vec3(0.0, 1.0, 0.0), k * 0.5, 6.0, seed);
        petals(c, rd, sceneT, at + vec3(0.0, 1.0, 0.0), k, seed, 8.0, 0.3);
        petals(c, rd, sceneT, at + vec3(0.0, 0.8, 0.0), k - 0.05, seed + 4.0, 6.0, 0.22);
    }
    // The colossal sword breaks into light.
    float kf = (t - fade) / 20.0;
    if (kf >= 0.0 && kf < 1.0) {
        for (int i = 0; i < 4; i++) {
            vec3 at = Target + vec3(0.0, -1.0 + float(i) * P2.w * 0.24, 0.0);
            petals(c, rd, sceneT, at, kf - float(i) * 0.03, seed + 10.0 + float(i), 4.0, 0.35);
            spark(c, rd, sceneT, at, kf - float(i) * 0.03, 2.0, seed + float(i));
        }
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
        flyingSword(c, rd, sceneT);
    } else if (mode == 2) {
        trigramArray(c, rd, sceneT, surface, sky);
    } else if (mode == 3) {
        celestialAttack(c, rd, sceneT, surface, sky);
    }
    fragColor = c;
}
