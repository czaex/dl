// Ki effects. P0.x picks the skill: 1 Ki Barrage, 2 Aura Burst, 3 Spirit Cannon.

const vec3 KI_CORE = vec3(0.95, 1.0, 1.0);
const vec3 KI_MID = vec3(0.35, 0.82, 1.0);
const vec3 KI_EDGE = vec3(0.08, 0.3, 0.95);

// Cel-shaded glowing ball (camera-facing), with flickering surface.
void orb(inout vec4 c, vec3 rd, float sceneT, vec3 pos, float radius, float flicker) {
    float tp;
    float d = rayPoint(rd, pos, tp);
    if (tp <= 0.0 || tp > sceneT + radius || d > radius * 2.2) return;
    float n = vnoise2(vec2(atan(dot(rd * tp - pos, vec3(0.0, 1.0, 0.0)), d) * 5.0, GTime * 18.0 + flicker));
    float i = (1.0 - d / radius) * 1.15 + (n - 0.5) * 0.25;
    float m = celMask(i);
    vec3 col = cel(i, KI_CORE, KI_MID, KI_EDGE);
    paint(c, col, m);
    float glow = exp(-max(d - radius, 0.0) / (radius * 0.5)) * 0.3 * (1.0 - m);
    emit(c, col * 0.3 * m + KI_MID * glow, max(m, glow));
}

// Jagged lightning between a and b.
void bolt(inout vec4 c, vec3 rd, float sceneT, vec3 a, vec3 b, float amp, float seed, float alpha) {
    if (alpha <= 0.001) return;
    vec3 prev = a;
    float best = 1e9;
    float bestT = 0.0;
    for (int k = 1; k <= 6; k++) {
        float f = float(k) / 6.0;
        vec3 p = mix(a, b, f);
        if (k < 6) p += (hash31(seed + float(k) * 3.7) - 0.5) * amp;
        float t, s;
        float d = raySeg(rd, prev, p, t, s);
        if (d < best) { best = d; bestT = t; }
        prev = p;
    }
    if (bestT <= 0.0 || bestT > sceneT + 0.5) return;
    float core = ink(best, 0.012, bestT);
    float glow = halo(best, 0.06) * 0.6;
    emit(c, (vec3(1.0) * core + KI_MID * glow) * alpha, (core + glow) * alpha);
}

// Blue cel flame around the body.
void aura(inout vec4 c, vec3 rd, float sceneT, vec3 feet, float radius, float power, float time) {
    if (power <= 0.001 || cameraInside(feet, 2.3, radius)) return;
    float t, s;
    float d = raySeg(rd, feet + vec3(0.0, 0.05, 0.0), feet + vec3(0.0, 2.3, 0.0), t, s);
    if (d > radius * 1.6 || t <= 0.0 || t > sceneT + radius) return;
    vec3 q = rd * t - feet;
    float n = fbm3(vec3(q.x * 2.4, q.y * 1.1 - time * 5.5, q.z * 2.4));
    float i = ((1.0 - d / (radius * (1.0 - 0.3 * s))) * 1.0 + (n - 0.5) * 1.7 - 0.12) * power;
    float m = celMask(i);
    if (m <= 0.0) return;
    vec3 col = cel(i, KI_CORE, KI_MID, KI_EDGE);
    paint(c, col, m * 0.5);
    emit(c, col * 0.25 * m, m);
}

void shell(inout vec4 c, vec3 rd, float sceneT, vec3 center, float radius, float alpha, float time) {
    if (alpha <= 0.001) return;
    vec2 hit = raySphere(rd, center, radius);
    if (hit.x <= 0.0 || hit.x > sceneT) return;
    vec3 p = rd * hit.x - center;
    float rim = 1.0 - abs(dot(normalize(p), rd));
    float n = fbm3(p * 0.9 + vec3(0.0, time * 3.0, 0.0));
    float i = (rim * 1.2 + (n - 0.5) * 0.6) * alpha;
    float m = celMask(i);
    vec3 col = cel(i, KI_CORE, KI_MID, KI_EDGE);
    paint(c, col, m * 0.75);
    emit(c, col * 0.3 * m, m);
}

void barrage(inout vec4 c, vec3 rd, float sceneT) {
    for (int i = 0; i < 12; i++) {
        vec4 o = Pts[i * 2];
        vec4 tr = Pts[i * 2 + 1];
        if (o.w > 0.0) {
            // Trail.
            float t, s;
            float d = raySeg(rd, tr.xyz, o.xyz, t, s);
            if (t > 0.0 && t < sceneT + 0.5) {
                float i2 = (1.0 - d / (o.w * 0.75 * s + 0.02)) * s;
                float m = celMask(i2) * 0.85;
                paint(c, cel(i2, KI_CORE, KI_MID, KI_EDGE), m);
                c.a = max(c.a, m);
            }
            orb(c, rd, sceneT, o.xyz, o.w, float(i));
        }
        if (tr.w >= 0.0 && tr.w < 0.35) {
            float k = tr.w / 0.35;
            shell(c, rd, sceneT, o.xyz, 0.3 + 1.6 * sqrt(k), 1.0 - k, GTime);
            float tp;
            float d = rayPoint(rd, o.xyz, tp);
            float flash = exp(-tr.w * 20.0) * exp(-d / 0.3);
            if (tp < sceneT + 1.0) emit(c, vec3(1.0) * flash, flash);
        }
    }
}

void burst(inout vec4 c, vec3 rd, float sceneT, vec3 surface, bool sky) {
    float t = P0.y;
    float at = P0.z;
    float time = t;
    vec3 feet = Caster;
    if (t < at + 0.15) {
        aura(c, rd, sceneT, feet, 1.1, 0.6 + 0.6 * t / at, time);
        for (int i = 0; i < 4; i++) {
            float seed = floor(GTime * 14.0) * 7.0 + float(i) * 13.0 + P0.w;
            vec3 a = feet + vec3(0.0, 1.0 + 0.6 * (hash11(seed) - 0.5), 0.0);
            vec3 b = a + (hash31(seed + 1.0) - 0.5) * vec3(3.0, 2.0, 3.0);
            bolt(c, rd, sceneT, a, b, 0.5, seed, step(0.4, hash11(seed + 5.0)));
        }
    }
    float k = t - at;
    if (k > 0.0) {
        float R = P1.x;
        float r = R * (1.0 - pow(1.0 - saturate(k / 0.3), 3.0)) + 0.2;
        shell(c, rd, sceneT, feet + vec3(0.0, 1.0, 0.0), r, 1.0 - smoothstep(0.15, 0.55, k), time);
        if (!sky) {
            vec3 q = surface - feet;
            float rr = length(q.xz);
            float ring = (1.0 - smoothstep(0.1, 0.45, abs(rr - r * 1.15))) * (1.0 - smoothstep(0.2, 0.6, k)) * step(abs(q.y), 2.5);
            emit(c, KI_MID * ring * 1.3, ring);
        }
        float tp;
        float d = rayPoint(rd, feet + vec3(0.0, 1.0, 0.0), tp);
        float flash = exp(-k * 12.0) * exp(-d / 0.6);
        if (tp < sceneT + 1.0) emit(c, vec3(1.0) * flash, flash);
    }
}

void cannon(inout vec4 c, vec3 rd, float sceneT) {
    float tick = P0.y;
    float seed = P0.z;
    float time = tick / 20.0;
    float orbR = P1.x;
    float grow = P1.y;
    float beamR = P1.z;
    float beamA = P1.w;
    float charge = P2.y;
    vec3 hand = Origin;

    aura(c, rd, sceneT, Caster, 1.2, charge * 1.2, time);
    if (orbR > 0.01) {
        orb(c, rd, sceneT, hand, orbR, seed);
        for (int i = 0; i < 5; i++) {
            float s = floor(GTime * 16.0) * 5.0 + float(i) * 17.0 + seed;
            vec3 dir = normalize(hash31(s) - 0.5);
            bolt(c, rd, sceneT, hand + dir * orbR * 0.6, hand + dir * orbR * (2.0 + 1.5 * hash11(s + 2.0)), orbR * 0.6, s,
                step(0.35, hash11(s + 9.0)) * saturate(charge * 1.5));
        }
    }

    if (grow > 0.0 && beamA > 0.0) {
        vec3 dir = normalize(Facing);
        float len = length(Target - hand) * grow;
        vec3 tip = hand + dir * len;
        float t, s;
        float d = raySeg(rd, hand, tip, t, s);
        if (t > 0.0 && t < sceneT + beamR * 1.5) {
            float along = s * len;
            float wobble = 1.0 + 0.12 * sin(along * 0.7 - time * 40.0) + 0.06 * sin(along * 2.3 + time * 25.0);
            float bulb = 1.0 + 0.6 * exp(-along * 0.4);
            float R = beamR * wobble * bulb * beamA;
            float i = (1.0 - d / R) * 1.2;
            float m = celMask(i);
            vec3 col = cel(i, KI_CORE, KI_MID, KI_EDGE);
            paint(c, col, m);
            emit(c, col * 0.35 * m, m);
            // Spiral sheath rings sliding along the beam.
            float ringR = R * 1.35;
            float band = abs(fract(along / 3.2 - time * 3.5) - 0.5);
            float ring = (1.0 - smoothstep(0.02, 0.06, band)) * (1.0 - smoothstep(0.05, 0.25, abs(d - ringR)));
            emit(c, KI_MID * ring * 0.9 * beamA, ring * beamA);
            float glow = halo(d, R * 1.6) * 0.25 * beamA;
            emit(c, KI_MID * glow, glow);
        }
    }

    // Explosion where the beam lands.
    float k = P2.x;
    if (k >= 0.0) {
        float r = 7.0 * (1.0 - pow(1.0 - saturate(k / 0.4), 3.0)) + 0.5 * sin(GTime * 30.0) * step(k, 2.5);
        float alpha = 1.0 - smoothstep(2.6, 3.3, k);
        shell(c, rd, sceneT + 4.0, Target, r, alpha, time);
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
        barrage(c, rd, sceneT);
    } else if (mode == 2) {
        burst(c, rd, sceneT, surface, sky);
    } else if (mode == 3) {
        cannon(c, rd, sceneT);
    }
    fragColor = c;
}
