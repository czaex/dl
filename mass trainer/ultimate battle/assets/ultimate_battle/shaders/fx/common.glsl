#version 150

// Shared by every Ultimate Battle pass. World positions are camera-relative; Minecraft 26 uses reversed Z
// (depth 0 = sky / far plane).

uniform sampler2D DiffuseSampler;
uniform sampler2D DepthSampler;
uniform sampler2D SceneSampler;
uniform mat4 InvProj;
uniform mat4 InvView;
uniform mat4 ViewProj;
uniform vec2 OutSize;
uniform float GTime;
uniform float DepthZeroToOne;
uniform float FirstPass;

uniform float Time;
uniform vec3 Origin;
uniform vec3 Target;
uniform vec3 Caster;
uniform vec3 Facing;
uniform vec4 P0;
uniform vec4 P1;
uniform vec4 P2;
uniform vec4 P3;
uniform vec4 Pts[24];

in vec2 texCoord;
out vec4 fragColor;

#define PI 3.14159265
#define TAU 6.28318531
#define FAR 100000.0

vec3 unproject(vec2 uv, float depth) {
    vec4 v = InvProj * vec4(uv * 2.0 - 1.0, DepthZeroToOne > 0.5 ? depth : depth * 2.0 - 1.0, 1.0);
    v.xyz /= v.w;
    return (InvView * vec4(v.xyz, 1.0)).xyz;
}

vec3 viewDir(vec2 uv) {
    return normalize(unproject(uv, 0.0) - unproject(uv, 1.0));
}

float rawDepth(vec2 uv) {
    return texture(DepthSampler, uv).r;
}

// Distance along the view ray to the scene (FAR for sky).
float sceneDist(vec2 uv) {
    float d = rawDepth(uv);
    if (d <= 0.00001) return FAR;
    return length(unproject(uv, d));
}

vec3 scenePos(vec2 uv) {
    float d = rawDepth(uv);
    if (d <= 0.00001) return viewDir(uv) * FAR;
    return unproject(uv, d);
}

vec3 project(vec3 p) {
    vec4 c = ViewProj * vec4(p, 1.0);
    if (c.w <= 0.0) return vec3(0.0, 0.0, -1.0);
    return vec3(c.xy / c.w * 0.5 + 0.5, c.w);
}

float saturate(float x) { return clamp(x, 0.0, 1.0); }
float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

float hash11(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

vec3 hash31(float p) {
    vec3 p3 = fract(vec3(p) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xxy + p3.yzz) * p3.zyx);
}

float hash13(vec3 p3) {
    p3 = fract(p3 * 0.1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}

float vnoise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash12(i), hash12(i + vec2(1, 0)), u.x), mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), u.x), u.y);
}

float vnoise3(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    vec3 u = f * f * (3.0 - 2.0 * f);
    float a = mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), u.x), mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), u.x), u.y);
    float b = mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), u.x), mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), u.x), u.y);
    return mix(a, b, u.z);
}

float fbm3(vec3 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * vnoise3(p);
        p = p * 2.02 + vec3(11.3, 5.7, 3.1);
        a *= 0.5;
    }
    return v;
}

// Distance between the view ray (from the camera) and segment a-b; t = ray distance of the closest point,
// s = 0..1 position of that point along the segment.
float raySeg(vec3 rd, vec3 a, vec3 b, out float t, out float s) {
    vec3 ba = b - a;
    vec3 oa = -a;
    float baba = dot(ba, ba);
    float bard = dot(ba, rd);
    float baoa = dot(ba, oa);
    float rdoa = dot(rd, oa);
    float denom = baba - bard * bard;
    s = denom > 1e-6 ? saturate((baoa - bard * rdoa) / denom) : 0.0;
    vec3 q = a + ba * s;
    t = max(dot(q, rd), 0.0);
    return length(rd * t - q);
}

float rayPoint(vec3 rd, vec3 p, out float t) {
    t = max(dot(p, rd), 0.0);
    return length(rd * t - p);
}

vec2 raySphere(vec3 rd, vec3 c, float r) {
    float b = dot(-c, rd);
    float h = b * b - dot(c, c) + r * r;
    if (h < 0.0) return vec2(-1.0);
    h = sqrt(h);
    return vec2(-b - h, -b + h);
}

float rayPlane(vec3 rd, vec3 c, vec3 n) {
    float d = dot(rd, n);
    if (abs(d) < 1e-6) return -1.0;
    return dot(c, n) / d;
}

// World size of one pixel at distance 1 (set by initPixel); used to keep thin lines crisp, never sub-pixel.
float gPix = 0.001;

void initPixel(vec2 uv) {
    gPix = length(viewDir(uv + vec2(0.0, 1.0 / OutSize.y)) - viewDir(uv));
}

// Crisp line of half-width w (world units) at ray distance t, antialiased to one pixel.
float ink(float d, float w, float t) {
    float aa = gPix * t * 0.75;
    w = max(w, aa * 0.6);
    return smoothstep(w + aa, w - aa, d);
}

float halo(float d, float w) {
    return w * w / (d * d + w * w);
}

// Cel shading: snaps a 0..1 intensity to flat anime bands (white core, colour, deep edge).
vec3 cel(float i, vec3 core, vec3 mid, vec3 edge) {
    float a = 0.015;
    vec3 c = edge * smoothstep(0.08 - a, 0.08 + a, i);
    c = mix(c, mid, smoothstep(0.38 - a, 0.38 + a, i));
    c = mix(c, core, smoothstep(0.72 - a, 0.72 + a, i));
    return c;
}

float celMask(float i) {
    return smoothstep(0.065, 0.095, i);
}

// Voronoi edge distance (for cracked ground).
float crackDist(vec2 p, float seed) {
    vec2 n = floor(p);
    vec2 f = fract(p);
    vec2 mg, mr;
    float md = 8.0;
    for (int j = -1; j <= 1; j++)
    for (int i = -1; i <= 1; i++) {
        vec2 g = vec2(float(i), float(j));
        vec2 o = hash22(n + g + seed);
        vec2 r = g + o - f;
        float d = dot(r, r);
        if (d < md) { md = d; mr = r; mg = g; }
    }
    md = 8.0;
    for (int j = -2; j <= 2; j++)
    for (int i = -2; i <= 2; i++) {
        vec2 g = mg + vec2(float(i), float(j));
        vec2 o = hash22(n + g + seed);
        vec2 r = g + o - f;
        if (dot(mr - r, mr - r) > 0.00001) md = min(md, dot(0.5 * (mr + r), normalize(r - mr)));
    }
    return md;
}

// True when the camera sits inside a body-shaped volume (first person): auras around that body are skipped
// so they never wash over the caster's own view.
bool cameraInside(vec3 feet, float height, float radius) {
    vec3 a = feet;
    vec3 b = feet + vec3(0.0, height, 0.0);
    vec3 ba = b - a;
    float h = saturate(dot(-a, ba) / dot(ba, ba));
    return length(-a - ba * h) < radius + 0.35;
}

// Base colour for this pass (the scene on the first pass, the previous pass after that) and its glow mask.
vec4 baseColor(vec2 uv) {
    vec4 c = texture(DiffuseSampler, uv);
    if (FirstPass > 0.5) c.a = 0.0;
    return c;
}

// Adds emitted light; alpha keeps the strongest emission so bloom and the grey "stopped world" can find it.
void emit(inout vec4 c, vec3 light, float mask) {
    c.rgb += light;
    c.a = max(c.a, saturate(mask));
}

void paint(inout vec4 c, vec3 col, float a) {
    c.rgb = mix(c.rgb, col, saturate(a));
    c.a = max(c.a, saturate(a));
}
