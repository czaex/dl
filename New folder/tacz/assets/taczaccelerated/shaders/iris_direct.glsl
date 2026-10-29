uniform bool taczt_DirectEnabled;
uniform samplerBuffer taczt_Source;
uniform samplerBuffer taczt_Palette;
uniform int taczt_PaletteBase;
uniform ivec3 taczt_Ids;

vec3 taczt_pose(vec3 p, vec4 a, vec4 b, vec4 c, vec4 d) {
    precise vec3 result = a.xyz * p.x;
    result = result + b.xyz * p.y;
    result = result + c.xyz * p.z;
    return result + d.xyz;
}

void main() {
    TACZT_INITIALIZE
    if (taczt_DirectEnabled) {
        int q = (gl_VertexID / 4) * 8;
        vec4 s0 = texelFetch(taczt_Source, q);
        vec4 s1 = texelFetch(taczt_Source, q + 2);
        vec4 s2 = texelFetch(taczt_Source, q + 4);
        vec4 s3 = texelFetch(taczt_Source, q + 6);
        int base = taczt_PaletteBase + int(s0.w) * 10;
        vec4 a = texelFetch(taczt_Palette, base);
        vec4 b = texelFetch(taczt_Palette, base + 1);
        vec4 c = texelFetch(taczt_Palette, base + 2);
        vec4 d = texelFetch(taczt_Palette, base + 3);
        bool visible = texelFetch(taczt_Palette, base + 9).x != 0.0;
        vec3 p0 = visible ? taczt_pose(s0.xyz, a, b, c, d) : vec3(0);
        vec3 p1 = visible ? taczt_pose(s1.xyz, a, b, c, d) : vec3(0);
        vec3 p2 = visible ? taczt_pose(s2.xyz, a, b, c, d) : vec3(0);
        vec3 p3 = visible ? taczt_pose(s3.xyz, a, b, c, d) : vec3(0);
        vec2 uv0 = texelFetch(taczt_Source, q + 1).xy;
        vec2 uv1 = texelFetch(taczt_Source, q + 3).xy;
        vec2 uv2 = texelFetch(taczt_Source, q + 5).xy;
        vec2 uv3 = texelFetch(taczt_Source, q + 7).xy;
        precise vec3 diagonalA = p2 - p0;
        precise vec3 diagonalB = p3 - p1;
        precise vec3 n = cross(diagonalA, diagonalB);
        float lengthN = length(n);
        if (lengthN != 0.0) n /= lengthN;
        vec2 duv1 = uv1 - uv0, duv2 = uv2 - uv0;
        float determinant = duv1.x * duv2.y - duv2.x * duv1.y;
        float inverse = determinant == 0.0 ? 1.0 : 1.0 / determinant;
        vec3 t = (duv2.y * (p1 - p0) - duv1.y * (p2 - p0)) * inverse;
        vec3 bitangent = (duv1.x * (p2 - p0) - duv2.x * (p1 - p0)) * inverse;
        t = length(t) > 0.0 ? normalize(t) : vec3(0);
        bitangent = length(bitangent) > 0.0 ? normalize(bitangent) : vec3(0);
        float handed = dot(bitangent, cross(t, n)) < 0.0 ? -1.0 : 1.0;
        vec2 mid = ((uv0 + uv1) + uv2) + uv3;
        mid /= 4.0;
        int corner = gl_VertexID % 4;
        iris_Position = corner == 0 ? p0 : corner == 1 ? p1 : corner == 2 ? p2 : p3;
        iris_UV0 = texelFetch(taczt_Source, gl_VertexID * 2 + 1).xy;
        iris_Normal = vec3(ivec3(clamp(n, -1.0, 1.0) * 127.0)) / 127.0;
        iris_Color = vec4(ivec4(texelFetch(taczt_Palette, base + 7) * 255.0)) / 255.0;
        vec4 meta = texelFetch(taczt_Palette, base + 8);
        iris_UV1 = (ivec2(meta.zw) << 16) >> 16;
        iris_UV2 = (ivec2(meta.xy) << 16) >> 16;
        iris_Entity = taczt_Ids;
        TACZT_OPTIONAL
    }
    taczt_pack_main();
}
