vec4 GetVolumetricClouds(float depth0, float depth1, vec3 vlAlbedo, float dither, vec4 viewPos) {
    vec4 clouds = vec4(0.0);

    //Color+
    float sunVisibility2 = sunVisibility * sunVisibility;
    float sunVisibility4 = sunVisibility2 * sunVisibility2;

    vec3 cloudNightColor = ambientCol * 2.0;
    vec3 cloudDayColor = pow(lightCol, vec3(1.5)) * (0.5 + 0.5 * timeBrightness);
    vec3 cloudRainColor = normalize(pow(lightCol, vec3(1.0 + sunVisibility4))) * (0.015 + 0.1 * sunVisibility4 + 0.1 * timeBrightness);

    vec3 cloudUpColor = mix(cloudNightColor, cloudDayColor, sunVisibility4);
         cloudUpColor = mix(cloudUpColor, cloudRainColor, rainStrengthS);
    
    vec3 cloudDownColor = cloudUpColor * 0.35;
	
    float cloudAmountM = 0.075 * CLOUD_AMOUNT * (1.0 - 0.35 * rainStrengthS);

    //Settings
    float cloudAltitude = 128.0;
    float cloudThickness = 24.0;
    int sampleCount = 20;
    float minDistFactor = 160.0 / sampleCount * sqrt(far / 256.0);

    //Ray Trace
    for(int i = 0; i < sampleCount; i++) {
        float minDist = (i + dither) * minDistFactor;

        if (depth1 < minDist || (depth0 < minDist && vlAlbedo == vec3(0.0))) break;

        float distX = GetDistX(minDist);
        vec4 viewPos = gbufferProjectionInverse * (vec4(texCoord, distX, 1.0) * 2.0 - 1.0);
        viewPos /= viewPos.w;
        vec4 wpos = gbufferModelViewInverse * viewPos;
        vec3 worldPos = wpos.xyz + cameraPosition.xyz + vec3(cloudtime * 2.0, 0.0, 0.0);

		float yFactor = max(cloudThickness - abs(worldPos.y - cloudAltitude), 0.0) / cloudThickness;
        float disFalloff = max(32.0 - max(length(wpos.xz) - 256.0, 0.0), 0.0) / 32.0;
        float smoke = 0.0;
        if (yFactor * disFalloff > 0.001) {
            worldPos.xz *= 2.0;
            smoke  = texture2D(noisetex, worldPos.xz * 0.0002  ).r * 0.5;
            smoke += texture2D(noisetex, worldPos.xz * 0.0001  ).r;
            smoke += texture2D(noisetex, worldPos.xz * 0.00005 ).r;
            smoke += texture2D(noisetex, worldPos.xz * 0.000025).r * 2.0;
        }

        smoke *= disFalloff;
        smoke *= sqrt1(yFactor) * 0.35;
        smoke = max(smoke - cloudAmountM, 0.0);
        
        float blend = ( (worldPos.y - cloudAltitude) / cloudThickness + 1.0 ) * 0.5;
        blend = clamp(blend, 0.0, 1.0);
        blend *= blend;
        vec3 cloudColorSample = mix(cloudDownColor, cloudUpColor, blend);
        if (depth0 < minDist) cloudColorSample *= vlAlbedo;
        clouds.rgb = mix(cloudColorSample, clouds.rgb, min(clouds.a, 1.0));
        
        clouds.a += smoke * 256.0 / sampleCount;
    }

    clouds *= 0.9;
    clouds += clouds * dither * 0.19;
    clouds = sqrt(clouds);

    return clouds;
}