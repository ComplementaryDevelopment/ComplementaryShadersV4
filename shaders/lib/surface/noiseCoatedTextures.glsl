void NoiseCoatTextures(inout vec4 albedo, inout float smoothness, inout float emissive, inout float metalness, vec3 worldPos, float miplevel, float noiseVaryingM, float snowFactor) {
    float packSizeNT = 64.0;
    #ifndef SAFE_GENERATED_NORMALS
        vec2 noiseCoord = floor(vTexCoordL.xy / 32.0 * packSizeNT * atlasSize) / packSizeNT / 12.0;
    #else
        vec2 offsetR = max(vTexCoordAM.z, vTexCoordAM.w) * vec2(float(atlasSize.y) / float(atlasSize.x), 1.0);
        vec2 noiseCoord = floor(vTexCoordL.xy / 2.0 * packSizeNT / offsetR) / packSizeNT / 12.0;
    #endif
    if (noiseVaryingM < 999.0) {
        noiseCoord += 0.21 * (floor((worldPos.xz + cameraPosition.xz) + 0.001) + floor((worldPos.y + cameraPosition.y) + 0.001));
    } else {
        noiseVaryingM -= 1000.0;
    }
    float noiseTexture = texture2D(noisetex, noiseCoord).r;
    noiseTexture = noiseTexture * 0.75 + 0.625;
    float colorBrightness = 0.2126 * albedo.r + 0.7152 * albedo.g + 0.0722 * albedo.b;
    float noiseFactor = 0.7 * sqrt(1.0 - colorBrightness) * (1.0 - 0.5 * metalness)
                        * (1.0 - 0.25 * smoothness) * max(1.0 - emissive, 0.0);
    #if defined SNOW_MODE && defined OVERWORLD
        noiseFactor *= 2.0 * max(0.5 - snowFactor, 0.0);
    #endif
    noiseFactor *= noiseVaryingM;
    noiseFactor *= max(1.0 - miplevel * 0.25, 0.0);
    noiseTexture = pow(noiseTexture, noiseFactor);
    albedo.rgb *= noiseTexture;
    smoothness = min(smoothness * sqrt(2.0 - noiseTexture), 1.0);
}