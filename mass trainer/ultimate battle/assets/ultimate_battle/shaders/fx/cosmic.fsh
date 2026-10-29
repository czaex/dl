// Cosmic effects. P0.x picks the skill: 1 Comet Lance, 2 Gravity Well, 3 Event Horizon.
// Deep space is painted here: a procedural starfield and nebula, and black holes traced through bent space
// (photon paths integrated round the hole, the accretion disk sampled where they cross it). The Gravity Well's
// small singularity bends the real scene behind it. Lines stay crisp and the glow mask stays low.

// Loop counts come from a uniform (always 1) so the driver keeps the loops as loops instead of unrolling them
// into a huge program that takes seconds to compile.
uniform float Loops;
// Deep space is traced at half resolution (mode 4) into these two: colour with disk cover in a, and the bent
// sky direction with "swallowed" in w. The full resolution pass adds the crisp stars along that direction.
uniform sampler2D HalfSampler;
uniform sampler2D HalfAux;
out vec4 fragAux;

int loops(int n) {
    return int(float(n) * Loops + 0.5);
}

const vec3 NEB = vec3(1.0, 0.31, 0.85);
const vec3 NEB_DEEP = vec3(0.42, 0.06, 0.4);
const vec3 STARLIGHT = vec3(0.56, 0.91, 1.0);
const vec3 PALE = vec3(1.0, 0.97, 1.0);
const vec3 VOID = vec3(0.01, 0.007, 0.028);
const vec3 INDIGO = vec3(0.14, 0.07, 0.38);
const vec3 HOT = vec3(1.0, 0.95, 0.85);
const vec3 EMBER = vec3(1.0, 0.62, 0.22);

float window2(float t, float in0, float in1, float out0, float out1) {
    return saturate((t - in0) / max(in1 - in0, 0.001)) * (1.0 - saturate((t - out0) / max(out1 - out0, 0.001)));
}

vec3 camRight() { return normalize((InvView * vec4(1.0, 0.0, 0.0, 0.0)).xyz); }
vec3 camUp() { return normalize((InvView * vec4(0.0, 1.0, 0.0, 0.0)).xyz); }

// Paints over the scene without raising the glow mask (solid things, not light).
void solid(inout vec4 c, vec3 col, float a) {
    c.rgb = mix(c.rgb, col, saturate(a));
}

// Rotates v round the unit axis k by angle a.
vec3 spin(vec3 v, vec3 k, float a) {
    float cs = cos(a), sn = sin(a);
    return v * cs + cross(k, v) * sn + k * dot(k, v) * (1.0 - cs);
}

// ---------------------------------------------------------------- deep space

// Two-octave value noise: deep space is painted on most of the screen, so its noise has to stay cheap.
float fbmLite(vec3 p) {
    return 0.65 * vnoise3(p) + 0.35 * vnoise3(p * 2.03 + vec3(11.3, 5.7, 3.1));
}

// One layer of stars: at most one per cell of a grid wrapped on the sky, crisp at any resolution.
vec3 starLayer(vec3 d, float scale, float density, float seed) {
    vec3 p = d * scale;
    vec3 cell = floor(p);
    if (hash13(cell + seed) > density) return vec3(0.0);
    vec3 pos = cell + 0.2 + 0.6 * vec3(hash13(cell + seed + 1.7), hash13(cell + seed + 3.1), hash13(cell + seed + 5.3));
    vec3 v = p - pos;
    v -= d * dot(v, d);
    float dist = length(v);
    float px = gPix * scale;
    float size = max(px * 0.7, 0.02 + 0.05 * hash13(cell + seed + 7.7));
    float core = smoothstep(size + px, size, dist);
    float bright = 0.35 + 1.8 * pow(hash13(cell + seed + 9.1), 4.0);
    float tone = hash13(cell + seed + 11.0);
    vec3 tint = tone < 0.33 ? mix(PALE, STARLIGHT, 0.6) : tone < 0.66 ? PALE : mix(PALE, vec3(1.0, 0.78, 0.6), 0.6);
    float flare = 0.0;
    if (bright > 1.0) {
        float a = abs(dot(v, camRight()));
        float b = abs(dot(v, camUp()));
        float len = size * 9.0 * (bright - 0.9);
        flare = smoothstep(px, 0.0, a) * smoothstep(len, 0.0, b) + smoothstep(px, 0.0, b) * smoothstep(len, 0.0, a);
        flare *= 0.8;
    }
    return tint * (core * bright + flare);
}

vec3 nebula(vec3 d, float seed) {
    vec3 axis = normalize(vec3(0.25, 0.8, 0.45));
    float band = exp(-abs(dot(d, axis)) * 4.5);
    float n = fbmLite(d * 2.1 + seed);
    float m = vnoise3(d * 4.3 + seed + 10.0);
    vec3 col = VOID;
    col += INDIGO * smoothstep(0.35, 0.75, n) * 0.6;
    col += NEB * smoothstep(0.58, 0.86, n * (0.55 + 0.6 * m)) * 0.32;
    col += STARLIGHT * smoothstep(0.62, 0.9, m) * band * 0.16;
    col += vec3(0.85, 0.8, 1.0) * band * 0.07;
    // Dust lanes across the galactic band, with a crisp edge.
    float lane = vnoise3(d * 8.0 + seed + 20.0);
    col *= 1.0 - 0.7 * band * smoothstep(0.5, 0.56, lane);
    return col;
}

vec3 starField(vec3 d, float seed) {
    vec3 axis = normalize(vec3(0.25, 0.8, 0.45));
    float band = exp(-abs(dot(d, axis)) * 4.5);
    vec3 c = starLayer(d, 60.0, 0.09, seed);
    c += starLayer(d, 150.0, 0.12 + 0.2 * band, seed + 20.0) * 0.75;
    c += starLayer(d, 330.0, 0.1 + 0.35 * band, seed + 40.0) * 0.5;
    return c;
}

vec3 skyColor(vec3 d, float seed) {
    return nebula(d, seed) + starField(d, seed);
}

// The sky seen through a portal: a lighter version (one star layer, one noise) for a small disc.
vec3 portalSky(vec3 d, float seed) {
    float n = vnoise3(d * 3.0 + seed);
    vec3 c = VOID + INDIGO * smoothstep(0.3, 0.8, n) * 0.7 + NEB * smoothstep(0.65, 0.95, n) * 0.3;
    return c + starLayer(d, 90.0, 0.14, seed);
}

// Accretion disk: white-hot inside, through gold and orange to a deep red rim, in flat anime bands.
vec3 diskRamp(float i) {
    float a = 0.02;
    vec3 c = vec3(0.42, 0.06, 0.05) * smoothstep(0.04, 0.12, i);
    c = mix(c, vec3(0.92, 0.33, 0.1), smoothstep(0.28 - a, 0.28 + a, i));
    c = mix(c, vec3(1.0, 0.66, 0.26), smoothstep(0.52 - a, 0.52 + a, i));
    c = mix(c, HOT, smoothstep(0.8 - a, 0.8 + a, i));
    return c * (0.75 + 0.45 * min(i, 1.5));
}

// Disk colour and opacity where a photon path crosses it: q in hole units, v the path direction.
vec4 diskSample(vec3 q, vec3 v, float rin, float rout, float t, float seed) {
    float r = length(q.xz);
    float ang = atan(q.z, q.x);
    float omega = 1.6 * pow(r / rin, -1.5);
    float sw = ang - t * 0.045 * omega;
    vec3 np = vec3(cos(sw) * 1.6, sin(sw) * 1.6, r * 5.5 / rin);
    float n = fbmLite(np + seed);
    float lanes = smoothstep(0.38, 0.44, fract(r * 3.0 / rin + n * 0.7));
    float temp = pow(rin / r, 0.8);
    vec3 vel = normalize(vec3(-q.z, 0.0, q.x));
    float dop = 1.0 + 0.9 * inversesqrt(r / rin) * 0.5 * dot(vel, -v);
    float i = temp * (0.55 + 0.8 * n) * dop * dop * (0.75 + 0.25 * lanes);
    float edge = smoothstep(rin, rin * 1.06, r) * (1.0 - smoothstep(rout * 0.72, rout, r));
    float a = edge * saturate(0.55 + 0.6 * n) * (0.7 + 0.3 * lanes);
    return vec4(diskRamp(i), a);
}

// A black hole of horizon radius rs at camera-relative centre b, its disk flat (y up) from rin to rout (in
// horizon radii). Returns the colour of deep space along rd (sky: 0 none, 1 nebula and stars, 2 nebula only);
// the final (bent) direction comes back in bent, how much disk was crossed in diskA, and whether the path fell in
// in captured.
vec3 blackHole(vec3 rd, vec3 b, float rs, float rin, float rout, float gravity, float t, float seed, int sky,
               out vec3 bent, out float diskA, out bool captured) {
    bent = rd;
    diskA = 0.0;
    captured = false;
    vec3 acc = vec3(0.0);
    float bound = rout * 1.12;
    float tc = dot(b, rd);
    float dmin = length(rd * tc - b);
    float rmin = 1e9;
    if (dmin < bound * rs && tc > -bound * rs) {
        vec2 hit = raySphere(rd, b, bound * rs);
        float t0 = max(hit.x, 0.0);
        vec3 p = (rd * t0 - b) / rs;
        vec3 v = rd;
        vec3 l = cross(p, v);
        float h2 = dot(l, l);
        int steps = loops(90);
        for (int i = 0; i < steps; i++) {
            float r = length(p);
            rmin = min(rmin, r);
            if (r < 1.0) {
                captured = true;
                break;
            }
            if (r > bound + 0.3 && dot(p, v) > 0.0) break;
            float dt = clamp(0.11 * r, 0.035, 0.75);
            vec3 pp = p;
            float r2 = r * r;
            v += -1.5 * gravity * h2 * p / (r2 * r2 * r) * dt;
            v = normalize(v);
            p += v * dt;
            if (pp.y * p.y < 0.0 && diskA < 0.99) {
                vec3 q = mix(pp, p, pp.y / (pp.y - p.y));
                float rq = length(q.xz);
                if (rq > rin && rq < rout) {
                    vec4 d = diskSample(q, v, rin, rout, t, seed);
                    acc += (1.0 - diskA) * d.rgb * d.a;
                    diskA += (1.0 - diskA) * d.a;
                }
            }
        }
        bent = v;
    }
    vec3 col = acc;
    if (!captured) {
        // The photon ring: one crisp gold line where light skims the photon sphere.
        float ring = smoothstep(0.05, 0.0, abs(rmin - 1.52)) * (1.0 - diskA);
        col += HOT * ring * 0.9;
        if (sky == 1) col += (1.0 - diskA) * skyColor(normalize(bent), seed);
        if (sky == 2) col += (1.0 - diskA) * nebula(normalize(bent), seed);
    }
    return col;
}

// ---------------------------------------------------------------- shared marks

// A star burst: an expanding ring, eight crisp spikes and a flash, camera-facing. k in seconds.
void starBurst(inout vec4 c, vec3 rd, float sceneT, vec3 pos, float k, float size, float seed) {
    if (k < 0.0 || k > 0.35) return;
    float tp;
    float d = rayPoint(rd, pos, tp);
    if (tp > sceneT + size || d > size * 3.0) return;
    float u = k / 0.35;
    float rr = size * (0.25 + 1.3 * sqrt(u));
    float ring = ink(abs(d - rr), 0.035 * size * (1.0 - u) + 0.004, tp);
    float ring2 = ink(abs(d - rr * 0.7), 0.015 * size * (1.0 - u) + 0.003, tp) * 0.7;
    vec3 v = rd * tp - pos;
    float ang = atan(dot(v, camUp()), dot(v, camRight())) + seed;
    float spikes = pow(max(cos(ang * 2.0), 0.0), 70.0) + pow(max(cos(ang * 2.0 + PI * 0.5), 0.0), 70.0) * 0.55;
    float spike = spikes * smoothstep(rr * 2.0, rr * 0.3, d) * step(rr * 0.15, d) * (1.0 - u);
    float flash = exp(-d / (size * 0.1)) * exp(-k * 24.0);
    emit(c, PALE * (ring + spike) + NEB * ring2 + STARLIGHT * flash, saturate(ring + spike + flash) * 0.8);
}

// A portal torn in space: a disc of deep sky with a vortex in it, a wobbling crisp rim and two broken rings
// turning round it in opposite directions. open 0..1 scales it.
void portal(inout vec4 c, vec3 rd, float sceneT, vec3 at, vec3 n, float radius, float t, float seed) {
    if (radius < 0.02) return;
    float facing = abs(dot(rd, n));
    float tp = rayPlane(rd, at, n);
    if (tp <= 0.0 || tp > sceneT + 0.2) return;
    vec3 q = rd * tp - at;
    float r = length(q);
    if (r > radius * 1.45) return;
    vec3 u = normalize(abs(n.y) > 0.95 ? cross(n, vec3(1.0, 0.0, 0.0)) : cross(n, vec3(0.0, 1.0, 0.0)));
    vec3 w = cross(n, u);
    float ang = atan(dot(q, w), dot(q, u));
    float re = radius * (1.0 + 0.06 * sin(ang * 5.0 + t * 0.35) + 0.04 * sin(ang * 11.0 - t * 0.6));
    float fade = smoothstep(0.04, 0.22, facing);
    float aa = gPix * tp;
    if (r < re && tp < sceneT) {
        float depth = 1.0 - r / re;
        vec3 d2 = spin(rd, n, depth * 3.0 + t * 0.04);
        vec3 inside = portalSky(d2, seed) * 1.3;
        float vort = abs(fract((ang + log(r / radius + 0.05) * 1.8 - t * 0.09) * 4.0 / TAU) - 0.5);
        inside += NEB * smoothstep(0.08, 0.0, vort) * (0.25 + 0.5 * depth) * smoothstep(0.0, 0.3, r / re);
        inside = mix(inside, vec3(0.0), smoothstep(0.35, 0.0, r / re) * 0.5);
        solid(c, inside, smoothstep(re, re - aa * 1.5, r) * fade);
    }
    float rim = ink(abs(r - re), 0.05 * radius / 2.6 + 0.01, tp);
    float glowRim = ink(abs(r - re), 0.12 * radius / 2.6, tp) - rim;
    float a1 = step(0.4, fract((ang + t * 0.08) * 5.0 / TAU));
    float a2 = step(0.55, fract((-ang + t * 0.05) * 3.0 / TAU));
    float ring1 = ink(abs(r - re * 1.1), 0.02 * radius / 2.6 + 0.004, tp) * a1;
    float ring2 = ink(abs(r - re * 1.22), 0.014 * radius / 2.6 + 0.003, tp) * a2;
    vec3 col = PALE * rim + NEB * glowRim * 0.8 + NEB * ring1 + STARLIGHT * ring2;
    emit(c, col * fade, saturate(rim + ring1 * 0.6 + ring2 * 0.5) * fade * 0.7);
}

// A thin tapering streak a-b.
void line3(inout vec4 c, vec3 rd, float sceneT, vec3 a, vec3 b, float width, vec3 col, float alpha) {
    if (alpha <= 0.001) return;
    float t, s;
    float d = raySeg(rd, a, b, t, s);
    if (t <= 0.0 || t > sceneT + 0.3) return;
    float w = width * sqrt(max(sin(PI * s), 0.0));
    float core = ink(d, w * 0.4, t);
    float body = ink(d, w, t) - core;
    emit(c, (PALE * core + col * body) * alpha, max(core, body * 0.6) * alpha);
}

// Ground decal of a cosmic blow: shock rings racing out, then glowing cracks and a fading galaxy spiral.
void groundBlow(inout vec4 c, vec3 surface, vec3 at, float k, float reach, float seed) {
    vec3 q = surface - at;
    if (abs(q.y) > 0.6 || k < 0.0) return;
    float r = length(q.xz);
    float dist = length(surface);
    float rr = reach * (1.0 - pow(1.0 - saturate(k / 0.6), 3.0));
    float ring = ink(abs(r - rr), 0.12 * (1.0 - saturate(k / 0.8)) + 0.02, dist) * (1.0 - smoothstep(0.4, 0.9, k));
    float rr2 = reach * 0.5 * (1.0 - pow(1.0 - saturate(k / 0.45), 3.0));
    ring += ink(abs(r - rr2), 0.05, dist) * (1.0 - smoothstep(0.2, 0.5, k));
    emit(c, PALE * ring, ring);
    float spread = reach * 0.55 * smoothstep(0.0, 0.25, k);
    if (r < spread) {
        float cd = crackDist(q.xz * 0.55, seed);
        float l = 1.0 - smoothstep(0.015, 0.05, cd);
        l *= smoothstep(0.42, 0.5, vnoise2(q.xz * 0.9 + seed * 3.0));
        float f = (1.0 - smoothstep(reach * 0.25, reach * 0.5, r)) * (1.0 - smoothstep(0.5, 1.3, k));
        emit(c, mix(NEB, STARLIGHT, step(0.5, hash12(floor(q.xz * 2.0)))) * l * f, l * f);
    }
    // The galaxy left in the ground: two crisp spiral arms that fade.
    float g = (1.0 - smoothstep(0.6, 2.2, k)) * smoothstep(0.05, 0.2, k);
    if (g > 0.0 && r < reach * 0.45) {
        float ang = atan(q.z, q.x);
        float arm = abs(fract((ang - log(r + 0.3) * 2.4 + k * 0.6) * 2.0 / TAU) - 0.5) * TAU / 2.0 * r;
        float l = ink(arm, 0.06 + 0.02 * r, dist) * (1.0 - smoothstep(reach * 0.25, reach * 0.45, r));
        emit(c, mix(STARLIGHT, NEB, saturate(r / (reach * 0.4))) * l * g, l * g * 0.7);
    }
}

// ---------------------------------------------------------------- Comet Lance
// P0 = (1, tick, FIRE, arrive), P1 = (seed, locked). Pts[0] start (staff head), Pts[1] end, Pts[2..9] hits (w = tick, < 0 none).
void cometLance(inout vec4 c, vec3 rd, float sceneT, vec3 surface, bool sky) {
    float t = P0.y;
    float fire = P0.z;
    float arrive = P0.w;
    float seed = P1.x;
    vec3 s = Pts[0].xyz;
    vec3 e = Pts[1].xyz;
    vec3 dir = normalize(e - s);
    // Charge: rings of light collapsing into the staff's head.
    if (t < fire + 1.0) {
        float tp;
        float d = rayPoint(rd, s, tp);
        // Not drawn right in front of the caster's own eyes, where it would fill the screen.
        float near = 1.0;
        if (length(s) > 2.0 && tp < sceneT + 1.0 && d < 1.4) {
            for (int i = 0; i < 3; i++) {
                float u = fract(t / 4.0 + float(i) / 3.0);
                float rr = 1.1 * near * (1.0 - u);
                float l = ink(abs(d - rr), 0.012, tp) * u * window2(t, 0.0, 2.0, fire - 1.0, fire + 1.0);
                emit(c, mix(STARLIGHT, NEB, float(i) * 0.5) * l, l * 0.6);
            }
            float core = ink(d, 0.06 * saturate(t / fire), tp);
            emit(c, PALE * core, core * 0.5);
        }
    }
    if (t >= fire && t < arrive + 1.0) {
        float u = saturate((t - fire) / max(arrive - fire, 0.01));
        vec3 head = mix(s, e, u);
        float tail = min(7.5, length(head - s));
        vec3 back = head - dir * tail;
        // Tail: a tapering streak, white along its spine, starlight into nebula toward the head.
        float tt, ss;
        float d = raySeg(rd, back, head, tt, ss);
        if (tt > 0.0 && tt < sceneT + 0.5) {
            float w = 0.34 * pow(ss, 1.6);
            float core = ink(d, w * 0.28, tt);
            float body = ink(d, w, tt) - core;
            float fringe = ink(d, w * 1.55, tt) - core - body;
            vec3 col = PALE * core + mix(NEB, STARLIGHT, ss) * body * 0.9 + NEB_DEEP * fringe;
            emit(c, col, max(core, body * 0.5));
        }
        // Three thin streamers corkscrewing round the tail.
        vec3 side = normalize(cross(dir, abs(dir.y) > 0.9 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0)));
        vec3 up2 = cross(dir, side);
        for (int i = 0; i < 3; i++) {
            float ph = float(i) * TAU / 3.0 + t * 0.9;
            for (int j = 0; j < 5; j++) {
                float a0 = float(j) / 5.0;
                float a1 = float(j + 1) / 5.0;
                float r0 = 0.32 * a0;
                float r1 = 0.32 * a1;
                vec3 p0 = mix(back, head, a0) + (side * cos(ph + a0 * 6.0) + up2 * sin(ph + a0 * 6.0)) * r0;
                vec3 p1 = mix(back, head, a1) + (side * cos(ph + a1 * 6.0) + up2 * sin(ph + a1 * 6.0)) * r1;
                float t2, s2;
                float d2 = raySeg(rd, p0, p1, t2, s2);
                if (t2 > 0.0 && t2 < sceneT + 0.3) {
                    float l = ink(d2, 0.012, t2) * (a0 + s2 * 0.2);
                    emit(c, mix(STARLIGHT, PALE, a0) * l, l * 0.5);
                }
            }
        }
        // Head: a white-hot core in flat bands, a four-point flare and a ring turning round it.
        float th;
        float dh = rayPoint(rd, head, th);
        if (th > 0.0 && th < sceneT + 0.5 && dh < 2.0) {
            float i = 1.0 - dh / 0.36;
            float m = celMask(i);
            vec3 col = cel(i, PALE, STARLIGHT, NEB);
            paint(c, col, m);
            vec3 v = rd * th - head;
            float a = abs(dot(v, camRight()));
            float b = abs(dot(v, camUp()));
            float flare = ink(a, 0.01, th) * smoothstep(1.6, 0.0, b) + ink(b, 0.01, th) * smoothstep(1.6, 0.0, a);
            emit(c, PALE * flare, flare * 0.6);
            float tr = rayPlane(rd, head, dir);
            if (tr > 0.0 && tr < sceneT) {
                float rr = length(rd * tr - head);
                float ring = ink(abs(rr - 0.62), 0.015, tr) * step(0.5, fract(atan(dot(rd * tr - head, up2), dot(rd * tr - head, side)) / TAU * 4.0 + t * 0.3));
                emit(c, STARLIGHT * ring, ring * 0.5);
            }
        }
    }
    for (int i = 2; i < 10; i++) {
        if (Pts[i].w < 0.0) continue;
        starBurst(c, rd, sceneT, Pts[i].xyz, (t - Pts[i].w) / 20.0, 0.9, float(i) + seed);
    }
    float k = (t - arrive) / 20.0;
    if (k >= 0.0) {
        starBurst(c, rd, sceneT, e, k * 0.8, 2.2, seed);
        starBurst(c, rd, sceneT, e, k * 0.8 - 0.05, 1.4, seed + 1.0);
        if (!sky) groundBlow(c, surface, e - vec3(0.0, 0.0, 0.0), k * 1.4, 6.0, seed);
    }
}

// ---------------------------------------------------------------- Gravity Well
// P0 = (2, tick, seed, size 0..1), P1 = (PLANT, PULL, COLLAPSE, BURST), P2 = (ground height under it). Origin = centre.
void gravityWell(inout vec4 c, vec2 uv, vec3 rd, float sceneT, vec3 surface, bool sky) {
    float t = P0.y;
    float seed = P0.z;
    float size = P0.w;
    float plant = P1.x;
    float pull = P1.y;
    float collapse = P1.z;
    float burst = P1.w;
    vec3 at = Origin;
    float groundY = P2.x;

    // No purple swirl or light streams while it pulls (removed on request): only the singularity itself,
    // then the burst.

    // The singularity itself, bending the world behind it.
    float rs = 0.75 * size;
    if (rs > 0.01) {
        float tcc;
        float dcc = rayPoint(rd, at, tcc);
        float bound = rs * 6.5;
        if (dcc < bound && tcc - bound < sceneT) {
            vec3 bent;
            float diskA;
            bool captured;
            vec3 disk = blackHole(rd, at, rs, 2.0, 4.8, 0.55, t, seed, 0, bent, diskA, captured) * 1.5;
            float lens = smoothstep(bound, bound * 0.45, dcc);
            vec3 behind;
            if (captured) {
                behind = vec3(0.0);
            } else {
                float dist = sky ? 300.0 : max(sceneT, tcc + 2.0);
                vec3 pr = project(bent * dist);
                vec2 luv = pr.xy;
                behind = pr.z > 0.0 && luv.x > 0.0 && luv.x < 1.0 && luv.y > 0.0 && luv.y < 1.0
                    ? texture(DiffuseSampler, luv).rgb : c.rgb * 0.5;
            }
            vec3 lensed = disk + (1.0 - diskA) * behind;
            float front = step(tcc - rs * 2.0, sceneT);
            c.rgb = mix(c.rgb, lensed, lens * front);
            c.a = max(c.a, diskA * 0.35 * front);
        }
    }

    // Collapse to a point, then the burst.
    float tp;
    float d = rayPoint(rd, at, tp);
    float squeeze = window2(t, collapse, collapse + 1.0, burst, burst + 0.5);
    if (squeeze > 0.0 && tp < sceneT + 1.0) {
        float core = ink(d, 0.04, tp);
        float a = abs(dot(rd * tp - at, camRight()));
        float b = abs(dot(rd * tp - at, camUp()));
        float flare = ink(a, 0.008, tp) * smoothstep(4.0, 0.0, b) + ink(b, 0.008, tp) * smoothstep(4.0, 0.0, a);
        emit(c, PALE * (core + flare) * squeeze, (core + flare) * squeeze * 0.7);
    }
    float k = (t - burst) / 20.0;
    if (k >= 0.0) {
        starBurst(c, rd, sceneT, at, k * 0.7, 4.5, seed);
        starBurst(c, rd, sceneT, at, k * 0.7 - 0.04, 2.6, seed + 2.0);
        // A shell of light racing out: a ring round the view and one flat round the singularity.
        float rr = 11.0 * (1.0 - pow(1.0 - saturate(k / 0.7), 3.0));
        float shell = ink(abs(d - rr), 0.05, tp) * (1.0 - smoothstep(0.3, 0.8, k));
        emit(c, mix(STARLIGHT, NEB, 0.4) * shell, shell * 0.6);
        float tf = rayPlane(rd, at, vec3(0.0, 1.0, 0.0));
        if (tf > 0.0 && tf < sceneT) {
            float rf = length((rd * tf - at).xz);
            float flat1 = ink(abs(rf - rr * 1.1), 0.08, tf) * (1.0 - smoothstep(0.3, 0.8, k));
            emit(c, PALE * flat1, flat1 * 0.7);
        }
        if (!sky) groundBlow(c, surface, vec3(at.x, groundY, at.z), k, 12.0, seed);
    }
}

// ---------------------------------------------------------------- Event Horizon
// P0 = (3, tick, seed, space 0..1), P1 = (portal, exit portal, sky portal radii, warp 0..1),
// P2 = (KICK, KICK2, IMPACT, grind heat 0..1), P3 = (hole radius, disk in, disk out, flash 0..1).
// Origin = the black hole, Target = target's start (ground), Caster = caster's feet now, Facing = forward.
// Pts[0] portal (w = radius), Pts[1] its normal, Pts[2] exit portal, Pts[3] its normal, Pts[4] sky portal,
// Pts[5] where the target is pressed into the disk (w = spark power), Pts[6] direction of travel,
// Pts[7..18] the scorch trail on the disk, newest first (w = age in ticks, < 0 none), Pts[19] target chest
// (w = heat), Pts[20] space-kick point (w = tick), Pts[21] world-kick point (w = tick).

void warpTunnel(inout vec4 c, vec2 uv, float k, float t, float seed) {
    if (k <= 0.001) return;
    vec2 p = (uv - 0.5) * vec2(OutSize.x / OutSize.y, 1.0);
    float r = length(p);
    float a = atan(p.y, p.x);
    vec3 bg = mix(VOID, INDIGO * 0.8, smoothstep(0.9, 0.0, r));
    bg += NEB_DEEP * 0.5 * (0.5 + 0.5 * sin(a * 3.0 + log(r + 0.01) * 4.0 - t * 0.6)) * smoothstep(0.1, 0.6, r);
    float lines = 0.0;
    vec3 tint = vec3(0.0);
    for (int layer = 0; layer < 2; layer++) {
        float bins = layer == 0 ? 90.0 : 170.0;
        float f = (a / TAU + 0.5) * bins;
        float bin = floor(f);
        float h = hash11(bin * 1.37 + float(layer) * 17.0 + seed);
        float sp = 0.5 + 1.3 * h;
        float s = fract(log(r + 0.001) * 0.7 - t * 0.09 * sp + h * 9.0);
        float along = smoothstep(0.0, 0.03, s) * smoothstep(0.5 + 0.3 * h, 0.05, s);
        float across = abs(fract(f) - 0.5);
        float w = 0.08 + 0.06 * h;
        float l = smoothstep(w, w * 0.4, across) * along * smoothstep(0.05, 0.25, r);
        lines += l;
        tint += mix(STARLIGHT, NEB, step(0.5, h)) * l;
    }
    vec3 col = bg + tint + PALE * smoothstep(0.12, 0.0, r) * 0.9;
    c.rgb = mix(c.rgb, col, k);
    c.a = max(c.a, saturate(lines) * 0.4 * k);
}

// Sparks sprayed back off the point of contact. Each one is worked out once per frame on the CPU (Spk[2i] = tail,
// w = life; Spk[2i + 1] = head, w = brightness) so a pixel only tests segments, and pixels well away from the
// spray skip it altogether.
uniform vec4 Spk[32];

void grindSparks(inout vec4 c, vec3 rd, float sceneT, vec3 at, float power, float count, float t, float seed) {
    if (power <= 0.01) return;
    float tk;
    float dk = rayPoint(rd, at, tk);
    if (dk > 5.6 || tk - 6.0 > sceneT) return;
    int n = int(count + 0.5);
    for (int i = 0; i < 16; i++) {
        if (i >= n) break;
        vec4 a = Spk[i * 2];
        vec4 b = Spk[i * 2 + 1];
        float t2, s2;
        float d2 = raySeg(rd, a.xyz, b.xyz, t2, s2);
        if (t2 <= 0.0 || t2 > sceneT + 0.3) continue;
        float l = ink(d2, 0.02 * (1.0 - a.w) + 0.004, t2) * b.w;
        emit(c, mix(HOT, EMBER, a.w) * l * 1.2, l * 0.5);
    }
    // White-hot contact flash, flickering.
    float flick = 0.7 + 0.3 * hash11(floor(t * 3.0) + seed);
    float core = ink(dk, 0.18 * power * flick, tk);
    emit(c, HOT * core, core * 0.5);
}

void eventHorizon(inout vec4 c, vec2 uv, vec3 rd, float sceneT, vec3 surface, bool sky) {
    float t = P0.y;
    float seed = P0.z;
    float space = P0.w;
    vec3 hole = Origin;
    bool inSpace = space > 0.5 && length(hole) < 260.0;

    if (inSpace && (sky || sceneT > 120.0)) {
        vec4 half1 = texture(HalfSampler, uv);
        vec4 aux = texture(HalfAux, uv);
        float l = length(aux.xyz);
        vec3 stars = l > 0.01 ? starField(aux.xyz / l, seed) : vec3(0.0);
        c.rgb = half1.rgb + (1.0 - saturate(half1.a)) * (1.0 - saturate(aux.w)) * stars;
        c.a = max(c.a, saturate(half1.a) * 0.22);
    } else if (inSpace) {
        // Bodies out in space: lit warm from the disk below, cool from the stars.
        c.rgb = c.rgb * vec3(1.05, 0.9, 1.08) + vec3(0.06, 0.025, 0.0) * smoothstep(0.0, 0.6, lum(c.rgb));
    }

    // The scorched groove left on the disk, newest first.
    // A pixel only walks the scorch trail when it is near the chord from its newest point to its oldest.
    float tch, sch;
    bool nearTrail = Pts[7].w >= 0.0 && raySeg(rd, Pts[7].xyz, Pts[18].xyz, tch, sch) < 3.8;
    if (inSpace) {
        int trail = nearTrail ? 7 + loops(11) : 7;
        for (int i = 7; i < trail; i++) {
            if (Pts[i].w < 0.0 || Pts[i + 1].w < 0.0) continue;
            float age = Pts[i].w;
            float tt, ss;
            float d = raySeg(rd, Pts[i].xyz, Pts[i + 1].xyz, tt, ss);
            if (tt <= 0.0 || tt > sceneT + 0.3) continue;
            float f = 1.0 - saturate(age / 14.0);
            float core = ink(d, 0.07 * f + 0.01, tt);
            float body = ink(d, 0.22 * f + 0.02, tt) - core;
            emit(c, (HOT * core + EMBER * body * 0.8) * f, max(core, body * 0.4) * f);
        }
        grindSparks(c, rd, sceneT, Pts[5].xyz, Pts[5].w, Pts[6].w, t, seed);
        // Friction flames streaming off the target.
        float heat = Pts[19].w;
        if (heat > 0.01) {
            for (int i = 0; i < 4; i++) {
                vec3 h = hash31(float(i) * 5.3 + seed);
                vec3 a = Pts[19].xyz + vec3(h.x - 0.5, (h.y - 0.5) * 1.2, h.z - 0.5) * 0.6;
                float len = 1.5 + 1.5 * h.z * (0.7 + 0.3 * sin(t * 1.3 + float(i)));
                line3(c, rd, sceneT, a, a - Pts[6].xyz * len + vec3(0.0, 0.25, 0.0), 0.09, EMBER, heat);
            }
        }
    }

    // Portals: into space, out of it, and back out of the sky.
    portal(c, rd, sceneT, Pts[0].xyz, normalize(Pts[1].xyz), Pts[0].w, t, seed);
    portal(c, rd, sceneT, Pts[2].xyz, normalize(Pts[3].xyz), Pts[2].w, t, seed + 3.0);
    portal(c, rd, sceneT, Pts[4].xyz, vec3(0.0, -1.0, 0.0), Pts[4].w, t, seed + 5.0);

    // The world kick, the space kick.
    starBurst(c, rd, sceneT, Pts[21].xyz, (t - Pts[21].w) / 20.0, 1.6, seed);
    starBurst(c, rd, sceneT, Pts[20].xyz, (t - Pts[20].w) / 20.0, 2.6, seed + 1.0);

    // The fall home: a pillar of starlight from the sky portal, then the blow.
    float impact = P2.z;
    vec3 skyAt = Pts[4].xyz;
    float k = (t - impact) / 20.0;
    float fall = window2(t, impact - 13.0, impact - 11.0, impact, impact + 3.0);
    if (fall > 0.0) {
        float tt, ss;
        float d = raySeg(rd, Target, skyAt, tt, ss);
        if (tt > 0.0 && tt < sceneT + 1.0) {
            float edge = ink(abs(d - 1.1), 0.03, tt) + ink(abs(d - 0.6), 0.015, tt);
            emit(c, mix(STARLIGHT, NEB, ss) * edge * fall, edge * fall * 0.6);
        }
    }
    if (k >= 0.0) {
        float tt, ss;
        float d = raySeg(rd, Target, Target + vec3(0.0, 40.0, 0.0), tt, ss);
        if (tt > 0.0 && tt < sceneT + 3.0) {
            float w = 3.0 * (1.0 - saturate(k / 0.4));
            float pillar = ink(d, w * 0.3, tt) + (ink(abs(d - w), 0.05, tt));
            emit(c, PALE * pillar * (1.0 - smoothstep(0.1, 0.45, k)), pillar * (1.0 - smoothstep(0.1, 0.45, k)));
        }
        starBurst(c, rd, sceneT, Target + vec3(0.0, 1.0, 0.0), k * 0.5, 6.0, seed + 7.0);
        if (!sky) groundBlow(c, surface, Target, k, 20.0, seed);
    }

    if (inSpace) {
        warpTunnel(c, uv, P1.w, t, seed);
        c.rgb = mix(c.rgb, PALE, P3.w);
    }
}

// Mode 4: deep space alone at half resolution (see HalfSampler).
void spaceHalf(vec2 uv) {
    vec3 rd = viewDir(uv);
    vec3 bent;
    float diskA;
    bool captured;
    vec3 col = blackHole(rd, Origin, P3.x, P3.y, P3.z, 1.0, P0.y, P0.z, 2, bent, diskA, captured);
    fragColor = vec4(col, diskA);
    fragAux = vec4(normalize(bent), captured ? 1.0 : 0.0);
}

void main() {
    vec2 uv = texCoord;
    initPixel(uv);
    if (int(P0.x + 0.5) == 4) {
        spaceHalf(uv);
        return;
    }
    fragAux = vec4(0.0);
    vec4 c = baseColor(uv);
    vec3 rd = viewDir(uv);
    float sceneT = sceneDist(uv);
    bool sky = sceneT >= FAR;
    vec3 surface = sky ? vec3(0.0) : rd * sceneT;
    int mode = int(P0.x + 0.5);
    if (mode == 1) {
        cometLance(c, rd, sceneT, surface, sky);
    } else if (mode == 2) {
        gravityWell(c, uv, rd, sceneT, surface, sky);
    } else if (mode == 3) {
        eventHorizon(c, uv, rd, sceneT, surface, sky);
    }
    fragColor = c;
}
