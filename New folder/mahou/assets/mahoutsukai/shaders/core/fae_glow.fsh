#version 150



uniform sampler2D Sampler0;

in vec2 texCoord0;
in vec4 vertexColor;

out vec4 fragColor;

void main() {
    vec2 texel = 1.0 / vec2(textureSize(Sampler0, 0));
    float blurredAlpha = 0.0;
    float totalWeight = 0.0;

    for (int sampleY = -3; sampleY <= 3; sampleY++) {
        for (int sampleX = -3; sampleX <= 3; sampleX++) {
            vec2 sampleOffset = vec2(sampleX, sampleY) * 2.0;
            float weight = exp(-dot(sampleOffset, sampleOffset) / 18.0);
            blurredAlpha += texture(Sampler0, texCoord0 + texel * sampleOffset).a * weight;
            totalWeight += weight;
        }
    }

    float borderDistance = min(min(texCoord0.x, 1.0 - texCoord0.x),
                               min(texCoord0.y, 1.0 - texCoord0.y));
    float edgeFade = smoothstep(0.0, 0.16, borderDistance);
    float halo = blurredAlpha / totalWeight * edgeFade * vertexColor.a;

    if (halo < 0.002) discard;
    float glowStrength = halo * 1.2;
    fragColor = vec4(vertexColor.rgb * glowStrength, halo);
}
