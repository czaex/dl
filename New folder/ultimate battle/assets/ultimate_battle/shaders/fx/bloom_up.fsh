uniform sampler2D AuxSampler;
uniform vec2 TexelSize;

// Tent upsample of the coarser level, added to this level's downsample.
void main() {
    vec2 d = TexelSize;
    vec2 uv = texCoord;
    vec3 s = texture(DiffuseSampler, uv).rgb * 4.0;
    s += (texture(DiffuseSampler, uv + vec2(-d.x, 0.0)).rgb + texture(DiffuseSampler, uv + vec2(d.x, 0.0)).rgb
        + texture(DiffuseSampler, uv + vec2(0.0, -d.y)).rgb + texture(DiffuseSampler, uv + vec2(0.0, d.y)).rgb) * 2.0;
    s += texture(DiffuseSampler, uv + d).rgb + texture(DiffuseSampler, uv - d).rgb
        + texture(DiffuseSampler, uv + vec2(d.x, -d.y)).rgb + texture(DiffuseSampler, uv + vec2(-d.x, d.y)).rgb;
    fragColor = vec4(s / 16.0 + texture(AuxSampler, uv).rgb, 1.0);
}
