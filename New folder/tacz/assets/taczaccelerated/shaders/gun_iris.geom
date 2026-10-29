#version 400 core
layout(lines_adjacency) in;
layout(points, max_vertices=4) out;
in vec3 PackedPosition[];
flat in uint PackedColor[];
in vec2 PackedUV[];
flat in uint PackedOverlay[];
flat in uint PackedLight[];
flat in uint PackedNormal[];
uniform ivec3 IrisIds;
out vec3 IrisPosition;
flat out uint IrisColor;
out vec2 IrisUV;
flat out uint IrisOverlay;
flat out uint IrisLight;
flat out uint IrisNormal;
flat out uint IrisIds01;
flat out uint IrisId2MidU;
flat out uint IrisMidUV;
flat out uint IrisMidVTangent;
flat out uint IrisTangentPad;
uint tangent(vec3 n) {
    vec3 e1=PackedPosition[1]-PackedPosition[0];
    vec3 e2=PackedPosition[2]-PackedPosition[0];
    vec2 uv1=PackedUV[1]-PackedUV[0],uv2=PackedUV[2]-PackedUV[0];
    float determinant=uv1.x*uv2.y-uv2.x*uv1.y;
    float inverse=determinant==0.0?1.0:1.0/determinant;
    vec3 t=(uv2.y*e1-uv1.y*e2)*inverse;
    vec3 bitangent=(uv1.x*e2-uv2.x*e1)*inverse;
    t=length(t)>0.0?normalize(t):vec3(0);
    bitangent=length(bitangent)>0.0?normalize(bitangent):vec3(0);
    float handed=dot(bitangent,cross(t,n))<0.0?-1.0:1.0;
    uvec4 bytes=uvec4(ivec4(clamp(vec4(t,handed),-1.0,1.0)*127.0))&uvec4(255);
    return bytes.x|(bytes.y<<8)|(bytes.z<<16)|(bytes.w<<24);
}
void main() {
    vec2 mid=((PackedUV[0]+PackedUV[1])+PackedUV[2])+PackedUV[3];
    mid/=4.0;
    uint u=floatBitsToUint(mid.x),v=floatBitsToUint(mid.y);
    precise vec3 diagonalA=PackedPosition[2]-PackedPosition[0];
    precise vec3 diagonalB=PackedPosition[3]-PackedPosition[1];
    precise vec3 faceNormal=cross(diagonalA,diagonalB);
    float normalLength=length(faceNormal);
    if(normalLength!=0.0) faceNormal/=normalLength;
    uvec3 normalBytes=uvec3(ivec3(clamp(faceNormal,-1.0,1.0)*127.0))&uvec3(255);
    uint normal=normalBytes.x|(normalBytes.y<<8)|(normalBytes.z<<16);
    uint packedTangent=tangent(faceNormal);
    for(int i=0;i<4;i++) {
        IrisPosition=PackedPosition[i];IrisColor=PackedColor[i];IrisUV=PackedUV[i];
        IrisOverlay=PackedOverlay[i];IrisLight=PackedLight[i];IrisNormal=normal;
        IrisIds01=(uint(IrisIds.x)&65535u)|((uint(IrisIds.y)&65535u)<<16);
        IrisId2MidU=(uint(IrisIds.z)&65535u)|(u<<16);
        IrisMidUV=(u>>16)|(v<<16);
        IrisMidVTangent=(v>>16)|(packedTangent<<16);
        IrisTangentPad=packedTangent>>16;
        gl_Position=vec4(0,0,0,1);EmitVertex();EndPrimitive();
    }
}
