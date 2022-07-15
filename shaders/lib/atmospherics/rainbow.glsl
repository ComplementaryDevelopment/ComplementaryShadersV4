float rainbowTime = sqrt3(max(pow2(pow2(sunVisibility * shadowFade)) - timeBrightness * 2.5, 0.0));
#ifdef RAINBOW_AFTER_RAIN_CHECK
    rainbowTime *= sqrt3(max(wetness - 0.1, 0.0) * (1.0 - rainStrength) * (1.0 - rainStrengthS)) * isRainy;
#endif

if (rainbowTime > 0.001) {
    float rainbowDistance = max(far, 256.0) * 0.25;
    float rainbowLength = max(far, 256.0) * 0.75;

    vec3 rainbowTranslucent = translucent;
    if (water) rainbowTranslucent = vec3(float(isEyeInWater == 1));
    
    vec4 viewPosZ1 = gbufferProjectionInverse * (vec4(texCoord, z1, 1.0) * 2.0 - 1.0);
    viewPosZ1 /= viewPosZ1.w;
    float lViewPosZ1 = length(viewPosZ1.xyz);
    float lViewPosZ0 = length(viewPos.xyz);
    
    float rainbowCoord = 1.0 - (cosS + 0.75) / (0.0625 * RAINBOW_DIAMETER);
    
    float rainbowFactor = clamp(1.0 - rainbowCoord, 0.0, 1.0) * clamp(rainbowCoord, 0.0, 1.0);
          rainbowFactor *= rainbowFactor * (3.0 - 2.0 * rainbowFactor);
          rainbowFactor *= min(max(lViewPosZ1 - rainbowDistance, 0.0) / rainbowLength, 1.0);
          rainbowFactor *= rainbowTime;
        #ifdef CAVE_SKY_FIX
          rainbowFactor *= 1.0 - isEyeInCave;
        #endif

    if (rainbowFactor > 0.0) {
        #if RAINBOW_STYLE == 1
            float rainbowCoordM = pow(rainbowCoord, 1.4 + max(rainbowCoord - 0.5, 0.0) * 1.6);
            rainbowCoordM = smoothstep(0.0, 1.0, rainbowCoordM) * 0.85;
            rainbowCoordM += (dither - 0.5) * 0.1;
            vec3 rainbow = clamp(abs(mod(rainbowCoordM * 6.0 + vec3(-0.55,4.3,2.2) ,6.0)-3.0)-1.0, 0.0, 1.0);
                rainbowCoordM += 0.1;
                rainbow += clamp(abs(mod(rainbowCoordM * 6.0 + vec3(-0.55,4.3,2.2) ,6.0)-3.0)-1.0, 0.0, 1.0);
                rainbowCoordM -= 0.2;
                rainbow += clamp(abs(mod(rainbowCoordM * 6.0 + vec3(-0.55,4.3,2.2) ,6.0)-3.0)-1.0, 0.0, 1.0);
                rainbow /= 3.0;
            rainbow.r += pow2(max(rainbowCoord - 0.5, 0.0)) * (max(1.0 - rainbowCoord, 0.0)) * 26.0;
            rainbow = pow(rainbow, vec3(2.2)) * vec3(0.25, 0.075, 0.25) * 3.0;
        #else
            float rainbowCoordM = pow(rainbowCoord, 1.35);
            rainbowCoordM = smoothstep(0.0, 1.0, rainbowCoordM);
            vec3 rainbow = clamp(abs(mod(rainbowCoordM * 6.0 + vec3(0.0,4.0,2.0) ,6.0)-3.0)-1.0, 0.0, 1.0);
            rainbow *= rainbow * (3.0 - 2.0 * rainbow);
            rainbow = pow(rainbow, vec3(2.2)) * vec3(0.25, 0.075, 0.25) * 3.0;
        #endif

        if (z1 > z0 && lViewPosZ0 < rainbowDistance + rainbowLength)
        rainbow *= mix(rainbowTranslucent, vec3(1.0),
                    clamp((lViewPosZ0 - rainbowDistance) / rainbowLength, 0.0, 1.0)
                    );
        if (isEyeInWater == 1) rainbow *= float(water) * 0.05;

        color.rgb += rainbow * rainbowFactor;
    }
}