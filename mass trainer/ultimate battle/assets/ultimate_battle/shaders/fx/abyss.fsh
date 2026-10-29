// Abyss effects. P0.x picks the skill: 1 Rending Claw, 2 Feral Pounce, 3 Abyssal Fusion (opener), 4 Ravage,
// 5 Crater Pounce, 6 the beast landing stomp, 7 Devour, 8 the beast's swipe, 9 the beast changing back.
// Everything is crisp ink: black rips with thin violet rims, nothing soft or blobby.

const vec3 INK = vec3(0.015, 0.006, 0.03);
const vec3 DEEP = vec3(0.22, 0.04, 0.42);
const vec3 DUSK = vec3(0.30, 0.08, 0.52);
const vec3 VIOLET = vec3(0.69, 0.15, 1.0);
const vec3 PALE = vec3(0.95, 0.86, 1.0);

vec3 camRight() { return normalize((InvView * vec4(1.0, 0.0, 0.0, 0.0)).xyz); }
vec3 camUp() { return normalize((InvView * vec4(0.0, 1.0, 0.0, 0.0)).xyz); }

// Three claw tears ripped through the air in the plane through 'center' (normal n), swept along 'along':
// they rip open from one end in a tick or two, hang open as black void with violet rims, then close.
void tears(inout vec4 c, vec3 rd, float sceneT, vec3 center, vec3 along, vec3 n, float age, float len, float gap, float width) {
    if (age < 0.0 || age > 0.95) return;
    float tp = rayPlane(rd, center, n);
    if (tp <= 0.0 || tp > sceneT + 0.05) return;
    vec3 p = rd * tp - center;
    vec3 across = normalize(cross(n, along));
    float u = dot(p, along) / (len * 0.5);
    if (abs(u) > 1.05) return;
    float v = dot(p, across);
    float sweep = saturate(age / 0.075);
    float head = mix(-1.05, 1.05, sweep);
    float open = saturate(age / 0.09) * (1.0 - smoothstep(0.3, 0.9, age));
    vec3 rimCol = mix(VIOLET, PALE, exp(-age * 16.0));
    for (int k = -1; k <= 1; k++) {
        float fk = float(k);
        // Real claw marks: they bow a little and draw together toward the ends.
        float off = fk * gap * (1.0 - 0.3 * u * u) + (1.0 - u * u) * 0.1 * len * (1.0 + 0.25 * fk);
        float d = abs(v - off);
        float vis = step(u, head - 0.1 * abs(fk));
        float shape = pow(max(1.0 - u * u, 0.0), 0.65);
        float w = width * shape * open * (k == 0 ? 1.15 : 0.9);
        float core = ink(d, w, tp) * vis;
        float rim = max(ink(d, w + 0.018 + 0.03 * (1.0 - open), tp) * vis - core, 0.0);
        paint(c, INK, core);
        float inner = fbm3(vec3(u * 3.0, v * 9.0, age * 5.0 + fk));
        emit(c, DEEP * inner * core * 0.7, 0.0);
        emit(c, rimCol * rim * 1.5, rim);
        // A spark rides the tip of each claw while it rips.
        float hd = length(vec2((u - head) * len * 0.5, d));
        float spark = exp(-hd / 0.045) * (1.0 - sweep) * step(0.001, age);
        emit(c, PALE * spark, spark);
    }
}

// Three claw gashes torn into the ground at 'center' along 'along': black, a burnt rim, a thin violet edge that
// starts white-hot, embers in the cut. Limited to the ground (|dy| small) so it never paints on legs.
void scars(inout vec4 c, vec3 surface, vec3 center, vec3 along, float age, float len, float gap, float wmax, float life) {
    if (age < 0.0 || age > life) return;
    vec3 q = surface - center;
    if (abs(q.y) > 0.3) return;
    vec3 a = normalize(vec3(along.x, 0.0, along.z));
    vec3 across = vec3(-a.z, 0.0, a.x);
    float u = dot(q, a) / (len * 0.5);
    if (abs(u) > 1.1) return;
    float v = dot(q, across);
    float grow = saturate(age / 0.12);
    float reach = mix(-1.05, 1.05, grow);
    float fade = 1.0 - smoothstep(life * 0.55, life, age);
    float hot = exp(-age * 2.2);
    for (int k = -1; k <= 1; k++) {
        float fk = float(k);
        if (u > reach) continue;
        float jag = (vnoise2(vec2(u * len * 1.6, fk * 7.0)) - 0.5) * 0.08;
        float off = fk * gap * (1.0 - 0.25 * u * u) + jag;
        float d = abs(v - off);
        float shape = pow(max(1.0 - u * u, 0.0), 0.5);
        float w = wmax * shape;
        float core = 1.0 - smoothstep(w * 0.55, w * 0.55 + 0.02, d);
        float edge = max((1.0 - smoothstep(w, w + 0.025, d)) - core, 0.0);
        float burn = (1.0 - smoothstep(w, w * 3.2, d)) * 0.55;
        c.rgb *= 1.0 - burn * fade;
        paint(c, INK, core * fade);
        emit(c, mix(VIOLET, PALE, hot) * edge * (0.7 + hot) * fade, edge * fade);
        float ember = step(0.9, hash12(floor(vec2(u * len * 5.0, fk + 3.0)))) * core * hot;
        emit(c, VIOLET * ember * 1.2, ember);
    }
}

// A billow of cel-shaded ink smoke: black core, violet edge.
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
    // Ink, not glow: black body, a deep purple band, violet only on the thin outer edge.
    float edge = m - celMask(i - 0.12);
    vec3 col = mix(INK, DEEP * 0.45, smoothstep(0.2, 0.6, 1.0 - i));
    // Solid paint: covers the scene without raising the bloom mask, so the smoke never glows.
    c.rgb = mix(c.rgb, col, m * 0.94);
    emit(c, VIOLET * saturate(edge) * 0.4, saturate(edge) * 0.25);
}

// A tapering, wavering tendril of ink from 'base' along 'dir' (length h), with a violet rim.
void tendril(inout vec4 c, vec3 rd, float sceneT, vec3 base, vec3 dir, float h, float seed, float time, float width) {
    if (h <= 0.05) return;
    vec3 side = normalize(cross(dir, vec3(0.0, 1.0, 0.001)));
    vec3 up = normalize(cross(side, dir));
    vec3 prev = base;
    for (int k = 1; k <= 5; k++) {
        float f = float(k) / 5.0;
        vec3 p = base + dir * h * f
            + side * sin(seed * 3.0 + f * 6.0 + time * 7.0) * 0.22 * f
            + up * cos(seed * 5.0 + f * 5.0 + time * 6.0) * 0.18 * f;
        float t, s;
        float d = raySeg(rd, prev, p, t, s);
        if (t > 0.0 && t < sceneT + 0.3) {
            float w = mix(width, width * 0.12, mix(f - 0.2, f, s));
            float core = ink(d, w, t);
            float rim = max(ink(d, w + 0.03, t) - core, 0.0);
            paint(c, INK, core);
            emit(c, VIOLET * rim * 1.3, rim);
        }
        prev = p;
    }
}

// An expanding ring with ink spikes, camera-facing (a hit).
void spark(inout vec4 c, vec3 rd, float sceneT, vec3 pos, float k, float size, float seed) {
    if (k < 0.0 || k > 0.3) return;
    float tp;
    float d = rayPoint(rd, pos, tp);
    // Behind the camera the distance means nothing (it would fill half the screen).
    if (tp <= 0.05 || tp > sceneT + 1.0) return;
    float u = k / 0.3;
    float rr = size * (0.25 + 1.2 * sqrt(u));
    float ring = ink(abs(d - rr), 0.03 * (1.0 - u) + 0.004, tp);
    vec3 v = rd * tp - pos;
    float ang = atan(dot(v, camUp()), dot(v, camRight()));
    float spikes = pow(max(cos(ang * 4.0 + seed * 5.0), 0.0), 50.0) + pow(max(cos(ang * 3.0 + seed * 11.0 + 0.7), 0.0), 70.0);
    float spike = spikes * smoothstep(rr * 1.8, rr * 0.4, d) * step(rr * 0.25, d) * (1.0 - u);
    emit(c, PALE * (ring + spike), saturate(ring + spike));
}

// A soft dark pool on the ground under the beast (it has no vanilla shadow).
void contact(inout vec4 c, vec3 surface, vec3 feet, float radius, float a) {
    vec3 q = surface - feet;
    if (a <= 0.0 || abs(q.y) > 0.5) return;
    float r = length(q.xz);
    c.rgb *= 1.0 - (1.0 - smoothstep(radius * 0.3, radius, r)) * 0.6 * a;
}

void rendingClaw(inout vec4 c, vec3 rd, float sceneT) {
    float t = P0.y;
    float strike = P0.w;
    vec3 f = Facing;
    vec3 r = normalize(vec3(-f.z, 0.0, f.x));
    vec3 along = normalize(-r - vec3(0.0, 0.95, 0.0));
    tears(c, rd, sceneT, Target, along, f, (t - strike) / 20.0, 2.5, 0.3, 0.075);
    spark(c, rd, sceneT, Target, (t - strike) / 20.0, 1.0, P0.z);
}

void feralPounce(inout vec4 c, vec3 rd, float sceneT, vec3 surface, bool sky) {
    float t = P0.y;
    float land = P0.w;
    float age = (t - land) / 20.0;
    vec3 f = Facing;
    vec3 r = normalize(vec3(-f.z, 0.0, f.x));
    tears(c, rd, sceneT, Target, normalize(-r - vec3(0.0, 1.0, 0.0)), f, age, 2.7, 0.3, 0.08);
    tears(c, rd, sceneT, Target + f * 0.05, normalize(r - vec3(0.0, 1.0, 0.0)), f, age - 0.04, 2.7, 0.3, 0.08);
    if (!sky) {
        vec3 hub = Caster + f * 1.1;
        scars(c, surface, hub, normalize(f + r * 0.55), age, 3.4, 0.36, 0.13, 2.6);
        scars(c, surface, hub, normalize(f - r * 0.55), age - 0.03, 3.4, 0.36, 0.13, 2.6);
    }
    spark(c, rd, sceneT, Target, age, 1.3, P0.z);
}

// A thin ink shock ring expanding over the ground from 'center' (age in seconds), with violet edge.
void groundRing(inout vec4 c, vec3 surface, vec3 center, float age, float speed, float life) {
    if (age < 0.0 || age > life) return;
    vec3 q = surface - center;
    if (abs(q.y) > 0.6) return;
    float fade = 1.0 - age / life;
    float g = 1.0 - smoothstep(0.04, 0.2, abs(length(q.xz) - age * speed));
    emit(c, VIOLET * g * fade * 0.9, g * fade);
}

// Short cracks running out from 'center' over the ground (a heavy landing).
void stompCracks(inout vec4 c, vec3 surface, vec3 center, float age, float radius, float seed) {
    if (age < 0.0 || age > 1.8) return;
    vec3 q = surface - center;
    if (abs(q.y) > 0.3) return;
    float r = length(q.xz);
    float reach = radius * 0.8 * (1.0 - pow(1.0 - saturate(age / 0.15), 3.0));
    if (r > reach) return;
    float fade = 1.0 - smoothstep(0.9, 1.8, age);
    float hot = exp(-age * 3.0);
    float ang = atan(q.z, q.x);
    float n = 9.0;
    float a = fract(ang / TAU * n + seed);
    float jag = (vnoise2(vec2(r * 3.0, floor(ang / TAU * n + seed) * 5.0)) - 0.5) * 0.25;
    float d = abs(a - 0.5 - jag) * r * TAU / n;
    float w = 0.05 * (1.0 - r / max(reach, 0.01));
    float line = 1.0 - smoothstep(w, w + 0.02, d);
    c.rgb *= 1.0 - (1.0 - smoothstep(0.0, radius * 0.5, r)) * 0.4 * fade;
    paint(c, INK, line * fade);
    emit(c, mix(VIOLET, PALE, hot) * line * hot * 0.8, line * hot);
}

void opener(inout vec4 c, vec3 rd, float sceneT, vec3 surface, bool sky) {
    float t = P0.y;
    float seed = P0.z;
    float xslash = P0.w;
    float fuse = P1.x;
    float roar = P1.y;
    vec3 f = Facing;
    vec3 r = normalize(vec3(-f.z, 0.0, f.x));
    vec3 chest = Origin + vec3(0.0, 1.25, 0.0);
    // Ink tendrils bursting out of the chest before the fusion.
    if (t < fuse + 4.0) {
        float grow = saturate(t / fuse);
        float gone = 1.0 - saturate((t - fuse) / 4.0);
        for (int i = 0; i < 10; i++) {
            float fi = float(i);
            vec3 h = hash31(fi + seed) * 2.0 - 1.0;
            vec3 dir = normalize(vec3(h.x, abs(h.y) * 0.8 - 0.2, h.z) + f * 0.3);
            float len = (0.6 + 1.6 * hash11(fi * 5.3)) * grow * grow;
            tendril(c, rd, sceneT, chest, dir, len * gone, fi, t / 20.0, 0.09);
        }
    }
    float fk = (t - fuse) / 20.0;
    smoke(c, rd, sceneT, chest + vec3(0.0, 0.4, 0.0), 1.6, fk, 0.5);
    smoke(c, rd, sceneT, chest + f * 0.8 + vec3(0.0, 1.2, 0.0), 1.2, fk - 0.05, 0.45);
    spark(c, rd, sceneT, chest, fk, 2.4, seed);
    // The roar.
    vec3 mouth = Origin + f * 1.4 + vec3(0.0, 2.9, 0.0);
    for (int i = 0; i < 3; i++) {
        float a = (t - roar) / 20.0 - float(i) * 0.2;
        if (a < 0.0 || a > 0.8) continue;
        float tp;
        float d = rayPoint(rd, mouth, tp);
        float rr = 0.8 + a * 15.0;
        float fade = 1.0 - a / 0.8;
        float ring = ink(abs(d - rr), 0.04 * fade + 0.008, max(tp, 0.1));
        if (tp > 0.0 && tp < sceneT + rr) emit(c, mix(VIOLET, PALE, 0.4) * ring * fade, ring * fade);
        if (!sky) groundRing(c, surface, Origin, a, 13.0, 0.8);
    }
    // The crossed rend: two sets of tears through the enemy.
    float xa = (t - xslash) / 20.0;
    tears(c, rd, sceneT, Target, normalize(-r - vec3(0.0, 1.0, 0.0)), f, xa, 3.6, 0.42, 0.12);
    tears(c, rd, sceneT, Target + f * 0.05, normalize(r - vec3(0.0, 1.0, 0.0)), f, xa - 0.03, 3.6, 0.42, 0.12);
    spark(c, rd, sceneT, Target, xa, 2.0, seed + 1.0);
    if (!sky) contact(c, surface, Caster, 2.2, P2.z);
}

// The beast's left-click swipe: one big set of claw tears, slanting the way P1.x says.
void beastSwipe(inout vec4 c, vec3 rd, float sceneT) {
    float t = P0.y;
    float strike = P0.w;
    vec3 f = Facing;
    vec3 r = normalize(vec3(-f.z, 0.0, f.x));
    vec3 along = normalize(r * P1.x - vec3(0.0, 0.8, 0.0));
    tears(c, rd, sceneT, Target, along, f, (t - strike) / 20.0, 3.2, 0.42, 0.1);
    spark(c, rd, sceneT, Target, (t - strike) / 20.0, 1.2, P0.z);
}

void ravage(inout vec4 c, vec3 rd, float sceneT, vec3 surface, bool sky) {
    float t = P0.y;
    vec3 f = Facing;
    vec3 r = normalize(vec3(-f.z, 0.0, f.x));
    for (int k = 0; k < 3; k++) {
        vec4 s = Pts[k];
        float age = (t - s.w) / 20.0;
        if (age < -0.01 || age > 1.6) continue;
        if (k < 2) {
            float side = k == 0 ? -1.0 : 1.0;
            tears(c, rd, sceneT, s.xyz, normalize(r * side - vec3(0.0, 0.85, 0.0)), f, age, 3.0, 0.38, 0.1);
        } else {
            tears(c, rd, sceneT, s.xyz + vec3(0.0, 0.5, 0.0), normalize(vec3(0.0, -1.0, 0.0) + f * 0.15), r, age, 3.2, 0.45, 0.11);
            if (!sky) scars(c, surface, s.xyz + f * 0.4 - vec3(0.0, 0.9, 0.0), f, age, 3.6, 0.45, 0.16, 1.6);
        }
        spark(c, rd, sceneT, s.xyz, age, 1.2, float(k));
    }
}

void crater(inout vec4 c, vec3 rd, float sceneT, vec3 surface, bool sky) {
    float t = P0.y;
    float land = P0.w;
    float age = (t - land) / 20.0;
    vec3 f = Facing;
    if (!sky) {
        // Two long claw gashes crossing in an X at the landing point, its arms on the diagonals of the way the
        // beast faces, so from behind it reads as an X on the ground (one per claw).
        vec3 fr = normalize(vec3(-f.z, 0.0, f.x));
        vec3 ff = normalize(vec3(f.x, 0.0, f.z));
        scars(c, surface, Target, normalize(ff + fr), age, P1.x * 1.5, 0.32, 0.17, 2.6);
        scars(c, surface, Target, normalize(ff - fr), age - 0.025, P1.x * 1.5, 0.32, 0.17, 2.6);
        groundRing(c, surface, Target, age, 16.0, 0.5);
    }
    smoke(c, rd, sceneT, Target + vec3(0.0, 0.4, 0.0), 1.4, age, 0.5);
    spark(c, rd, sceneT, Target + vec3(0.0, 0.8, 0.0), age, 2.4, P0.z);
}

void stomp(inout vec4 c, vec3 rd, float sceneT, vec3 surface, bool sky) {
    float age = P0.y / 20.0;
    if (sky) return;
    groundRing(c, surface, Target, age, 12.0, 0.45);
    stompCracks(c, surface, Target, age, P1.x, P0.z);
}

// A crisp streak of ink from 'tail' to 'head': thin at the tail, 'width' at the head, a violet rim.
void streak(inout vec4 c, vec3 rd, float sceneT, vec3 tail, vec3 head, float width, float fade) {
    if (fade <= 0.0) return;
    float t, s;
    float d = raySeg(rd, tail, head, t, s);
    if (t <= 0.0 || t > sceneT + 0.3) return;
    float w = width * s * s * fade;
    float core = ink(d, w, t);
    float rim = max(ink(d, w + 0.025, t) - core, 0.0);
    paint(c, INK, core);
    emit(c, VIOLET * rim * 1.2, rim);
}

// The last 'len' blocks of a path that ends at 'head' and came from 'from'.
vec3 tailOf(vec3 from, vec3 head, float len) {
    vec3 d = from - head;
    float l = length(d);
    return l < 1e-3 ? head : head + d * min(1.0, len / l);
}

// The crater: the ground scorched dark in a ragged disc, with a burnt lip that glows violet-hot at first.
void pit(inout vec4 c, vec3 surface, vec3 center, float age, float radius, float life) {
    if (age < 0.0 || age > life) return;
    vec3 q = surface - center;
    if (abs(q.y) > 0.6) return;
    float r = length(q.xz);
    float R = radius * (1.0 - pow(1.0 - saturate(age / 0.12), 3.0));
    if (r > R * 1.3 + 0.2) return;
    float fade = 1.0 - smoothstep(life * 0.7, life, age);
    float ang = atan(q.z, q.x);
    float jag = (vnoise2(vec2(ang * 2.5, 1.7)) - 0.5) * 0.3 * radius;
    float edge = R + jag;
    float inside = 1.0 - smoothstep(edge * 0.5, edge, r);
    c.rgb *= 1.0 - inside * 0.55 * fade;
    float lip = 1.0 - smoothstep(0.0, 0.1, abs(r - edge));
    float hot = exp(-age * 2.5);
    c.rgb *= 1.0 - lip * 0.45 * fade;
    emit(c, mix(VIOLET, PALE, hot) * lip * hot * 0.9 * fade, lip * hot * fade);
}

// The moment the beast is the fighter again: a crisp ring off the chest and a shock over the ground.
void turnBurst(inout vec4 c, vec3 rd, float sceneT, vec3 surface, bool sky, vec3 feet, float age, float seed) {
    spark(c, rd, sceneT, feet + vec3(0.0, 1.1, 0.0), age, 2.4, seed);
    if (!sky) groundRing(c, surface, feet, age, 8.0, 0.45);
}

// Devour (Carnage Meteor). Target = where the enemy lies and is slammed; Pts[0..3] the rips (xyz, tick),
// Pts[4] the catch at the top, Pts[5] where the dive starts; P3 the enemy's middle now; Origin the maw roaring.
void devour(inout vec4 c, vec3 rd, float sceneT, vec3 surface, bool sky) {
    float t = P0.y;
    float seed = P0.z;
    float slam = P0.w;
    float tackle = P1.x;
    float catchT = P1.y;
    float roar = P1.z;
    float turn = P1.w;
    float throwT = P2.x;
    float dive = P2.y;
    vec3 f = Facing;
    vec3 r = normalize(vec3(-f.z, 0.0, f.x));
    vec3 up = vec3(0.0, 1.0, 0.0);
    // The tackle: a ring off the enemy as it goes down, a short shock over the ground.
    float ta = (t - tackle) / 20.0;
    spark(c, rd, sceneT, Target + up * 0.6, ta, 1.8, seed);
    if (!sky) groundRing(c, surface, Target, ta, 9.0, 0.35);
    // Four rips through the pinned body, each also gouging three marks into the ground beside it.
    for (int k = 0; k < 4; k++) {
        vec4 s = Pts[k];
        float age = (t - s.w) / 20.0;
        if (age < -0.01 || age > 3.0) continue;
        float side = (k == 0 || k == 2) ? 1.0 : -1.0;
        float heavy = k == 3 ? 1.0 : 0.0;
        tears(c, rd, sceneT, s.xyz + up * 0.5, normalize(r * side * 0.8 - up), f, age, 2.8 + heavy * 0.6, 0.36, 0.1 + heavy * 0.03);
        if (!sky) scars(c, surface, Target + r * side * 0.35 + f * 0.15 * float(k - 1), normalize(f + r * side * 0.7), age, 2.4, 0.3, 0.11, 3.0);
        spark(c, rd, sceneT, s.xyz, age, 1.1 + heavy * 0.6, float(k) + seed);
    }
    // Flung into the sky: a short wake of ink behind it.
    if (t > throwT && t < catchT + 5.0) {
        vec3 head = t < catchT ? P3.xyz : Pts[4].xyz;
        streak(c, rd, sceneT, tailOf(Target, head, 3.0 * (1.0 - saturate((t - catchT) / 5.0))), head, 0.13, 1.0);
    }
    // Caught at the top.
    spark(c, rd, sceneT, Pts[4].xyz, (t - catchT) / 20.0, 2.2, seed + 3.0);
    // The dive: a sonic ring where it starts down, and a comet tail of ink behind the falling pair.
    spark(c, rd, sceneT, Pts[5].xyz + up * 1.2, (t - dive) / 20.0, 3.2, seed + 4.0);
    if (t > dive && t < slam + 4.0) {
        float fade = 1.0 - saturate((t - slam) / 4.0);
        vec3 head = t < slam ? P3.xyz : Target + up * 0.3;
        vec3 from = Pts[5].xyz + up * 2.0;
        streak(c, rd, sceneT, tailOf(from, head, 7.0 * fade), head, 0.55, fade);
        streak(c, rd, sceneT, tailOf(from + r * 1.2, head + r * 1.0, 5.0 * fade), head + r * 1.0, 0.06, fade);
        streak(c, rd, sceneT, tailOf(from - r * 1.2, head - r * 1.0, 5.0 * fade), head - r * 1.0, 0.06, fade);
    }
    // The meteor lands: a crater, a downward rend through the enemy, three huge gashes, two shocks over the ground.
    float sk = (t - slam) / 20.0;
    if (sk > -0.05) {
        tears(c, rd, sceneT, Target + up * 1.4, normalize(-up + f * 0.15), r, sk + 0.03, 5.0, 0.6, 0.15);
        if (!sky) {
            pit(c, surface, Target, sk, 2.6, 4.0);
            scars(c, surface, Target + f * 2.6, f, sk, 8.0, 0.9, 0.32, 4.0);
            groundRing(c, surface, Target, sk, 18.0, 0.6);
            groundRing(c, surface, Target, sk - 0.08, 9.0, 0.8);
        }
        smoke(c, rd, sceneT, Target + up * 0.5, 2.0, sk, 0.7);
        spark(c, rd, sceneT, Target + up * 0.6, sk, 3.6, seed + 2.0);
    }
    // Roaring to the sky: rings off the maw, a shock over the ground round the beast.
    for (int i = 0; i < 3; i++) {
        float a = (t - roar) / 20.0 - float(i) * 0.22;
        if (a < 0.0 || a > 0.8) continue;
        float tp;
        float d = rayPoint(rd, Origin, tp);
        float rr = 0.8 + a * 14.0;
        float fade = 1.0 - a / 0.8;
        float ring = ink(abs(d - rr), 0.04 * fade + 0.008, max(tp, 0.1));
        if (tp > 0.0 && tp < sceneT + rr) emit(c, mix(VIOLET, PALE, 0.4) * ring * fade, ring * fade);
        if (!sky && i == 0) groundRing(c, surface, Caster, a, 12.0, 0.8);
    }
    if (!sky) contact(c, surface, Caster, 2.2, P2.z);
    // The fighter again (the violet fire is drawn on the bodies themselves).
    turnBurst(c, rd, sceneT, surface, sky, Caster, (t - turn) / 20.0, seed + 5.0);
}

// Beast Mode over: the same burst as Devour's end, at the turn (P0.w).
void revert(inout vec4 c, vec3 rd, float sceneT, vec3 surface, bool sky) {
    float t = P0.y;
    turnBurst(c, rd, sceneT, surface, sky, Caster, (t - P0.w) / 20.0, P0.z);
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
        rendingClaw(c, rd, sceneT);
    } else if (mode == 2) {
        feralPounce(c, rd, sceneT, surface, sky);
    } else if (mode == 3) {
        opener(c, rd, sceneT, surface, sky);
    } else if (mode == 4) {
        ravage(c, rd, sceneT, surface, sky);
    } else if (mode == 5) {
        crater(c, rd, sceneT, surface, sky);
    } else if (mode == 6) {
        stomp(c, rd, sceneT, surface, sky);
    } else if (mode == 7) {
        devour(c, rd, sceneT, surface, sky);
    } else if (mode == 8) {
        beastSwipe(c, rd, sceneT);
    } else if (mode == 9) {
        revert(c, rd, sceneT, surface, sky);
    }
    fragColor = c;
}
