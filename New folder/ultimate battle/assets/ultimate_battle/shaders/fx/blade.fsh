// Blade effects. P0.x picks the skill: 1 Iai Flash, 2 Crescent Wave, 3 Thousand Cuts.

const vec3 CRIMSON = vec3(1.0, 0.13, 0.24);
const vec3 STEEL = vec3(0.78, 0.92, 1.0);

// One crisp cut: white ink core with a thin coloured rim. Returns (light, mask) through c.
void cut(inout vec4 c, vec3 rd, float sceneT, vec3 a, vec3 b, float w, float rim, vec3 tint, float alpha) {
    float t, s;
    float d = raySeg(rd, a, b, t, s);
    if (t <= 0.0 || t > sceneT + 0.25 || alpha <= 0.001) return;
    float taper = sqrt(max(sin(PI * s), 0.0));
    float core = ink(d, w * taper, t);
    float glow = exp(-d / max(rim * (0.4 + 0.6 * taper), 1e-3)) * 0.45;
    emit(c, (vec3(1.0) * core + tint * glow) * alpha, (core + glow * 0.5) * alpha);
}

void iai(inout vec4 c, vec3 rd, float sceneT) {
    float t = P0.y;
    float draw = saturate(t / 0.07);
    vec3 a = Origin;
    vec3 b = mix(Origin, Target, draw);
    float fade = 1.0 - smoothstep(0.32, 0.8, t);
    // Motion smear left by the blink.
    float tr, s;
    float d = raySeg(rd, a, b, tr, s);
    if (tr > 0.0 && tr < sceneT + 0.25) {
        float smear = exp(-d / 0.25) * (1.0 - smoothstep(0.0, 0.3, t)) * 0.3;
        emit(c, STEEL * smear, smear);
        // The cut line breaks into fragments as it fades.
        float frag = step(hash12(vec2(floor(s * 34.0), P0.w)), 1.0 - saturate((t - 0.3) * 2.2));
        float core = ink(d, 0.028 * sqrt(max(sin(PI * s), 0.0)), tr) * frag * fade;
        float glow = exp(-d / 0.05) * 0.45 * fade * frag;
        emit(c, vec3(1.0) * core + CRIMSON * glow, core + glow * 0.5);
    }
    // The delayed X cut across the target.
    if (P1.w > 0.5) {
        float k = t - P0.z;
        if (k > 0.0 && k < 0.7) {
            vec3 right = normalize(cross(Facing, vec3(0.0, 1.0, 0.0)));
            vec3 up = vec3(0.0, 1.0, 0.0);
            float grow = saturate(k / 0.05);
            float alpha = 1.0 - smoothstep(0.25, 0.7, k);
            float spread = 0.08 * smoothstep(0.1, 0.5, k);
            for (int i = 0; i < 2; i++) {
                float sgn = i == 0 ? 1.0 : -1.0;
                vec3 dir = normalize(right * 0.85 + up * 0.55 * sgn + Facing * 0.15);
                vec3 off = cross(dir, Facing) * spread;
                vec3 a0 = P1.xyz - dir * 1.3 * grow;
                vec3 b0 = P1.xyz + dir * 1.3 * grow;
                cut(c, rd, sceneT, a0 + off, b0 + off, 0.03, 0.12, CRIMSON, alpha);
                cut(c, rd, sceneT, a0 - off, b0 - off, 0.02, 0.08, CRIMSON, alpha * step(0.08, k));
            }
            float flash = exp(-k * 14.0);
            float tp;
            float dp = rayPoint(rd, P1.xyz, tp);
            float spark = exp(-dp / 0.12) * flash;
            if (tp < sceneT + 1.0) emit(c, vec3(1.0, 0.8, 0.85) * spark, spark);
        }
    }
}

void crescent(inout vec4 c, vec3 rd, float sceneT, vec3 surface, bool sky) {
    float t = P0.y;
    float speed = P0.z;
    float flight = P0.w;
    if (t < 0.0) return;
    vec3 f = normalize(Facing);
    vec3 right = normalize(cross(f, vec3(0.0, 1.0, 0.0)));
    vec3 up = normalize(cross(right, f));
    // The arc stands across the flight path (a diagonal arch flying away), so it faces whoever threw it.
    float tilt = 0.45;
    vec3 e1 = right * cos(tilt) + up * sin(tilt);
    vec3 e2 = up * cos(tilt) - right * sin(tilt);
    vec3 center = Origin + f * speed * min(t, flight);
    float grow = 0.45 + 0.55 * smoothstep(0.0, 0.12, t);
    float alpha = 1.0 - smoothstep(flight - 0.15, flight + 0.1, t);

    float tp = rayPlane(rd, center, f);
    if (tp <= 0.0 || tp > sceneT + 0.2 || alpha <= 0.0) return;
    vec3 p = rd * tp - center;
    vec2 q = vec2(dot(p, e1), dot(p, e2)) / grow;
    float R = 3.6;
    vec2 ac = vec2(0.0, -R * 0.7);
    vec2 rel = q - ac;
    float r = length(rel);
    float ang = atan(rel.x, rel.y);
    float extent = 1.05;
    if (abs(ang) > extent) return;
    float u = ang / extent;
    float thick = 0.75 * (1.0 - u * u);
    float inside = (R - r) / max(thick, 1e-3);
    if (inside < -0.15 || inside > 1.0) return;
    float i = saturate(1.0 - inside);
    // Streaks trailing behind the edge.
    float streak = vnoise2(vec2(u * 16.0, r * 2.0 - t * 30.0));
    i = i * (0.8 + 0.4 * streak);
    vec3 col = cel(i, vec3(1.0), vec3(0.55, 0.92, 1.0), vec3(0.1, 0.35, 0.95));
    float m = celMask(i) * alpha;
    paint(c, col, m * 0.92);
    emit(c, col * 0.25 * m, m);
}

void thousandCuts(inout vec4 c, vec3 rd, float sceneT, vec2 uv) {
    float t = P0.y;
    float seed = P0.z;
    float cs = P2.x, ce = P2.y, click = P2.z, boom = P2.w;
    float k = t - boom;

    // Eye glint at the start.
    if (t < 0.9) {
        vec3 e = project(P3.xyz);
        if (e.z > 0.0) {
            float aspect = OutSize.x / OutSize.y;
            vec2 q = (uv - e.xy) * vec2(aspect, 1.0);
            float env = smoothstep(0.15, 0.3, t) * (1.0 - smoothstep(0.5, 0.85, t));
            vec2 r1 = rot(0.3) * q;
            float star = exp(-abs(r1.y) * 900.0) * exp(-abs(r1.x) * 9.0) + exp(-abs(r1.x) * 900.0) * exp(-abs(r1.y) * 16.0) * 0.6;
            star += halo(length(q), 0.004) * 1.5;
            emit(c, mix(vec3(1.0), CRIMSON, 0.25) * star * env * 1.5, star * env);
        }
    }

    // The vanish streak.
    float kv = t - P1.w;
    if (kv > 0.0 && kv < 0.5) {
        float a = 1.0 - smoothstep(0.1, 0.5, kv);
        cut(c, rd, sceneT, Origin, P1.xyz, 0.02, 0.35, STEEL, a);
    }

    // The cuts, drawn one after another while the world is stopped, all opening red at the boom.
    const int N = 40;
    for (int i = 0; i < N; i++) {
        float fi = float(i);
        float ti = cs + (ce - cs) * fi / float(N);
        if (t < ti) break;
        vec3 h = hash31(fi * 1.37 + seed);
        vec3 center = Target + (h - 0.5) * vec3(2.8, 2.4, 2.8);
        vec3 dir = normalize(hash31(fi * 7.31 + seed * 3.1) - 0.5);
        float len = 1.6 + 2.4 * hash11(fi * 3.7 + seed);
        float draw = saturate((t - ti) / 0.05);
        vec3 a = center - dir * len * 0.5;
        vec3 b = a + dir * len * draw;
        if (k < 0.0) {
            cut(c, rd, sceneT, a, b, 0.01, 0.015, STEEL, 0.85);
        } else {
            float alpha = 1.0 - smoothstep(0.25, 1.0 + 0.4 * h.x, k);
            float w = 0.012 + 0.07 * exp(-k * 5.0);
            vec3 off = normalize(cross(dir, vec3(0.3, 1.0, 0.2))) * 0.12 * smoothstep(0.0, 0.5, k);
            cut(c, rd, sceneT, a + off, b + off, w, 0.08, CRIMSON, alpha);
        }
    }

    // Sheath click: a thin ring snaps out round the caster's hip.
    float kc = t - click;
    if (kc > 0.0 && kc < 0.35) {
        vec3 hip = P1.xyz - vec3(0.0, 0.35, 0.0);
        float tp = rayPlane(rd, hip, vec3(0.0, 1.0, 0.0));
        if (tp > 0.0 && tp < sceneT + 0.2) {
            float r = length(rd * tp - hip);
            float rr = 0.3 + 1.6 * sqrt(kc / 0.35);
            float ring = ink(abs(r - rr), 0.015, tp) * (1.0 - kc / 0.35);
            emit(c, vec3(1.0) * ring, ring);
        }
    }

    // Finisher: a giant X across the target.
    if (k > 0.0 && k < 1.4) {
        vec3 right = normalize(cross(Facing, vec3(0.0, 1.0, 0.0)));
        float grow = saturate(k / 0.06);
        float alpha = 1.0 - smoothstep(0.4, 1.4, k);
        for (int i = 0; i < 2; i++) {
            float sgn = i == 0 ? 1.0 : -1.0;
            vec3 dir = normalize(right + vec3(0.0, 0.8 * sgn, 0.0));
            cut(c, rd, sceneT + 2.0, Target - dir * 7.0 * grow, Target + dir * 7.0 * grow, 0.05 * (1.0 - 0.6 * saturate(k)), 0.18, CRIMSON, alpha);
        }
        float tp;
        float dp = rayPoint(rd, Target, tp);
        float flash = exp(-k * 7.0);
        float burst = exp(-dp / 0.45) * flash;
        emit(c, mix(CRIMSON, vec3(1.0), 0.4) * burst, burst);
    }
}

void main() {
    vec2 uv = texCoord;
    initPixel(uv);
    vec4 c = baseColor(uv);
    vec3 rd = viewDir(uv);
    float sceneT = sceneDist(uv);
    int mode = int(P0.x + 0.5);
    if (mode == 1) {
        iai(c, rd, sceneT);
    } else if (mode == 2) {
        crescent(c, rd, sceneT, scenePos(uv), sceneT >= FAR);
    } else if (mode == 3) {
        thousandCuts(c, rd, sceneT, uv);
    }
    fragColor = c;
}
