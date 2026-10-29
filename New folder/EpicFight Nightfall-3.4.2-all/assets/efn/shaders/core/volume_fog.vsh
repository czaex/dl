#version 150

// 只声明必要的uniform
uniform mat4 ProjMat;
uniform mat4 ModelViewMat;

in vec3 Position;

void main() {
    gl_Position = ProjMat * ModelViewMat * vec4(Position, 1.0);
}