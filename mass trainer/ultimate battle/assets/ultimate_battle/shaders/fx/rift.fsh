// Rift effects. P0.x picks the skill: 1 Blink Gate, 3 Three Realms, 4 Three Realms' realm alone at half resolution
// (into HalfSampler / HalfAux, read back by mode 3), 5 Rift Ricochet.
// Everything is drawn with the game's own textures: portals torn open like Cosmic's (wobbling rim, vortex, broken
// rings, sparks) with the nether portal's animated texture or vanilla's end portal effect inside; and the two realms of Three Realms traced block by block through snapshots of real vanilla
// terrain (RealmVolume: a Nether lava ocean, the End's main island and spikes), textured from the block atlas per
// face, shaded per face with ambient occlusion and lit through vanilla's light curve, under Nether fog or the End sky.
// Lava, magma and the nether portal are animated from their own strips the way their .mcmeta runs them.
// Pts holds the portals as pairs: (centre, size - 0 when shut) then (facing, kind: 0 nether, 1 end, 2 gateway).

uniform sampler2D BlockAtlas;
uniform sampler2D EndSky;
uniform sampler2D EndPortalTex;
uniform sampler2D LavaTex;
uniform sampler2D MagmaTex;
uniform sampler2D PortalTex;
uniform sampler2D HalfSampler;
uniform sampler2D HalfAux;
uniform sampler3D Volume;
uniform sampler3D LightVol;
uniform vec4 Sprites[96];
uniform vec4 Flags[32];
uniform vec3 VolCorner;
uniform vec4 VolSize;
uniform float AtlasMips;
out vec4 fragAux;

#include "rift_tear.glsl"
const vec3 NETHER_FOG = vec3(0.2, 0.031, 0.031);
const float MISS = 10000.0;

const int B_AIR = 0;

float window2(float t, float in0, float in1, float out0, float out1) {
    return saturate((t - in0) / max(in1 - in0, 0.001)) * (1.0 - saturate((t - out0) / max(out1 - out0, 0.001)));
}

vec3 camRight() { return normalize((InvView * vec4(1.0, 0.0, 0.0, 0.0)).xyz); }
vec3 camUp() { return normalize((InvView * vec4(0.0, 1.0, 0.0, 0.0)).xyz); }

void planeAxes(vec3 n, out vec3 u, out vec3 v) {
    vec3 h = cross(n, vec3(0.0, 1.0, 0.0));
    u = dot(h, h) < 1e-6 ? vec3(1.0, 0.0, 0.0) : normalize(h);
    v = normalize(cross(n, u));
}

// ---------------------------------------------------------------- the game's textures

// A texel of an animated strip (16 px frames stacked), frame by frame.
vec4 stripTex(sampler2D tex, int frame, vec2 uv) {
    ivec2 size = textureSize(tex, 0);
    int w = size.x;
    int frames = max(size.y / w, 1);
    ivec2 p = clamp(ivec2(floor(fract(uv) * float(w))), ivec2(0), ivec2(w - 1));
    return texelFetch(tex, ivec2(p.x, (frame % frames) * w + p.y), 0);
}

// The current look of an animated block: lava runs frames 0-19 and back, two ticks each; magma blends its three
// frames over eight ticks each.
vec4 animTex(int kind, vec2 uv) {
    float ticks = GTime * 20.0;
    if (kind == 1) {
        int step = int(mod(floor(ticks / 2.0), 38.0));
        return stripTex(LavaTex, step < 20 ? step : 38 - step, uv);
    }
    float f = mod(ticks / 8.0, 3.0);
    int a = int(floor(f));
    return mix(stripTex(MagmaTex, a, uv), stripTex(MagmaTex, (a + 1) % 3, uv), fract(f));
}

// A texel of a realm block's face (0 top, 1 side, 2 bottom) from the atlas: uv in blocks (the sprite repeats every
// block, top row up), at the mip level matching how many texels fall in a pixel at ray distance t.
vec4 blockTex(int id, int face, vec2 uv, float t) {
    int anim = int(Flags[id].x + 0.5);
    if (anim > 0) return animTex(anim, uv);
    vec4 s = Sprites[id * 3 + face];
    float texels = gPix * t * s.z;
    int lod = int(clamp(floor(log2(max(texels, 1.0))), 0.0, AtlasMips));
    ivec2 size = max(ivec2(s.zw) >> lod, ivec2(1));
    ivec2 p = ivec2(floor(fract(uv) * vec2(size)));
    p = clamp(p, ivec2(0), size - 1);
    return texelFetch(BlockAtlas, (ivec2(s.xy) >> lod) + p, lod);
}

vec3 repeatTex(sampler2D tex, vec2 uv) {
    ivec2 size = textureSize(tex, 0);
    ivec2 p = ivec2(floor(fract(uv) * vec2(size)));
    return texelFetch(tex, clamp(p, ivec2(0), size - 1), 0).rgb;
}

// Vanilla's End sky: the end_sky texture tiled sixteen times over each face of a cube, darkened to 40/255.
vec3 endSky(vec3 rd) {
    vec3 a = abs(rd);
    vec2 uv = a.y >= a.x && a.y >= a.z ? rd.xz / a.y : a.x >= a.z ? rd.zy / a.x : rd.xy / a.z;
    return repeatTex(EndSky, (uv * 0.5 + 0.5) * 16.0) * (40.0 / 255.0);
}

// Vanilla's end portal effect: the End sky layer plus drifting, turning layers of the end_portal texture in screen
// space, each tinted its own deep teal or blue.
const vec3 END_COLORS[16] = vec3[](
    vec3(0.022087, 0.098399, 0.110818), vec3(0.011892, 0.095924, 0.089485), vec3(0.027636, 0.101689, 0.100326),
    vec3(0.046564, 0.109883, 0.114838), vec3(0.064901, 0.117696, 0.097189), vec3(0.063761, 0.086895, 0.123646),
    vec3(0.084817, 0.111994, 0.166380), vec3(0.097489, 0.154120, 0.091064), vec3(0.106152, 0.131144, 0.195191),
    vec3(0.097721, 0.110188, 0.187229), vec3(0.133516, 0.138278, 0.148582), vec3(0.070006, 0.243332, 0.235792),
    vec3(0.196766, 0.142899, 0.214696), vec3(0.047281, 0.315338, 0.321970), vec3(0.204675, 0.390010, 0.302066),
    vec3(0.080955, 0.314821, 0.661491));

vec3 endPortal(vec2 uv, int layers) {
    float gameTime = mod(GTime * 20.0, 24000.0) / 24000.0;
    vec3 color = repeatTex(EndSky, uv * 0.5 + 0.25) * END_COLORS[0];
    for (int i = 0; i < 16; i++) {
        if (i >= layers) break;
        float layer = float(i + 1);
        vec2 p = uv * 0.5 + 0.25;
        p += vec2(17.0 / layer, (2.0 + layer / 1.5) * (gameTime * 1.5));
        p = rot(radians((layer * layer * 4321.0 + layer * 9.0) * 2.0)) * p * ((4.5 - layer / 4.0) * 2.0);
        color += repeatTex(EndPortalTex, p) * END_COLORS[i];
    }
    return color;
}

// ---------------------------------------------------------------- portals

// A portal torn open, in the manner of Cosmic's: a disc with a still, uneven crisp rim (it must not sway), its
// membrane (the nether portal's own animated swirl, or vanilla's end portal effect) turning deeper toward the middle
// with a vortex in it, a glow round the rim, two broken rings slowly turning round it and a few small sparks drifting
// off. A gateway is the same disc always facing the camera, with no beam.
void drawPortal(inout vec4 c, vec2 suv, vec3 rd, float sceneT, vec4 a, vec4 b, float t, float seed) {
    float radius = a.w;
    if (radius < 0.02) return;
    float kind = b.w;
    if (kind > 2.5) {
        riftTear(c, rd, sceneT, a.xyz, normalize(b.xyz), radius, t, seed);
        return;
    }
    vec3 n = kind > 1.5 ? -rd : normalize(b.xyz);
    float facing = abs(dot(rd, n));
    float tp = rayPlane(rd, a.xyz, n);
    if (tp <= 0.0 || tp > sceneT + 0.2) return;
    vec3 q = rd * tp - a.xyz;
    float r = length(q);
    if (r > radius * 1.6) return;
    vec3 u = normalize(abs(n.y) > 0.95 ? cross(n, vec3(1.0, 0.0, 0.0)) : cross(n, vec3(0.0, 1.0, 0.0)));
    vec3 w = cross(n, u);
    vec2 p = vec2(dot(q, u), dot(q, w));
    float ang = atan(p.y, p.x);
    float re = radius * (1.0 + 0.06 * sin(ang * 5.0 + seed) + 0.04 * sin(ang * 11.0 + seed * 1.7));
    float fade = smoothstep(0.04, 0.22, facing);
    float aa = gPix * tp;
    bool nether = kind < 0.5;
    vec3 glow = nether ? VIOLET : TEAL;
    vec3 glow2 = nether ? vec3(1.0, 0.55, 0.95) : vec3(0.7, 0.85, 1.0);
    if (r < re && tp < sceneT) {
        vec3 inside;
        if (nether) {
            // A flat sheet of the nether portal's own animated texture - no hole, no depth.
            inside = stripTex(PortalTex, int(mod(GTime * 20.0, 32.0)), p * vec2(1.0, -1.0)).rgb * 1.1;
        } else {
            float depth = 1.0 - r / re;
            inside = endPortal(suv, 15) * 1.5;
            float vort = abs(fract((ang + log(r / radius + 0.05) * 1.8 - t * 0.09) * 4.0 / TAU) - 0.5);
            inside += glow * smoothstep(0.08, 0.0, vort) * (0.25 + 0.5 * depth) * smoothstep(0.0, 0.3, r / re);
            inside = mix(inside, vec3(0.0), smoothstep(0.35, 0.0, r / re) * 0.5);
        }
        solid(c, inside, smoothstep(re, re - aa * 1.5, r) * fade);
        c.a = max(c.a, 0.15 * fade);
    }
    float rim = ink(abs(r - re), 0.05 * radius / 2.6 + 0.01, tp);
    float glowRim = ink(abs(r - re), 0.12 * radius / 2.6, tp) - rim;
    float a1 = step(0.4, fract((ang + t * 0.03) * 5.0 / TAU));
    float a2 = step(0.55, fract((-ang + t * 0.02) * 3.0 / TAU));
    float ring1 = ink(abs(r - re * 1.1), 0.02 * radius / 2.6 + 0.004, tp) * a1;
    float ring2 = ink(abs(r - re * 1.22), 0.014 * radius / 2.6 + 0.003, tp) * a2;
    // Small sparks drifting off the rim.
    float sparks = 0.0;
    if (r > re * 0.9) {
        for (int k = 0; k < 10; k++) {
            float fk = float(k);
            float life = fract(t * (0.03 + 0.01 * hash11(fk + seed)) + hash11(fk * 7.1 + seed));
            float sa = hash11(fk * 3.7 + seed) * TAU + life * 0.5;
            vec2 at = vec2(cos(sa), sin(sa)) * radius * (1.04 + 0.5 * life);
            sparks = max(sparks, ink(length(p - at), 0.035 * radius / 2.6 + 0.008, tp) * (1.0 - life));
        }
    }
    vec3 col = PALE * rim + glow * glowRim * 0.8 + glow * ring1 + glow2 * ring2 + mix(glow, PALE, 0.6) * sparks;
    emit(c, col * fade, saturate(rim + ring1 * 0.6 + ring2 * 0.5 + sparks) * fade * 0.7);
}

void portals(inout vec4 c, vec2 suv, vec3 rd, float sceneT, int count, float t) {
    for (int i = 0; i < 12; i++) {
        if (i >= count) break;
        drawPortal(c, suv, rd, sceneT, Pts[i * 2], Pts[i * 2 + 1], t, float(i) * 3.1);
    }
}

// Rift Ricochet's trail: the last ticks of the target's path (Pts[14..17], w = strength), a thin crisp streak - teal
// at the target, violet and thinner behind it.
void ricochetTrail(inout vec4 c, vec3 rd, float sceneT) {
    for (int i = 0; i < 3; i++) {
        vec4 a = Pts[14 + i];
        vec4 b = Pts[15 + i];
        float k = min(a.w, b.w);
        if (k < 0.01) continue;
        float tt, s;
        float d = raySeg(rd, a.xyz, b.xyz, tt, s);
        if (tt <= 0.05 || tt > sceneT + 0.3) continue;
        float along = (float(i) + s) / 3.0;
        float near = smoothstep(1.4, 3.0, tt);
        float w = mix(0.012, 0.075, along);
        float line = ink(d, w, tt) * smoothstep(0.0, 0.35, along) * k * near;
        float core = ink(d, w * 0.35, tt) * along * k * near;
        emit(c, mix(VIOLET, TEAL, along) * line + PALE * core, saturate(line * 0.8 + core));
    }
}

// A violet hit: a ring with four spikes, camera-facing. k in seconds.
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
    emit(c, PALE * (ring + spike) + VIOLET * flash, saturate(ring + spike + flash));
}

void ringFlat(inout vec4 c, vec3 rd, float sceneT, vec3 center, vec3 n, float radius, float width, vec3 col, float alpha) {
    if (alpha <= 0.001 || radius <= 0.0) return;
    float tp = rayPlane(rd, center, n);
    if (tp <= 0.05 || tp > sceneT + 0.3) return;
    alpha *= smoothstep(0.04, 0.25, abs(dot(rd, n)));
    float l = ink(abs(length(rd * tp - center) - radius), width, tp) * alpha;
    emit(c, col * l, l);
}

// ---------------------------------------------------------------- the realms' blocks

int cellId(vec4 v) { return int(v.r * 255.0 + 0.5); }

float safeInv(float x) {
    return 1.0 / (abs(x) < 1e-6 ? (x < 0.0 ? -1e-6 : 1e-6) : x);
}

bool inGrid(ivec3 c, ivec3 size) {
    return all(greaterThanEqual(c, ivec3(0))) && all(lessThan(c, size));
}

bool solidAt(ivec3 c, ivec3 size) {
    if (!inGrid(c, size)) return false;
    int id = cellId(texelFetch(Volume, c, 0));
    return id != B_AIR && Flags[id].w < 0.5;
}

// The texel of the last wall torch traceBlocks hit.
vec4 gTorchTex = vec4(0.0);

// A wall torch (vanilla's template_torch_wall: a 2x10 px stick leaning 22.5 degrees off the block behind it, turned
// by its facing) in cell c along the ray: the ray distance, or -1 when it passes by.
float torchHit(vec3 ro, vec3 rd, ivec3 c, int id, float t) {
    int facing = int(Flags[id].w + 0.5);
    vec2 f = facing == 1 ? vec2(1.0, 0.0) : facing == 2 ? vec2(0.0, 1.0) : facing == 3 ? vec2(-1.0, 0.0) : vec2(0.0, -1.0);
    vec2 g = vec2(-f.y, f.x);
    // Into the model's pixels: x out from the wall, z across, y up, then undo the lean round (0, 3.5).
    vec3 o = ro - (vec3(c) + 0.5);
    vec3 mo = vec3(dot(o.xz, f) * 16.0 + 8.0, o.y * 16.0, dot(o.xz, g) * 16.0 + 8.0);
    vec3 md = vec3(dot(rd.xz, f), rd.y, dot(rd.xz, g)) * 16.0;
    const float CS = 0.92388;
    const float SN = 0.38268;
    mo.y -= 3.5;
    mo.xy = vec2(mo.x * CS - mo.y * SN, mo.x * SN + mo.y * CS);
    md.xy = vec2(md.x * CS - md.y * SN, md.x * SN + md.y * CS);
    mo.y += 3.5;
    vec3 inv = vec3(safeInv(md.x), safeInv(md.y), safeInv(md.z));
    vec3 a = (vec3(-1.0, 3.5, 7.0) - mo) * inv;
    vec3 b = (vec3(1.0, 13.5, 9.0) - mo) * inv;
    vec3 lo = min(a, b);
    vec3 hi = max(a, b);
    float tn = max(max(lo.x, lo.y), lo.z);
    float tf = min(min(hi.x, hi.y), hi.z);
    if (tf < max(tn, 0.0)) return -1.0;
    vec3 p = mo + md * tn;
    // Its faces' uv (pixels): the sides show the stick (7-9, 6-16), the top its flame, the bottom 7-9, 13-15.
    vec2 uv = tn == lo.y
        ? vec2(p.x + 8.0, p.z + (md.y < 0.0 ? -1.0 : 6.0))
        : vec2(7.0 + (tn == lo.x ? p.z - 7.0 : p.x + 1.0), 6.0 + 13.5 - p.y);
    gTorchTex = blockTex(id, 1, clamp(uv, vec2(0.0), vec2(15.99)) / 16.0, tn);
    return tn;
}

// Traces the view ray through the realm's blocks, skipping empty space by each cell's distance to the nearest
// solid one. Returns the ray distance (or -1), the block, the face's normal, the cell hit and the empty cell before.
float traceBlocks(vec3 rd, float maxT, out int id, out ivec3 nrm, out ivec3 hit, out ivec3 before) {
    id = 0;
    nrm = ivec3(0, 1, 0);
    hit = ivec3(0);
    before = ivec3(0);
    ivec3 size = ivec3(VolSize.xyz);
    vec3 ro = -VolCorner;
    vec3 inv = vec3(safeInv(rd.x), safeInv(rd.y), safeInv(rd.z));
    vec3 t0 = (vec3(0.0) - ro) * inv;
    vec3 t1 = (vec3(size) - ro) * inv;
    vec3 tsm = min(t0, t1);
    vec3 tbg = max(t0, t1);
    float tmin = max(max(tsm.x, tsm.y), tsm.z);
    float tmax = min(min(min(tbg.x, tbg.y), tbg.z), maxT);
    if (tmax < max(tmin, 0.0)) return -1.0;
    ivec3 st = ivec3(rd.x >= 0.0 ? 1 : -1, rd.y >= 0.0 ? 1 : -1, rd.z >= 0.0 ? 1 : -1);
    vec3 tDelta = abs(inv);
    float t = max(tmin, 0.0);
    if (tmin > 0.0) {
        nrm = tmin == tsm.x ? ivec3(-st.x, 0, 0) : tmin == tsm.y ? ivec3(0, -st.y, 0) : ivec3(0, 0, -st.z);
    }
    ivec3 c = clamp(ivec3(floor(ro + rd * (t + 1e-4))), ivec3(0), size - 1);
    vec3 tMax = (vec3(c) + max(vec3(st), 0.0) - ro) * inv;
    ivec3 prev = c + nrm;
    for (int i = 0; i < 200; i++) {
        if (t > tmax) break;
        vec2 v = texelFetch(Volume, c, 0).rg;
        int bid = int(v.r * 255.0 + 0.5);
        if (bid != B_AIR) {
            bool through = false;
            if (Flags[bid].w > 0.5) {
                float th = torchHit(ro, rd, c, bid, t);
                if (th >= 0.0) {
                    id = bid;
                    hit = c;
                    before = prev;
                    return th;
                }
                through = true;
            } else if (Flags[bid].z > 0.5) {
                vec3 hp = ro + rd * t;
                vec2 uv = nrm.y != 0 ? hp.xz : nrm.x != 0 ? vec2(hp.z, -hp.y) : vec2(hp.x, -hp.y);
                through = blockTex(bid, nrm.y != 0 ? 0 : 1, uv, t).a < 0.5;
            }
            if (!through) {
                id = bid;
                hit = c;
                before = prev;
                return t;
            }
        }
        int skip = int(v.g * 255.0 + 0.5);
        if (bid == B_AIR && skip > 1) {
            // Jump out of the empty cube round this cell in one go.
            vec3 lo = vec3(c - ivec3(skip - 1));
            vec3 hi = vec3(c + ivec3(skip));
            vec3 te = max((lo - ro) * inv, (hi - ro) * inv);
            float tExit = min(min(te.x, te.y), te.z);
            nrm = tExit == te.x ? ivec3(-st.x, 0, 0) : tExit == te.y ? ivec3(0, -st.y, 0) : ivec3(0, 0, -st.z);
            t = tExit;
            c = ivec3(floor(ro + rd * (t + 1e-4)));
            prev = c + nrm;
            if (!inGrid(c, size)) break;
            tMax = (vec3(c) + max(vec3(st), 0.0) - ro) * inv;
            continue;
        }
        prev = c;
        if (tMax.x < tMax.y && tMax.x < tMax.z) {
            t = tMax.x;
            c.x += st.x;
            tMax.x += tDelta.x;
            nrm = ivec3(-st.x, 0, 0);
        } else if (tMax.y < tMax.z) {
            t = tMax.y;
            c.y += st.y;
            tMax.y += tDelta.y;
            nrm = ivec3(0, -st.y, 0);
        } else {
            t = tMax.z;
            c.z += st.z;
            tMax.z += tDelta.z;
            nrm = ivec3(0, 0, -st.z);
        }
        if (!inGrid(c, size)) break;
    }
    return -1.0;
}

// Vanilla's light curve for a block light level, with the dimension's ambient light, warm like the lightmap.
vec3 blockLight(float level, float ambient) {
    float f = level / 15.0;
    float b = mix(f / (4.0 - 3.0 * f), 1.0, ambient);
    vec3 col = vec3(b, b * ((b * 0.6 + 0.4) * 0.6 + 0.4), b * (b * b * 0.6 + 0.4));
    // The default brightness setting lifts the darks like vanilla's lightmap.
    return mix(col, vec3(1.0) - pow(vec3(1.0) - col, vec3(4.0)), 0.5);
}

// Smooth-lighting style ambient occlusion over the face at hp (grid coordinates), from the cells in front of it.
float faceAO(vec3 hp, ivec3 before, ivec3 n, ivec3 size) {
    ivec3 a = n.x != 0 ? ivec3(0, 1, 0) : ivec3(1, 0, 0);
    ivec3 b = n.z != 0 ? ivec3(0, 1, 0) : ivec3(0, 0, 1);
    if (n.y != 0) {
        a = ivec3(1, 0, 0);
        b = ivec3(0, 0, 1);
    }
    vec3 f = fract(hp);
    float fa = dot(f, vec3(a));
    float fb = dot(f, vec3(b));
    float ao[4];
    for (int k = 0; k < 4; k++) {
        ivec3 sa = (k & 1) == 0 ? -a : a;
        ivec3 sb = (k & 2) == 0 ? -b : b;
        bool s1 = solidAt(before + sa, size);
        bool s2 = solidAt(before + sb, size);
        bool cc = solidAt(before + sa + sb, size);
        float occ = s1 && s2 ? 3.0 : float(s1) + float(s2) + float(cc);
        ao[k] = 1.0 - occ * 0.22;
    }
    return mix(mix(ao[0], ao[1], fa), mix(ao[2], ao[3], fa), fb);
}

// The realm seen along a ray, ignoring the scene: its colour, glow mask and distance (MISS for its fog or sky).
vec4 realmColor(vec3 rd, bool nether, out float dist) {
    float far = nether ? 72.0 : 400.0;
    int id;
    ivec3 n;
    ivec3 hit;
    ivec3 before;
    float tb = traceBlocks(rd, far, id, n, hit, before);
    if (tb < 0.0) {
        dist = MISS;
        return vec4(nether ? NETHER_FOG : endSky(rd), 0.0);
    }
    dist = tb;
    ivec3 size = ivec3(VolSize.xyz);
    vec3 hp = -VolCorner + rd * tb;
    vec2 uv = n.y != 0 ? hp.xz : n.x != 0 ? vec2(hp.z * float(n.x), -hp.y) : vec2(-hp.x * float(n.z), -hp.y);
    bool torch = Flags[id].w > 0.5;
    vec4 tex = torch ? gTorchTex : blockTex(id, n.y > 0 ? 0 : n.y < 0 ? 2 : 1, uv, tb);
    // Torches shade every face like a top one and skip ambient occlusion, as their model asks.
    float shade = torch || n.y > 0 ? 1.0 : n.y < 0 ? 0.5 : n.z != 0 ? 0.8 : 0.6;
    bool glows = Flags[id].y > 0.5;
    float ao = torch || glows || tb > (nether ? 32.0 : 70.0) ? 1.0 : faceAO(hp, before, n, size);
    vec3 col;
    if (nether) {
        float level = inGrid(before, size) ? texelFetch(LightVol, before, 0).r * 15.0 : 0.0;
        vec3 light = glows ? vec3(1.0) : blockLight(level, 0.1);
        col = tex.rgb * light * (glows ? 1.0 : shade * ao);
        col = mix(col, NETHER_FOG, saturate((tb - 8.0) / 64.0));
    } else {
        // The End keeps a flat, bright lightmap.
        col = tex.rgb * vec3(0.99, 0.98, 0.94) * shade * ao;
    }
    return vec4(col, glows ? 0.08 : 0.0);
}

// ---------------------------------------------------------------- Three Realms

void threeRealms(inout vec4 c, vec2 suv, vec3 rd, float sceneT, vec3 surface, bool sky) {
    float t = P0.y;
    float seed = P0.z;
    int world = int(P1.x + 0.5);
    bool inRealm = P1.y > 0.5;
    float dropkick = P2.w;
    float impact = P3.x;

    if (inRealm && world > 0 && VolSize.w > 0.5) {
        // The realm was traced at half resolution; lay it in wherever it is nearer than the scene.
        ivec2 hsize = textureSize(HalfAux, 0);
        float realmT = texelFetch(HalfAux, clamp(ivec2(suv * vec2(hsize)), ivec2(0), hsize - 1), 0).x;
        bool background = sky || sceneT > 120.0;
        if (background || realmT < sceneT) {
            vec4 r = texture(HalfSampler, suv);
            c.rgb = r.rgb;
            c.a = max(c.a, r.a);
        } else if (world == 1) {
            // Bodies in the Nether take its light, hot from the lava, and its fog.
            c.rgb = mix(c.rgb * vec3(1.05, 0.72, 0.6), NETHER_FOG, saturate((sceneT - 8.0) / 64.0));
        } else {
            c.rgb *= vec3(0.94, 0.92, 1.04);
        }
    }

    portals(c, suv, rd, sceneT, 6, t);

    // Home: the drop-kick, the fall it drives, the blow.
    vec4 dk = Pts[22];
    ringFlat(c, rd, sceneT, dk.xyz, vec3(0.0, 1.0, 0.0), 1.0 + (t - dropkick) * 1.4, 0.08, mix(VIOLET, PALE, 0.5),
             window2(t, dropkick, dropkick + 0.5, dropkick + 3.0, dropkick + 6.0));
    spark(c, rd, sceneT, dk.xyz, (t - dropkick) / 20.0, 2.0, seed);
    float fallA = window2(t, dropkick, dropkick + 1.0, impact, impact + 3.0);
    if (fallA > 0.001) {
        float tt, ss;
        float d = raySeg(rd, Target, dk.xyz + vec3(0.0, 6.0, 0.0), tt, ss);
        if (tt > 0.3 && tt < sceneT) {
            float l = ink(d, 0.25 * (1.0 - ss) + 0.05, tt) * fallA;
            emit(c, mix(PALE, VIOLET, ss) * l, l);
        }
    }
    float k = (t - impact) / 20.0;
    if (k >= 0.0 && !sky) {
        vec3 q = surface - Target;
        if (abs(q.y) < 0.35) {
            float r = length(q.xz);
            float ts = length(surface);
            float rr = 18.0 * (1.0 - pow(1.0 - saturate(k / 0.6), 3.0));
            float ring = ink(abs(r - rr), 0.12 * (1.0 - saturate(k / 0.8)) + 0.02, ts) * (1.0 - smoothstep(0.4, 0.9, k));
            emit(c, mix(VIOLET, PALE, 0.4) * ring, ring);
        }
    }
    if (k >= 0.0) {
        float tt, ss;
        float d = raySeg(rd, Target, Target + vec3(0.0, 40.0, 0.0), tt, ss);
        if (tt > 0.3 && tt < sceneT + 3.0) {
            float w = 3.0 * (1.0 - saturate(k / 0.4));
            float pillar = ink(d, w * 0.3, tt) + ink(abs(d - w), 0.05, tt);
            float fade = 1.0 - smoothstep(0.1, 0.45, k);
            emit(c, mix(VIOLET, PALE, 0.5) * pillar * fade, pillar * fade);
        }
        spark(c, rd, sceneT, Target + vec3(0.0, 1.0, 0.0), k * 0.5, 6.0, seed + 7.0);
    }

    // Crossing between worlds: a flash of portal light.
    c.rgb = mix(c.rgb, vec3(0.78, 0.62, 1.0), P1.z * 0.85);
}

void main() {
    vec2 uv = texCoord;
    initPixel(uv);
    int mode = int(P0.x + 0.5);
    if (mode == 4) {
        // The realm alone, at half resolution.
        float dist;
        vec4 r = VolSize.w > 0.5 ? realmColor(viewDir(uv), P1.x < 1.5, dist) : vec4(0.0);
        fragColor = r;
        fragAux = vec4(VolSize.w > 0.5 ? dist : MISS, 0.0, 0.0, 1.0);
        return;
    }
    fragAux = vec4(0.0);
    vec4 c = baseColor(uv);
    vec3 rd = viewDir(uv);
    float sceneT = sceneDist(uv);
    bool sky = sceneT >= FAR;
    vec3 surface = sky ? vec3(0.0) : rd * sceneT;
    float t = P0.y;
    float seed = P0.z;
    if (mode == 1) {
        portals(c, uv, rd, sceneT, 2, t);
        spark(c, rd, sceneT, Pts[4].xyz, (t - Pts[4].w) / 20.0, 1.4, seed);
    } else if (mode == 5) {
        portals(c, uv, rd, sceneT, int(P0.w + 0.5), t);
        if (P1.x > 0.5) ricochetTrail(c, rd, sceneT);
        for (int i = 0; i < 6; i++) {
            if (Pts[18 + i].w > 0.0) spark(c, rd, sceneT, Pts[18 + i].xyz, (t - Pts[18 + i].w) / 20.0, i == 5 ? 2.0 : 1.2, seed + float(i));
        }
    } else if (mode == 3) {
        threeRealms(c, uv, rd, sceneT, surface, sky);
    }
    fragColor = c;
}
