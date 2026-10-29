#version 150

uniform sampler2D uDepthTexture;
uniform sampler2D bgl_RenderedTexture;
uniform vec2 uNearFar; // near and far z
uniform vec2 uInvertedVp; // 1.0/width, 1.0/height
uniform vec4 uSmokeColor;
uniform float uSmokeSoftness;

in vec4 vertexColor;
in vec2 texCoord0;
in vec2 texCoord2;

out vec4 fragColor;

float calc_depth( in float z ){
  return (2.0 * uNearFar.x) / (uNearFar.y + uNearFar.x - z*(uNearFar.y - uNearFar.x) );
}

void main(){
    vec4 diffuse = texture(bgl_RenderedTexture, texCoord0.xy) * uSmokeColor;
    vec2 uv = gl_FragCoord.xy * uInvertedVp;
    float z1 = calc_depth( texture(uDepthTexture, uv).x );
    float z2 = calc_depth( gl_FragCoord.z );
    float a = clamp(z1 - z2, 0.0, 1.0);
    float b = smoothstep(0.0, uSmokeSoftness, a);
    fragColor = vec4(diffuse.r,diffuse.g,diffuse.b,diffuse.a*b);
    if (fragColor.a < 0.02) discard;
    //if(fragColor.a < 0.01) discard;
    //gl_FragColor = vec4(z1,z1,z1,1);
}
