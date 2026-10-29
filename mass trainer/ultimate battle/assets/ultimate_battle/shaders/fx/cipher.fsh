// Cipher effects: crisp red lasers, dark dash trails with a red rim and targeting sparks; for Orbital Lock also the
// scan ring with its hex grid on the ground and the orbital beam. Lines stay sharp and the bloom low.
//
// P0 = (mode, ticks, primitive count, -). Pts holds up to 12 primitives, two vec4s each:
//   (a.xyz, r) (b.xyz, k)   r > 0: laser from a to b, radius r, strength k
//                           r < 0: dash trail from a to b (head at b), half-width -r, strength k
//                           a == b: targeting spark at a, size r, k = its age 0..1
// Mode 2 (Orbital Lock) adds P1 = (ring centre, ring radius), P2 = (ring, grid, beam strength, beam radius),
// P3 = (beam foot, beam height).

const vec3 RED = vec3(1.0, 0.10, 0.15);
const vec3 HOT = vec3(1.0, 0.86, 0.84);
const vec3 DEEP = vec3(0.32, 0.01, 0.04);
const vec3 GUN = vec3(0.045, 0.045, 0.055);

vec3 camRight() { return normalize((InvView * vec4(1.0, 0.0, 0.0, 0.0)).xyz); }
vec3 camUp() { return normalize((InvView * vec4(0.0, 1.0, 0.0, 0.0)).xyz); }

void laser(inout vec4 c, vec3 rd, float sceneT, vec3 a, vec3 b, float r, float k) {
    float t, s;
    float d = raySeg(rd, a, b, t, s);
    if (t <= 0.0 || t > sceneT + r) return;
    // A beam brushing past the lens would cover the screen: fade it out right in front of the camera.
    k *= smoothstep(0.4, 1.4, t);
    if (k <= 0.001) return;
    float body = ink(d, r, t);
    float core = ink(d, r * 0.42, t);
    paint(c, mix(RED, HOT, core), body * k);
    c.rgb += RED * halo(d, r * 2.0) * 0.12 * k;
    c.a = max(c.a, body * k * 0.45);
}

void trail(inout vec4 c, vec3 rd, float sceneT, vec3 a, vec3 b, float w, float k) {
    float t, s;
    float d = raySeg(rd, a, b, t, s);
    if (t <= 0.0 || t > sceneT + 0.3) return;
    k *= smoothstep(0.4, 1.4, t);
    float ww = w * (0.25 + 0.75 * s);
    float core = ink(d, ww, t);
    float rim = saturate(ink(d, ww * 1.5 + 0.012, t) - core);
    float fade = k * (0.3 + 0.7 * s);
    paint(c, GUN, core * fade);
    paint(c, RED, rim * fade);
}

void spark(inout vec4 c, vec3 rd, float sceneT, vec3 p, float size, float k) {
    if (k < 0.0 || k > 1.0) return;
    float tp;
    float d = rayPoint(rd, p, tp);
    // Behind (or right at) the camera the distance means nothing: drawing it there filled half the screen red.
    if (tp <= 0.05 || tp > sceneT + size) return;
    k = 1.0 - (1.0 - k) * smoothstep(0.4, 1.4, tp);
    if (k >= 1.0) return;
    float rr = size * (0.25 + sqrt(k));
    float ring = ink(abs(d - rr), 0.022 * (1.0 - k) + 0.004, tp) * (1.0 - k);
    vec3 v = rd * tp - p;
    float ang = atan(dot(v, camUp()), dot(v, camRight()));
    // Four hairline spikes like a sight's crosshair.
    float spike = pow(abs(cos(ang * 2.0)), 120.0) * smoothstep(rr * 1.8, rr * 0.35, d) * step(rr * 0.3, d) * (1.0 - k);
    float flash = exp(-d / (size * 0.12)) * exp(-k * 9.0);
    paint(c, mix(RED, HOT, saturate(flash * 2.0)), saturate(ring + spike + flash));
}

// Distance to the nearest edge of a hex cell (cells one unit across).
float hexEdge(vec2 p) {
    const vec2 s = vec2(1.0, 1.7320508);
    vec4 hc = floor(vec4(p, p - vec2(0.5, 1.0)) / s.xyxy) + 0.5;
    vec4 h = vec4(p - hc.xy * s, p - (hc.zw + 0.5) * s);
    vec2 g = dot(h.xy, h.xy) < dot(h.zw, h.zw) ? h.xy : h.zw;
    vec2 a = abs(g);
    return 0.5 - max(dot(a, s * 0.5), a.x);
}

// The scan on the ground: a sharp red front, a dim wake behind it and a hex grid over what it has swept.
// Only on upward-facing surfaces near the ring's height, so it never paints legs or walls.
void scan(inout vec4 c, vec3 surface, bool sky, float sceneT) {
    if (sky || P2.x + P2.y <= 0.001) return;
    vec3 q = surface - P1.xyz;
    if (abs(q.y) > 2.5) return;
    vec3 n = normalize(cross(dFdx(surface), dFdy(surface)));
    if (abs(n.y) < 0.75) return;
    float dist = length(q.xz);
    float R = P1.w;
    float inside = step(dist, R);
    float front = ink(abs(dist - R), 0.07, sceneT) * P2.x;
    float wake = exp(-(R - dist) * 0.9) * inside * 0.45 * P2.x;
    float cell = hexEdge(q.xz / 1.3) * 1.3;
    float grid = ink(cell, 0.018, sceneT) * inside * P2.y * (0.35 + 0.65 * exp(-(R - dist) * 0.25));
    c.rgb = mix(c.rgb, c.rgb * 0.55 + DEEP * 0.6, wake * 0.6);
    paint(c, RED, saturate(grid * 0.7 + wake * 0.35));
    paint(c, mix(RED, HOT, 0.35), front);
}

// The orbital beam: a red column with a white-hot core, rings running down it, from the sky to its foot.
void beam(inout vec4 c, vec3 rd, float sceneT, vec3 foot, float h, float r, float k) {
    if (k <= 0.001 || r <= 0.0) return;
    float t, s;
    float d = raySeg(rd, foot, foot + vec3(0.0, h, 0.0), t, s);
    if (t <= 0.0 || t > sceneT + r) return;
    k *= smoothstep(0.5, 2.0, t);
    float y = s * h;
    float rr = r * (0.92 + 0.08 * sin(y * 1.7 - P0.y * 2.3));
    float body = ink(d, rr, t);
    float core = ink(d, rr * 0.48, t);
    float seam = ink(abs(d - rr * 0.78), 0.025, t);
    float ringY = fract(y * 0.11 + P0.y * 0.16);
    float rings = smoothstep(0.93, 1.0, ringY) * ink(abs(d - rr * 1.12), 0.05, t);
    vec3 col = mix(RED, HOT, core);
    col = mix(col, DEEP, seam * (1.0 - core) * 0.8);
    paint(c, col, body * k);
    paint(c, RED, rings * k);
    c.rgb += RED * halo(d, rr * 1.6) * 0.18 * k;
    c.a = max(c.a, body * k * 0.55);
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
    if (mode == 2) {
        scan(c, surface, sky, sceneT);
        beam(c, rd, sceneT, P3.xyz, P3.w, P2.w, P2.z);
    }
    int n = int(P0.z + 0.5);
    for (int i = 0; i < 12; i++) {
        if (i >= n) break;
        vec4 A = Pts[i * 2];
        vec4 B = Pts[i * 2 + 1];
        if (B.w <= 0.0 && A.w > 0.0 && distance(A.xyz, B.xyz) > 1e-4) continue;
        if (distance(A.xyz, B.xyz) < 1e-4) {
            spark(c, rd, sceneT, A.xyz, A.w, B.w);
        } else if (A.w > 0.0) {
            laser(c, rd, sceneT, A.xyz, B.xyz, A.w, B.w);
        } else {
            trail(c, rd, sceneT, A.xyz, B.xyz, -A.w, B.w);
        }
    }
    fragColor = c;
}
