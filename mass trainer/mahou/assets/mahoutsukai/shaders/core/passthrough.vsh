#version 150

// POSITION_COLOR_TEX_LIGHTMAP
in vec3 Position;
in vec4 Color;
in vec2 UV0;
in vec2 UV2;

uniform mat4 ModelViewMat;
uniform mat4 ProjMat;

out vec4 vertexColor;
out vec2 texCoord0;
out vec2 texCoord2;

void main(){

    texCoord0 = UV0;
    texCoord2 = UV2;
    vertexColor = Color;

    gl_Position = ProjMat * ModelViewMat * vec4(Position, 1.0);


}
