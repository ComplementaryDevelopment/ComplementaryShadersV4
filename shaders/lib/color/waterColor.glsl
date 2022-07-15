#if MC_VERSION > 10711
    vec4 underwaterColor = vec4(pow(fogColor, vec3(UNDERWATER_R, UNDERWATER_G, UNDERWATER_B)) * UNDERWATER_I * 0.2, 1.0);
#else
    vec4 underwaterColor = vec4(pow(vec3(0.2, 0.3, 1.0), vec3(UNDERWATER_R, UNDERWATER_G, UNDERWATER_B)) * UNDERWATER_I * 0.2, 1.0);
#endif

vec4 waterColorSqrt = vec4(WATER_R, WATER_G, WATER_B, 255.0) * WATER_I / 255.0;
vec4 waterColor = waterColorSqrt * waterColorSqrt;

const float waterFog = WATER_FOG;

const float waterAlpha = WATER_OPACITY;