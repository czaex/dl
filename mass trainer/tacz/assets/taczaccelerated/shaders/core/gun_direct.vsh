#version 400 core
#moj_import <minecraft:light.glsl>
#moj_import <minecraft:fog.glsl>
layout(location=0) in vec3 LocalPosition;
layout(location=1) in vec2 LocalUV;
layout(location=2) in vec3 LocalNormal;
layout(location=3) in int Bone;
uniform samplerBuffer Palette;
uniform int PaletteBase;
uniform sampler2D Sampler1;
uniform sampler2D Sampler2;
uniform mat4 ModelViewMat;
uniform mat4 ProjMat;
uniform mat3 IViewRotMat;
uniform int FogShape;
uniform vec3 Light0_Direction;
uniform vec3 Light1_Direction;
out float vertexDistance;
out vec4 vertexColor;
out vec4 lightMapColor;
out vec4 overlayColor;
out vec2 texCoord0;
out vec4 normal;
void main() {
    int base=PaletteBase+Bone*10;
    vec4 p0=texelFetch(Palette,base),p1=texelFetch(Palette,base+1),p2=texelFetch(Palette,base+2),p3=texelFetch(Palette,base+3);
    precise vec3 position=p0.xyz*LocalPosition.x;
    position=position+p1.xyz*LocalPosition.y;
    position=position+p2.xyz*LocalPosition.z;
    position=position+p3.xyz;
    precise vec3 n=texelFetch(Palette,base+4).xyz*LocalNormal.x;
    n=n+texelFetch(Palette,base+5).xyz*LocalNormal.y;
    n=n+texelFetch(Palette,base+6).xyz*LocalNormal.z;
    n=vec3(ivec3(clamp(n,-1.0,1.0)*127.0))/127.0;
    vec4 color=vec4(ivec4(texelFetch(Palette,base+7)*255.0))/255.0;
    ivec4 meta=ivec4(texelFetch(Palette,base+8));
    bool visible=texelFetch(Palette,base+9).x!=0.0;
    gl_Position=visible?ProjMat*ModelViewMat*vec4(position,1.0):vec4(0,0,0,1);
    vertexDistance=fog_distance(ModelViewMat,IViewRotMat*position,FogShape);
    vertexColor=minecraft_mix_light(Light0_Direction,Light1_Direction,n,color);
    lightMapColor=texelFetch(Sampler2,meta.xy/16,0);
    overlayColor=texelFetch(Sampler1,meta.zw,0);
    texCoord0=LocalUV;
    normal=ProjMat*ModelViewMat*vec4(n,0.0);
}
