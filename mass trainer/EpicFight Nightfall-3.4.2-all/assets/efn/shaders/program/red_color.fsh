#version 150

uniform sampler2D DiffuseSampler;
uniform float RedIntensity;
uniform float Alpha;
uniform vec2 OutSize;
uniform float Time;
uniform float RedReduceFactor; // 新增：红色减少因子 (0.0-1.0)

in vec2 texCoord;
out vec4 fragColor;

// 噪声函数
float hash(float n) { return fract(sin(n) * 43758.5453); }
float noise(vec2 p) {
    return hash(p.x * 12.9898 + p.y * 78.233);
}

// 强烈扭曲函数
float violentNoise(vec2 p) {
    return sin(p.x * 50.0 + Time * 15.0) * cos(p.y * 40.0 + Time * 12.0);
}

// 平滑过渡函数
float smoothTransition(float x, float start, float end) {
    return smoothstep(start, end, clamp(x, start, end));
}

// 更丝滑的过渡曲线
float smootherstep(float x) {
    return x * x * x * (x * (x * 6.0 - 15.0) + 10.0);
}

void main(){
    vec4 originalColor = texture(DiffuseSampler, texCoord);
    vec2 uv = texCoord;

    // 计算到屏幕中心的距离（归一化）
    vec2 centerVec = uv - 0.5;
    float distToCenter = length(centerVec) * 2.0;

    // 使用更平滑的过渡曲线
    float edgeFactor = distToCenter;
    float effectIntensity = smootherstep(smoothstep(0.0, 1.0, edgeFactor));

    // 创建多层过渡效果，更加丝滑
    float transitionStart = 0.15;  // 开始过渡的位置
    float transitionEnd = 0.85;    // 完全过渡的位置
    float smoothIntensity = smoothTransition(edgeFactor, transitionStart, transitionEnd);

    // 使用两个不同的混合强度，创建更平滑的渐变
    float intensitySoft = smoothstep(0.0, 0.8, edgeFactor); // 用于柔和效果
    float intensityHard = smoothstep(0.2, 1.0, edgeFactor); // 用于强烈效果

    // 计算红色减少比例
    float redReduce = 1.0 - RedReduceFactor * 0.6;

    // 狂暴节奏
    float violentPulse = sin(Time * 15.0) * 0.7 + 0.3;
    float rageHeartbeat = sin(Time * 4.0 + sin(Time * 8.0) * 2.0) * 0.5 + 0.5;
    float chaosRhythm = sin(Time * 25.0) * 0.4 + 0.6;

    // 根据效果强度调整扭曲程度 - 使用柔和过渡
    vec2 violentUV = uv;
    float distortionPower = RedIntensity * 0.02 * intensitySoft;

    // 多重扭曲波 - 使用平滑过渡
    violentUV.x += sin(uv.y * 30.0 + Time * 12.0) * distortionPower * intensitySoft;
    violentUV.y += cos(uv.x * 25.0 + Time * 10.0) * distortionPower * intensitySoft;
    violentUV.x += violentNoise(uv * 8.0) * distortionPower * 0.5 * intensitySoft;
    violentUV.y += violentNoise(uv * 6.0 + 0.5) * distortionPower * 0.5 * intensitySoft;

    // 红色通道色差偏移 - 使用柔和过渡
    vec2 redOffsetDirection = normalize(centerVec);
    float chromaticIntensity = RedIntensity * (0.01 + violentPulse * 0.02) * intensitySoft;

    // 红色通道偏移
    vec2 redUV = violentUV + redOffsetDirection * chromaticIntensity;
    vec2 redUV2 = violentUV - redOffsetDirection * chromaticIntensity * 0.7;

    // 采样不同偏移的红色通道
    float redChannel1 = texture(DiffuseSampler, redUV).r;
    float redChannel2 = texture(DiffuseSampler, redUV2).r;

    // 混合红色通道
    float finalRed = (redChannel1 + redChannel2) * 0.5;

    vec3 distortedColor = texture(DiffuseSampler, violentUV).rgb;
    vec3 processedColor = distortedColor;
    processedColor.r = finalRed;

    // 沸腾的血色效果 - 多层过渡
    float boilingBlood = noise(uv * 8.0 + Time * 5.0);
    float bloodVeins = sin(uv.x * 100.0 + Time * 8.0) * sin(uv.y * 80.0 + Time * 6.0) * 0.3;

    vec3 bloodTint = vec3((0.7 + boilingBlood * 0.3) * redReduce,
    0.1 + bloodVeins * 0.1,
    0.1);

    // 原始野性红色
    vec3 savageRed = processedColor;

    // 增强红色 - 使用平滑过渡
    float redRage = RedIntensity * Alpha * (0.4 + violentPulse * 0.3) * redReduce * smoothIntensity;
    savageRed.r += redRage;
    savageRed.r *= 1.2 + rageHeartbeat * 0.2;

    // 减少对其他颜色的压制 - 平滑过渡
    savageRed.g *= mix(1.0, 0.5 - violentPulse * 0.1, smoothIntensity);
    savageRed.b *= mix(1.0, 0.4 - chaosRhythm * 0.1, smoothIntensity);

    // 血色覆盖 - 平滑过渡
    savageRed = mix(savageRed, bloodTint, RedIntensity * (0.3 + violentPulse * 0.2) * redReduce * smoothIntensity);

    // 添加血色扫描线 - 平滑过渡
    float bloodScan = sin(uv.y * 800.0 + Time * 20.0) * 0.1 * RedIntensity * redReduce * smoothIntensity;
    savageRed.r += bloodScan;

    // 边缘增强红色色差效果 - 平滑过渡
    float edgeChromatic = (1.0 - smoothIntensity) * chromaticIntensity * 2.0 * redReduce;
    vec2 edgeRedUV = uv + redOffsetDirection * edgeChromatic;
    float edgeRed = texture(DiffuseSampler, edgeRedUV).r;

    // 边缘红色效果 - 更加平滑的混合
    vec3 edgeRage = savageRed;
    edgeRage.r = mix(edgeRage.r, edgeRed, (1.0 - smoothIntensity) * 0.6 * redReduce);
    edgeRage.r += (1.0 - smoothIntensity) * RedIntensity * 0.5 * redReduce;
    edgeRage.g *= mix(1.0, 0.4, (1.0 - smoothIntensity));
    edgeRage.b *= mix(1.0, 0.3, (1.0 - smoothIntensity));

    // 使用平滑的混合函数
    float blendFactor = 1.0 - smoothIntensity * 0.8;
    blendFactor = smootherstep(blendFactor);
    savageRed = mix(edgeRage, savageRed, blendFactor);

    // 颜色控制
    savageRed = clamp(savageRed, 0.0, 2.0);

    // 更丝滑的最终混合
    vec3 finalColor;

    // 使用平滑的混合曲线
    float finalBlend = smootherstep(smoothIntensity);

    // 对于不同的效果使用不同的混合强度
    float colorBlend = smoothstep(0.0, 0.6, edgeFactor); // 颜色混合
    float distortionBlend = smoothstep(0.0, 0.4, edgeFactor); // 扭曲混合

    // 多层混合实现丝滑过渡
    vec3 baseColor = originalColor.rgb;

    // 第一步：先混合扭曲效果（较早开始，较平滑）
    vec3 distortedBase = mix(baseColor, processedColor, distortionBlend);

    // 第二步：再混合红色增强效果（稍后开始，较强）
    vec3 redEnhanced = mix(distortedBase, savageRed, colorBlend);

    // 第三步：应用微妙的中心保护
    float centerProtection = 1.0 - smoothstep(0.0, 0.3, edgeFactor);
    redEnhanced = mix(baseColor, redEnhanced, 1.0 - centerProtection * 0.3);

    finalColor = redEnhanced;

    // 微暗角效果 - 使用更平滑的暗角
    float vignette = 1.0 - dot(centerVec, centerVec) * 0.3;
    vignette = pow(vignette, 0.8);

    // 让暗角边缘过渡更平滑
    float vignetteSoft = smootherstep(vignette);
    finalColor *= vignetteSoft;

    // 最终过曝处理
    finalColor = clamp(finalColor, 0.0, 2.0);

    // 边缘轻微增强对比度
    float edgeBoost = 1.0 + (1.0 - vignette) * 0.1;
    finalColor *= mix(1.0, edgeBoost, smoothIntensity);

    finalColor = pow(finalColor, mix(vec3(1.0), vec3(0.9), smoothIntensity));

    fragColor = vec4(finalColor, originalColor.a);
}