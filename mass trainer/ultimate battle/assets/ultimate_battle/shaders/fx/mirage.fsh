// Mirage effects. P0.x picks the skill: 1 Mirror Split, 2 Phantom Legion, 3 Infinite Mirage.
// The clones themselves are real player models drawn by the game; this pass adds what happens round them:
// mirror seams when they split off, dash streaks, hit sparks, and the shards when they break.

const vec3 JADE = vec3(0.36, 0.95, 0.78);
const vec3 JADE_DEEP = vec3(0.04, 0.38, 0.32);
const vec3 PALE = vec3(0.88, 1.0, 0.96);

float window2(float t, float in0, float in1, float out0, float out1) {
    return saturate((t - in0) / max(in1 - in0, 0.001)) * (1.0 - saturate((t - out0) / max(out1 - out0, 0.001)));
}

vec3 camRight() { return normalize((InvView * vec4(1.0, 0.0, 0.0, 0.0)).xyz); }
vec3 camUp() { return normalize((InvView * vec4(0.0, 1.0, 0.0, 0.0)).xyz); }

// Ray from the camera (at the origin) along rd against triangle a-b-c: ray distance or -1, barycentrics in bc.
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

// Mirror shards flung from a point: flat tumbling triangles, a mirror face that flashes as it turns to the
// camera and a crisp pale edge. age in seconds.
void shards(inout vec4 c, vec3 rd, float sceneT, vec3 pos, float age, float seed, float speed, float size) {
    if (age < 0.0 || age > 0.8) return;
    float life = age / 0.8;
    float reach = speed * 1.3 * age + 5.0 * age * age + size * 1.5;
    float tp;
    float dc = rayPoint(rd, pos, tp);
    if (dc > reach + 0.3 || tp - reach > sceneT) return;
    float best = 1e9;
    vec3 col = vec3(0.0);
    float edge = 0.0;
    for (int i = 0; i < 14; i++) {
        float fi = float(i) + seed * 17.0;
        vec3 h = hash31(fi * 1.37 + 0.5);
        vec3 h2 = hash31(fi * 2.71 + 9.0);
        vec3 dir = normalize(h * 2.0 - 1.0 + vec3(0.0, 0.35, 0.0));
        vec3 p = pos + dir * speed * (0.45 + 0.85 * h2.x) * age - vec3(0.0, 5.0 * age * age, 0.0);
        float s = size * (0.55 + 0.9 * h2.y) * (1.0 - 0.45 * life);
        float spin = age * (9.0 + 14.0 * h2.z) + fi;
        vec3 ax = normalize(cross(dir, normalize(h2 - 0.5 + vec3(0.01, 0.02, 0.0))));
        vec3 ay = cross(dir, ax);
        vec3 n = normalize(dir * cos(spin) + ax * sin(spin));
        vec3 u = normalize(cross(n, ay + dir * 0.3));
        vec3 v = cross(n, u);
        vec3 a = p + u * s;
        vec3 b = p + (-0.5 * u + 0.85 * v) * s * (0.7 + 0.5 * h.x);
        vec3 d = p + (-0.6 * u - 0.75 * v) * s;
        vec3 bc;
        float t = rayTri(rd, a, b, d, bc);
        if (t > 0.0 && t < sceneT && t < best) {
            best = t;
            float facing = abs(dot(n, rd));
            float glint = pow(facing, 8.0);
            col = cel(facing * 0.7 + glint * 0.5, PALE, JADE, JADE_DEEP);
            float e = min(bc.x, min(bc.y, bc.z)) * s * 1.6;
            edge = 1.0 - smoothstep(gPix * t * 0.8, gPix * t * 2.0, e);
        }
    }
    if (best < 1e8) {
        float fade = 1.0 - smoothstep(0.65, 1.0, life);
        paint(c, mix(col, PALE, edge), 0.92 * fade);
        c.a = max(c.a, 0.35 * fade);
    }
}

// The instant a clone breaks: jagged crack lines run out from its chest across the camera plane.
void crackBurst(inout vec4 c, vec3 rd, float sceneT, vec3 pos, float age, float size, float seed) {
    if (age < 0.0 || age > 0.22) return;
    float tp;
    float d0 = rayPoint(rd, pos, tp);
    if (d0 > size * 1.3 || tp > sceneT + 1.0) return;
    vec3 r = camRight();
    vec3 up = camUp();
    float k = age / 0.22;
    float grow = 1.0 - pow(1.0 - saturate(age / 0.05), 3.0);
    float best = 1e9;
    for (int i = 0; i < 7; i++) {
        float fi = float(i) + seed * 13.0;
        float ang = (float(i) + hash11(fi) * 0.6) / 7.0 * TAU;
        vec3 prev = pos;
        float len = size * (0.6 + 0.5 * hash11(fi + 4.0)) * grow;
        for (int j = 1; j <= 3; j++) {
            float f = float(j) / 3.0;
            float a2 = ang + (hash11(fi * 3.0 + float(j)) - 0.5) * 0.7;
            vec3 p = pos + (r * cos(a2) + up * sin(a2)) * len * f;
            float t, s;
            float dd = raySeg(rd, prev, p, t, s);
            best = min(best, dd);
            prev = p;
        }
    }
    float line = ink(best, 0.012 * (1.0 - k), tp);
    float rim = ink(best, 0.03 * (1.0 - k), tp) - line;
    emit(c, PALE * line + JADE * rim * 0.8, max(line, rim * 0.6));
}

// Expanding ring with a few spikes, camera-facing (a hit). k in seconds.
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
    float flash = exp(-d / (size * 0.15)) * exp(-k * 20.0);
    emit(c, PALE * (ring + spike) + JADE * flash, saturate(ring + spike + flash));
}

// A dash streak: a thin jade line with a white core, tapering at both ends.
void streak(inout vec4 c, vec3 rd, float sceneT, vec3 a, vec3 b, float width, float alpha) {
    if (alpha <= 0.001) return;
    float t, s;
    float d = raySeg(rd, a, b, t, s);
    if (t <= 0.0 || t > sceneT + 0.5) return;
    float w = width * sqrt(max(sin(PI * s), 0.0));
    float core = ink(d, w * 0.4, t);
    float body = ink(d, w, t) - core;
    emit(c, (PALE * core + JADE * body * 0.8) * alpha, max(core, body * 0.7) * alpha);
}

// A crisp ring lying on a horizontal plane at 'center' (ground circles, the sky halo).
float flatRing(vec3 rd, float sceneT, vec3 center, float radius, float width, out float tp, out float ang) {
    tp = rayPlane(rd, center, vec3(0.0, 1.0, 0.0));
    ang = 0.0;
    if (tp <= 0.0 || tp > sceneT + 0.2) return 0.0;
    vec3 q = rd * tp - center;
    ang = atan(q.z, q.x);
    return ink(abs(length(q.xz) - radius), width, tp);
}

// A vertical seam of light: the cut a clone peels out of.
void seam(inout vec4 c, vec3 rd, float sceneT, vec3 feet, float alpha) {
    if (alpha <= 0.001) return;
    float t, s;
    float d = raySeg(rd, feet, feet + vec3(0.0, 2.0, 0.0), t, s);
    if (t <= 0.0 || t > sceneT + 0.3) return;
    float w = 0.035 * sqrt(max(sin(PI * s), 0.0));
    float core = ink(d, w, t);
    float rim = ink(d, w * 2.6, t) - core;
    emit(c, (PALE * core + JADE * rim * 0.7) * alpha, max(core, rim * 0.5) * alpha);
}

// Jade cracks and a ring racing out over the ground round an impact. k in seconds.
void mirrorGround(inout vec4 c, vec3 surface, vec3 center, float k, float radius, float seed) {
    vec3 q = surface - center;
    if (abs(q.y) > 0.3 || k < 0.0) return;
    float r = length(q.xz);
    float rr = radius * 1.6 * (1.0 - pow(1.0 - saturate(k / 0.4), 3.0));
    float ring = (1.0 - smoothstep(0.06, 0.2, abs(r - rr))) * (1.0 - smoothstep(0.25, 0.6, k));
    emit(c, JADE * ring, ring);
    float spread = radius * smoothstep(0.0, 0.2, k);
    if (r < spread) {
        float cd = crackDist(q.xz * 0.7, seed);
        float line = 1.0 - smoothstep(0.012, 0.04, cd);
        float fade = 1.0 - smoothstep(radius * 0.5, radius, r);
        float life = 1.0 - smoothstep(2.0, 3.5, k);
        paint(c, mix(JADE, PALE, 0.5), line * fade * life);
        c.a = max(c.a, line * fade * life * 0.5);
    }
}

// ---------------------------------------------------------------- Mirror Split
// P0 = (1, tick, SPLIT, DASH), P1 = (STRIKE, SHATTER, locked, seed). Pts[0,1] clone starts (feet), Pts[2,3] clone
// ends (feet), Pts[4] caster origin, Pts[5] caster end, Pts[6] strike focus (chest).
void mirrorSplit(inout vec4 c, vec3 rd, float sceneT) {
    float t = P0.y;
    float split = P0.z;
    float dash = P0.w;
    float strike = P1.x;
    float shatter = P1.y;
    vec3 up = vec3(0.0, 1.05, 0.0);
    // The two seams peeling away from the caster to where the clones stand.
    float peel = 1.0 - pow(1.0 - saturate(t / split), 3.0);
    float seamA = window2(t, 0.0, 1.0, split, split + 3.0);
    for (int i = 0; i < 2; i++) {
        seam(c, rd, sceneT, mix(Pts[4].xyz, Pts[i].xyz, peel), seamA);
    }
    // Dash streaks of all three bodies.
    float run = saturate((t - dash) / max(strike - dash, 0.001));
    float streakA = window2(t, dash, dash + 0.5, strike + 1.0, strike + 6.0);
    if (streakA > 0.0) {
        for (int i = 0; i < 2; i++) {
            streak(c, rd, sceneT, Pts[i].xyz + up, mix(Pts[i].xyz, Pts[i + 2].xyz, run) + up, 0.05, streakA);
        }
        streak(c, rd, sceneT, Pts[4].xyz + up, mix(Pts[4].xyz, Pts[5].xyz, run) + up, 0.05, streakA);
    }
    // The strike: one spark where the three meet (or one on each body's line when nothing was locked).
    float k = (t - strike) / 20.0;
    if (P1.z > 0.5) {
        spark(c, rd, sceneT, Pts[6].xyz, k, 1.5, P1.w);
    } else {
        for (int i = 0; i < 2; i++) {
            spark(c, rd, sceneT, Pts[i + 2].xyz + up, k, 1.0, float(i));
        }
        spark(c, rd, sceneT, Pts[5].xyz + up, k, 1.0, 2.0);
    }
    // The clones break.
    float s = (t - shatter) / 20.0;
    for (int i = 0; i < 2; i++) {
        vec3 chest = Pts[i + 2].xyz + up;
        crackBurst(c, rd, sceneT, chest, s, 0.9, float(i) + P1.w);
        shards(c, rd, sceneT, chest, s, float(i) + P1.w * 7.0, 3.2, 0.16);
    }
}

// ---------------------------------------------------------------- Phantom Legion
// P0 = (2, tick, SUMMON, BURST), P1 = (ring radius, seed, -, -), Target = caster feet. Pts[0..5] clone homes
// (feet, w = leap tick), Pts[6..11] kick points (chest, w = kick tick).
void legion(inout vec4 c, vec3 rd, float sceneT) {
    float t = P0.y;
    float summon = P0.z;
    float burst = P0.w;
    float R = P1.x;
    vec3 up = vec3(0.0, 1.1, 0.0);
    // The summoning circle, with a short tick under every clone.
    float open = window2(t, 1.0, summon, burst, burst + 6.0);
    if (open > 0.0) {
        vec3 ground = Target + vec3(0.0, 0.05, 0.0);
        float tp, ang;
        float outer = flatRing(rd, sceneT, ground, R + 0.75, 0.03, tp, ang);
        float inner = flatRing(rd, sceneT, ground, R - 0.55, 0.015, tp, ang);
        float ticks = 0.0;
        if (tp > 0.0 && tp < sceneT + 0.2) {
            vec3 q = rd * tp - ground;
            float r = length(q.xz);
            float marks = step(0.82, fract(ang / TAU * 24.0 + t * 0.01));
            ticks = marks * (1.0 - smoothstep(0.0, 0.04, abs(r - R - 0.45))) ;
        }
        float a = (outer + inner * 0.8 + ticks * 0.7) * open;
        emit(c, mix(JADE, PALE, 0.3) * a, a * 0.8);
    }
    for (int k = 0; k < 6; k++) {
        vec3 home = Pts[k].xyz;
        float leap = Pts[k].w;
        vec4 kick = Pts[k + 6];
        // Rising out of the ring: a seam of light where each clone stands up.
        seam(c, rd, sceneT, home, window2(t, summon - 3.0, summon - 1.0, summon + 2.0, summon + 6.0));
        if (kick.w > 0.0) {
            float flight = saturate((t - leap) / max(kick.w - leap, 0.001));
            float a = window2(t, leap, leap + 0.5, kick.w + 1.0, kick.w + 6.0);
            streak(c, rd, sceneT, home + up, mix(home + up, kick.xyz, flight), 0.04, a);
            spark(c, rd, sceneT, kick.xyz, (t - kick.w) / 20.0, 1.0, float(k));
        }
        vec3 at = kick.w > 0.0 ? kick.xyz : home + up;
        float s = (t - burst) / 20.0;
        crackBurst(c, rd, sceneT, at, s, 0.9, float(k));
        shards(c, rd, sceneT, at, s, float(k) + P1.y * 5.0, 3.4, 0.15);
    }
}

// ---------------------------------------------------------------- Infinite Mirage
// P0 = (3, tick, seed, -), P1 = (RING_START, ABOVE, MERGE_END, DROP), P2 = (LAND, ring radius, -, -).
// Origin = ring centre, Target = the target's chest now, Caster = the caster's chest above the target.
// Pts[0..11] clone homes (chest, w = appear tick), Pts[12..17] recent strikes (clone chest, w = strike tick),
// Pts[18] landing point (feet), Pts[19] palm strike point (chest, w = tick).
void infinite(inout vec4 c, vec3 rd, float sceneT, vec3 surface, bool sky) {
    float t = P0.y;
    float seed = P0.z;
    float ringStart = P1.x;
    float above = P1.y;
    float mergeEnd = P1.z;
    float drop = P1.w;
    float land = P2.x;
    float R = P2.y;
    spark(c, rd, sceneT, Pts[19].xyz, (t - Pts[19].w) / 20.0, 1.6, seed);
    // The halo the ring of clones stands on, drawn round as they appear.
    float haloA = window2(t, ringStart, ringStart + 2.0, above, above + 4.0);
    if (haloA > 0.0) {
        float tp, ang;
        float ring = flatRing(rd, sceneT, Origin, R, 0.025, tp, ang);
        float drawn = saturate((t - ringStart) / 12.0);
        float frac = fract((ang - atan(-Facing.z, -Facing.x)) / TAU);
        ring *= step(frac, drawn);
        float inner = flatRing(rd, sceneT, Origin, R * 0.55, 0.012, tp, ang);
        emit(c, (JADE * ring + PALE * inner * 0.6) * haloA, max(ring, inner * 0.6) * haloA);
    }
    for (int i = 0; i < 12; i++) {
        float appear = Pts[i].w;
        seam(c, rd, sceneT, Pts[i].xyz - vec3(0.0, 1.05, 0.0), window2(t, appear - 1.0, appear, appear + 1.0, appear + 4.0));
        // Every clone streaks back into the caster.
        float m = saturate((t - above - float(i) * 0.3) / max(mergeEnd - above - 2.0, 0.001));
        float mA = window2(t, above, above + 0.5, mergeEnd, mergeEnd + 3.0);
        if (mA > 0.0) {
            streak(c, rd, sceneT, mix(Pts[i].xyz, Caster, m * 0.6), mix(Pts[i].xyz, Caster, m), 0.05, mA);
        }
    }
    // The strikes: a dash line from the clone to the target and a spark where it lands.
    for (int i = 12; i < 18; i++) {
        vec4 s = Pts[i];
        if (s.w <= 0.0) continue;
        float age = (t - s.w) / 20.0;
        if (age < -0.1 || age > 0.4) continue;
        streak(c, rd, sceneT, s.xyz, Target, 0.04, 1.0 - smoothstep(0.05, 0.3, age));
        spark(c, rd, sceneT, mix(s.xyz, Target, 0.8), age, 0.9, float(i) + seed);
    }
    // The drop.
    float dropA = window2(t, drop, drop + 1.0, land, land + 3.0);
    if (dropA > 0.0) {
        streak(c, rd, sceneT, Target + vec3(0.0, 4.0, 0.0), Target, 0.2, dropA);
    }
    float k = (t - land) / 20.0;
    if (k >= 0.0) {
        vec3 impact = Pts[18].xyz;
        if (!sky) mirrorGround(c, surface, impact, k, 5.0, seed);
        crackBurst(c, rd, sceneT, impact + vec3(0.0, 1.0, 0.0), k, 2.2, seed);
        shards(c, rd, sceneT, impact + vec3(0.0, 0.8, 0.0), k, seed, 6.0, 0.24);
        shards(c, rd, sceneT, impact + vec3(0.0, 0.6, 0.0), k - 0.04, seed + 3.0, 4.5, 0.18);
        float tp;
        float d = rayPoint(rd, impact + vec3(0.0, 0.5, 0.0), tp);
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
        mirrorSplit(c, rd, sceneT);
    } else if (mode == 2) {
        legion(c, rd, sceneT);
    } else if (mode == 3) {
        infinite(c, rd, sceneT, surface, sky);
    }
    fragColor = c;
}
