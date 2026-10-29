#version 150

uniform sampler2D DiffuseSampler;
uniform sampler2D DepthSampler;
uniform sampler2D FogDataTexture; // 雾效数据纹理
uniform vec2 OutSize;
uniform vec3 CameraPos;
uniform mat4 InvProjMat;
uniform mat4 InvModelViewMat;

uniform int FogCount;

in vec3 vertPos;
in vec3 cameraPos;
flat in int fogIndex;
in vec2 texCoord;

out vec4 fragColor;

// 从纹理中读取雾效数据
vec4 getFogData(int fogIndex, int component) {
    float texX = (float(fogIndex) + 0.5) / 16.0; // 假设最多16个雾
    float texY = (float(component) + 0.5) / 4.0; // 0:位置,1:大小,2:颜色,3:参数
    return texture(FogDataTexture, vec2(texX, texY));
}

// 3D噪声函数（保持原样）
float hash(float n) {
    return fract(sin(n) * 43758.5453);
}

float noise3D(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);

    f = f * f * (3.0 - 2.0 * f);

    float n = i.x + i.y * 57.0 + i.z * 113.0;

    return mix(mix(mix(hash(n), hash(n + 1.0), f.x),
    mix(hash(n + 57.0), hash(n + 58.0), f.x), f.y),
    mix(mix(hash(n + 113.0), hash(n + 114.0), f.x),
    mix(hash(n + 170.0), hash(n + 171.0), f.x), f.y), f.z);
}

// 从深度重建世界位置（保持原样）
vec3 reconstructWorldPos(vec2 uv, float depth) {
    vec4 clipPos = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 worldPos = InvProjMat * clipPos;
    worldPos /= worldPos.w;
    worldPos = InvModelViewMat * worldPos;
    return worldPos.xyz;
}

void main() {
    // 如果雾索引无效，直接丢弃
    if (fogIndex < 0 || fogIndex >= FogCount) {
        discard;
        return;
    }

    // 从纹理中读取雾效数据
    vec3 fogPos = getFogData(fogIndex, 0).rgb;
    vec3 fogSize = getFogData(fogIndex, 1).rgb;
    vec4 fogColor = getFogData(fogIndex, 2);
    vec4 fogParams = getFogData(fogIndex, 3);

    // 计算在雾内的归一化距离
    vec3 localPos = (vertPos - fogPos) / fogSize;
    float dist = length(localPos);

    // 如果在雾的边界外，丢弃
    if (dist > 0.5) {
        discard;
        return;
    }

    // 边缘衰减
    float edgeFalloff = 1.0 - smoothstep(0.3, 0.5, dist);

    // 添加3D噪声
    float noiseScale = fogParams.y;
    float noiseIntensity = fogParams.z;
    float time = fogParams.w;

    vec3 noiseCoord = vertPos * noiseScale + vec3(time);
    float noise = noise3D(noiseCoord);
    noise = noise * 0.5 + 0.5; // 映射到 [0,1]

    // 计算最终密度
    float baseDensity = fogParams.x * edgeFalloff;
    float finalDensity = mix(baseDensity, noise, noiseIntensity * 0.5);
    finalDensity = clamp(finalDensity, 0.0, 1.0);

    // 如果密度太小，丢弃
    if (finalDensity < 0.01) {
        discard;
        return;
    }

    // 基于距离相机的衰减
    float distToCamera = distance(vertPos, CameraPos);
    float distanceFalloff = exp(-distToCamera * 0.01);
    finalDensity *= distanceFalloff;

    // 获取屏幕颜色
    vec2 screenCoord = gl_FragCoord.xy / OutSize;
    vec4 originalColor = texture(DiffuseSampler, screenCoord);

    // 获取深度信息用于后续混合
    float depth = texture(DepthSampler, screenCoord).r;
    vec3 worldPosFromDepth = reconstructWorldPos(screenCoord, depth);

    // 计算雾与场景的混合
    float fogAlpha = fogColor.a * finalDensity;

    // 简单的alpha混合
    vec3 finalRGB = mix(originalColor.rgb, fogColor.rgb, fogAlpha);

    // 添加颜色偏移（使雾更有气氛）
    finalRGB.r += fogAlpha * 0.1;
    finalRGB.g *= 1.0 - fogAlpha * 0.3;
    finalRGB.b *= 1.0 - fogAlpha * 0.4;

    // 输出最终颜色
    fragColor = vec4(finalRGB, originalColor.a);
}