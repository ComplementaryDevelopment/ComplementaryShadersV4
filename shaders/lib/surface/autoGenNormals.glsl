void AutoGenerateNormals(inout vec4 normalMap, vec3 albedoP, float delta) {
    float packSizeGN = 128.0;
    float lOriginalAlbedo = length(albedoP);
    float normalMult = max(1.0 - delta, 0.0) * 1.8 * sqrt(NORMAL_MULTIPLIER);
    float normalClamp = 0.05;

    #ifndef SAFE_GENERATED_NORMALS
        vec2 offsetR = 16.0 / atlasSize;
    #else
        vec2 offsetR = max(vTexCoordAM.z, vTexCoordAM.w) * vec2(float(atlasSize.y) / float(atlasSize.x), 1.0);
    #endif
    offsetR /= packSizeGN;
    
    vec2 midCoord = texCoord - vTexCoordL / 2.0;
    vec2 vTexCoordAM_M = vTexCoordAM.zw * (0.5 - 0.5 / packSizeGN);
    if (normalMult > 0.0) {
        for(int i = 0; i < 4; i++) {
            vec2 offsetCoord;
            if (i == 0) {
                offsetCoord = texCoord + vec2( 0.0, offsetR.y);
                if (offsetCoord.y > midCoord.y + vTexCoordAM_M.y) continue;
            } else if (i == 1) {
                offsetCoord = texCoord + vec2( offsetR.x, 0.0);
                if (offsetCoord.x > midCoord.x + vTexCoordAM_M.x) continue;
            } else if (i == 2) {
                offsetCoord = texCoord + vec2( 0.0,-offsetR.y);
                if (offsetCoord.y < midCoord.y - vTexCoordAM_M.y) continue;
            } else if (i == 3) {
                offsetCoord = texCoord + vec2(-offsetR.x, 0.0);
                if (offsetCoord.x < midCoord.x - vTexCoordAM_M.x) continue;
            }

            float lNearbyAlbedo = length(texture2D(texture, offsetCoord).rgb);
            float dif = lOriginalAlbedo - lNearbyAlbedo;
            if (dif > 0.0) dif = max(dif - normalClamp, 0.0);
            else           dif = min(dif + normalClamp, 0.0);
            dif *= normalMult;
            if (i == 0)
                normalMap.y += dif;
            else if (i == 1)
                normalMap.x += dif;
            else if (i == 2)
                normalMap.y -= dif;
            else if (i == 3)
                normalMap.x -= dif;
        }
    }
}