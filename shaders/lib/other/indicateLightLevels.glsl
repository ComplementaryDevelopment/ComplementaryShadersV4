#ifdef OVERWORLD
    #if MC_VERSION < 11800
        float lxMin = 0.533334;
    #else
        float lxMin = 0.000001;
    #endif
        float lyMin = 0.533334;
#else
    float lxMin = 0.8;
    float lyMin = 0.533334;
#endif

bool xDanger = false;
bool yDanger = false;
if (lmCoord.x < lxMin) xDanger = true;
#ifndef NETHER
    if (lmCoord.y < lyMin) yDanger = true;
#else
    if (lmCoord.x < lyMin) yDanger = true;
#endif

if (xDanger) {
    vec2 indicatePos = worldPos.xz + cameraPosition.xz;
    indicatePos = 1.0 - 2.0 * abs(fract(indicatePos) - 0.5);
    float minPos = min(indicatePos.x, indicatePos.y);
    float maxPos = max(indicatePos.x, indicatePos.y);
    float dif = abs(indicatePos.x - indicatePos.y);

            vec3 dangerColor = vec3(0.4, 0.2, 0.0);
    if (yDanger) dangerColor = vec3(0.125, 0.0, 0.0);

    float indicateFactor = float(minPos > 0.5);
    albedo.rgb = mix(albedo.rgb, dangerColor, indicateFactor);
}