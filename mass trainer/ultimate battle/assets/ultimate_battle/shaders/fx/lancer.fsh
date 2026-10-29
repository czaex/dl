// Lancer effects. P0.x picks the skill: 1 Piercing Lunge, 2 Crescent Sweep, 3 Gungnir.
// The colossal Gungnir spear is traced here voxel by voxel from its own long sprite (lancer_spear.glsl, written by
// tools/art_spear.py in the hand spear's palette and style), so it looks like a Minecraft item with a real spear's
// proportions, and whatever of it is still above the celestial gate is simply not there.
// Lines stay crisp; only light (not solid things) raises the glow mask.

#include "lancer_spear.glsl"

const vec3 SAPPHIRE = vec3(0.31, 0.48, 1.0);
const vec3 SAPPHIRE_DEEP = vec3(0.07, 0.14, 0.5);
const vec3 PALE = vec3(0.86, 0.92, 1.0);
const vec3 NIGHT = vec3(0.012, 0.02, 0.07);

// Shared with LancerMoves.Gungnir.

float window2(float t, float in0, float in1, float out0, float out1) {
    return saturate((t - in0) / max(in1 - in0, 0.001)) * (1.0 - saturate((t - out0) / max(out1 - out0, 0.001)));
}

vec3 camRight() { return normalize((InvView * vec4(1.0, 0.0, 0.0, 0.0)).xyz); }
vec3 camUp() { return normalize((InvView * vec4(0.0, 1.0, 0.0, 0.0)).xyz); }

// Paints over the scene without raising the glow mask (solid things, not light).
void solid(inout vec4 c, vec3 col, float a) {
    c.rgb = mix(c.rgb, col, saturate(a));
}

// Two unit vectors spanning the plane with normal n.
void planeAxes(vec3 n, out vec3 u, out vec3 v) {
    vec3 h = cross(n, vec3(0.0, 1.0, 0.0));
    u = dot(h, h) < 1e-6 ? vec3(1.0, 0.0, 0.0) : normalize(h);
    v = normalize(cross(n, u));
}

// A streak of light: white core, sapphire body, tapering at both ends.
void streak(inout vec4 c, vec3 rd, float sceneT, vec3 a, vec3 b, float width, float alpha) {
    if (alpha <= 0.001) return;
    float t, s;
    float d = raySeg(rd, a, b, t, s);
    if (t <= 0.05 || t > sceneT + 0.5) return;
    alpha *= smoothstep(0.6, 1.6, t);
    float w = width * sqrt(max(sin(PI * s), 0.0));
    float core = ink(d, w * 0.35, t);
    float body = ink(d, w, t) - core;
    emit(c, (vec3(1.0) * core + SAPPHIRE * body * 0.9) * alpha, max(core, body * 0.7) * alpha);
}

// A crisp ring of light in a plane. Fades away when the plane is seen edge-on (it would smear into a streak).
void ringIn(inout vec4 c, vec3 rd, float sceneT, vec3 center, vec3 n, float radius, float width, float alpha) {
    if (alpha <= 0.001 || radius <= 0.0) return;
    float tp = rayPlane(rd, center, n);
    if (tp <= 0.05 || tp > sceneT + 0.3) return;
    alpha *= smoothstep(0.06, 0.3, abs(dot(rd, n)));
    float r = length(rd * tp - center);
    float l = ink(abs(r - radius), width, tp) * alpha;
    emit(c, mix(SAPPHIRE, PALE, 0.6) * l, l);
}

// A hit: a ring with four sharp spikes and a short flash, camera-facing. k in seconds.
void spark(inout vec4 c, vec3 rd, float sceneT, vec3 pos, float k, float size, float seed) {
    if (k < 0.0 || k > 0.3) return;
    float tp;
    float d = rayPoint(rd, pos, tp);
    if (tp <= 0.05 || tp > sceneT + 1.0 || d > size * 2.5) return;
    float u = k / 0.3;
    float rr = size * (0.25 + 1.2 * sqrt(u));
    float ring = ink(abs(d - rr), 0.03 * (1.0 - u) + 0.004, tp);
    vec3 v = rd * tp - pos;
    float ang = atan(dot(v, camUp()), dot(v, camRight())) + seed;
    float spikes = pow(max(cos(ang * 2.0), 0.0), 60.0) + pow(max(cos(ang * 2.0 + PI * 0.5), 0.0), 60.0) * 0.6;
    float spike = spikes * smoothstep(rr * 1.9, rr * 0.3, d) * step(rr * 0.2, d) * (1.0 - u);
    float flash = exp(-d / (size * 0.12)) * exp(-k * 22.0);
    emit(c, PALE * (ring + spike) + SAPPHIRE * flash, saturate(ring + spike + flash));
}

// A four-pointed glint, camera-facing (light catching a point of steel). size in blocks, alpha 0..1.
void glint(inout vec4 c, vec3 rd, float sceneT, vec3 pos, float size, float alpha) {
    if (alpha <= 0.001) return;
    float tp;
    float d = rayPoint(rd, pos, tp);
    if (tp <= 0.3 || tp > sceneT + 0.5 || d > size * 1.2) return;
    vec3 v = rd * tp - pos;
    vec2 p = vec2(dot(v, camRight()), dot(v, camUp()));
    float arm = max(ink(abs(p.y), 0.012 * size * 4.0 * (1.0 - abs(p.x) / size), tp) * step(abs(p.x), size),
                    ink(abs(p.x), 0.012 * size * 4.0 * (1.0 - abs(p.y) / size), tp) * step(abs(p.y), size));
    float dot0 = ink(d, size * 0.08, tp);
    float l = saturate(arm + dot0) * alpha;
    emit(c, PALE * l, l);
}

// Ray against triangle a-b-c (camera at the origin): ray distance or -1, barycentrics in bc.
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

// Shards of light flung from a point: thin tumbling slivers, silver when they turn to the camera. age in seconds.
void shards(inout vec4 c, vec3 rd, float sceneT, vec3 pos, float age, float seed, float speed, float size) {
    if (age < 0.0 || age > 1.0) return;
    float reach = speed * 1.3 * age + size * 2.0 + 0.5;
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
        vec3 dir = normalize(h * 2.0 - 1.0 + vec3(0.0, 0.6, 0.0));
        vec3 p = pos + dir * speed * (0.45 + 0.85 * h2.x) * age - vec3(0.0, 1.5 * age * age, 0.0);
        float s = size * (0.55 + 0.9 * h2.y) * (1.0 - 0.6 * age);
        float spin = age * (6.0 + 9.0 * h2.z) + fi;
        vec3 ax = normalize(cross(dir, normalize(h2 - 0.5 + vec3(0.01, 0.02, 0.0))));
        vec3 ay = cross(dir, ax);
        vec3 n = normalize(dir * cos(spin) + ax * sin(spin));
        vec3 u = normalize(cross(n, ay + dir * 0.3));
        vec3 v = cross(n, u);
        vec3 a = p + u * s * 1.4;
        vec3 b = p + (-0.6 * u + 0.35 * v) * s;
        vec3 d = p + (-0.6 * u - 0.35 * v) * s;
        vec3 bc;
        float t = rayTri(rd, a, b, d, bc);
        if (t > 0.05 && t < sceneT && t < best) {
            best = t;
            float facing = abs(dot(n, rd));
            col = cel(facing * 0.75 + pow(facing, 8.0) * 0.4, vec3(1.0), PALE, SAPPHIRE);
            float e = min(bc.x, min(bc.y, bc.z)) * s * 1.6;
            edge = 1.0 - smoothstep(gPix * t * 0.8, gPix * t * 2.0, e);
        }
    }
    if (best < 1e8) {
        float fade = 1.0 - smoothstep(0.7, 1.0, age);
        paint(c, mix(col, vec3(1.0), edge), 0.92 * fade);
        c.a = max(c.a, 0.35 * fade);
    }
}

// Ground decals only touch the ground right at the given height (never the legs of whatever stands on it).
bool onGround(vec3 surface, vec3 at, bool sky) {
    return !sky && abs(surface.y - at.y) < 0.35;
}

// ---------------------------------------------------------------- Piercing Lunge

void piercingLunge(inout vec4 c, vec3 rd, float sceneT) {
    float t = P0.y;
    float dash = P0.z;
    float strike = P0.w;
    float seed = P1.x;
    vec3 f = Facing;
    // The point gathers light before the lunge.
    glint(c, rd, sceneT, Origin, 0.15 + 0.35 * smoothstep(0.0, dash, t), window2(t, 0.0, dash - 1.0, dash, dash + 1.0));
    if (t < dash) return;
    // The wake: from where the point started to where it is, thinning away after the strike.
    float fade = 1.0 - smoothstep(strike + 1.0, strike + 12.0, t);
    streak(c, rd, sceneT, Origin, Caster + f * 0.3, 0.13 * fade + 0.02, fade);
    // The drill: two sapphire strands winding round the last stretch of the wake while the spear is moving.
    float drill = window2(t, dash, dash + 0.5, strike, strike + 2.0);
    if (drill > 0.001) {
        vec3 u, v;
        planeAxes(f, u, v);
        float best = 1e9;
        float bestT = 0.0;
        for (int strand = 0; strand < 2; strand++) {
            vec3 prev = Caster;
            for (int i = 1; i <= 12; i++) {
                float s = float(i) / 12.0;
                float th = s * 11.0 - t * 2.6 + float(strand) * PI;
                vec3 p = Caster - f * (3.2 * s) + (u * cos(th) + v * sin(th)) * (0.1 + 0.42 * s);
                float tt, ss;
                float d = raySeg(rd, prev, p, tt, ss);
                if (tt > 0.3 && tt < sceneT && d / (1.0 - s * 0.6) < best) {
                    best = d / (1.0 - s * 0.6);
                    bestT = tt;
                }
                prev = p;
            }
        }
        if (best < 1e8) {
            float l = ink(best, 0.035, bestT) * drill;
            emit(c, mix(SAPPHIRE, PALE, 0.4) * l, l);
        }
    }
    // Sonic rings torn off along the lunge.
    for (int i = 0; i < 3; i++) {
        float born = dash + 0.6 + float(i) * 1.1;
        float age = t - born;
        if (age < 0.0 || age > 7.0) continue;
        float k = saturate((born - dash) / (strike - dash));
        k = 1.0 - (1.0 - k) * (1.0 - k);
        vec3 at = mix(Origin, Target, k);
        ringIn(c, rd, sceneT, at, f, 0.35 + age * 0.22, 0.03 * (1.0 - age / 7.0) + 0.006, 1.0 - age / 7.0);
    }
    // The end of the thrust: a burst ahead of the point.
    spark(c, rd, sceneT, Target + f * 0.4, (t - strike) / 20.0, 1.0, seed);
    ringIn(c, rd, sceneT, Target + f * 0.6, f, 0.4 + (t - strike) * 0.25, 0.04, window2(t, strike, strike + 0.5, strike + 3.0, strike + 7.0));
    // Run through the locked target.
    if (P1.y > 0.5) {
        float k = (t - P1.z) / 20.0;
        spark(c, rd, sceneT, Pts[0].xyz, k, 1.3, seed + 3.0);
        shards(c, rd, sceneT, Pts[0].xyz, k * 2.0, seed, 4.0, 0.14);
    }
}

// ---------------------------------------------------------------- Crescent Sweep

void crescentSweep(inout vec4 c, vec3 rd, float sceneT, vec3 surface, bool sky) {
    float t = P0.y;
    float sweep = P0.z;
    float hit = P0.w;
    float spinEnd = P1.x;
    float echo = P1.y;
    float radius = P1.z;
    float echoRadius = P1.w;
    float seed = P2.x;
    float head = P2.y;
    vec3 center = Origin + vec3(0.0, 0.95, 0.0);
    float face = atan(Facing.z, Facing.x);

    // Ground: the reach of the sweep drawn round the caster while it winds up, then the scar it cuts.
    if (onGround(surface, Origin, sky)) {
        vec3 q = surface - Origin;
        float r = length(q.xz);
        float ts = length(surface);
        float ang = atan(q.z, q.x);
        float from = abs(mod(ang - face + PI, TAU) - PI) / PI;
        float tele = window2(t, 0.0, 2.0, sweep, hit) * step(from, smoothstep(0.0, sweep, t));
        float l = ink(abs(r - radius), 0.03, ts) * tele * 0.8;
        float tick = abs(fract(ang * 24.0 / TAU + 0.5) - 0.5) * TAU / 24.0 * r;
        l += ink(tick, 0.02, ts) * step(radius - 0.35, r) * step(r, radius) * tele * 0.6;
        emit(c, SAPPHIRE * l, l * 0.6);
        float scar = 1.0 - smoothstep(hit + 14.0, hit + 34.0, t);
        if (t >= hit && scar > 0.0) {
            float cut = ink(abs(r - 2.9), 0.05, ts) * scar;
            solid(c, c.rgb * 0.35, cut);
            float rim = ink(abs(r - 2.9), 0.012, ts) * scar;
            emit(c, SAPPHIRE * rim, rim * 0.7);
            // Short cuts in the grass where the blade's wind ran out.
            for (int i = 0; i < 14; i++) {
                float a = hash11(float(i) + seed * 7.0) * TAU;
                float rr = 3.6 + 1.6 * hash11(float(i) * 3.1 + seed);
                vec2 p0 = vec2(cos(a), sin(a)) * rr;
                vec2 dir = vec2(-sin(a), cos(a));
                vec2 w = q.xz - p0;
                float along = dot(w, dir);
                float across = abs(dot(w, vec2(cos(a), sin(a))));
                float len = 0.5 + 0.4 * hash11(float(i) + 4.0);
                float g = ink(across, 0.03 * (1.0 - abs(along) / len), ts) * step(abs(along), len) * scar;
                solid(c, c.rgb * 0.4, g);
            }
        }
    }

    // The crescent: in the waist-high plane, a band of light from the spear's head back along its sweep.
    float live = window2(t, sweep - 0.5, sweep, spinEnd + 1.0, spinEnd + 5.0);
    float tp = rayPlane(rd, center, vec3(0.0, 1.0, 0.0));
    if (live > 0.001 && tp > 0.3 && tp < sceneT) {
        vec3 q = rd * tp - center;
        float r = length(q.xz);
        float span = 5.2 * smoothstep(sweep - 0.5, sweep + 3.0, t) * (1.0 - smoothstep(spinEnd, spinEnd + 4.0, t));
        float tail = mod(atan(q.z, q.x) - head, TAU);
        if (span > 0.05 && tail < span && r < 3.8) {
            float u = tail / span;
            float outer = 3.4 - 0.9 * pow(u, 0.7);
            float inner = 1.0 + 1.6 * u;
            float edgeOn = smoothstep(0.03, 0.2, abs(rd.y));
            float a = edgeOn * live;
            if (r > inner && r < outer + 0.05) {
                float fill = 0.35 * (1.0 - u) * a;
                emit(c, SAPPHIRE * fill, fill * 0.5);
            }
            float rim = ink(abs(r - outer), 0.05 * (1.0 - u) + 0.01, tp) * (1.0 - u * 0.7) * a;
            float rim2 = ink(abs(r - inner), 0.015, tp) * step(inner, outer) * (1.0 - u) * a * 0.6;
            emit(c, PALE * rim + SAPPHIRE * rim2, saturate(rim + rim2));
        }
    }
    // The crescent's light let go: a ring rolling out to the edge of the reach, then the echo.
    float k = saturate((t - hit + 1.0) / 7.0);
    ringIn(c, rd, sceneT, center, vec3(0.0, 1.0, 0.0), mix(3.4, radius + 0.8, 1.0 - pow(1.0 - k, 3.0)), 0.06 * (1.0 - k) + 0.01,
           window2(t, hit - 1.0, hit - 0.5, hit + 3.0, hit + 6.0));
    float e = saturate((t - echo) / 8.0);
    float echoA = window2(t, echo, echo + 0.5, echo + 4.0, echo + 8.0);
    ringIn(c, rd, sceneT, center + vec3(0.0, -0.5, 0.0), vec3(0.0, 1.0, 0.0), mix(2.0, echoRadius, 1.0 - pow(1.0 - e, 2.0)), 0.025, echoA * 0.8);
    ringIn(c, rd, sceneT, Origin + vec3(0.0, 0.05, 0.0), vec3(0.0, 1.0, 0.0), mix(2.0, echoRadius, 1.0 - pow(1.0 - e, 2.0)), 0.04, echoA);
}

// ---------------------------------------------------------------- Gungnir: the colossal spear

int giantIdx(ivec2 p) {
    if (p.x < 0 || p.y < 0 || p.x >= GSPEAR_W || p.y >= GSPEAR_H) return 0;
    uint w = GSPEAR[p.y * 2 + (p.x >> 3)];
    return int((w >> uint((p.x & 7) * 4)) & 15u);
}

// A texel's colour: light running down the fuller toward the point, a glint sweeping the edge, the gem pulsing.
vec3 giantColor(int idx, ivec2 p, float t) {
    vec3 base = SPEAR_PAL[idx];
    float y = float(p.y);
    if (idx == 6) {
        float head = float(GSPEAR_BLADE) - 3.0 - mod(t * 0.8, float(GSPEAR_BLADE) + 6.0);
        return mix(base, SPEAR_FULLER_LIGHT, max(0.0, 1.0 - abs(y - head) / 3.0));
    }
    if (idx == 5 || (idx == 4 && p.y < GSPEAR_BLADE)) {
        float head = mod(t * 1.1, 46.0) - 8.0;
        return mix(base, vec3(1.0), max(0.0, 1.0 - abs(y - head) / 1.5));
    }
    if (idx == 11) {
        return mix(base, SPEAR_PAL[12], 0.5 + 0.5 * sin(t * 0.4));
    }
    return base;
}

float safeInv(float x) {
    return 1.0 / (abs(x) < 1e-6 ? (x < 0.0 ? -1e-6 : 1e-6) : x);
}

// Traces the view ray through the colossal spear: its sprite extruded two texels thick (like an item model), the
// point at tip (camera-relative), running along A, its width across W and its flat facing N, tx blocks per texel.
// Above the gate (world y > gateY) it is not there; where the gate cuts a texel, the cut face is hit (face 3).
// dissolve 0..1 breaks it into light from the point back to the butt.
// Returns the ray distance, or -1. face: 0 flat, 1 side, 2 end of a texel column, 3 cut by the gate.
float giantTrace(vec3 rd, vec3 tip, vec3 A, vec3 W, vec3 N, float tx, float gateY, float dissolve, float seed,
                 out int idx, out ivec2 cell, out int face, out float burn) {
    idx = 0;
    face = 0;
    burn = 0.0;
    cell = ivec2(0);
    vec3 ro = vec3(dot(-tip, W) / tx + float(GSPEAR_W) * 0.5, dot(tip, A) / tx, dot(-tip, N) / tx);
    vec3 dl = vec3(dot(rd, W), -dot(rd, A), dot(rd, N)) / tx;
    vec3 inv = vec3(safeInv(dl.x), safeInv(dl.y), safeInv(dl.z));
    vec3 t0 = (vec3(0.0, 0.0, -1.0) - ro) * inv;
    vec3 t1 = (vec3(float(GSPEAR_W), float(GSPEAR_H), 1.0) - ro) * inv;
    vec3 tsm = min(t0, t1);
    vec3 tbg = max(t0, t1);
    float tmin = max(max(tsm.x, tsm.y), tsm.z);
    float tmax = min(min(tbg.x, tbg.y), tbg.z);
    if (tmax < max(tmin, 0.05)) return -1.0;
    int entry = tsm.x >= tsm.y && tsm.x >= tsm.z ? 1 : (tsm.y >= tsm.z ? 2 : 0);
    float t = max(tmin, 0.05);
    vec3 p = ro + dl * (t + 1e-4);
    ivec2 cl = ivec2(floor(p.xy));
    ivec2 st = ivec2(dl.x > 0.0 ? 1 : -1, dl.y > 0.0 ? 1 : -1);
    vec2 next = vec2(cl) + vec2(st.x > 0 ? 1.0 : 0.0, st.y > 0 ? 1.0 : 0.0);
    vec2 tm = (next - ro.xy) * inv.xy;
    vec2 td = abs(inv.xy);
    for (int i = 0; i < 160; i++) {
        float tExit = min(min(tm.x, tm.y), tmax);
        int v = giantIdx(cl);
        if (v != 0) {
            bool gone = false;
            float b = 0.0;
            if (dissolve > 0.0) {
                float th = float(cl.y) / float(GSPEAR_H) * 0.8 + hash12(vec2(cl) + seed) * 0.2;
                gone = dissolve > th;
                b = smoothstep(th - 0.1, th, dissolve);
            }
            if (!gone) {
                float sa = gateY - (rd * t).y;
                if (sa >= 0.0) {
                    idx = v;
                    cell = cl;
                    face = entry;
                    burn = b;
                    return t;
                }
                float sb = gateY - (rd * tExit).y;
                if (sb >= 0.0) {
                    idx = v;
                    cell = cl;
                    face = 3;
                    burn = b;
                    return t + (tExit - t) * sa / (sa - sb);
                }
            }
        }
        if (tExit >= tmax) break;
        if (tm.x < tm.y) {
            t = tm.x;
            cl.x += st.x;
            tm.x += td.x;
            entry = 1;
        } else {
            t = tm.y;
            cl.y += st.y;
            tm.y += td.y;
            entry = 2;
        }
        if (cl.x < 0 || cl.y < 0 || cl.x >= GSPEAR_W || cl.y >= GSPEAR_H) break;
    }
    return -1.0;
}

// How far the colossal spear's point is out of the gate at tick t (LancerMoves.Gungnir.out).
float spearOut(float t, float emerge, float impact, float reach) {
    if (t < emerge) return 0.0;
    float u = min(1.0, (t - emerge) / (impact - emerge));
    return reach * (0.06 * u + 0.94 * pow(u, 3.2));
}

// ---------------------------------------------------------------- Gungnir: the celestial gate

// Opening of the gate along its two axes (an eye opening in the sky), 0..1 each.
vec2 gateOpen(float t, float open, float opened, float close) {
    float ou = smoothstep(open, open + 7.0, t);
    float ov = smoothstep(open + 4.0, opened, t);
    float cu = 1.0 - smoothstep(close + 5.0, close + 12.0, t);
    float cv = 1.0 - smoothstep(close, close + 7.0, t);
    return vec2(ou * cu, (0.04 + 0.96 * ov) * cv * step(0.001, ou * cu));
}

// The gate: a disc of night sky in the plane through G facing A, a crisp double rim, a ring of runes and eight
// long rays turning slowly round it. Painted opaque; returns its ray distance (or -1) through gt.
void gate(inout vec4 c, vec3 rd, float sceneT, vec3 G, vec3 A, float R, float t, float seed, vec4 times, float flare, out float gt) {
    gt = -1.0;
    vec2 o = gateOpen(t, times.x, times.y, times.z);
    if (o.x <= 0.001) return;
    float tp = rayPlane(rd, G, A);
    if (tp <= 0.3 || tp > sceneT) return;
    float edgeOn = smoothstep(0.03, 0.18, abs(dot(rd, A)));
    if (edgeOn <= 0.001) return;
    vec3 u, v;
    planeAxes(A, u, v);
    vec3 q = rd * tp - G;
    vec2 p = vec2(dot(q, u), dot(q, v));
    vec2 rad = R * max(o, vec2(0.002));
    float e = length(p / rad);
    float r = length(p);
    float ang = atan(p.y, p.x);
    if (e > 1.9 && r > R * 1.9) return;
    float aa = gPix * tp;
    float rim = 0.0;
    // The sky beyond.
    if (e < 1.0) {
        gt = tp;
        float sw = ang + e * 2.4 - t * 0.02;
        vec2 sp = vec2(cos(sw), sin(sw)) * (e * 2.2 + 0.4);
        float neb = fbm3(vec3(sp * 1.3, t * 0.006 + seed));
        vec3 sky = mix(NIGHT, SAPPHIRE_DEEP, smoothstep(0.35, 0.8, neb) * 0.9 + 0.25 * e);
        // Stars: a grid in the gate's own plane, each twinkling.
        vec2 cellP = p * 1.4;
        vec2 id = floor(cellP);
        vec2 h = hash22(id + seed);
        float sd = length(fract(cellP) - h);
        float tw = 0.6 + 0.4 * sin(t * 0.4 + h.x * 30.0);
        float star = step(0.78, hash12(id + 3.1)) * ink(sd / 1.4, 0.035 + 0.03 * h.y, tp) * tw;
        sky += PALE * star;
        // Light from deep inside, where the spear comes from.
        float core = exp(-e * e * 6.0) * (0.25 + 0.75 * flare);
        sky = mix(sky, PALE, core * 0.8);
        solid(c, sky, 0.97 * edgeOn);
        emit(c, PALE * star * edgeOn * 0.6, (star * 0.6 + core * 0.5) * edgeOn);
        rim = max(rim, ink(abs(e - 1.0) * min(rad.x, rad.y), 0.25, tp) * smoothstep(0.75, 1.0, e) * 0.5);
    }
    // The rim: two crisp rings that follow the opening, then the runes and rays once it is wide open.
    float ed = (e - 1.0) * min(rad.x, rad.y);
    rim = max(rim, ink(abs(ed), 0.08, tp));
    rim = max(rim, ink(abs(ed - 0.45), 0.03, tp) * o.y);
    float full = smoothstep(0.7, 1.0, o.y) * o.x;
    float rr = r / R;
    float runeA = ang + t * 0.012;
    float tick = abs(fract(runeA * 96.0 / TAU + 0.5) - 0.5) * TAU / 96.0 * r;
    float glyph = step(0.35, hash11(floor(runeA * 48.0 / TAU) + seed));
    float band = step(1.1, rr) * step(rr, 1.24);
    rim = max(rim, ink(tick, 0.035, tp) * band * glyph * full);
    rim = max(rim, ink(abs(r - R * 1.27), 0.03, tp) * full);
    rim = max(rim, ink(abs(r - R * 1.08), 0.02, tp) * full);
    float rayA = ang - t * 0.008;
    float spoke = abs(fract(rayA * 8.0 / TAU + 0.5) - 0.5) * TAU / 8.0 * r;
    float len8 = 1.3 + 0.45 * full;
    rim = max(rim, ink(spoke, 0.06 * (1.0 - (rr - 1.3) / (len8 - 1.3)), tp) * step(1.3, rr) * step(rr, len8) * full);
    float spoke16 = abs(fract(rayA * 16.0 / TAU) - 0.5) * TAU / 16.0 * r;
    rim = max(rim, ink(spoke16, 0.03 * (1.0 - (rr - 1.3) / 0.22), tp) * step(1.3, rr) * step(rr, 1.52) * full);
    // The orrery: a wide faint ring carrying twelve small four-pointed stars, turning the other way.
    float orb = ink(abs(r - R * 1.95), 0.04, tp) * 0.6;
    float oa = ang + t * 0.006;
    float slot = (fract(oa * 12.0 / TAU + 0.5) - 0.5) * TAU / 12.0 * r;
    vec2 sp2 = vec2(slot, r - R * 1.95);
    float st4 = ink(abs(sp2.y), 0.05 * max(0.0, 1.0 - abs(sp2.x) / 1.1), tp) * step(abs(sp2.x), 1.1)
              + ink(abs(sp2.x), 0.05 * max(0.0, 1.0 - abs(sp2.y) / 1.1), tp) * step(abs(sp2.y), 1.1);
    rim = max(rim, (orb + st4) * full);
    rim *= edgeOn * (1.0 + flare);
    emit(c, mix(SAPPHIRE, PALE, 0.65) * rim, rim);
}

// Curtains of light hanging down from the rim of the open gate: thin lines swaying, fading as they fall.
void curtains(inout vec4 c, vec3 rd, float sceneT, vec3 G, float R, float t, float seed, float alpha) {
    if (alpha <= 0.001) return;
    for (int i = 0; i < 20; i++) {
        float fi = float(i);
        float a = fi / 20.0 * TAU + hash11(fi + seed) * 0.25 + t * 0.004;
        float rr = R * (1.02 + 0.25 * hash11(fi * 3.7 + seed));
        vec3 top = G + vec3(cos(a) * rr, -0.2, sin(a) * rr);
        float len = R * (0.8 + 1.4 * hash11(fi * 5.3 + seed));
        vec3 bottom = top + vec3(sin(t * 0.05 + fi) * 0.6, -len, cos(t * 0.04 + fi) * 0.6);
        float tt, ss;
        float d = raySeg(rd, top, bottom, tt, ss);
        if (tt <= 0.3 || tt > sceneT) continue;
        float flick = 0.6 + 0.4 * sin(t * 0.3 + fi * 2.1);
        float l = ink(d, 0.05 * (1.0 - ss), tt) * (1.0 - ss) * flick * alpha;
        emit(c, mix(SAPPHIRE, PALE, 0.4) * l, l * 0.8);
    }
}

// ---------------------------------------------------------------- Gungnir: chains, seals, ground

vec3 bezier(vec3 a, vec3 b, vec3 m, float s) {
    return mix(mix(a, m, s), mix(m, b, s), s);
}

// One chain of light from a ground anchor to the target: real links (rings seen flat, then edge-on, in turn).
void chain(inout vec4 c, vec3 rd, float sceneT, vec3 a, vec3 b, float reach, float tight, float shake, float alpha) {
    if (alpha <= 0.001 || reach <= 0.001) return;
    vec3 side = normalize(cross(b - a, vec3(0.0, 1.0, 0.0)) + vec3(1e-4));
    vec3 m = mix(a, b, 0.5) + vec3(0.0, 1.5 * (1.0 - tight), 0.0) + side * shake;
    float best = 1e9;
    float bestT = 0.0;
    float bestS = 0.0;
    vec3 prev = a;
    float len = 0.0;
    for (int i = 1; i <= 6; i++) {
        float s = reach * float(i) / 6.0;
        vec3 p = bezier(a, b, m, s);
        float tt, ss;
        float d = raySeg(rd, prev, p, tt, ss);
        float segLen = length(p - prev);
        if (tt > 0.3 && tt < sceneT + 0.2 && d < best) {
            best = d;
            bestT = tt;
            bestS = len + ss * segLen;
        }
        len += segLen;
        prev = p;
    }
    if (best > 0.4) return;
    float link = 0.42;
    float n = bestS / link;
    float x = (fract(n) - 0.5) * link;
    float l;
    if (mod(floor(n), 2.0) < 0.5) {
        float ex = length(vec2(x / (link * 0.66), best / 0.13));
        l = ink(abs(ex - 1.0) * 0.13, 0.026, bestT);
    } else {
        l = ink(best, 0.032, bestT) * step(abs(x), link * 0.66);
    }
    // The links glow faintly blue round their bright silver.
    float glow = ink(best, 0.16, bestT) * 0.18;
    l *= alpha;
    emit(c, PALE * l + SAPPHIRE * glow * alpha, l);
}

// A small seal of light on the ground where a chain is anchored.
void anchorSeal(inout vec4 c, vec3 surface, vec3 at, float r0, float alpha, float spin) {
    if (alpha <= 0.001) return;
    vec3 q = surface - at;
    float r = length(q.xz);
    if (r > r0 * 1.4) return;
    float ts = length(surface);
    float ang = atan(q.z, q.x) + spin;
    float l = ink(abs(r - r0), 0.03, ts) + ink(abs(r - r0 * 0.7), 0.015, ts);
    float tick = abs(fract(ang * 12.0 / TAU + 0.5) - 0.5) * TAU / 12.0 * r;
    l += ink(tick, 0.015, ts) * step(r0 * 0.7, r) * step(r, r0);
    l *= alpha;
    emit(c, mix(SAPPHIRE, PALE, 0.5) * l, l * 0.8);
}

// The great seal on the ground round the target (rings and runes only), marking where Gungnir will fall. draw 0..1 traces it out.
void targetSeal(inout vec4 c, vec3 surface, vec3 at, float R, float draw, float bright, float spin, float alpha) {
    if (alpha <= 0.001) return;
    vec3 q = surface - at;
    float r = length(q.xz);
    if (r > R * 1.05) return;
    float ts = length(surface);
    float ang = atan(q.z, q.x);
    float from = (mod(ang + PI * 0.5, TAU)) / TAU;
    float on = step(from, draw);
    float l = 0.0;
    l = max(l, ink(abs(r - R), 0.07, ts) * on);
    l = max(l, ink(abs(r - R * 0.94), 0.03, ts) * on);
    l = max(l, ink(abs(r - R * 0.62), 0.04, ts) * on);
    l = max(l, ink(abs(r - R * 0.3), 0.03, ts) * smoothstep(0.4, 0.8, draw));
    float runeA = ang + spin;
    float tick = abs(fract(runeA * 72.0 / TAU + 0.5) - 0.5) * TAU / 72.0 * r;
    l = max(l, ink(tick, 0.03, ts) * step(R * 0.95, r) * step(r, R * 0.995) * step(0.3, hash11(floor(runeA * 36.0 / TAU))) * on);
    l *= alpha * bright;
    emit(c, mix(SAPPHIRE, PALE, 0.55) * l, min(l, 1.0) * 0.8);
}

// ---------------------------------------------------------------- Gungnir

void callMagic(inout vec4 c, vec3 rd, float sceneT, vec3 tip, vec3 G, float a, float t, float seed) {
    if (a <= 0.001) return;
    vec3 ax = normalize(G - tip);
    vec3 u, v;
    planeAxes(ax, u, v);
    // The seal, just past the point: two rings, rune marks between them turning one way, six beads the other.
    vec3 center = tip + ax * 0.4;
    float tp = rayPlane(rd, center, ax);
    if (tp > 0.05 && tp < sceneT + 0.3) {
        float face = smoothstep(0.06, 0.3, abs(dot(rd, ax)));
        vec3 q = rd * tp - center;
        float r = length(q);
        float ang = atan(dot(q, v), dot(q, u));
        float R = 1.5 * (1.0 - pow(1.0 - saturate(a), 3.0));
        float l = ink(abs(r - R), 0.035, tp) + ink(abs(r - R * 0.7), 0.022, tp);
        float ra = ang + t * 0.12;
        float cellA = floor(ra * 18.0 / TAU);
        float inCell = abs(fract(ra * 18.0 / TAU) - 0.5);
        float runeR = R * (0.8 + 0.1 * hash11(cellA * 1.7 + seed));
        l += ink(abs(r - runeR), 0.05, tp) * step(inCell, 0.16) * step(0.3, hash11(cellA + seed)) * step(r, R * 0.97);
        float rb = ang - t * 0.2;
        float arc = (abs(fract(rb * 6.0 / TAU) - 0.5) * TAU / 6.0) * R * 0.45;
        l += ink(length(vec2(arc, r - R * 0.45)), 0.07, tp);
        l *= face * a;
        emit(c, mix(SAPPHIRE, PALE, 0.65) * l, saturate(l));
    }
    // A thread of light up to the gate, with pulses climbing it - ever smaller as they rise.
    streak(c, rd, sceneT, center, G, 0.03, a * 0.6);
    for (int i = 0; i < 5; i++) {
        float s = fract(t * 0.05 + float(i) / 5.0);
        glint(c, rd, sceneT, mix(center, G, s * s), 0.45 * (1.0 - s) + 0.12, a * (1.0 - s * 0.6));
    }
    // Motes spiralling up round the point.
    for (int i = 0; i < 6; i++) {
        float h = fract(t * 0.045 + float(i) / 6.0);
        float an = t * 0.4 + float(i) * TAU / 6.0;
        vec3 p = tip + ax * (h * 1.8 - 0.2) + (u * cos(an) + v * sin(an)) * (0.6 * (1.0 - h) + 0.12);
        float mt;
        float d = rayPoint(rd, p, mt);
        if (mt <= 0.05 || mt > sceneT + 0.3) continue;
        float m = ink(d, 0.035, mt) * a * (1.0 - h);
        emit(c, PALE * m, m);
    }
}

void gungnir(inout vec4 c, vec3 rd, float sceneT, vec3 surface, bool sky) {
    float t = P0.y;
    float seed = P0.z;
    float reach = P0.w;
    float bind = P1.x;
    float leap = P1.y;
    float hover = P1.z;
    float call = P1.w;
    float open = P2.x;
    float opened = P2.y;
    float emerge = P2.z;
    float release = P2.w;
    float impact = P3.x;
    float close = P3.y;
    float shatter = P3.z;
    float shattered = P3.w;
    float point = Pts[3].w;
    vec3 G = Origin;
    vec3 A = Facing;
    const vec3 DOWN = vec3(0.0, -1.0, 0.0);
    float R = Pts[1].w;
    float L = Pts[0].w;
    vec3 chest = Pts[10].xyz;
    vec3 side = Pts[5].xyz;
    float radius = Pts[5].w;

    // The sky darkens to a starry night while the gate is open.
    float dusk = window2(t, open - 4.0, open + 10.0, close, close + 24.0);
    if (sky && dusk > 0.001) {
        float toward = saturate(dot(rd, normalize(G)) * 0.5 + 0.5);
        vec3 night = mix(NIGHT * 1.5, SAPPHIRE_DEEP * 0.7, pow(toward, 6.0));
        vec2 sc = vec2(atan(rd.z, rd.x) * 60.0, rd.y * 60.0);
        float star = step(0.985, hash12(floor(sc))) * (0.5 + 0.5 * sin(t * 0.3 + hash12(floor(sc) + 1.0) * 20.0));
        solid(c, night + PALE * star * 0.8, dusk * 0.75);
    }

    // Chains of light from four anchors round the target, binding it until the blow.
    float chainsA = 1.0 - smoothstep(impact, impact + 2.0, t);
    if (chainsA > 0.001) {
        float tight = smoothstep(bind - 1.0, bind + 1.0, t);
        float strain = window2(t, emerge, impact - 10.0, impact - 1.0, impact);
        for (int k = 0; k < 4; k++) {
            vec3 a = Pts[6 + k].xyz;
            vec3 dir = a - chest;
            vec3 b = chest + normalize(vec3(dir.x, 0.0, dir.z)) * 0.32 + vec3(0.0, -0.1 * float(k & 1), 0.0);
            float reachK = 1.0 - pow(1.0 - saturate((t - float(k) * 0.7) / 5.0), 3.0);
            float shake = sin(t * 1.9 + float(k) * 1.7) * 0.06 * strain;
            chain(c, rd, sceneT, a, b, reachK, tight, shake, chainsA);
            if (!sky) anchorSeal(c, surface, a, 0.55, chainsA * smoothstep(0.0, 3.0, t - float(k) * 0.7), t * 0.05);
        }
        // Binding rings round the target's chest and waist.
        float bound = window2(t, bind - 0.5, bind + 1.0, impact, impact + 1.0);
        vec3 feet = Target;
        float h = Pts[2].w;
        ringIn(c, rd, sceneT, chest, vec3(0.0, 1.0, 0.0), 0.7, 0.03, bound);
        ringIn(c, rd, sceneT, feet + vec3(0.0, h * 0.32, 0.0), vec3(0.0, 1.0, 0.0), 0.62, 0.025, bound * 0.8);
        spark(c, rd, sceneT, chest, (t - bind) / 20.0, 1.0, seed);
    }

    // The leap: a streak through where the caster flew.
    for (int k = 0; k < 7; k++) {
        vec4 a = Pts[11 + k];
        vec4 b = Pts[12 + k];
        if (a.w < 0.5 || b.w < 0.5) continue;
        float w = 0.2 * (1.0 - float(k) / 7.0);
        streak(c, rd, sceneT, b.xyz, a.xyz, w, 0.85 * (1.0 - smoothstep(hover - 2.0, hover + 4.0, t)));
    }

    // The call: at the raised spear's point, a seal of runes turning to face the gate, a thread of light up to it
    // with pulses climbing along, and motes spiralling round the point.
    vec4 hand = Pts[4];
    callMagic(c, rd, sceneT, hand.xyz, G, hand.w, t, seed);
    glint(c, rd, sceneT, hand.xyz, 0.5 + 0.6 * window2(t, call - 2.0, call, call + 3.0, call + 8.0), window2(t, call - 6.0, call - 2.0, open + 6.0, open + 12.0));

    // The great seal round the target.
    float sealA = window2(t, point, point + 2.0, impact, impact + 1.0);
    if (onGround(surface, Target, sky) && sealA > 0.001) {
        float draw = smoothstep(point, point + 12.0, t);
        float bright = 0.55 + 0.45 * smoothstep(emerge, impact - 20.0, t) + 0.5 * window2(t, release, release + 1.0, impact, impact + 1.0) * (0.6 + 0.4 * sin(t * 6.0));
        targetSeal(c, surface, Target, radius, draw, bright, t * 0.01, sealA);
    }

    // The gate and the spear: whichever is nearer is drawn last.
    float flare = window2(t, emerge, release - 4.0, release, release + 4.0) * 0.5 + window2(t, release, release + 0.5, release + 2.0, release + 6.0);
    float openA = window2(t, open, opened, close, close + 12.0);
    vec3 cloudAt = Pts[22].xyz;
    if (!sky && openA > 0.001 && abs(surface.y - cloudAt.y) < 4.0) {
        float d = length((surface - G).xz) / (R * 3.0);
        float lit = (1.0 - smoothstep(0.0, 1.0, d)) * openA;
        emit(c, mix(SAPPHIRE, PALE, 0.3) * lit * 0.35, lit * 0.3);
    }
    curtains(c, rd, sceneT, G, R, t, seed, window2(t, opened - 4.0, opened + 6.0, close, close + 8.0));
    vec4 gateC = c;
    float gt;
    gate(gateC, rd, sceneT, G, DOWN, R, t, seed, vec4(open, opened, close, 0.0), flare, gt);

    float st = -1.0;
    int idx;
    ivec2 cell;
    int face;
    float burn;
    if (L > 0.0) {
        float dissolve = saturate((t - shatter) / (shattered - shatter));
        st = giantTrace(rd, Pts[0].xyz, A, Pts[1].xyz, Pts[2].xyz, L / float(GSPEAR_H), G.y, dissolve, seed, idx, cell, face, burn);
        if (st > sceneT) st = -1.0;
    }
    // Seen from above, the gate's disc covers the spear below it.
    bool gateOver = st > 0.0 && gt > 0.0 && gt < st;
    if (!gateOver) c = gateC;
    if (st > 0.0) {
        vec3 col = giantColor(idx, cell, t);
        float shade = face == 0 ? 1.0 : face == 1 ? 0.84 : face == 2 ? 0.7 : 1.0;
        col *= shade;
        float light = 0.0;
        if (idx == 6 || idx == 11 || idx == 12) light = 0.6;
        if (face == 3) {
            col = mix(PALE, vec3(1.0), 0.6);
            light = 1.0;
        }
        col = mix(col, mix(PALE, vec3(1.0), 0.5), burn);
        light = max(light, burn);
        solid(c, col, 1.0);
        c.a = max(c.a, light * 0.8);
    }
    if (gateOver) {
        float gt2;
        gate(c, rd, sceneT, G, DOWN, R, t, seed, vec4(open, opened, close, 0.0), flare, gt2);
    }

    // A ring of light thrown off the gate as the spear's butt clears it.
    float kl = saturate((t - release) / 10.0);
    ringIn(c, rd, sceneT, G, DOWN, R * (1.1 + 1.6 * (1.0 - pow(1.0 - kl, 3.0))), 0.14 * (1.0 - kl) + 0.03,
           window2(t, release, release + 0.5, release + 4.0, release + 10.0));

    // The fall: a wake down from the gate behind the spear, and sonic rings torn off the air - ever closer together
    // in time as it gathers speed.
    vec3 tip = Pts[21].xyz;
    float fallA = window2(t, release - 6.0, release + 1.0, impact, impact + 6.0);
    if (fallA > 0.001) {
        vec3 butt = tip - A * L;
        streak(c, rd, sceneT, G, butt + A * 6.0, 1.4, fallA * 0.85);
        vec3 u, v;
        planeAxes(A, u, v);
        for (int i = 0; i < 6; i++) {
            float a = hash11(float(i) + seed) * TAU;
            vec3 off = (u * cos(a) + v * sin(a)) * (2.2 + 1.6 * hash11(float(i) * 2.3 + seed));
            streak(c, rd, sceneT, butt + off - A * 14.0, tip + off - A * (6.0 + 4.0 * hash11(float(i) * 5.1)), 0.08, fallA * 0.7);
        }
    }
    for (int i = 0; i < 10; i++) {
        float dist = reach * (0.3 + 0.07 * float(i));
        float lo = emerge;
        float hi = impact;
        for (int j = 0; j < 14; j++) {
            float mid = (lo + hi) * 0.5;
            if (spearOut(mid, emerge, impact, reach) < dist) lo = mid; else hi = mid;
        }
        float age = t - hi;
        if (age < 0.0 || age > 8.0) continue;
        ringIn(c, rd, sceneT, G + A * (dist - 6.0), A, 3.5 + age * 1.8, 0.14 * (1.0 - age / 8.0) + 0.02, 1.0 - age / 8.0);
    }

    // The blow.
    float k = (t - impact) / 20.0;
    if (k >= 0.0) {
        float fadeCracks = 1.0 - smoothstep((shattered - impact) / 20.0, (shattered - impact) / 20.0 + 1.5, k);
        if (onGround(surface, Target, sky)) {
            vec3 q = surface - Target;
            float r = length(q.xz);
            float ts = length(surface);
            // Shock rings racing out across the ground.
            float rr = 26.0 * (1.0 - pow(1.0 - saturate(k / 0.6), 3.0));
            float ring = ink(abs(r - rr), 0.14 * (1.0 - saturate(k / 0.8)) + 0.02, ts) * (1.0 - smoothstep(0.4, 0.9, k));
            float rr2 = 13.0 * (1.0 - pow(1.0 - saturate(k / 0.45), 3.0));
            ring += ink(abs(r - rr2), 0.06, ts) * (1.0 - smoothstep(0.2, 0.5, k));
            emit(c, PALE * ring, ring);
            // A scorched crater round the buried point.
            solid(c, c.rgb * 0.45, smoothstep(4.2, 2.6, r) * fadeCracks * 0.8);
            // Broken ground all round: a web of cracks, finer further out, its edge ragged rather than round.
            float spread = smoothstep(0.0, 0.2, k);
            float ang = atan(q.z, q.x);
            float edge = (7.0 + 3.5 * vnoise2(vec2(ang * 2.2, seed)) + 1.5 * vnoise2(vec2(ang * 6.0, seed + 3.0))) * spread + 0.01;
            float cd = crackDist(q.xz * 0.55, seed);
            float cdFine = crackDist(q.xz * 1.1, seed + 5.0);
            float reachOut = 1.0 - smoothstep(edge * 0.55, edge, r);
            float web = (1.0 - smoothstep(0.015, 0.05, cd)) * reachOut * spread;
            web = max(web, (1.0 - smoothstep(0.01, 0.035, cdFine)) * (1.0 - smoothstep(edge * 0.25, edge * 0.6, r)) * spread * 0.8);
            solid(c, c.rgb * 0.25, saturate(web) * fadeCracks);
            emit(c, SAPPHIRE * web * 0.7 * fadeCracks, web * fadeCracks * 0.7);
            // Light pooling round the buried point.
            float pool = ink(abs(r - 1.8 - 0.3 * sin(t * 0.4)), 0.05, ts) * window2(t, impact, impact + 2.0, shatter, shatter + 4.0);
            emit(c, PALE * pool, pool);
        }
        // A pillar of light down the spear's line, gone in a blink.
        streak(c, rd, sceneT, Target - A * 40.0, Target + A * 2.0, 3.5 * (1.0 - saturate(k / 0.35)), 1.0 - smoothstep(0.1, 0.4, k));
        spark(c, rd, sceneT, Target + vec3(0.0, 1.0, 0.0), k * 0.5, 7.0, seed);
        shards(c, rd, sceneT, Target + vec3(0.0, 1.0, 0.0), k, seed, 9.0, 0.32);
        shards(c, rd, sceneT, Target + vec3(0.0, 0.8, 0.0), k - 0.05, seed + 4.0, 6.0, 0.24);
    }

    // The spear breaks into light, from its buried point back up to its butt.
    if (t >= shatter && t < shattered + 20.0 && L > 0.0) {
        for (int i = 0; i < 6; i++) {
            float along = (float(i) + 0.5) / 6.0;
            vec3 at = tip - A * (L * along);
            float born = shatter + along * (shattered - shatter) * 0.85;
            float age = (t - born) / 20.0;
            shards(c, rd, sceneT, at, age, seed + 10.0 + float(i), 5.0, 0.4);
            spark(c, rd, sceneT, at, age * 0.6, 2.2, seed + float(i));
        }
        float kk = (t - shattered) / 20.0;
        if (kk > 0.0) {
            ringIn(c, rd, sceneT, Target + vec3(0.0, 0.1, 0.0), vec3(0.0, 1.0, 0.0), 2.0 + 12.0 * (1.0 - pow(1.0 - saturate(kk / 0.7), 3.0)), 0.05, 1.0 - smoothstep(0.3, 0.8, kk));
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
        piercingLunge(c, rd, sceneT);
    } else if (mode == 2) {
        crescentSweep(c, rd, sceneT, surface, sky);
    } else if (mode == 3) {
        gungnir(c, rd, sceneT, surface, sky);
    }
    fragColor = c;
}
