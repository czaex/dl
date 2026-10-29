#version 150

uniform mat4 ProjMat;
uniform mat4 ModelViewMat;
uniform vec3 CameraPos;
uniform vec2 OutSize;

uniform sampler2D FogDataTexture; // 雾效数据纹理
uniform int FogCount;

in vec3 Position;
out vec3 vertPos;
out vec3 cameraPos;
flat out int fogIndex;
out vec2 texCoord;

vec4 getFogData(int fogIndex, int component) {
    // 纹理宽度为MAX_FOGS，高度为4
    // 每个纹素对应一个雾的一个组件
    float texX = (float(fogIndex) + 0.5) / float(16); // 16是MAX_FOGS
    float texY = (float(component) + 0.5) / 4.0; // 4个组件
    return texture(FogDataTexture, vec2(texX, texY));
}

void main() {
    // 使用gl_VertexID计算雾索引
    int verticesPerFog = 36;
    fogIndex = gl_VertexID / verticesPerFog;

    // 确保索引在有效范围内
    if (fogIndex >= FogCount) {
        fogIndex = max(0, FogCount - 1);
    }

    // 从纹理中读取雾效数据
    vec3 fogPos = getFogData(fogIndex, 0).rgb;    // 位置
    vec3 fogSize = getFogData(fogIndex, 1).rgb;   // 大小
    // 颜色和参数在片段着色器中读取

    // 计算世界位置
    vec3 worldPos = Position * fogSize + fogPos;

    // 转换到裁剪空间
    gl_Position = ProjMat * ModelViewMat * vec4(worldPos, 1.0);

    // 传递参数
    vertPos = worldPos;
    cameraPos = CameraPos;

    // 纹理坐标
    texCoord = vec2(float((gl_VertexID / 6) % 2), float((gl_VertexID / 3) % 2));
}