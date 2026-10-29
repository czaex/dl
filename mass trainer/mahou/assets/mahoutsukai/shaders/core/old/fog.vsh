#version 120

varying vec4 texCoord0;

void main(){
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
    //gl_TexCoord[0] = gl_MultiTexCoord0;
    texCoord0 =  gl_MultiTexCoord0;
    gl_FrontColor = gl_Color;
}
