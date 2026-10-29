#version 150

uniform sampler2D DiffuseSampler;
uniform float DistortionStrength;
uniform float Frequency;
uniform float Time;
uniform float Progress;
uniform vec2 OutSize;

in vec2 texCoord;
out vec4 fragColor;

void main() {
    vec2 uv = texCoord;

    // 基础正弦/余弦畸变
    vec2 distortion = vec2(0.0);
    distortion.x = sin(uv.y * Frequency + Time) * DistortionStrength;
    distortion.y = cos(uv.x * Frequency + Time) * DistortionStrength;

    // 径向畸变
    vec2 centerVec = uv - vec2(0.5, 0.5);
    float centerDist = length(centerVec);
    vec2 radialDistortion = centerVec * sin(centerDist * Frequency * 2.0 + Time) * DistortionStrength * 0.5;

    // 原有的螺旋吸入效果 (shippudenSpiral)
    vec2 shippudenSpiral = vec2(0.0);
    float spiralPower = 0.025 * DistortionStrength;
    float spiralTurns = 12.0;
    float spiralSpeed = 3.0;
    float distToCenter = length(centerVec);
    float angle = atan(centerVec.y, centerVec.x);
    float spiralRotation = spiralTurns * distToCenter - Time * spiralSpeed;
    float cosRot = cos(spiralRotation);
    float sinRot = sin(spiralRotation);
    vec2 rotatedCoord = vec2(
    centerVec.x * cosRot - centerVec.y * sinRot,
    centerVec.x * sinRot + centerVec.y * cosRot
    );
    float contraction = 0.015 * DistortionStrength * (1.0 - exp(-distToCenter * 8.0));
    rotatedCoord *= (1.0 - contraction * Progress);
    shippudenSpiral = (rotatedCoord - centerVec) * spiralPower * Progress;
    float centerWarp = 0.01 * DistortionStrength * sin(Time * 3.0) * exp(-distToCenter * 10.0);
    shippudenSpiral += centerVec * centerWarp * Progress;

    // --- 新增：鱼眼畸变（桶形畸变，中心放大，边缘压缩） ---
    float fisheyeStrength = DistortionStrength * 1.2;  // 负值产生桶形畸变
    float r2 = distToCenter * distToCenter;
    vec2 fisheyeOffset = centerVec * fisheyeStrength * r2 * Progress;

    // 组合所有畸变
    vec2 finalDistortion = distortion + radialDistortion + shippudenSpiral + fisheyeOffset;
    finalDistortion *= Progress;

    // 应用畸变
    vec2 distortedUV = uv + finalDistortion;
    distortedUV = clamp(distortedUV, 0.0, 1.0);

    // 基础采样
    fragColor = texture(DiffuseSampler, distortedUV);

    // --- 升级的色差效果 ---
    // 中心区域的细微 RGB 偏移（保留原逻辑，增强动态）
    if (Progress > 0.3) {
        float centerEffect = exp(-distToCenter * 15.0) * Progress;
        if (centerEffect > 0.05) {
            vec2 offset = centerVec * 0.008 * centerEffect;
            fragColor.r = texture(DiffuseSampler, clamp(distortedUV + offset, 0.0, 1.0)).r;
            fragColor.b = texture(DiffuseSampler, clamp(distortedUV - offset, 0.0, 1.0)).b;
        }
    }

    // 强烈径向色差：红通道向外偏移，蓝通道向内偏移，随距离平方增强
    if (Progress > 0.5) {
        // 色差强度：根据进度、畸变强度、径向距离动态调整
        float chromaStrength = (Progress - 0.5) * 3.0 * DistortionStrength * r2 * 0.5;
        // 加入轻微的时间变化，使色差更生动
        chromaStrength += 0.002 * sin(Time * 5.0) * Progress * DistortionStrength;
        vec2 radialDir = vec2(0.0);
        if (distToCenter > 0.001) {
            radialDir = centerVec / distToCenter;
        }
        vec2 chromaOffset = radialDir * chromaStrength;

        // 采样红蓝通道偏移
        float r = texture(DiffuseSampler, clamp(distortedUV + chromaOffset, 0.0, 1.0)).r;
        float b = texture(DiffuseSampler, clamp(distortedUV - chromaOffset, 0.0, 1.0)).b;
        // 绿色保持原样（或稍作混合）
        fragColor.r = r;
        fragColor.b = b;

        // 可选：边缘额外模糊混合（保留原有边缘处理思路，但用色差主导）
        if (distToCenter > 0.3 && Progress > 0.7) {
            float edgeEffect = smoothstep(0.3, 0.5, distToCenter) * (Progress - 0.7) * 2.0;
            vec2 blurOffset = normalize(centerVec) * 0.005 * edgeEffect;
            vec4 blurred = texture(DiffuseSampler, clamp(distortedUV + blurOffset, 0.0, 1.0)) * 0.5 +
            texture(DiffuseSampler, clamp(distortedUV - blurOffset, 0.0, 1.0)) * 0.5;
            fragColor = mix(fragColor, blurred, edgeEffect * 0.2);
        }
    }
}