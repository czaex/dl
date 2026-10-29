#version 150

uniform sampler2D DiffuseSampler;

/// Original
uniform float Contrast;
uniform float Brightness;
uniform float Time;

/// Impact Animation
uniform float Intensity;
uniform float Speed;

/// Mode: 0.0 = LIGHT (2-phase), 1.0 = HEAVY (3-phase)
uniform float Mode;

/// Colored Cutout
uniform vec3 ColorDark;
uniform vec3 ColorLight;
uniform float ImpactThreshold;
uniform float ImpactThresholdLerp;
uniform float InvertFactor;
uniform float CappedGrayscale;

/// Radial Blur
uniform vec2 FocalUV;
uniform float RadialStrength;
uniform int Samples;

/// Chromatic Aberration
uniform float ChromaticStrength;

/// Lens Distortion & Shockwave
uniform float LensDistortStrength;

in vec2 texCoord;
out vec4 fragColor;

// ==================== Utility Functions ====================

float getLuminance(vec3 color) {
    return dot(color, vec3(0.299, 0.587, 0.114));
}

vec3 boostSaturation(vec3 color, float boost) {
    float luminance = getLuminance(color);
    vec3 saturated = mix(vec3(luminance), color, 1.0 + boost);
    if (luminance > 0.7) {
        float whitePush = (luminance - 0.7) / 0.3 * boost * 0.5;
        saturated = mix(saturated, vec3(1.0), whitePush);
    }
    return saturated;
}

float quickFlash(float t, float freq) {
    return abs(sin(t * 3.14159 * freq));
}

vec2 applyLensDistortion(vec2 uv, vec2 center, float strength) {
    if (abs(strength) < 0.0001) return uv;
    vec2 dir = uv - center;
    float dist = length(dir);
    float factor = 1.0 + strength * dist * dist;
    return clamp(center + dir * factor, vec2(0.0), vec2(1.0));
}

float computeShockwave(vec2 uv, vec2 center, float time, float speed) {
    float dist = length(uv - center);
    float radius = time * speed;
    float ring = exp(-abs(dist - radius) * 30.0);
    float interior = smoothstep(radius, radius - 0.05, dist);
    return ring * 0.6 + interior * 0.15;
}

float computeFresnel(vec2 uv) {
    vec2 center = uv - vec2(0.5);
    float dist = length(center);
    return smoothstep(0.2, 0.85, dist);
}

vec3 applyRadialBlur(vec3 baseColor) {
    vec2 dir = FocalUV - texCoord;
    float dist = length(dir);
    if (dist < 0.0001) return baseColor;
    dir /= dist;

    float strength = RadialStrength;
    int s = max(1, min(Samples, 32));

    vec3 result = vec3(0.0);
    float totalWeight = 0.0;

    for (int i = 0; i < 32; i++) {
        if (i >= s) break;
        float t = (s == 1) ? 0.0 : (float(i) / float(s - 1));
        float weight = 1.0 - abs(t - 0.5) * 2.0;
        float offset = t * strength * dist;
        vec2 sampleCoord = clamp(texCoord + dir * offset, vec2(0.0), vec2(1.0));
        vec3 sampleColor = mix(baseColor, texture(DiffuseSampler, sampleCoord).rgb, 0.7);
        result += sampleColor * weight;
        totalWeight += weight;
    }

    if (totalWeight > 0.0) result /= totalWeight;
    return result;
}

vec3 applyChromaticAberration(vec3 baseColor, vec2 uv, float strength) {
    if (strength <= 0.0001) return baseColor;

    vec2 dir = uv - FocalUV;
    float dist = length(dir);
    if (dist < 0.001) dir = vec2(1.0, 0.0);
    else dir /= dist;

    float distScale = smoothstep(0.0, 0.4, dist);
    float s = strength * distScale;
    vec2 offset = dir * s;

    float r = texture(DiffuseSampler, clamp(uv + offset, 0.0, 1.0)).r;
    float g = baseColor.g;
    float b = texture(DiffuseSampler, clamp(uv - offset, 0.0, 1.0)).b;

    return vec3(r, g, b);
}

float computeBicolorFactor(vec3 color, float extraInvert) {
    float luma = max(max(color.r, color.g), color.b);
    luma /= max(CappedGrayscale, 0.001);

    float safeContrast = max(Contrast, 0.001);
    luma = pow(clamp(luma, 0.0, 1.0), 1.0 / safeContrast);

    float factor = 0.0;
    if (luma > ImpactThreshold) {
        factor = 1.0;
    } else {
        if (ImpactThresholdLerp != 0.0) {
            float v = ImpactThreshold - luma;
            factor = smoothstep(0.0, 1.0, 1.0 - min(1.0, v / ImpactThresholdLerp));
        }
    }

    float totalInvert = clamp(InvertFactor + extraInvert, 0.0, 1.0);
    if (totalInvert > 0.0) {
        factor = mix(factor, 1.0 - factor, totalInvert);
    }

    return factor;
}

vec3 impactColoredCutout(vec3 color) {
    float factor = computeBicolorFactor(color, 0.0);
    return mix(ColorDark, ColorLight, factor);
}

// ==================== Recovery Phase (shared by both modes) ====================

vec4 doRecovery(vec4 original, float phase, float timePassed) {
    float gray = getLuminance(original.rgb);

    gray = (gray - 0.5) * (Contrast * 0.6) + 0.5;
    gray += (Brightness - 0.5) * 0.2;
    gray = clamp(gray, 0.0, 1.0);

    // Motion trail
    float trailFade = (1.0 - phase) * 0.4;
    vec2 mbOffset = vec2(0.005, 0.0) * trailFade;
    float prev1 = getLuminance(texture(DiffuseSampler, texCoord + mbOffset).rgb);
    float prev2 = getLuminance(texture(DiffuseSampler, texCoord - mbOffset * 0.5).rgb);
    gray = mix(gray, (prev1 + prev2) * 0.5, trailFade);

    // Radial blur residue
    vec3 blurred = applyRadialBlur(original.rgb);
    float blurGray = getLuminance(blurred);
    float blurResidue = (1.0 - phase) * 0.12 * Intensity;
    gray = mix(gray, blurGray, blurResidue);

    // Bicolor residue
    float bicolorFactor = computeBicolorFactor(original.rgb, 0.0);
    vec3 bicolor = mix(ColorDark, ColorLight, bicolorFactor);
    float bicolorGray = getLuminance(bicolor);
    float bicolorResidue = (1.0 - phase) * 0.15 * Intensity;
    gray = mix(gray, bicolorGray, bicolorResidue);

    // Film grain
    float noise = fract(sin(dot(texCoord, vec2(12.9898, 78.233))) * 43758.5453) * 0.02;
    gray += noise;

    // Vignette
    vec2 center = texCoord - vec2(0.5);
    float vDist = length(center);
    float vig = 1.0 - vDist * 0.06;
    gray *= vig;

    // Shockwave ghost
    float shockGhost = computeShockwave(texCoord, FocalUV, timePassed * 1.5 + 0.5, 1.5 * Speed);
    gray = min(gray + shockGhost * (1.0 - phase) * Intensity * 0.06, 1.0);

    // Fade to white
    float fadeWhite = (1.0 - timePassed) * 2.0;
    gray = min(gray + fadeWhite, 1.0);

    gray = clamp(gray, 0.0, 1.0);
    return vec4(gray, gray, gray, original.a);
}

// ==================== Main ====================

void main() {
    vec4 original = texture(DiffuseSampler, texCoord);

    // ====================================================================
    //  LIGHT MODE (Mode < 0.5): 2-phase aggressive — punch + recover
    // ====================================================================
    if (Mode < 0.5) {

        // --- Phase A: Combined Impact + Chaos (0.0 – 0.5) ---
        if (Time < 0.5) {
            float phase = Time / 0.5;

            // Instant whiteout (first 20% → full white, then drops)
            float whiteout = 1.0 - smoothstep(0.0, 0.25, phase);
            whiteout *= 0.9 * Intensity;

            // Lens distortion: snap immediately, release over phase
            float lensCurve = 1.0 - phase; // 1 → 0
            float lensStr = LensDistortStrength * lensCurve * Intensity;
            vec2 sampleUV = applyLensDistortion(texCoord, FocalUV, lensStr);
            vec3 distortedSample = texture(DiffuseSampler, sampleUV).rgb;

            // Radial blur: immediate then fades (reverse curve: 1 → 0)
            float blurCurve = 1.0 - pow(phase, 0.6);
            float blurIntensity = blurCurve * Intensity * 0.7;
            vec3 blurred = applyRadialBlur(distortedSample);
            vec3 color = mix(distortedSample, blurred, blurIntensity);

            // Chromatic aberration: strong at start, fading
            float chromaStr = ChromaticStrength * blurCurve * Intensity * 3.0;
            color = applyChromaticAberration(color, sampleUV, chromaStr);

            // Saturation boost: instant spike
            float satBoost = blurCurve * Intensity * 3.5;
            color = boostSaturation(color, satBoost);
            color = min(color * (1.0 + satBoost * 0.3), 1.0);

            // Quick flash bursts
            float flash = quickFlash(phase, 12.0) * 0.2 * Intensity * blurCurve;
            color += vec3(flash);

            // Shockwave: expanding fast
            float shock = computeShockwave(texCoord, FocalUV, phase * 2.0, 2.0 * Speed);
            color += vec3(shock * Intensity * 0.8);

            // Fresnel edge glow
            float fresnel = computeFresnel(texCoord);
            float fresnelBoost = fresnel * blurCurve * Intensity * 0.4;
            color = mix(color, color * 1.5, fresnelBoost);

            // Bicolor + oscillating invert (merged impact + chaos)
            float invertOsc = quickFlash(phase, 6.0) * blurCurve;
            float factor = computeBicolorFactor(color, invertOsc);
            vec3 bicolorMap = mix(ColorDark, ColorLight, factor);
            float bicolorBlend = smoothstep(0.05, 0.3, phase) * Intensity;
            color = mix(color, bicolorMap, bicolorBlend);

            // Glitch
            float glitchStr = quickFlash(phase, 15.0) * 0.02 * blurCurve;
            vec2 glitchUV = sampleUV + vec2(glitchStr, 0.0);
            vec3 glitchColor = texture(DiffuseSampler, clamp(glitchUV, vec2(0.0), vec2(1.0))).rgb;
            color = mix(color, glitchColor, glitchStr * 10.0);

            // Whiteout overlay
            color = mix(color, vec3(1.0), whiteout);

            // Contrast punch
            float contrastStrength = 1.0 + Intensity * 0.6 * blurCurve;
            color = (color - 0.5) * contrastStrength + 0.5;
            color = clamp(color, 0.0, 1.0);

            fragColor = vec4(color, original.a);
            return;
        }

        // --- Phase B: Recovery (0.5 – 1.0) ---
        {
            float phase = (Time - 0.5) / 0.5;
            fragColor = doRecovery(original, phase, Time);
            return;
        }
    }

    // ====================================================================
    //  HEAVY MODE (Mode >= 0.5): 3-phase cinematic — burst → chaos → recover
    // ====================================================================
    else {

        // --- Frame 1: Impact Burst (0.0 – 0.33) ---
        if (Time < 0.33) {
            float phase = Time / 0.33;

            // Initial whiteout
            float whiteout = 1.0 - smoothstep(0.0, 0.15, phase);
            whiteout *= 0.85 * Intensity;

            // Lens distortion: bulge then snap back
            float lensCurve = sin(phase * 3.14159);
            float lensStr = LensDistortStrength * lensCurve * Intensity;
            vec2 sampleUV = applyLensDistortion(texCoord, FocalUV, lensStr);
            vec3 distortedSample = texture(DiffuseSampler, sampleUV).rgb;

            // Radial blur rises then falls
            float blurCurve = sin(phase * 3.14159);
            float blurIntensity = blurCurve * Intensity;
            vec3 blurred = applyRadialBlur(distortedSample);
            vec3 color = mix(distortedSample, blurred, blurIntensity);

            // Chromatic aberration
            float chromaStr = ChromaticStrength * blurCurve * Intensity * 2.5;
            color = applyChromaticAberration(color, sampleUV, chromaStr);

            // Saturation boost
            float satBoost = blurCurve * Intensity * 3.0;
            color = boostSaturation(color, satBoost);
            color = min(color * (1.0 + satBoost * 0.25), 1.0);

            // Flash
            float flash = quickFlash(phase, 8.0) * 0.15 * Intensity * blurCurve;
            color += vec3(flash);

            // Shockwave
            float shock = computeShockwave(texCoord, FocalUV, phase, 2.5 * Speed);
            color += vec3(shock * Intensity);

            // Fresnel
            float fresnel = computeFresnel(texCoord);
            float fresnelBoost = fresnel * blurCurve * Intensity * 0.35;
            color = mix(color, color * 1.4, fresnelBoost);

            // Bicolor cutout fades in
            vec3 bicolorMap = impactColoredCutout(color);
            float bicolorBlend = smoothstep(0.15, 0.7, phase) * Intensity;
            color = mix(color, bicolorMap, bicolorBlend);

            // Whiteout overlay
            color = mix(color, vec3(1.0), whiteout);

            // Contrast punch
            float contrastStrength = 1.0 + Intensity * 0.5 * blurCurve;
            color = (color - 0.5) * contrastStrength + 0.5;
            color = clamp(color, 0.0, 1.0);

            fragColor = vec4(color, original.a);
            return;
        }

        // --- Frame 2: Chaos Invert (0.33 – 0.66) ---
        if (Time < 0.66) {
            float phase = (Time - 0.33) / 0.33;

            // Lens distortion residue
            float lensResidue = LensDistortStrength * (1.0 - phase) * 0.4 * Intensity;
            vec2 sampleUV = applyLensDistortion(texCoord, FocalUV, lensResidue);
            vec3 distortedSample = texture(DiffuseSampler, sampleUV).rgb;

            // Oscillating chromatic aberration
            float chromaChaos = ChromaticStrength * (0.8 + quickFlash(phase, 8.0) * 0.4) * Intensity;
            vec3 chromaSample = applyChromaticAberration(distortedSample, sampleUV, chromaChaos);

            // Oscillating invert
            float invertOsc = quickFlash(phase, 5.0);
            float factor = computeBicolorFactor(chromaSample, invertOsc);
            vec3 color = mix(ColorDark, ColorLight, factor);

            // Shockwave fading
            float shockTime = 1.0 + phase;
            float shockFade = (1.0 - phase);
            float shock = computeShockwave(texCoord, FocalUV, shockTime, 2.5 * Speed) * shockFade;
            color += vec3(shock * Intensity * 0.6);

            // Fresnel fading
            float fresnel = computeFresnel(texCoord);
            float fresnelFade = fresnel * (1.0 - phase) * Intensity * 0.2;
            color = mix(color, color * 1.3, fresnelFade);

            // Glitch
            float glitchStr = quickFlash(phase, 12.0) * 0.025 * (1.0 - abs(phase - 0.5) * 2.0);
            vec2 glitchUV = sampleUV + vec2(glitchStr, 0.0);
            vec3 glitchColor = texture(DiffuseSampler, clamp(glitchUV, vec2(0.0), vec2(1.0))).rgb;
            color = mix(color, glitchColor, glitchStr * 15.0);

            // Vignette
            vec2 center = texCoord - vec2(0.5);
            float dist = length(center);
            float vignette = 1.0 - dist * 0.10;
            color *= vignette;

            // Burst flashes
            float burst = quickFlash(phase, 15.0) * 0.15;
            color += vec3(burst);

            color = clamp(color, 0.0, 1.0);
            fragColor = vec4(color, original.a);
            return;
        }

        // --- Frame 3: Recovery (0.66 – 1.0) ---
        {
            float phase = (Time - 0.66) / 0.34;
            fragColor = doRecovery(original, phase, Time);
            return;
        }
    }
}
