#version 150
#extension GL_ARB_geometry_shader4 : enable

layout(triangles) in;
layout(triangle_strip, max_vertices = 3) out;

in vec3 fragPos[];
in vec3 fogCenter[];
in vec3 fogSize[];
in vec4 fogColor[];
in float fogDensity[];
in float noiseScale[];
in float noiseIntensity[];
in float fogTime[];
in float fogDistance[];

out vec3 g_fragPos;
out vec3 g_fogCenter;
out vec3 g_fogSize;
out vec4 g_fogColor;
out float g_fogDensity;
out float g_noiseScale;
out float g_noiseIntensity;
out float g_fogTime;
out float g_fogDistance;

void main() {
    for(int i = 0; i < 3; i++) {
        g_fragPos = fragPos[i];
        g_fogCenter = fogCenter[i];
        g_fogSize = fogSize[i];
        g_fogColor = fogColor[i];
        g_fogDensity = fogDensity[i];
        g_noiseScale = noiseScale[i];
        g_noiseIntensity = noiseIntensity[i];
        g_fogTime = fogTime[i];
        g_fogDistance = fogDistance[i];

        gl_Position = gl_in[i].gl_Position;
        EmitVertex();
    }
    EndPrimitive();
}