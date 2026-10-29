#version 150

// POSITION_COLOR_TEX_LIGHTMAP
in vec3 Position;
in vec4 Color;
in vec2 UV0;
in vec2 UV2;


uniform mat4 ModelViewMat;
uniform mat4 ProjMat;
uniform mat4 ModelMat;
uniform vec4 uClipPlane;

out vec4 vertexColor;
out vec2 texCoord0;
out vec2 texCoord2;

void main(){

    texCoord0 = UV0;
    texCoord2 = UV2;
    vertexColor = Color;

    //vec4 modelPos  = ModelMat * vec4( Position, 1.0 );
    gl_Position = ProjMat * ModelViewMat * vec4(Position, 1.0);
   // gl_ClipDistance[0] = dot(modelPos, uClipPlane);
    gl_ClipDistance[0] = dot( vec4(Position, 1.0) * ModelMat, uClipPlane);


}
