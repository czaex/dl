#version 150

uniform sampler2D DiffuseSampler;
uniform sampler2D Mask;
uniform float DistortionStrength;
uniform float Time;
uniform vec2 Direction;

in vec2 texCoord;
out vec4 fragColor;

// 伪随机函数
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 random2(vec2 p) {
    return fract(
    sin(vec2(
    dot(p, vec2(127.1, 311.7)),
    dot(p, vec2(269.5, 183.3))
    )) * 43758.5453
    );
}

float perlinNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);

    // 四个角点的梯度
    vec2 grad00 = random2(i) * 2.0 - 1.0;
    vec2 grad10 = random2(i + vec2(1.0, 0.0)) * 2.0 - 1.0;
    vec2 grad01 = random2(i + vec2(0.0, 1.0)) * 2.0 - 1.0;
    vec2 grad11 = random2(i + vec2(1.0, 1.0)) * 2.0 - 1.0;

    // 距离向量
    vec2 dist00 = f;
    vec2 dist10 = f - vec2(1.0, 0.0);
    vec2 dist01 = f - vec2(0.0, 1.0);
    vec2 dist11 = f - vec2(1.0, 1.0);

    // 点乘
    float dot00 = dot(grad00, dist00);
    float dot10 = dot(grad10, dist10);
    float dot01 = dot(grad01, dist01);
    float dot11 = dot(grad11, dist11);

    // 平滑插值
    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(
    mix(dot00, dot10, u.x),
    mix(dot01, dot11, u.x),
    u.y
    ) * 0.5 + 0.5;
}

float fbm(vec2 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;

    for(int i = 0; i < octaves; i++) {
        value += amplitude * perlinNoise(frequency * p);
        amplitude *= 0.5;
        frequency *= 2.0;
    }

    return value;
}

// 湍流噪声
float turbulence(vec2 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;

    for(int i = 0; i < octaves; i++) {
        value += amplitude * abs(perlinNoise(frequency * p) - 0.5);
        amplitude *= 0.5;
        frequency *= 2.0;
    }

    return value;
}

void main() {
    // 获取原始颜色（未扭曲）
    vec4 originalColor = texture(DiffuseSampler, texCoord);
    vec4 mask = texture(Mask, texCoord);
    float alpha = mask.a;

    // 边缘羽化阈值 - 可以根据需要调整
    float featherStart = 0.2;
    float featherEnd = 0.8;
    float featherAlpha = smoothstep(featherStart, featherEnd, alpha);

    // 当alpha很低时直接返回原始颜色
    if (alpha < 0.001) {
        fragColor = originalColor;
        return;
    }

    // 计算增强的强度，但使用羽化后的alpha
    vec2 centerVec = texCoord - vec2(0.5);
    float centerDist = length(centerVec);

    // 更平滑的边缘衰减
    float edgeFalloff = 1.0 - smoothstep(0.0, 0.4, centerDist);
    float strength = DistortionStrength * featherAlpha * 0.18 * edgeFalloff;

    // 当强度很小时，减少效果强度以获得更平滑的过渡
    if (featherAlpha < 0.3) {
        strength *= featherAlpha * featherAlpha; // 平方衰减以获得更平滑的过渡
    }

    // 使用FBM噪声
    vec2 noiseCoord = texCoord * 4.0 + Time * 2.0;
    float fbmNoise = fbm(noiseCoord, 4) * 2.0 - 1.0;

    // 湍流噪声
    float turb = turbulence(texCoord * 8.0 + Time * 3.0, 3) * 0.5;

    // 多层热浪扰动
    float heatWave1 = sin(texCoord.x * 50.0 + texCoord.y * 30.0 + Time * 8.0 + fbmNoise) * strength;
    float heatWave2 = cos(texCoord.x * 40.0 - texCoord.y * 25.0 + Time * 6.0 + turb) * strength * 0.7;
    float heatWave3 = perlinNoise(texCoord * 15.0 + Time * 4.0) * strength * 0.8;

    // 高级噪声扰动
    float advancedNoiseDistort = fbm(texCoord * 12.0 + Time * 2.5, 3) * strength * 0.4;

    // 运动扭曲
    vec2 noiseMotion = vec2(
    perlinNoise(texCoord * 6.0 + Time * 3.0) - 0.5,
    perlinNoise(texCoord * 6.0 + Time * 3.0 + 100.0) - 0.5
    ) * strength * 0.2;

    vec2 motionDistortion = Direction * strength * 0.3 * (0.8 + 0.4 * sin(Time * 5.0)) + noiseMotion;

    // 组合所有扭曲效果
    vec2 totalDistortion = vec2(heatWave1 + heatWave3, heatWave2) +
    motionDistortion +
    vec2(advancedNoiseDistort);

    vec2 distortedCoord = texCoord + totalDistortion;

    // 色差效果 - 在边缘处减弱
    float chromaNoise = fbm(texCoord * 20.0 + Time, 2);
    float chromaStrength = strength * (0.01 + chromaNoise * 0.02) * smoothstep(0.1, 0.5, featherAlpha);

    vec2 chromaRed = totalDistortion * (1.02 + chromaNoise * 0.01) + vec2(chromaStrength, chromaStrength * 0.3);
    vec2 chromaBlue = totalDistortion * (0.98 - chromaNoise * 0.01) - vec2(chromaStrength, chromaStrength * 0.2);

    // 分别采样RGB通道
    vec4 baseColor = texture(DiffuseSampler, distortedCoord);
    float r = texture(DiffuseSampler, distortedCoord + chromaRed).r;
    float g = baseColor.g;
    float b = texture(DiffuseSampler, distortedCoord + chromaBlue).b;

    vec4 distortedColor = vec4(r, g, b, originalColor.a);

    // 亮度增强 - 在边缘处减弱
    float brightnessNoise = fbm(texCoord * 8.0 + Time * 2.0, 2);
    float brightnessBoost = 1.0 + strength * (0.3 + brightnessNoise * 0.2) * featherAlpha;
    distortedColor.rgb *= brightnessBoost;

    // 热浪颜色偏移
    float heatTurbulence = turbulence(texCoord * 10.0 + Time * 2.0, 2);
    float heatColorShift = strength * (0.01 + heatTurbulence * 0.02) * featherAlpha;

    distortedColor.r += heatColorShift * 0.75;
    distortedColor.g += heatColorShift * 0.15;
    distortedColor.b += heatColorShift * 0.9;

    // 动态边缘发光效果 - 在边缘处减弱
    float glowIntensity = fbm(centerVec * 12.0 + Time * 3.0, 2);
    float glow = smoothstep(0.0, 0.2, centerDist) * strength * (0.5 + glowIntensity * 0.3) * featherAlpha;

    vec3 glowColor = mix(vec3(0.3, 0.5, 0.8), vec3(0.8, 0.9, 1.0), glowIntensity);
    distortedColor.rgb += glowColor * glow;

    // 对比度增强 - 在边缘处减弱
    float contrast = 1.0 + strength * 0.2 * featherAlpha;
    distortedColor.rgb = (distortedColor.rgb - 0.5) * contrast + 0.5;

    // 关键改进：使用alpha值在原始颜色和扭曲颜色之间平滑混合
    // 在低alpha区域（边缘）更多地混合原始颜色
    float blendFactor = featherAlpha * featherAlpha; // 使用平方以获得更平滑的过渡

    // 最终混合：在原始和扭曲颜色之间插值
    fragColor = mix(originalColor, distortedColor, blendFactor);

    // 确保alpha通道正确
    fragColor.a = originalColor.a;
}