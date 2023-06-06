vec4 ReadNormal(vec2 coord) {
    coord = fract(coord) * vTexCoordAM.pq + vTexCoordAM.st;
	return textureGrad(normals, coord, dcdx, dcdy);
}

vec2 GetParallaxCoord(float parallaxFade, inout vec2 newCoord, inout float texDepth, inout vec3 traceCoordDepth) {
    if (parallaxFade >= 1.0) return vTexCoord.st;

    float invParallaxQuality = 1.0 / PARALLAX_QUALITY;
    vec3 normalMap = ReadNormal(vTexCoord.st).xyz * 2.0 - 1.0;
    float normalCheck = normalMap.x + normalMap.y;
    float minHeight = 1.0 - invParallaxQuality;

    if (viewVector.z >= 0.0 || ReadNormal(vTexCoord.st).a >= minHeight || normalCheck <= -1.999) return vTexCoord.st;

    float multiplier = 0.25 * (1.0 - parallaxFade) * PARALLAX_DEPTH /
                        (-viewVector.z * PARALLAX_QUALITY);

    vec2 interval = viewVector.xy * multiplier;

    #ifdef SELF_SHADOW
        float lowSurface = 0.0;
    #endif

    texDepth = 1.0;
    vec2 localCoord;
    int i = 0;

    for (; i < PARALLAX_QUALITY && texDepth <= 1.0 - float(i) * invParallaxQuality; i++) {
        localCoord = vTexCoord.st + float(i) * interval;
        texDepth = ReadNormal(localCoord).a;
    }

    float pI = float(max(i - 1, 0));
    traceCoordDepth.xy -= pI * interval;
    traceCoordDepth.z -= pI * invParallaxQuality;

    localCoord = fract(vTexCoord.st + pI * interval);
    newCoord = localCoord * vTexCoordAM.pq + vTexCoordAM.st;
    return localCoord;
}

float GetParallaxShadow(float parallaxFade, vec2 coord, vec3 lightVec, mat3 tbn, float parallaxDepth, float normalDepth) {
    if (dist >= PARALLAX_DISTANCE + 32.0) return 1.0;

    float parallaxshadow = 1.0;
    float invParallaxQuality = 1.0 / PARALLAX_QUALITY;
    float minHeight = 1.0 - invParallaxQuality;

    #ifdef PARALLAX
        float heightCheck = parallaxDepth;
    #else
        float heightCheck = normalDepth;
    #endif

    if (heightCheck >= minHeight) return 1.0;

    vec3 parallaxdir = tbn * lightVec;
    parallaxdir.xy *= 0.2 * SELF_SHADOW_ANGLE * PARALLAX_DEPTH;
    float step = 1.28 / PARALLAX_QUALITY;
    float height = normalDepth;

    #ifdef PARALLAX
        int parallaxD32 = PARALLAX_QUALITY / 32;
    #endif

    for(int i = 0; i < PARALLAX_QUALITY / 4 && parallaxshadow >= 0.01; i++) {
        float currentHeight = height + parallaxdir.z * step * i;

        vec2 parallaxCoord = fract(coord + parallaxdir.xy * i * step) * 
                             vTexCoordAM.pq + vTexCoordAM.st;

        float offsetHeight = textureGrad(normals, parallaxCoord, dcdx, dcdy).a;

        #ifdef PARALLAX
            if (i == parallaxD32) height = parallaxDepth;
        #endif

        parallaxshadow *= clamp(1.0 - (offsetHeight - currentHeight) * 40.0, 0.0, 1.0);
    }
    
    return mix(parallaxshadow, 1.0, parallaxFade);
}

#ifdef PARALLAX_SLOPE_NORMALS
    vec3 GetParallaxSlopeNormal(vec2 texCoord, float traceDepth, vec3 viewDir) {
        vec2 atlasPixelSize = 1.0 / atlasSize;
        float atlasAspect = atlasSize.x / atlasSize.y;
        vec2 atlasCoord = fract(texCoord) * vTexCoordAM.pq + vTexCoordAM.st;

        vec2 tileSize = atlasSize * vTexCoordAM.pq;
        vec2 tilePixelSize = 1.0 / tileSize;

        vec2 tex_snapped = floor(atlasCoord * atlasSize) * atlasPixelSize;
        vec2 tex_offset = atlasCoord - (tex_snapped + 0.5 * atlasPixelSize);

        vec2 stepSign = sign(tex_offset);
        vec2 viewSign = sign(viewDir.xy);

        bool dir = abs(tex_offset.x * atlasAspect) < abs(tex_offset.y);
        vec2 tex_x, tex_y;

        if (dir) {
            tex_x = texCoord - vec2(tilePixelSize.x * viewSign.x, 0.0);
            tex_y = texCoord + vec2(0.0, stepSign.y * tilePixelSize.y);
        }
        else {
            tex_x = texCoord + vec2(tilePixelSize.x * stepSign.x, 0.0);
            tex_y = texCoord - vec2(0.0, viewSign.y * tilePixelSize.y);
        }

        float height_x = ReadNormal(tex_x).a;
        float height_y = ReadNormal(tex_y).a;

        if (dir) {
            if (!(traceDepth > height_y && viewSign.y != stepSign.y)) {
                if (traceDepth > height_x) return vec3(-viewSign.x, 0.0, 0.0);

                if (abs(viewDir.y) > abs(viewDir.x))
                    return vec3(0.0, -viewSign.y, 0.0);
                else
                    return vec3(-viewSign.x, 0.0, 0.0);
            }

            return vec3(0.0, -viewSign.y, 0.0);
        }
        else {
            if (!(traceDepth > height_x && viewSign.x != stepSign.x)) {
                if (traceDepth > height_y) return vec3(0.0, -viewSign.y, 0.0);

                if (abs(viewDir.y) > abs(viewDir.x))
                    return vec3(0.0, -viewSign.y, 0.0);
                else
                    return vec3(-viewSign.x, 0.0, 0.0);
            }

            return vec3(-viewSign.x, 0.0, 0.0);
        }
    }
#endif
