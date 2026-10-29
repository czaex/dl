// Thunder effects. P0.x picks the skill: 1 Lightning Step, 2 Storm Field, 3 Raijin Descent.

const vec3 BOLT_CORE = vec3(1.0, 1.0, 1.0);
const vec3 BOLT_GLOW = vec3(0.45, 0.78, 1.0);
const vec3 BOLT_DEEP = vec3(0.12, 0.35, 1.0);
const vec3 SPARK_YELLOW = vec3(1.0, 0.88, 0.3);

float window3(float t, float in0, float in1, float out0, float out1) {
    return saturate((t - in0) / max(in1 - in0, 0.001)) * (1.0 - saturate((t - out0) / max(out1 - out0, 0.001)));
}

void basis(vec3 dir, out vec3 n1, out vec3 n2) {
    vec3 ref = abs(dir.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
    n1 = normalize(cross(dir, ref));
    n2 = cross(dir, n1);
}

// One jagged segment chain from a to b. Returns the closest distance and its ray distance through t.
float jagged(vec3 rd, vec3 a, vec3 b, float seed, float jag, int steps, out float bestT) {
    vec3 dir = b - a;
    float len = length(dir);
    dir /= max(len, 1e-4);
    vec3 n1, n2;
    basis(dir, n1, n2);
    vec3 prev = a;
    float best = 1e9;
    bestT = 0.0;
    for (int k = 1; k <= 12; k++) {
        if (k > steps) break;
        float f = float(k) / float(steps);
        vec3 p = a + (b - a) * f;
        if (k < steps) {
            float taper = sin(PI * f);
            p += (n1 * (hash11(seed + float(k) * 7.13) - 0.5) + n2 * (hash11(seed + float(k) * 3.71 + 9.0) - 0.5)) * jag * len * 0.18 * taper;
        }
        float t, s;
        float d = raySeg(rd, prev, p, t, s);
        if (d < best) { best = d; bestT = t; }
        prev = p;
    }
    return best;
}

// A lightning bolt: white-hot core, blue glow, a couple of forks. Flickers with the seed.
void bolt(inout vec4 c, vec3 rd, float sceneT, vec3 a, vec3 b, float seed, float width, float alpha, float jag) {
    if (alpha <= 0.001) return;
    float t;
    float d = jagged(rd, a, b, seed, jag, 10, t);
    if (t > 0.0 && t < sceneT + width * 4.0) {
        float core = ink(d, width, t);
        float glow = exp(-max(d - width, 0.0) / (width * 2.5 + 0.03)) * 0.7;
        emit(c, (BOLT_CORE * core + BOLT_GLOW * glow) * alpha, (core + glow) * alpha);
    }
    for (int i = 0; i < 2; i++) {
        float fi = float(i);
        float f = 0.25 + 0.5 * hash11(seed * 1.7 + fi * 13.0);
        vec3 from = mix(a, b, f);
        vec3 dir = normalize(b - a);
        vec3 n1, n2;
        basis(dir, n1, n2);
        vec3 to = from + (dir * 0.6 + n1 * (hash11(seed + fi * 5.0) - 0.5) * 2.0 + n2 * (hash11(seed + fi * 9.0) - 0.5) * 2.0) * length(b - a) * 0.22;
        float tb;
        float db = jagged(rd, from, to, seed + fi * 31.0, jag, 4, tb);
        if (tb > 0.0 && tb < sceneT + width * 4.0) {
            float core = ink(db, width * 0.45, tb);
            float glow = exp(-max(db - width * 0.45, 0.0) / (width * 1.5 + 0.02)) * 0.45;
            emit(c, (BOLT_CORE * core + BOLT_GLOW * glow) * alpha * 0.8, (core + glow) * alpha * 0.8);
        }
    }
}

// Small arcs crawling round a body (feet to head).
void staticArcs(inout vec4 c, vec3 rd, float sceneT, vec3 feet, float height, float radius, float power, float seed) {
    if (power <= 0.001) return;
    for (int i = 0; i < 4; i++) {
        float s = floor(GTime * 18.0) * 3.0 + float(i) * 17.0 + seed;
        if (hash11(s + 2.0) < 0.35) continue;
        vec3 a = feet + vec3((hash11(s) - 0.5) * radius * 2.0, hash11(s + 1.0) * height, (hash11(s + 3.0) - 0.5) * radius * 2.0);
        vec3 b = a + (hash31(s + 4.0) - 0.5) * radius * 2.2;
        bolt(c, rd, sceneT, a, b, s, 0.012, power, 1.2);
    }
}

// Ground scorch: blue-white cracks spreading from an impact, a shockwave ring and a darkened crater.
void scorch(inout vec4 c, vec3 surface, vec3 center, float k, float radius, float seed) {
    vec3 q = surface - center;
    if (abs(q.y) > 0.5) return;
    float r = length(q.xz);
    // Only the ground: anything standing on it (mobs, walls) stays clean.
    float vertical = 1.0 - smoothstep(0.1, 0.3, abs(q.y));
    float rr = radius * 2.2 * (1.0 - pow(1.0 - saturate(k / 0.5), 3.0));
    float ring = (1.0 - smoothstep(0.12, 0.45, abs(r - rr))) * (1.0 - smoothstep(0.4, 0.9, k)) * vertical;
    emit(c, mix(BOLT_GLOW, BOLT_CORE, 0.4) * ring * 1.3, ring);
    float spread = radius * smoothstep(0.0, 0.2, k);
    if (r < spread) {
        float cd = crackDist(q.xz * 0.5, seed);
        float ang = atan(q.z, q.x);
        float ray = abs(fract(ang / TAU * 13.0 + hash11(floor(ang / TAU * 13.0) + seed) * 0.4) - 0.5);
        float radial = (1.0 - smoothstep(0.0, 0.05 + 0.012 * r, ray * r * 0.6)) * step(0.6, r);
        float web = step(0.55, vnoise2(q.xz * 0.35 + seed));
        float line = max((1.0 - smoothstep(0.012, 0.045, cd)) * web, radial);
        float fade = 1.0 - smoothstep(radius * 0.55, radius, r);
        float life = 1.0 - smoothstep(2.5, 4.5, k);
        float flick = 0.75 + 0.25 * step(0.5, hash12(vec2(floor(GTime * 15.0), floor(r * 2.0))));
        c.rgb = mix(c.rgb, c.rgb * 0.3, fade * vertical * (1.0 - smoothstep(0.0, radius, r)) * 0.9);
        paint(c, mix(BOLT_DEEP, BOLT_CORE, 0.5 * life) , line * fade * vertical * (0.35 + 0.65 * life));
        emit(c, BOLT_GLOW * line * fade * vertical * life * flick * 0.6, line * fade * life);
    }
}

// ------------------------------------------------------------------ 1: Lightning Step

void lightningStep(inout vec4 c, vec3 rd, float sceneT) {
    float t = P0.y;
    float seed = P0.z;
    float clap = P1.x;
    for (int k = 0; k < 3; k++) {
        vec4 a = Pts[k];
        vec4 b = Pts[k + 1];
        float at = b.w;
        float age = t - at;
        if (age < -0.02) continue;
        float flicker = floor(GTime * 24.0);
        // The trail stays as a crackling bolt until the clap, then bursts and fades.
        float alpha = (age < 0.06 ? 1.0 : 0.55 + 0.25 * hash11(flicker + float(k))) * (1.0 - smoothstep(clap + 0.1, clap + 0.55, t));
        float width = 0.03 + 0.06 * exp(-age * 18.0) + 0.05 * exp(-max(t - clap, 0.0) * 10.0) * step(clap, t);
        bolt(c, rd, sceneT, a.xyz, b.xyz, seed + float(k) * 11.0 + flicker * 0.37, width, alpha, 1.0);
        // The flash where it lands.
        float tp;
        float d = rayPoint(rd, b.xyz, tp);
        float flash = exp(-age * 16.0) * exp(-d / 0.5) * step(0.0, age);
        if (tp < sceneT + 1.0) emit(c, BOLT_GLOW * flash, flash);
    }
    // The thunderclap at the target.
    float k = t - clap;
    if (k > 0.0 && k < 0.5) {
        float tp;
        float d = rayPoint(rd, P1.yzw, tp);
        float u = k / 0.5;
        float ring = ink(abs(d - (0.3 + 2.2 * sqrt(u))), 0.03 * (1.0 - u) + 0.005, tp) * (1.0 - u);
        float flash = exp(-k * 12.0) * exp(-d / 1.0);
        if (tp < sceneT + 1.5) emit(c, BOLT_CORE * ring + BOLT_GLOW * flash, max(ring, flash));
        // And a bolt from the sky onto the target.
        vec3 top = P1.yzw + vec3((seed - floor(seed)) * 4.0 - 2.0, 24.0, 1.0);
        bolt(c, rd, sceneT, top, P1.yzw - vec3(0.0, 1.0, 0.0), seed + floor(GTime * 30.0), 0.1 * (1.0 - u) + 0.03, 1.0 - smoothstep(0.25, 0.5, k), 0.45);
    }
}

// ------------------------------------------------------------------ 2: Storm Field

void stormField(inout vec4 c, vec3 rd, float sceneT, vec3 surface, bool sky) {
    float t = P0.y;
    float seed = P0.z;
    float stomp = P0.w;
    vec3 feet = Caster;
    // The charged field on the ground.
    if (!sky && t > stomp - 0.05) {
        vec3 q = surface - feet;
        float r = length(q.xz);
        float R = P2.x;
        float open = saturate((t - stomp) / 0.2) * (1.0 - smoothstep(P2.y + 0.2, P2.y + 0.8, t));
        float vertical = 1.0 - smoothstep(0.1, 0.3, abs(q.y));
        float ring = (1.0 - smoothstep(0.03, 0.12, abs(r - R))) * open * vertical;
        float ang = atan(q.z, q.x);
        float ticks = step(0.75, fract(ang / TAU * 48.0 - t * 0.5)) * (1.0 - smoothstep(0.04, 0.1, abs(r - R * 0.92))) * open * vertical;
        float crawl = step(0.985, vnoise2(vec2(ang * 30.0, r * 3.0 - GTime * 20.0))) * step(r, R) * open * vertical;
        emit(c, BOLT_GLOW * (ring * 1.3 + ticks + crawl * 1.5), max(max(ring, ticks), crawl));
    }
    staticArcs(c, rd, sceneT, feet, 2.0, 0.6, window3(t, 0.0, 0.1, stomp, stomp + 0.3), seed);
    // The current chain: caster -> enemy -> enemy ...
    float age = P1.x;
    int count = int(P1.z + 0.5);
    if (age >= 0.0 && age < 0.45) {
        float flicker = floor(GTime * 30.0);
        float alpha = (1.0 - smoothstep(0.2, 0.45, age)) * (0.7 + 0.3 * hash11(flicker));
        vec3 prev = feet + vec3(0.0, 1.1, 0.0);
        for (int i = 0; i < 8; i++) {
            if (i >= count) break;
            vec3 p = Pts[i].xyz;
            bolt(c, rd, sceneT, prev, p, seed + float(i) * 7.0 + flicker * 0.5 + P1.y * 50.0, 0.06 * (1.0 - age / 0.45) + 0.025, alpha, 1.1);
            float tp;
            float d = rayPoint(rd, p, tp);
            float flash = exp(-age * 14.0) * exp(-d / 0.45);
            if (tp < sceneT + 1.0) emit(c, BOLT_GLOW * flash, flash);
            prev = p;
            // The last wave is called down from the sky onto the first three.
            if (P1.y > 1.5 && i < 3) {
                vec3 sky0 = p + vec3((hash11(seed + float(i)) - 0.5) * 6.0, 24.0, (hash11(seed + float(i) + 4.0) - 0.5) * 6.0);
                bolt(c, rd, sceneT, sky0, p - vec3(0.0, 1.1, 0.0), seed + float(i) * 19.0 + flicker, 0.09 * (1.0 - age / 0.45) + 0.03, alpha, 0.45);
            }
        }
    }
}

// ------------------------------------------------------------------ 3: Raijin Descent

// The storm: a dark cel-shaded spiral of cloud overhead with lightning flickering inside it.
void stormCloud(inout vec4 c, vec3 rd, float sceneT, vec3 center, float alpha, float time) {
    if (alpha <= 0.001) return;
    float tp = rayPlane(rd, center, vec3(0.0, 1.0, 0.0));
    if (tp <= 0.0 || tp > sceneT) return;
    vec3 q = rd * tp - center;
    float r = length(q.xz);
    float R = 34.0;
    if (r > R) return;
    float ang = atan(q.z, q.x);
    float sw = ang + r * 0.11 - time * 0.4;
    vec2 swirl = vec2(cos(sw), sin(sw)) * r;
    float n = fbm3(vec3(swirl * 0.11, time * 0.12));
    float arms = 0.5 + 0.5 * sin(ang * 3.0 + r * 0.32 - time * 1.2);
    float edge = 1.0 - smoothstep(R * 0.55, R, r);
    float eye = smoothstep(2.5, 5.5, r);
    float dens = (n * 0.9 + arms * 0.3 - 0.3) * edge * eye;
    float m = smoothstep(0.08, 0.13, dens);
    float tone = n + arms * 0.25;
    vec3 col = tone > 0.78 ? vec3(0.34, 0.37, 0.47) : tone > 0.6 ? vec3(0.19, 0.21, 0.3) : vec3(0.07, 0.08, 0.13);
    // Lightning inside the cloud: a cell lights up now and then.
    float cell = floor(time * 6.0);
    vec2 fpos = (hash22(vec2(cell, 3.0)) - 0.5) * R * 1.1;
    float lit = step(0.5, hash11(cell + 7.0)) * (1.0 - fract(time * 6.0));
    float near = 1.0 - smoothstep(4.0, 9.0, length(q.xz - fpos));
    col = mix(col, vec3(0.55, 0.7, 0.95), near * lit * 0.8);
    paint(c, col, m * alpha * 0.95);
    // A thin bright ring round the eye of the storm.
    float ring = (1.0 - smoothstep(0.05, 0.18, abs(r - 4.2))) * alpha;
    emit(c, BOLT_GLOW * ring * 0.8, ring);
}

// ------------------------------------------------------------------ the lightning dragon (ray-marched)
//
// Pts[0] = head centre, Pts[1..19] = spine to the tail tip (xyz, w = radius), Pts[21] = head forward (world
// direction, not camera-relative) and w = jaw opening 0..1. Drawn as a solid cel-shaded model: flattened
// scaled body with belly plates and a saw-toothed dorsal fin, four clawed legs, and a head with brows,
// antler horns, cheek spikes, a hinged jaw with fangs and a glowing throat.

const vec3 DR_HI = vec3(0.55, 0.86, 1.0);
const vec3 DR_MID = vec3(0.17, 0.46, 0.95);
const vec3 DR_LOW = vec3(0.05, 0.13, 0.42);
const vec3 DR_INK = vec3(0.01, 0.02, 0.09);
const vec3 DR_BELLY = vec3(0.86, 0.95, 1.0);
const vec3 DR_HORN = vec3(1.0, 0.86, 0.36);

int dCand[6];
int dCount;
bool dHeadNear;
bool dLegNear[4];
vec3 dHead, dF, dS, dU;
float dHr, dJaw, dTime;

// Opaque paint that does not light up the bloom mask (only what glows should bloom).
void solid(inout vec4 c, vec3 col, float a) {
    c.rgb = mix(c.rgb, col, saturate(a));
    c.a *= 1.0 - saturate(a);
}

float sdCap(vec3 p, vec3 a, vec3 b, float ra, float rb) {
    vec3 pa = p - a;
    vec3 ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
    return length(pa - ba * h) - mix(ra, rb, h);
}

float sdEll(vec3 p, vec3 r) {
    float k0 = length(p / r);
    float k1 = length(p / (r * r));
    return k0 * (k0 - 1.0) / max(k1, 1e-6);
}

float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

void frameOf(vec3 T, out vec3 S, out vec3 U) {
    vec3 s = cross(T, vec3(0.0, 1.0, 0.0));
    if (dot(s, s) < 0.04) s = cross(T, vec3(1.0, 0.0, 0.0));
    S = normalize(s);
    U = cross(S, T);
}

// One body segment. Returns (distance, material) and the local coordinates the shading needs.
vec2 bodySeg(vec3 p, int i, out vec4 local) {
    vec4 a = Pts[i];
    vec4 b = Pts[i + 1];
    if (i == 0) {
        // The neck runs into the back of the skull and is slimmer than the body.
        a = vec4(a.xyz - dF * a.w * 0.35 + dU * a.w * 0.05, b.w * 0.82);
    }
    vec3 ba = b.xyz - a.xyz;
    float L = max(length(ba), 1e-4);
    vec3 T = ba / L;
    float h = clamp(dot(p - a.xyz, T) / L, 0.0, 1.0);
    vec3 q = p - (a.xyz + ba * h);
    float r = mix(a.w, b.w, h);
    vec3 S, U;
    frameOf(T, S, U);
    float x = dot(q, S);
    float y = dot(q, U);
    float z = dot(q, T);
    float along = float(i) + h;
    float rr = r * (1.0 + 0.02 * sin(along * TAU * 3.0));
    float d = length(vec3(x, y * 1.15, z)) - rr;
    // Dorsal fin: a thin saw-toothed blade along the spine (none on the neck).
    float saw = 1.0 - fract(along * 2.6);
    float fh = rr * (0.15 + 0.85 * saw * saw) * smoothstep(0.6, 1.4, along);
    float fin = max(max(abs(x) - rr * 0.06 * (1.0 + saw), y - (rr * 0.85 + fh)), max(rr * 0.3 - y, abs(z) - 0.01));
    local = vec4(x, y, along, r);
    return fin < d ? vec2(fin, 2.0) : vec2(d, 0.0);
}

vec2 legSdf(vec3 p, int k) {
    int seg = k < 2 ? 3 : 11;
    float sgn = (k == 0 || k == 2) ? 1.0 : -1.0;
    vec3 base = Pts[seg].xyz;
    vec3 T = normalize(Pts[seg].xyz - Pts[seg + 1].xyz);
    vec3 S, U;
    frameOf(T, S, U);
    float r = Pts[seg].w;
    float sw = sin(dTime * 5.0 + float(k) * 1.7);
    vec3 hip = base + S * sgn * r * 0.65 - U * r * 0.25;
    vec3 knee = hip + S * sgn * r * 0.9 - U * r * 0.5 + T * r * (0.3 + 0.6 * sw);
    vec3 foot = knee - U * r * 1.2 + T * r * (0.7 - 0.5 * sw) + S * sgn * r * 0.15;
    float d = smin(sdCap(p, hip, knee, r * 0.42, r * 0.26), sdCap(p, knee, foot, r * 0.26, r * 0.17), r * 0.1);
    float claw = 1e9;
    for (int c = -1; c <= 1; c++) {
        vec3 dir = normalize(T + S * sgn * 0.45 * float(c) - U * 0.55);
        vec3 mid = foot + dir * r * 0.45;
        vec3 tip = mid + normalize(dir - U * 1.2) * r * 0.4;
        claw = min(claw, min(sdCap(p, foot, mid, r * 0.12, r * 0.08), sdCap(p, mid, tip, r * 0.08, r * 0.01)));
    }
    return claw < d ? vec2(claw, 5.0) : vec2(d, 0.0);
}

// The head in its own frame: x side, y up, z forward (units of the head radius). Materials: 2 spikes,
// 3 horn, 4 skin, 5 teeth, 6 eye.
float dJawAng;

vec3 toJaw(vec3 l) {
    vec3 hj = l - vec3(0.0, -0.18, -0.1);
    float cs = cos(dJawAng);
    float sn = sin(dJawAng);
    return vec3(hj.x, cs * hj.y + sn * hj.z, -sn * hj.y + cs * hj.z);
}

vec2 headSdf(vec3 p, out vec3 lh) {
    vec3 q = (p - dHead) / dHr;
    vec3 l = vec3(dot(q, dS), dot(q, dU), dot(q, dF));
    lh = l;
    vec3 m = vec3(abs(l.x), l.y, l.z);
    // Cranium, a long flat snout drooping slightly at the tip, nose bumps.
    float skull = sdEll(l - vec3(0.0, 0.1, -0.05), vec3(0.6, 0.5, 0.85));
    float snout = sdCap(vec3(l.x, l.y * 1.55, l.z), vec3(0.0, 0.2, 0.3), vec3(0.0, 0.02, 2.15), 0.44, 0.27);
    float d = smin(skull, snout, 0.3);
    d = smin(d, sdEll(m - vec3(0.12, 0.17, 2.0), vec3(0.1, 0.07, 0.12)), 0.08);
    // Heavy brows angled down toward the nose, and cheekbones.
    d = smin(d, sdCap(m, vec3(0.24, 0.55, -0.1), vec3(0.4, 0.4, 0.82), 0.14, 0.07), 0.16);
    d = smin(d, sdCap(m, vec3(0.44, 0.02, -0.25), vec3(0.4, 0.1, 0.65), 0.15, 0.08), 0.1);
    // The mouth: everything under the snout's flat bottom is open.
    d = max(d, -max(l.y + 0.05, 0.22 - l.z));
    vec2 res = vec2(d, 4.0);
    // Lower jaw on its hinge, with a chin and a spiked beard.
    vec3 lj = toJaw(l);
    vec3 mj = vec3(abs(lj.x), lj.y, lj.z);
    float jaw = sdCap(vec3(lj.x, lj.y * 1.6, lj.z), vec3(0.0, -0.1, 0.0), vec3(0.0, -0.1, 1.85), 0.34, 0.17);
    jaw = max(jaw, lj.y - 0.12);
    if (jaw < res.x) res = vec2(jaw, 4.0);
    float beard = min(sdCap(mj, vec3(0.0, -0.22, 0.55), vec3(0.0, -0.95, 0.15), 0.08, 0.01),
                      sdCap(mj, vec3(0.14, -0.2, 0.35), vec3(0.3, -0.8, -0.1), 0.06, 0.01));
    if (beard < res.x) res = vec2(beard, 2.0);
    // Forked tongue lying in the jaw.
    float tongue = sdCap(vec3(lj.x, lj.y * 2.5, lj.z), vec3(0.0, -0.05, 0.2), vec3(0.0, 0.05, 1.3), 0.16, 0.08);
    tongue = min(tongue, sdCap(mj, vec3(0.03, 0.03, 1.3), vec3(0.12, 0.08, 1.6), 0.05, 0.01));
    if (tongue < res.x) res = vec2(tongue, 8.0);
    // Teeth: a row down each side of both jaws, long fangs at the front.
    float teeth = 1e9;
    for (int k = 0; k < 5; k++) {
        float fk = float(k);
        float z = 0.55 + fk * 0.33;
        float x = 0.3 - fk * 0.025;
        float len = k == 4 ? 0.34 : 0.13;
        teeth = min(teeth, sdCap(m, vec3(x, -0.03, z), vec3(x - 0.02, -0.03 - len, z + 0.04), 0.05, 0.004));
        float lz = 0.5 + fk * 0.3;
        float llen = k == 3 ? 0.28 : 0.11;
        teeth = min(teeth, sdCap(mj, vec3(x - 0.04, -0.04, lz), vec3(x - 0.05, -0.04 + llen, lz + 0.03), 0.045, 0.004));
    }
    if (teeth < res.x) res = vec2(teeth, 5.0);
    // Eyes set under the brows.
    float eye = length(m - vec3(0.43, 0.32, 0.55)) - 0.12;
    if (eye < res.x) res = vec2(eye, 6.0);
    // Antler horns, each with two tines.
    float horn = min(sdCap(m, vec3(0.26, 0.5, -0.3), vec3(0.55, 1.0, -1.2), 0.14, 0.08),
                     sdCap(m, vec3(0.55, 1.0, -1.2), vec3(0.7, 1.12, -2.5), 0.08, 0.015));
    horn = min(horn, sdCap(m, vec3(0.5, 0.92, -1.0), vec3(0.62, 1.65, -1.1), 0.06, 0.012));
    horn = min(horn, sdCap(m, vec3(0.63, 1.08, -1.8), vec3(0.98, 1.55, -2.05), 0.045, 0.01));
    if (horn < res.x) res = vec2(horn, 3.0);
    // A crown of spikes sweeping back off the cheeks and the back of the skull.
    float spikes = min(sdCap(m, vec3(0.5, -0.05, -0.35), vec3(1.15, -0.2, -1.3), 0.12, 0.01),
                       sdCap(m, vec3(0.45, 0.22, -0.5), vec3(1.05, 0.45, -1.55), 0.1, 0.01));
    spikes = min(spikes, sdCap(m, vec3(0.2, 0.42, -0.6), vec3(0.45, 0.75, -1.65), 0.09, 0.01));
    if (spikes < res.x) res = vec2(spikes, 2.0);
    return vec2(res.x * dHr, res.y);
}

vec2 dragonSdf(vec3 p, out vec4 local, out vec3 lh) {
    vec2 res = vec2(1e9, 0.0);
    local = vec4(0.0);
    lh = vec3(0.0);
    for (int k = 0; k < 6; k++) {
        if (k >= dCount) break;
        vec4 lc;
        vec2 h = bodySeg(p, dCand[k], lc);
        if (h.x < res.x) { res = h; local = lc; }
    }
    for (int k = 0; k < 4; k++) {
        if (!dLegNear[k]) continue;
        vec2 h = legSdf(p, k);
        if (h.x < res.x) res = h;
    }
    if (dHeadNear) {
        float bound = length(p - dHead - dF * dHr * 0.5) - dHr * 3.1;
        if (bound < res.x) {
            vec3 l;
            vec2 h = headSdf(p, l);
            if (h.x < res.x) { res = h; lh = l; }
        }
    }
    return res;
}

float dragonDist(vec3 p) {
    vec4 a;
    vec3 b;
    return dragonSdf(p, a, b).x;
}

vec3 dragonNormal(vec3 p, float e) {
    vec2 k = vec2(1.0, -1.0);
    return normalize(k.xyy * dragonDist(p + k.xyy * e) + k.yyx * dragonDist(p + k.yyx * e)
        + k.yxy * dragonDist(p + k.yxy * e) + k.xxx * dragonDist(p + k.xxx * e));
}

// Overlapping scale rows on a body surface (x, y round the body, along the spine).
float scales(float along, float angle) {
    vec2 g = vec2(along * 6.0, angle * 2.2);
    float row = floor(g.y);
    g.x += mod(row, 2.0) * 0.5;
    vec2 f = fract(g) - vec2(0.5, 0.0);
    float arc = abs(length(f * vec2(1.0, 1.3)) - 0.5);
    return 1.0 - smoothstep(0.03, 0.08, arc);
}

void dragon(inout vec4 c, vec3 rd, float sceneT, float alpha, float time) {
    if (alpha <= 0.001) return;
    dTime = time;
    dHead = Pts[0].xyz;
    dHr = Pts[0].w;
    dF = normalize(Pts[21].xyz + vec3(0.0, 1e-5, 0.0));
    frameOf(dF, dS, dU);
    dJaw = Pts[21].w;
    dJawAng = dJaw * 0.85;
    // Which pieces can this ray touch at all? Only those are marched.
    dCount = 0;
    float tMin = 1e9;
    float tMax = 0.0;
    for (int i = 0; i < 19; i++) {
        vec4 a = Pts[i];
        vec4 b = Pts[i + 1];
        float t, s;
        float d = raySeg(rd, a.xyz, b.xyz, t, s);
        float r = max(a.w, b.w) * 2.0 + 0.05;
        if (d < r && dCount < 6) {
            dCand[dCount] = i;
            dCount++;
            tMin = min(tMin, t - r - 0.5);
            tMax = max(tMax, t + r + 0.5);
        }
    }
    float tp;
    dHeadNear = rayPoint(rd, dHead + dF * dHr * 0.5, tp) < dHr * 3.2;
    if (dHeadNear) {
        tMin = min(tMin, tp - dHr * 3.2);
        tMax = max(tMax, tp + dHr * 3.2);
    }
    for (int k = 0; k < 4; k++) {
        int seg = k < 2 ? 3 : 11;
        dLegNear[k] = rayPoint(rd, Pts[seg].xyz, tp) < Pts[seg].w * 4.0;
        if (dLegNear[k]) {
            tMin = min(tMin, tp - Pts[seg].w * 4.0);
            tMax = max(tMax, tp + Pts[seg].w * 4.0);
        }
    }
    if (dCount == 0 && !dHeadNear) return;
    tMax = min(tMax, sceneT);
    float t = max(tMin, 0.05);
    bool hit = false;
    float minD = 1e9;
    float minT = 0.0;
    vec4 local;
    vec3 lh;
    vec2 h = vec2(1e9, 0.0);
    for (int k = 0; k < 56; k++) {
        if (t > tMax) break;
        h = dragonSdf(rd * t, local, lh);
        if (h.x < minD) { minD = h.x; minT = t; }
        if (h.x < gPix * t * 0.5 + 0.002) { hit = true; break; }
        t += max(h.x * 0.75, gPix * t * 0.5);
    }
    if (!hit) {
        // Crisp ink outline where the ray only grazed the model.
        if (minD < 1e8 && minT < sceneT) {
            float line = ink(max(minD, 0.0), 0.018, minT);
            solid(c, DR_INK, line * alpha);
        }
        return;
    }
    vec3 p = rd * t;
    vec3 n = dragonNormal(p, max(gPix * t, 0.004));
    vec3 v = -rd;
    vec3 L = normalize(vec3(0.35, 0.9, 0.25));
    float lam = dot(n, L) * 0.5 + 0.5;
    float facing = abs(dot(n, v));
    float mat = h.y;
    vec3 col;
    float glow = 0.0;
    float band = dot(n, L);
    vec3 skin = band > 0.55 ? DR_HI : band > -0.15 ? DR_MID : DR_LOW;
    if (mat < 0.5) {
        col = skin;
        if (local.w > 0.0) {
            float angle = atan(local.y, local.x);
            bool belly = local.y < -local.w * 0.45 && abs(local.x) < local.w * 0.8;
            if (belly) {
                col = (band > -0.2 ? DR_BELLY : DR_BELLY * 0.7) * vec3(0.9, 0.95, 1.0);
                col *= 1.0 - 0.5 * (1.0 - smoothstep(0.05, 0.1, fract(local.z * 4.0)));
            } else {
                col = mix(col, DR_LOW * 0.55, scales(local.z, angle) * 0.6);
            }
            // Charge pulses running from head to tail.
            float pulse = 1.0 - smoothstep(0.0, 0.06, abs(fract(local.z * 0.18 - time * 1.4) - 0.5));
            col = mix(col, vec3(1.0), pulse * 0.55);
            glow = pulse;
        }
    } else if (mat < 2.5) {
        // Fins, spikes and beard: pale blades.
        col = band > 0.0 ? vec3(0.92, 0.98, 1.0) : DR_HI * 0.85;
        glow = 0.3;
    } else if (mat < 3.5) {
        col = band > 0.1 ? DR_HORN : DR_HORN * vec3(0.7, 0.6, 0.45);
        glow = 0.15;
    } else if (mat < 4.5) {
        col = skin;
        vec3 l = lh;
        // Inside of the mouth: the roof under the snout and the floor of the jaw.
        bool roof = l.y < 0.0 && l.y > -0.1 && l.z > 0.2 && dot(n, dU) < -0.35;
        bool floor_ = dJaw > 0.02 && l.y < -0.05 && l.z > 0.15 && dot(n, dU) > 0.2 && abs(l.x) < 0.3;
        if (roof || floor_) {
            col = vec3(0.2, 0.03, 0.09) + BOLT_GLOW * dJaw * 0.25 * smoothstep(0.6, 1.4, l.z);
            glow = dJaw * 0.5;
        } else {
            col = mix(col, DR_LOW * 0.6, scales(l.z * 0.8, atan(l.y, l.x)) * 0.4);
            vec3 m = vec3(abs(l.x), l.y, l.z);
            if (length(m.xz - vec2(0.12, 2.06)) < 0.045 && l.y > 0.15) col = DR_INK;
        }
    } else if (mat > 7.5) {
        col = band > 0.0 ? vec3(0.85, 0.25, 0.35) : vec3(0.5, 0.1, 0.2);
    } else if (mat < 5.5) {
        col = band > -0.1 ? vec3(0.97, 0.98, 1.0) : vec3(0.62, 0.7, 0.85);
    } else {
        // Burning eye with a dark slit pupil.
        vec3 m = vec3(abs(lh.x), lh.y, lh.z) - vec3(0.43, 0.32, 0.55);
        col = abs(m.z) < 0.03 ? DR_INK : mix(DR_HORN, vec3(1.0, 1.0, 0.85), smoothstep(0.1, 0.0, length(m.yz)));
        glow = 1.0;
    }
    // Anime rim light, then the ink silhouette edge.
    float rim = smoothstep(0.32, 0.26, facing) * step(0.5, dot(n, L) + 0.6);
    col = mix(col, vec3(1.0), rim * 0.7);
    col = mix(col, DR_INK, smoothstep(0.16, 0.08, facing));
    solid(c, col, alpha);
    float lit = max(glow, rim);
    emit(c, col * 0.18 * lit * alpha, lit * alpha * 0.6);
}

// Lightning that belongs to the dragon: a crackling mane, a tail tuft and arcs leaping off the body.
void dragonSparks(inout vec4 c, vec3 rd, float sceneT, float alpha, float time) {
    if (alpha <= 0.001) return;
    vec3 head = Pts[0].xyz;
    vec3 F = normalize(Pts[21].xyz + vec3(0.0, 1e-5, 0.0));
    vec3 S, U;
    frameOf(F, S, U);
    float hr = Pts[0].w;
    float flick = floor(time * 18.0);
    for (int i = 0; i < 2; i++) {
        float fi = float(i);
        float sgn = i == 0 ? 1.0 : -1.0;
        vec3 from = head - F * hr * 0.6 + U * hr * 0.6 + S * sgn * hr * 0.3;
        vec3 to = from - F * hr * 2.6 + U * hr * 0.9 + S * sgn * hr * 0.9;
        bolt(c, rd, sceneT, from, to, flick * 3.0 + fi * 17.0, 0.01, alpha * step(0.35, hash11(flick + fi)), 1.3);
    }
    // Whiskers trailing from the snout.
    for (int e = 0; e < 2; e++) {
        float sgn = e == 0 ? 1.0 : -1.0;
        vec3 snout = head + F * hr * 2.0 + S * sgn * hr * 0.2 + U * hr * 0.1;
        vec3 prev = snout;
        float bw = 1e9;
        float bwt = 0.0;
        for (int k = 1; k <= 8; k++) {
            float f = float(k) / 8.0;
            vec3 p = snout + S * sgn * hr * (0.25 + f * 1.1 + f * f * 0.6) - F * hr * f * 2.6 + U * hr * (sin(f * 6.0 + time * 5.0 + float(e) * 2.0) * 0.3 * f - f * f * 0.9);
            float t, s;
            float dw = raySeg(rd, prev, p, t, s);
            if (dw < bw) { bw = dw; bwt = t; }
            prev = p;
        }
        if (bwt > 0.0 && bwt < sceneT + 1.0) {
            float wl = ink(bw, hr * 0.012, bwt);
            emit(c, mix(BOLT_CORE, SPARK_YELLOW, 0.4) * wl * alpha, wl * alpha);
        }
    }
    vec3 tail = Pts[19].xyz;
    vec3 back = normalize(Pts[19].xyz - Pts[18].xyz + vec3(0.0, 1e-5, 0.0));
    for (int i = 0; i < 3; i++) {
        vec3 to = tail + back * 1.4 + (hash31(flick + float(i) * 7.0) - 0.5) * 1.6;
        bolt(c, rd, sceneT, tail, to, flick + float(i) * 23.0, 0.02, alpha, 1.2);
    }
    for (int i = 0; i < 3; i++) {
        float s = floor(time * 16.0) * 3.0 + float(i) * 11.0;
        int idx = 2 + int(hash11(s) * 16.0);
        vec4 p = Pts[idx];
        vec3 to = p.xyz + (hash31(s + 1.0) - 0.5) * p.w * 6.0;
        bolt(c, rd, sceneT, p.xyz, to, s, 0.012, alpha * step(0.45, hash11(s + 5.0)), 1.2);
    }
}

void raijin(inout vec4 c, vec3 rd, float sceneT, vec3 surface, bool sky) {
    float tick = P0.y;
    float seed = P0.z;
    float time = tick / 20.0;
    float rise = P1.z;
    float fin = P1.w;
    vec3 cloud = Origin;
    vec3 chest = Target;
    vec3 ground = Pts[20].xyz;
    // The sky goes dark under the storm and the world dims with it.
    float dark = P1.x;
    if (sky) {
        c.rgb = mix(c.rgb, vec3(0.05, 0.06, 0.12) + c.rgb * 0.15, dark * 0.85);
    } else {
        c.rgb *= 1.0 - 0.4 * dark;
    }
    stormCloud(c, rd, sceneT, cloud, P1.x, time);
    // The pillar that lifts the caster.
    float pillar = window3(tick, rise - 0.5, rise, rise + 8.0, rise + 14.0);
    if (pillar > 0.0) {
        float flicker = floor(GTime * 24.0);
        vec3 top = vec3(Caster.x, cloud.y, Caster.z);
        bolt(c, rd, sceneT, top, Caster, seed + flicker, 0.14 * pillar + 0.03, pillar, 0.5);
        bolt(c, rd, sceneT, top + vec3(0.8, 0.0, 0.3), Caster + vec3(0.2, 0.5, 0.0), seed + flicker + 5.0, 0.05, pillar * 0.7, 0.9);
    }
    // Electricity crawling over the caster while it rides the storm, and over the lifted enemy.
    staticArcs(c, rd, sceneT, Caster, 2.0, 0.6, window3(tick, 0.0, 6.0, fin + 6.0, fin + 16.0), seed);
    staticArcs(c, rd, sceneT, chest - vec3(0.0, 1.0, 0.0), 2.0, 0.7, window3(tick, P2.w, P2.w + 6.0, fin, fin + 4.0), seed + 40.0);
    dragon(c, rd, sceneT, P1.y, time);
    dragonSparks(c, rd, sceneT, P1.y, time);
    // Eight bolts in a row.
    for (int i = 0; i < 8; i++) {
        float at = P2.x + float(i) * P2.y;
        float age = (tick - at) / 20.0;
        if (age < 0.0 || age > 0.3) continue;
        float s = seed + float(i) * 13.0 + floor(GTime * 30.0);
        vec3 from = cloud + vec3((hash11(s) - 0.5) * 6.0, 0.0, (hash11(s + 1.0) - 0.5) * 6.0);
        bolt(c, rd, sceneT, from, chest, s, 0.09 * (1.0 - age / 0.3) + 0.02, 1.0 - smoothstep(0.15, 0.3, age), 0.7);
        float tp;
        float d = rayPoint(rd, chest, tp);
        float flash = exp(-age * 25.0) * exp(-d / 0.5);
        if (tp < sceneT + 2.0) emit(c, BOLT_GLOW * flash, flash);
    }
    // The final thunderbolt and what it leaves behind.
    float k = (tick - fin) / 20.0;
    if (k >= -0.05 && k < 0.6) {
        float flicker = floor(GTime * 30.0);
        float alpha = 1.0 - smoothstep(0.3, 0.6, k);
        bolt(c, rd, sceneT, cloud, ground, seed + flicker, 0.6 * (1.0 - saturate(k / 0.4)) + 0.08, alpha, 0.35);
        bolt(c, rd, sceneT, cloud + vec3(3.0, 0.0, 1.0), ground + vec3(1.2, 0.0, 0.0), seed + flicker + 3.0, 0.12, alpha * 0.8, 0.7);
        bolt(c, rd, sceneT, cloud + vec3(-2.5, 0.0, -2.0), ground + vec3(-1.0, 0.0, 0.8), seed + flicker + 6.0, 0.12, alpha * 0.8, 0.7);
    }
    if (k >= 0.0) {
        if (!sky) scorch(c, surface, ground, k, 7.0, seed);
        // A shock dome: only its rim is drawn, a crisp line racing outward.
        vec2 hit = raySphere(rd, ground, 7.5 * (1.0 - pow(1.0 - saturate(k / 0.3), 3.0)) + 0.1);
        float domeA = 1.0 - smoothstep(0.1, 0.45, k);
        if (hit.x > 0.0 && hit.x < sceneT && domeA > 0.0) {
            vec3 p = rd * hit.x - ground;
            float rim = 1.0 - abs(dot(normalize(p), rd));
            float line = smoothstep(0.8, 0.86, rim) * step(-0.3, p.y) * domeA;
            emit(c, mix(BOLT_GLOW, BOLT_CORE, 0.5) * line, line);
        }
        float tp;
        float d = rayPoint(rd, ground + vec3(0.0, 1.0, 0.0), tp);
        float flash = exp(-k * 10.0) * exp(-d / 1.5);
        if (tp < sceneT + 3.0) emit(c, BOLT_CORE * flash, flash);
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
        lightningStep(c, rd, sceneT);
    } else if (mode == 2) {
        stormField(c, rd, sceneT, surface, sky);
    } else if (mode == 3) {
        raijin(c, rd, sceneT, surface, sky);
    }
    fragColor = c;
}
