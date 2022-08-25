uniform sampler2DShadow shadowtex0;

#if defined COLORED_SHADOWS && defined OVERWORLD
uniform sampler2D shadowcolor1;
#endif

#if defined PROJECTED_CAUSTICS && defined WATER_CAUSTICS && defined OVERWORLD && !defined GBUFFERS_WATER
uniform sampler2D shadowcolor0;
#endif

vec2 shadowoffsets[8] = vec2[8](    vec2( 0.0   , 1.0   ),
                                    vec2( 0.7071, 0.7071),
                                    vec2( 1.0   , 0.0   ),
                                    vec2( 0.7071,-0.7071),
                                    vec2( 0.0   ,-1.0   ),
                                    vec2(-0.7071,-0.7071),
                                    vec2(-1.0   , 0.0   ),
                                    vec2(-0.7071, 0.7071));

vec2 offsetDist(float x, float s) {
	float n = fract(x * 1.414) * 3.1415;
    return vec2(cos(n), sin(n)) * 1.4 * x / s;
}

vec3 SampleBasicShadow(vec3 shadowPos, inout float water) {
    float shadow0 = shadow2D(shadowtex0, vec3(shadowPos.st, shadowPos.z)).x;

    #if (defined COLORED_SHADOWS || (defined PROJECTED_CAUSTICS && defined WATER_CAUSTICS && !defined GBUFFERS_WATER)) && defined OVERWORLD
        vec3 shadowcol = vec3(0.0);
        if (shadow0 < 1.0) {
            float shadow1 = shadow2D(shadowtex1, vec3(shadowPos.st, shadowPos.z)).x;
            if (shadow1 > 0.9999) {
                #if defined COLORED_SHADOWS && defined OVERWORLD
                    shadowcol = texture2D(shadowcolor1, shadowPos.st).rgb * shadow1;
                #endif
                #if defined PROJECTED_CAUSTICS && defined WATER_CAUSTICS && defined OVERWORLD && !defined GBUFFERS_WATER
                    water = texture2D(shadowcolor0, shadowPos.st).r * shadow1;
                #endif
            }
        }

        return shadowcol * (1.0 - shadow0) + shadow0;
    #else
        return vec3(shadow0);
    #endif
}

vec3 SampleFilteredShadow(vec3 shadowPos, float offset, inout float water) {
    vec3 shadow = SampleBasicShadow(vec3(shadowPos.st, shadowPos.z), water) * 2.0;

    for(int i = 0; i < 8; i++) {
        shadow+= SampleBasicShadow(vec3(offset * 1.2 * shadowoffsets[i] + shadowPos.st, shadowPos.z), water);
    }

    return shadow * 0.1;
}

float InterleavedGradientNoise() {
	float n = 52.9829189 * fract(0.06711056 * gl_FragCoord.x + 0.00583715 * gl_FragCoord.y);
	return fract(n + 1.61803398875 * mod(float(frameCounter), 3600.0));
}

vec3 SampleTAAFilteredShadow(vec3 shadowPos, float offset, inout float water, int doSubsurface) {
    float noise = InterleavedGradientNoise();
    vec3 shadow = vec3(0.0);
    offset = offset * (2.0 - 0.5 * (0.85 + 0.25 * (3072.0 / shadowMapResolution)));
    if (shadowMapResolution < 400.0) offset *= 30.0;

    #if SHADOW_SUBSURFACE < 3
        int sampleCount = 2;
    #else
        int sampleCount = 2 + doSubsurface;
    #endif

    for(int i = 0; i < sampleCount; i++) {
        vec2 offset = offsetDist(noise + i, sampleCount) * offset;
        shadow += SampleBasicShadow(vec3(shadowPos.st + offset, shadowPos.z), water);
        shadow += SampleBasicShadow(vec3(shadowPos.st - offset, shadowPos.z), water);
    }
    
    shadow /= sampleCount * 2;

    return shadow;
}

vec3 GetShadow(vec3 shadowPos, float offset, inout float water, int doSubsurface) {
    #ifdef SHADOW_FILTER
        #if AA > 1
            vec3 shadow = SampleTAAFilteredShadow(shadowPos, offset, water, doSubsurface);
        #else
            vec3 shadow = SampleFilteredShadow(shadowPos, offset, water);
        #endif
    #else
       vec3 shadow = SampleBasicShadow(shadowPos, water);
    #endif

    return shadow;
}