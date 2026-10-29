#version 400 core
layout(location=0) in vec3 LocalPosition;
layout(location=1) in vec2 LocalUV;
layout(location=2) in vec3 LocalNormal;
layout(location=3) in int Bone;
uniform samplerBuffer Palette;
uniform int PaletteBase;
uniform int BoneCount;
out vec3 PackedPosition;
flat out uint PackedColor;
out vec2 PackedUV;
flat out uint PackedOverlay;
flat out uint PackedLight;
flat out uint PackedNormal;
void main() {
    int base = PaletteBase + (gl_InstanceID * BoneCount + Bone) * 10;
    vec4 p0=texelFetch(Palette,base),p1=texelFetch(Palette,base+1),p2=texelFetch(Palette,base+2),p3=texelFetch(Palette,base+3);
    vec3 n0=texelFetch(Palette,base+4).xyz,n1=texelFetch(Palette,base+5).xyz,n2=texelFetch(Palette,base+6).xyz;
    vec4 color=texelFetch(Palette,base+7),meta=texelFetch(Palette,base+8);
    bool visible=texelFetch(Palette,base+9).x!=0.0;
    precise vec3 position=p0.xyz*LocalPosition.x;
    position=position+p1.xyz*LocalPosition.y;
    position=position+p2.xyz*LocalPosition.z;
    position=position+p3.xyz;
    precise vec3 normal=n0*LocalNormal.x;
    normal=normal+n1*LocalNormal.y;
    normal=normal+n2*LocalNormal.z;
    if (texelFetch(Palette,base+9).y != 0.0) normal=normalize(normal);
    uvec3 bytes=uvec3(ivec3(clamp(normal,-1.0,1.0)*127.0))&uvec3(255);
    uvec4 rgba=uvec4(ivec4(color*255.0))&uvec4(255);
    PackedPosition=visible?position:vec3(0);
    PackedColor=rgba.x|(rgba.y<<8)|(rgba.z<<16)|(rgba.w<<24);
    PackedUV=LocalUV;
    PackedOverlay=uint(meta.z)|(uint(meta.w)<<16);
    PackedLight=uint(meta.x)|(uint(meta.y)<<16);
    PackedNormal=bytes.x|(bytes.y<<8)|(bytes.z<<16);
    gl_Position=vec4(0,0,0,1);
}
