// Martial effects. P0.x picks the skill: 1 Rush Combo, 2 Quake Stomp, 3 Meteor Fist.

const vec3 FIRE_CORE = vec3(1.0, 0.97, 0.82);
const vec3 FIRE_MID = vec3(1.0, 0.62, 0.12);
const vec3 FIRE_EDGE = vec3(0.85, 0.16, 0.04);
const vec3 LAVA = vec3(1.0, 0.45, 0.08);

vec3 camRight() { return normalize((InvView * vec4(1.0, 0.0, 0.0, 0.0)).xyz); }
vec3 camUp() { return normalize((InvView * vec4(0.0, 1.0, 0.0, 0.0)).xyz); }

// A hit spark facing the camera: an expanding ring with ink spikes.
void hitSpark(inout vec4 c, vec3 rd, float sceneT, vec3 pos, float k, float size, float seed) {
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
    float flash = exp(-d / (size * 0.18)) * exp(-k * 18.0);
    float m = saturate(ring + spike + flash);
    emit(c, vec3(1.0) * (ring + spike) + FIRE_MID * flash, m);
}

// Cel-shaded flame around a vertical body (feet to head).
void bodyFlame(inout vec4 c, vec3 rd, float sceneT, vec3 feet, float height, float radius, float power, float time, vec3 core, vec3 mid, vec3 edge) {
    if (power <= 0.001 || cameraInside(feet, height, radius)) return;
    float t, s;
    float d = raySeg(rd, feet + vec3(0.0, 0.1, 0.0), feet + vec3(0.0, height, 0.0), t, s);
    if (d > radius * 1.6 || t <= 0.0 || t > sceneT + radius) return;
    vec3 q = rd * t - feet;
    float n = fbm3(vec3(q.x * 2.2, q.y * 1.3 - time * 4.5, q.z * 2.2));
    float lift = 1.0 - 0.35 * s;
    float i = (1.0 - d / (radius * lift)) * 1.0 + (n - 0.5) * 1.7 - 0.15;
    i *= power;
    float m = celMask(i);
    if (m <= 0.0) return;
    vec3 col = cel(i, core, mid, edge);
    paint(c, col, m * 0.6);
    emit(c, col * 0.2 * m, m);
}

// Ground treatment around an impact: ring shockwave, glowing cracks, scorch.
void groundImpact(inout vec4 c, vec3 surface, vec3 center, float k, float radius, float ringMax, float ringTime, float crackLife, float seed) {
    vec3 q = surface - center;
    if (abs(q.y) > 4.0) return;
    float r = length(q.xz);
    float vertical = 1.0 - smoothstep(2.0, 4.0, abs(q.y));
    // Shockwave ring.
    float rr = ringMax * (1.0 - pow(1.0 - saturate(k / ringTime), 3.0));
    float ringA = 1.0 - smoothstep(ringTime * 0.6, ringTime * 1.3, k);
    float ring = (1.0 - smoothstep(0.15, 0.55, abs(r - rr))) * ringA * vertical;
    emit(c, mix(FIRE_MID, vec3(1.0), 0.5) * ring * 1.2, ring);
    // Cracks spreading out from the centre, glowing like lava, then cooling.
    float spread = radius * smoothstep(0.0, 0.3, k);
    if (r < spread) {
        float cd = crackDist(q.xz * 0.55, seed);
        float ang = atan(q.z, q.x);
        float ray = abs(fract(ang / TAU * 11.0 + hash11(floor(ang / TAU * 11.0) + seed) * 0.3) - 0.5);
        float radial = (1.0 - smoothstep(0.0, 0.06 + 0.012 * r, ray * r * 0.6)) * step(0.8, r);
        float line = max(1.0 - smoothstep(0.015, 0.05, cd), radial * 0.9);
        float edgeFade = 1.0 - smoothstep(radius * 0.6, radius, r);
        float life = 1.0 - smoothstep(crackLife * 0.5, crackLife, k);
        float heat = line * edgeFade * vertical;
        vec3 crackCol = mix(vec3(0.35, 0.05, 0.02), LAVA, life) + vec3(1.0, 0.9, 0.6) * exp(-k * 2.0);
        c.rgb = mix(c.rgb, c.rgb * 0.55, edgeFade * vertical * (1.0 - smoothstep(0.0, radius, r)) * 0.8);
        paint(c, crackCol, heat * 0.95);
        emit(c, LAVA * heat * life * 0.4, heat * life);
    }
}

// A dust wall standing on the shockwave ring.
void dustWall(inout vec4 c, vec3 rd, float sceneT, vec3 center, float rr, float height, float alpha, float seed) {
    if (alpha <= 0.001 || rr <= 0.1) return;
    vec2 o = -center.xz;
    vec2 d = rd.xz;
    float a = dot(d, d);
    if (a < 1e-6) return;
    float b = dot(o, d);
    float cc = dot(o, o) - rr * rr;
    float h = b * b - a * cc;
    if (h < 0.0) return;
    h = sqrt(h);
    for (int i = 0; i < 2; i++) {
        float t = (-b + (i == 0 ? -h : h)) / a;
        if (t <= 0.0 || t > sceneT) continue;
        vec3 p = rd * t - center;
        if (p.y < -0.5 || p.y > height) continue;
        float ang = atan(p.z, p.x);
        float n = vnoise2(vec2(ang * 9.0, p.y * 1.5 - GTime * 2.0) + seed);
        float top = height * (0.55 + 0.45 * n);
        float m = smoothstep(top, top - 0.6, p.y) * (0.45 + 0.35 * n) * alpha;
        paint(c, vec3(0.78, 0.72, 0.64) * (0.8 + 0.3 * n), m);
    }
}

// A cel-shaded ball of fire (a burning fist), flickering tongues licking upward.
void fireBall(inout vec4 c, vec3 rd, float sceneT, vec3 pos, float radius, float power, float time) {
    if (power <= 0.001) return;
    float tp;
    float d = rayPoint(rd, pos, tp);
    if (tp <= 0.0 || tp > sceneT + radius || d > radius * 2.0) return;
    vec3 q = rd * tp - pos;
    float n = fbm3(vec3(q.x * 3.0, q.y * 2.0 - time * 7.0, q.z * 3.0));
    float i = ((1.0 - d / radius) * 1.15 + (n - 0.5) * 1.3 + max(q.y, 0.0) * 0.4) * power;
    float m = celMask(i);
    if (m <= 0.0) return;
    vec3 col = cel(i, FIRE_CORE, FIRE_MID, FIRE_EDGE);
    paint(c, col, m * 0.85);
    emit(c, col * 0.3 * m, m);
}

void rush(inout vec4 c, vec3 rd, float sceneT, vec3 surface, bool sky) {
    float t = P0.y;
    for (int i = 0; i < 10; i++) {
        vec4 h = Pts[i];
        float k = t - h.w;
        hitSpark(c, rd, sceneT, h.xyz, k, i == 9 ? 1.6 : i == 8 ? 1.4 : 0.6, float(i) + P0.z);
    }
    // The uppercut pillar.
    float ku = t - Pts[8].w;
    if (ku > 0.0 && ku < 0.5) {
        float tp, s;
        vec3 base = Target - vec3(0.0, 1.0, 0.0);
        float d = raySeg(rd, base, base + vec3(0.0, 9.0, 0.0), tp, s);
        if (tp < sceneT + 1.0) {
            float w = 0.35 * (1.0 - ku / 0.5) * (1.0 - s * 0.7);
            float core = ink(d, w, tp);
            float glow = halo(d, w * 2.5 + 0.05) * 0.6 * (1.0 - ku / 0.5);
            emit(c, vec3(1.0) * core + FIRE_MID * glow, core + glow);
        }
    }
    // The burning fist chasing the enemy up and hammering it down.
    fireBall(c, rd, sceneT, P1.xyz, 0.55, P1.w, t);
    // Where it lands: a small crater of glowing cracks, a ring and a dust wall.
    float k = P2.w;
    if (k >= 0.0) {
        if (!sky) groundImpact(c, surface, P2.xyz, k, 4.0, 7.0, 0.35, 2.2, P0.z);
        float rr = 7.0 * (1.0 - pow(1.0 - saturate(k / 0.35), 3.0));
        dustWall(c, rd, sceneT, P2.xyz, rr, 1.8 * (1.0 - saturate(k / 0.7)), 1.0 - smoothstep(0.25, 0.7, k), P0.z);
        float tp;
        float d = rayPoint(rd, P2.xyz + vec3(0.0, 0.4, 0.0), tp);
        float flash = exp(-k * 12.0) * exp(-d / 0.8);
        if (tp < sceneT + 2.0) emit(c, mix(FIRE_MID, vec3(1.0), 0.6) * flash, flash);
    }
}

void quake(inout vec4 c, vec3 rd, float sceneT, vec3 surface, bool sky) {
    float k = P0.y;
    float R = P0.z;
    if (k < 0.0) return;
    if (!sky) groundImpact(c, surface, Target, k, R * 0.85, R, 0.45, 2.6, P0.w);
    float rr = R * (1.0 - pow(1.0 - saturate(k / 0.45), 3.0));
    dustWall(c, rd, sceneT, Target, rr, 2.4 * (1.0 - saturate(k / 0.9)), 1.0 - smoothstep(0.3, 0.9, k), P0.w);
    float tp;
    float d = rayPoint(rd, Target + vec3(0.0, 0.5, 0.0), tp);
    float flash = exp(-k * 10.0);
    if (tp < sceneT + 2.0) emit(c, mix(FIRE_MID, vec3(1.0), 0.6) * halo(d, 1.5) * flash, halo(d, 1.5) * flash);
}

void meteor(inout vec4 c, vec3 rd, float sceneT, vec3 surface, bool sky) {
    float tick = P0.y;
    float seed = P0.z;
    float time = tick / 20.0;
    float launch = P3.x, apex = P3.y, dive = P3.z, impactAt = P3.w;
    vec3 feet = Caster;
    // Body aura while powering up; once airborne the fire gathers in the fist so the body stays visible.
    if (tick < launch + 4.0) {
        float power = 0.35 + 0.55 * saturate(tick / launch);
        bodyFlame(c, rd, sceneT, feet, 2.2, 0.8, power, time, FIRE_CORE, FIRE_MID, FIRE_EDGE);
    } else if (tick >= dive && tick < impactAt) {
        bodyFlame(c, rd, sceneT, feet, 2.0, 0.45, 0.5, time, FIRE_CORE, FIRE_MID, FIRE_EDGE);
    }
    fireBall(c, rd, sceneT, P1.xyz, tick >= dive ? 0.8 : 0.45, P1.w, time);
    // Comet trail behind the caster while it flies.
    if (tick > launch && tick < impactAt + 1.0 && P2.w > 0.05) {
        // The trail streams from behind the body (the feet), so the flying body itself stays visible.
        vec3 head = feet + vec3(0.0, 0.2, 0.0) - normalize(P2.xyz) * 0.4;
        float len = tick >= dive ? 16.0 : 7.0;
        vec3 tail = head - normalize(P2.xyz) * len;
        float t, s;
        float d = raySeg(rd, head, tail, t, s);
        if (t > 0.0 && t < sceneT + 2.0) {
            float r = (tick >= dive ? 1.0 : 0.6) * pow(1.0 - s, 0.7) + 0.1;
            vec3 q = rd * t;
            float n = fbm3(q * 1.4 + vec3(0.0, 0.0, time * 9.0));
            float i = (1.0 - d / r) * 1.15 + (n - 0.5) * 1.1 - s * 0.35;
            float m = celMask(i);
            if (m > 0.0) {
                vec3 col = cel(i, FIRE_CORE, FIRE_MID, FIRE_EDGE);
                paint(c, col, m * 0.9);
                emit(c, col * 0.25 * m, m);
            }
        }
    }
    // Impact.
    float k = (tick - impactAt) / 20.0;
    if (k < 0.0) return;
    if (!sky) groundImpact(c, surface, Target, k, 14.0, 28.0, 0.9, 5.0, seed);
    float rr = 28.0 * (1.0 - pow(1.0 - saturate(k / 0.9), 3.0));
    dustWall(c, rd, sceneT, Target, rr, 5.0 * (1.0 - saturate(k / 1.6)), 1.0 - smoothstep(0.6, 1.6, k), seed);
    // Fire dome.
    float Rd = 9.0 * (1.0 - pow(1.0 - saturate(k / 0.35), 3.0)) + 0.1;
    float domeA = 1.0 - smoothstep(0.25, 0.8, k);
    if (domeA > 0.0) {
        vec2 hit = raySphere(rd, Target, Rd);
        if (hit.x > 0.0 && hit.x < sceneT) {
            vec3 p = rd * hit.x - Target;
            vec3 nrm = normalize(p);
            float rim = 1.0 - abs(dot(nrm, rd));
            float n = fbm3(p * 0.6 + vec3(0.0, -k * 6.0, 0.0));
            float i = (rim * rim * 1.5 + (n - 0.5) * 0.7) * domeA;
            float m = celMask(i) * step(-0.5, p.y);
            vec3 col = cel(i, FIRE_CORE, FIRE_MID, FIRE_EDGE);
            paint(c, col, m * 0.7);
            emit(c, col * 0.3 * m, m);
        }
    }
    // Light pillar.
    if (k < 0.35) {
        float t, s;
        float d = raySeg(rd, Target, Target + vec3(0.0, 40.0, 0.0), t, s);
        if (t < sceneT + 2.0) {
            float w = 2.4 * (1.0 - k / 0.35) * (1.0 - 0.5 * s);
            float core = ink(d, w, t);
            emit(c, vec3(1.0, 0.95, 0.85) * core + FIRE_MID * halo(d, w * 2.0 + 0.1) * 0.5, core);
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
        rush(c, rd, sceneT, surface, sky);
    } else if (mode == 2) {
        quake(c, rd, sceneT, surface, sky);
    } else if (mode == 3) {
        meteor(c, rd, sceneT, surface, sky);
    }
    fragColor = c;
}
