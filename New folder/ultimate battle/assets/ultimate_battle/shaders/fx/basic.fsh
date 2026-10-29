// Basic attacks (the left click). P0.x picks the style's look: 1 Blade, 2 Martial, 3 Ki, 4 Shadow, 5 Thunder,
// 6 Mirage, 7 Celestial, 8 Cosmic, 9 Abyss, 10 Cipher, 11 Lancer, 12 Rift;
// P0.y is the pass alpha.
// Strokes: Pts[0 .. P1.x) are polyline points (camera-relative xyz, w = radius; w 0 lifts the pen, a negative w
// draws the style's light variant). Ring: centre P2.xyz, radius P2.w, normal P3.xyz, alpha P3.w, half-width P1.y.
// Orb (Ki): centre Target, radius P1.z (0 = none), alpha P1.w. Cosmic (mode 8) draws only its void sphere, below. Everything stays thin and crisp, the glow narrow.
// Rift (mode 12): negative-radius strokes are cuts in space (see rent below); the ring slot is the impact's shear
// (centre P2.xyz, radius P2.w, cut direction P3.xyz, strength P3.w); P0.w tears from rift_tear.glsl sit at the end of
// Pts as pairs from Pts[22]: (centre, radius) then (facing, seed).
// Cosmic (8): P0.w warps sit at the end of Pts the same way: (from, radius) then (to, strength) - the
// picture round the segment is pushed outward (strength > 0, air driven aside) or pulled in (< 0, space pinched).

#include "rift_tear.glsl"

const vec3 WHITE = vec3(1.0);

vec3 rimOf(int mode) {
    if (mode == 1) return vec3(1.0, 0.13, 0.24);
    if (mode == 2) return vec3(1.0, 0.54, 0.16);
    if (mode == 3) return vec3(0.27, 0.76, 1.0);
    if (mode == 4) return vec3(0.63, 0.44, 1.0);
    if (mode == 6) return vec3(0.36, 0.95, 0.78);
    if (mode == 7) return vec3(1.0, 0.79, 0.29);
    if (mode == 9) return vec3(0.69, 0.15, 1.0);
    if (mode == 10) return vec3(1.0, 0.16, 0.23);
    if (mode == 11) return vec3(0.31, 0.48, 1.0);
    if (mode == 12) return vec3(0.24, 0.94, 0.71);
    return mix(vec3(1.0, 0.88, 0.29), vec3(0.51, 0.82, 1.0), 0.35);
}

vec3 coreOf(int mode) {
    if (mode == 2) return vec3(1.0, 0.96, 0.85);
    if (mode == 4) return vec3(0.92, 0.84, 1.0);
    if (mode == 6) return vec3(0.91, 1.0, 0.96);
    if (mode == 7) return vec3(1.0, 0.97, 0.86);
    if (mode == 9) return vec3(0.89, 0.76, 1.0);
    if (mode == 11) return vec3(0.9, 0.93, 1.0);
    if (mode == 12) return vec3(0.86, 1.0, 0.95);
    return WHITE;
}

void strokes(inout vec4 c, vec3 rd, float sceneT, int mode, float alpha) {
    int n = int(P1.x + 0.5);
    float core = 0.0;
    float glow = 0.0;
    float dark = 0.0;
    float edge = 0.0;
    // Rift's cuts: how far inside one this pixel is, where along it, and the lip, halo and crackle round it.
    float rent = 0.0;
    float rentU = 0.0;
    float rentDepth = 0.0;
    float rentLip = 0.0;
    float rentHalo = 0.0;
    float crackle = 0.0;
    float ticks = GTime * 20.0;
    for (int i = 0; i < 23; i++) {
        if (i + 1 >= n) break;
        vec4 a = Pts[i];
        vec4 b = Pts[i + 1];
        if (a.w == 0.0 || b.w == 0.0) continue;
        float t, s;
        float d = raySeg(rd, a.xyz, b.xyz, t, s);
        if (t <= 0.0 || t > sceneT + 0.3) continue;
        float r = mix(abs(a.w), abs(b.w), s);
        if (mode == 12 && a.w < 0.0) {
            // A cut in space: a torn edge, sharp zigzags along its length, never a smooth tube.
            float u = float(i) + s;
            float zig = abs(fract(u * 1.7 + P0.z * 0.13) - 0.5) * 2.0;
            float zig2 = abs(fract(u * 4.3 + P0.z * 0.29) - 0.5) * 2.0;
            float rj = r * (1.0 - 0.3 * zig - 0.14 * zig2);
            float inside = ink(d, rj, t);
            if (inside > rent) {
                rent = inside;
                rentU = u;
                rentDepth = saturate(1.0 - d / max(rj, 1e-4));
            }
            float off = abs(d - rj);
            rentLip = max(rentLip, ink(off, 0.004 + rj * 0.1, t));
            rentHalo = max(rentHalo, ink(off, 0.012 + rj * 0.45, t));
            // Thin arcs crackling just off the edge, a few at a time, jumping about.
            float live = step(0.55, hash11(floor(ticks * 0.5) * 1.3 + floor(u * 2.5) + P0.z));
            float jag = 0.3 * sin(u * 37.0 + ticks * 3.0) + 0.2 * sin(u * 71.0 - ticks * 4.0);
            crackle = max(crackle, ink(abs(d - rj * (1.3 + jag)), 0.0035, t) * live * step(0.01, rj));
            continue;
        }
        if (mode == 4 && a.w > 0.0) {
            // Shadow's marks and Rift's tears are dark, painted with a thin coloured edge - no light of their own.
            dark = max(dark, ink(d, r, t));
            edge = max(edge, ink(d, r + 0.012, t));
        } else {
            core = max(core, ink(d, r, t));
            glow = max(glow, exp(-d / max(r * 2.0, 0.004)) * 0.28 * saturate(r / 0.012));
        }
    }
    vec3 rim = rimOf(mode);
    if (rent > 0.0 || rentHalo > 0.0 || crackle > 0.0) {
        // Through the cut: a violet-black void, deeper toward its middle, specks of light streaming into it.
        vec3 inside = mix(vec3(0.08, 0.02, 0.15), vec3(0.0, 0.0, 0.012), rentDepth);
        for (int k = 0; k < 2; k++) {
            float fk = float(k);
            float rr = fract(rentDepth * 1.4 + ticks * (0.09 + 0.04 * fk) + fk * 0.37);
            vec2 cell = vec2(floor(rentU * (9.0 + 5.0 * fk) + fk * 3.0), floor(rr * 3.0));
            float on = step(0.72, hash12(cell + P0.z + fk * 11.0)) * smoothstep(0.0, 0.3, fract(rr * 3.0))
                * (1.0 - smoothstep(0.55, 1.0, fract(rr * 3.0)));
            inside += mix(VIOLET, TEAL, step(0.5, hash12(cell + 3.0))) * on * (0.4 + 0.7 * rentDepth);
        }
        solid(c, inside, rent * alpha);
        float lip = saturate(rentLip - rent * 0.6);
        float halo = saturate(rentHalo - rentLip - rent);
        vec3 col = mix(TEAL, PALE, 0.35) * lip + VIOLET * halo * 0.55 + mix(PALE, TEAL, 0.3) * crackle;
        emit(c, col * alpha, saturate(lip * 0.7 + halo * 0.25 + crackle * 0.6) * alpha);
    }
    if (dark > 0.0 || edge > 0.0) {
        paint(c, vec3(0.04, 0.015, 0.07), dark * 0.95 * alpha);
        float e = saturate(edge - dark) * alpha;
        c.rgb = mix(c.rgb, rim, e * 0.85);
    }
    if (core > 0.0 || glow > 0.0) {
        emit(c, (coreOf(mode) * core + rim * glow) * alpha, (core * 0.6 + glow * 0.3) * alpha);
    }
}

void ring(inout vec4 c, vec3 rd, float sceneT, int mode, float alpha) {
    if (P3.w <= 0.001 || P2.w <= 0.0) return;
    vec3 nrm = normalize(P3.xyz);
    float tp = rayPlane(rd, P2.xyz, nrm);
    if (tp <= 0.0 || tp > sceneT + 0.3) return;
    float d = abs(length(rd * tp - P2.xyz) - P2.w);
    float a = P3.w * alpha;
    float core = ink(d, P1.y, tp);
    float glow = exp(-d / max(P1.y * 2.5, 0.004)) * 0.25;
    emit(c, (coreOf(mode) * core + rimOf(mode) * glow) * a, (core * 0.6 + glow * 0.3) * a);
}

void orb(inout vec4 c, vec3 rd, float sceneT, float alpha) {
    if (P1.z <= 0.0 || P1.w <= 0.001) return;
    float tp;
    float d = rayPoint(rd, Target, tp);
    if (tp <= 0.0 || tp > sceneT + P1.z) return;
    float i = saturate(1.0 - d / P1.z);
    i = sqrt(i);
    vec3 col = cel(i, WHITE, vec3(0.55, 0.88, 1.0), vec3(0.1, 0.45, 0.95));
    float m = celMask(i) * P1.w * alpha;
    paint(c, col, m);
    emit(c, col * 0.25 * m, m);
}

// ---------------------------------------------------------------- Cosmic (mode 8)
// A Cosmic shot is a tiny dark void sphere (orb slot: Target, P1.z radius, P1.w alpha) with a hairline rim, nebula
// below and starlight above, and a pinpoint of light inside. No glow, no trail, no burst. Its hit bends space: one
// wave of refraction runs out from the spot (ring slot: centre P2.xyz, radius P2.w, strength P3.w) - the scene
// behind it is pushed outward along the wave, so nothing lights up, the world itself ripples.

const vec3 C_NEB = vec3(1.0, 0.31, 0.85);
const vec3 C_STAR = vec3(0.56, 0.91, 1.0);
const vec3 C_PALE = vec3(1.0, 0.97, 1.0);
const vec3 C_VOID = vec3(0.01, 0.007, 0.028);
const vec3 C_INDIGO = vec3(0.14, 0.07, 0.38);

// Darkens without raising the glow mask: the void is not a light.
void shade(inout vec4 c, vec3 col, float a) {
    c.rgb = mix(c.rgb, col, saturate(a));
}

void spaceRipple(inout vec4 c, vec2 uv, float alpha) {
    if (P3.w <= 0.001 || P2.w <= 0.0) return;
    vec3 centre = project(P2.xyz);
    if (centre.z <= 0.05) return;
    vec3 right = normalize((InvView * vec4(1.0, 0.0, 0.0, 0.0)).xyz);
    vec3 edge = project(P2.xyz + right * P2.w);
    vec2 aspect = vec2(OutSize.x / OutSize.y, 1.0);
    float rs = length((edge.xy - centre.xy) * aspect);
    vec2 dv = (uv - centre.xy) * aspect;
    float d = length(dv);
    if (d < 1e-4) return;
    float width = max(rs * 0.22, 0.006);
    float x = (d - rs) / width;
    // One crest pushing outward with a trough just inside it, so the bend reads as a wave, not a blur.
    float wave = exp(-x * x) * x;
    float amp = 0.11 * P3.w * alpha * saturate(rs * 12.0);
    vec2 offset = dv / d * wave * amp / aspect;
    // Light bent by gravity splits a little along the wave: a faint colour fringe, no light added.
    c.r = texture(DiffuseSampler, uv - offset * 1.15).r;
    c.g = texture(DiffuseSampler, uv - offset).g;
    c.b = texture(DiffuseSampler, uv - offset * 0.85).b;
}

// The warps (see the header): no light added, only the scene behind pushed aside or drawn in, with a faint colour split
// on Cosmic's (light bent by gravity).
void warps(inout vec4 c, vec2 uv, int mode, float alpha) {
    int n = int(P0.w + 0.5);
    if (n <= 0) return;
    vec2 aspect = vec2(OutSize.x / OutSize.y, 1.0);
    vec3 right = normalize((InvView * vec4(1.0, 0.0, 0.0, 0.0)).xyz);
    vec2 p = uv * aspect;
    vec2 total = vec2(0.0);
    for (int k = 0; k < 3; k++) {
        if (k >= n) break;
        vec4 a = Pts[22 - 2 * k];
        vec4 b = Pts[23 - 2 * k];
        if (a.w <= 0.0 || abs(b.w) < 0.001) continue;
        // Never right at the camera: a warp there would smear the whole view.
        float near = smoothstep(1.0, 2.2, min(length(a.xyz), length(b.xyz)));
        vec3 pa = project(a.xyz);
        vec3 pb = project(b.xyz);
        if (pa.z <= 0.05 || pb.z <= 0.05 || near <= 0.0) continue;
        float rs = length((project(a.xyz + right * a.w).xy - pa.xy) * aspect);
        vec2 A = pa.xy * aspect;
        vec2 B = pb.xy * aspect;
        vec2 ab = B - A;
        float s = dot(ab, ab) < 1e-10 ? 0.0 : saturate(dot(p - A, ab) / dot(ab, ab));
        vec2 dv = p - (A + ab * s);
        float d = length(dv);
        // A cone along a segment (widest at its end), a round lens at a point.
        float r = rs * (dot(ab, ab) < 1e-10 ? 1.0 : mix(0.3, 1.0, s));
        float x = d / max(r, 1e-5);
        if (x >= 1.0 || d < 1e-6) continue;
        float shape = x * (1.0 - x) * (1.0 - x) * 6.75;
        total += dv / d * shape * r * 0.35 * b.w * near;
    }
    if (dot(total, total) < 1e-12) return;
    vec2 off = total * alpha / aspect;
    if (mode == 8) {
        c.r = texture(DiffuseSampler, uv - off * 1.12).r;
        c.g = texture(DiffuseSampler, uv - off).g;
        c.b = texture(DiffuseSampler, uv - off * 0.88).b;
    } else {
        c.rgb = texture(DiffuseSampler, uv - off).rgb;
    }
}

// Light passing a Cosmic shot bends round it: the scene just outside the sphere is drawn from nearer its middle, the
// way a mass lenses what is behind it - a thin ring of the world wrapped round the void.
void cosmicLens(inout vec4 c, vec2 uv, float alpha) {
    float dist = length(Target);
    if (dist < 1.4) return;
    vec3 cc = project(Target);
    if (cc.z <= 0.05) return;
    vec2 aspect = vec2(OutSize.x / OutSize.y, 1.0);
    vec3 right = normalize((InvView * vec4(1.0, 0.0, 0.0, 0.0)).xyz);
    float rs = length((project(Target + right * P1.z).xy - cc.xy) * aspect);
    vec2 dv = (uv - cc.xy) * aspect;
    float d = length(dv);
    float reach = rs * 4.0;
    if (d >= reach || d < 1e-6 || rs < 1e-5) return;
    float bend = rs * rs * 1.5 / d * (1.0 - smoothstep(rs * 1.6, reach, d)) * P1.w * alpha * smoothstep(1.4, 2.4, dist);
    vec2 src = dv / d * max(d - bend, 0.0);
    vec2 suv = cc.xy + src / aspect;
    vec2 fringe = (suv - uv) * 0.08;
    c.r = texture(DiffuseSampler, suv + fringe).r;
    c.g = texture(DiffuseSampler, suv).g;
    c.b = texture(DiffuseSampler, suv - fringe).b;
}

void cosmicBasic(inout vec4 c, vec2 uv, vec3 rd, float sceneT, float alpha) {
    warps(c, uv, 8, alpha);
    spaceRipple(c, uv, alpha);
    if (P1.z <= 0.0 || P1.w <= 0.001) return;
    cosmicLens(c, uv, alpha);
    vec3 right = normalize((InvView * vec4(1.0, 0.0, 0.0, 0.0)).xyz);
    vec3 up = normalize((InvView * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
    float tp;
    float d = rayPoint(rd, Target, tp);
    if (tp <= 0.0 || tp > sceneT + P1.z) return;
    float a = P1.w * alpha;
    float inside = 1.0 - smoothstep(P1.z - gPix * tp, P1.z, d);
    shade(c, mix(C_VOID, C_INDIGO, 0.5 * smoothstep(0.3 * P1.z, P1.z, d)), inside * a);
    vec3 q = rd * tp - Target;
    float side = dot(normalize(q + 1e-5), up) * 0.5 + 0.5;
    float rim = ink(abs(d - P1.z), 0.006 + P1.z * 0.06, tp);
    emit(c, mix(C_NEB, C_STAR, side) * rim * a, rim * a * 0.5);
    float pin = ink(length(q - (up - right) * P1.z * 0.3), P1.z * 0.07, tp);
    emit(c, C_PALE * pin * a, pin * a * 0.4);
}

// ---------------------------------------------------------------- Rift (mode 12)
// A Rift blow shears space: along the line of the cut, the picture on one side slides one way and the other side the
// other way, as if the world were cut through and knocked out of line for an instant, with a hairline void seam
// along the cut. No light is added; it is the scene itself that splits.
void riftShear(inout vec4 c, vec2 uv, float alpha) {
    if (P3.w <= 0.001 || P2.w <= 0.0) return;
    vec3 centre = project(P2.xyz);
    if (centre.z <= 0.05) return;
    vec2 aspect = vec2(OutSize.x / OutSize.y, 1.0);
    vec3 tip = project(P2.xyz + normalize(P3.xyz) * 0.5);
    vec2 line = (tip.xy - centre.xy) * aspect;
    if (dot(line, line) < 1e-8) return;
    line = normalize(line);
    vec2 across = vec2(-line.y, line.x);
    vec3 right = normalize((InvView * vec4(1.0, 0.0, 0.0, 0.0)).xyz);
    float rs = length((project(P2.xyz + right * P2.w).xy - centre.xy) * aspect);
    if (rs < 1e-4) return;
    vec2 dv = (uv - centre.xy) * aspect;
    float a = dot(dv, line) / (rs * 1.5);
    float b = dot(dv, across) / rs;
    if (abs(a) > 1.0 || abs(b) > 1.0) return;
    // Strongest on the cut and in its middle, gone at its ends and a radius away from it.
    float reach = (1.0 - a * a) * (1.0 - smoothstep(0.0, 1.0, abs(b)));
    float s = P3.w * alpha;
    vec2 offset = line * sign(b) * reach * rs * 0.32 * s / aspect;
    c.rgb = texture(DiffuseSampler, uv - offset).rgb;
    // The seam itself: a sliver of void with a teal lip, pointed at both ends.
    float px = 1.0 / OutSize.y;
    float w = (1.2 + 3.5 * s) * px * sqrt(max(1.0 - a * a, 0.0));
    float dist = abs(b) * rs;
    float seam = 1.0 - smoothstep(w, w + px, dist);
    float lip = (1.0 - smoothstep(w + px, w + 2.0 * px, dist)) - seam;
    solid(c, vec3(0.03, 0.0, 0.07), seam * saturate(s * 1.5));
    emit(c, mix(TEAL, PALE, 0.4) * lip * saturate(s * 1.5), lip * saturate(s * 1.5) * 0.5);
}

void riftBasic(inout vec4 c, vec2 uv, vec3 rd, float sceneT, float alpha) {
    riftShear(c, uv, alpha);
    strokes(c, rd, sceneT, 12, alpha);
    int tears = int(P0.w + 0.5);
    for (int k = 0; k < 3; k++) {
        if (k >= tears) break;
        vec4 a = Pts[22 - 2 * k];
        vec4 b = Pts[23 - 2 * k];
        if (a.w > 0.02) {
            riftTear(c, rd, sceneT, a.xyz, normalize(b.xyz), a.w, GTime * 20.0, b.w);
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
    float alpha = P0.y;
    if (mode == 8) {
        cosmicBasic(c, uv, rd, sceneT, alpha);
    } else if (mode == 12) {
        riftBasic(c, uv, rd, sceneT, alpha);
    } else {
        strokes(c, rd, sceneT, mode, alpha);
        ring(c, rd, sceneT, mode, alpha);
        orb(c, rd, sceneT, alpha);
    }
    fragColor = c;
}
