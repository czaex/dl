// Rift's palette and its tear in the world, shared by rift.fsh (Blink Gate, Rift Ricochet) and basic.fsh (Gate Step).

const vec3 VIOLET = vec3(0.61, 0.30, 1.0);
const vec3 TEAL = vec3(0.24, 0.94, 0.71);
const vec3 PALE = vec3(0.92, 0.86, 1.0);

// Paints over the scene without raising the bloom mask.
void solid(inout vec4 c, vec3 col, float a) {
    c.rgb = mix(c.rgb, col, saturate(a));
}

// Rift's own tear in the world (Blink Gate, Rift Ricochet): a jagged rent - a tall slit when it stands, a ragged hole
// when it lies flat - opening on a violet-black void whose specks of light stream into its depth, its torn edge
// running from violet to teal with thin arcs crackling along it, and small sparks spitting off.
void riftTear(inout vec4 c, vec3 rd, float sceneT, vec3 at, vec3 n, float radius, float t, float seed) {
    float facing = abs(dot(rd, n));
    float tp = rayPlane(rd, at, n);
    if (tp <= 0.0 || tp > sceneT + 0.2) return;
    bool standing = abs(n.y) < 0.5;
    vec3 u = normalize(abs(n.y) > 0.95 ? cross(n, vec3(1.0, 0.0, 0.0)) : cross(n, vec3(0.0, 1.0, 0.0)));
    vec3 w = cross(n, u);
    vec3 q = rd * tp - at;
    vec2 p = vec2(dot(q, u), dot(q, w));
    // Standing tears are narrow slits (a lens), lying ones ragged rounds.
    vec2 shape = standing ? vec2(0.55, 1.75) : vec2(1.0, 1.0);
    vec2 sp = p / (radius * shape);
    float r = length(sp);
    if (r > 1.7) return;
    float ang = atan(sp.y, sp.x);
    // A torn edge: sharp zigzags that shift a little, never smooth.
    float zig = abs(fract(ang * 7.0 / TAU + seed) - 0.5) * 2.0;
    float zig2 = abs(fract(ang * 17.0 / TAU + seed * 1.7 + floor(t * 0.25) * 0.13) - 0.5) * 2.0;
    float re = 1.0 - 0.16 * zig - 0.07 * zig2 + 0.03 * sin(t * 0.5 + ang * 3.0);
    float fade = smoothstep(0.04, 0.22, facing);
    float px = gPix * tp / (radius * min(shape.x, shape.y));
    if (r < re && tp < sceneT) {
        float depth = 1.0 - r / re;
        vec3 inside = mix(vec3(0.05, 0.015, 0.09), vec3(0.0, 0.0, 0.01), depth);
        // Specks of light streaming inward, layer by layer, ever faster near the middle.
        for (int k = 0; k < 3; k++) {
            float fk = float(k);
            float rr = fract(r * (1.2 + fk * 0.5) + t * (0.05 + 0.02 * fk) + fk * 0.37);
            vec2 cell = vec2(floor((ang + fk) * (10.0 + 6.0 * fk)), floor(rr * 8.0));
            float h = hash12(cell + seed + fk * 11.0);
            float on = step(0.82, h) * smoothstep(0.0, 0.2, fract(rr * 8.0)) * (1.0 - smoothstep(0.6, 1.0, fract(rr * 8.0)));
            inside += mix(VIOLET, TEAL, step(0.5, hash12(cell + 3.0))) * on * (0.5 + 0.8 * depth);
        }
        // A faint swirl drawing the eye in.
        float vort = abs(fract((ang + log(r + 0.05) * 1.5 - t * 0.08) * 3.0 / TAU) - 0.5);
        inside += VIOLET * smoothstep(0.07, 0.0, vort) * 0.35 * (1.0 - depth * 0.6);
        solid(c, inside, smoothstep(re, re - px * 1.5, r) * fade);
        c.a = max(c.a, 0.12 * fade);
    }
    // The torn edge, violet on the outside running to teal on the lip, and arcs crackling along it.
    float edgeD = abs(r - re) * radius * min(shape.x, shape.y);
    float lip = ink(edgeD, 0.035 * radius / 2.0 + 0.012, tp);
    float halo = ink(edgeD, 0.11 * radius / 2.0 + 0.02, tp) - lip;
    float arcs = 0.0;
    for (int k = 0; k < 4; k++) {
        float fk = float(k);
        float live = step(0.55, hash11(floor(t * 0.5) + fk * 7.0 + seed));
        float a0 = hash11(floor(t * 0.5) * 3.1 + fk + seed) * TAU;
        float da = abs(mod(ang - a0 + PI, TAU) - PI);
        float jag = 0.06 * sin(ang * 40.0 + fk * 5.0 + t * 3.0) + 0.04 * sin(ang * 73.0 - t * 4.0);
        float d = abs(r - re * (1.06 + jag)) * radius * min(shape.x, shape.y);
        arcs = max(arcs, ink(d, 0.012 * radius / 2.0 + 0.005, tp) * step(da, 0.6) * live);
    }
    float sparks = 0.0;
    if (r > re * 0.9) {
        for (int k = 0; k < 10; k++) {
            float fk = float(k);
            float life = fract(t * (0.035 + 0.01 * hash11(fk + seed)) + hash11(fk * 7.1 + seed));
            float sa = hash11(fk * 3.7 + seed) * TAU;
            vec2 spot = vec2(cos(sa), sin(sa)) * (1.04 + 0.55 * life);
            float d = length(sp - spot) * radius * min(shape.x, shape.y);
            sparks = max(sparks, ink(d, 0.03 * radius / 2.0 + 0.008, tp) * (1.0 - life));
        }
    }
    vec3 col = mix(TEAL, PALE, 0.4) * lip + VIOLET * halo * 0.8 + mix(PALE, TEAL, 0.3) * arcs + mix(VIOLET, TEAL, 0.5) * sparks;
    emit(c, col * fade, saturate(lip + halo * 0.4 + arcs + sparks) * fade * 0.75);
}
