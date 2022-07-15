float wavingTime = frametime * WAVING_SPEED;

const float PI = 3.1415927;
float pi2wt = 6.2831854 * (wavingTime * 24.0);

vec3 calcWave(vec3 pos, float fm, float mm, float ma, float f0, float f1, float f2, float f3, float f4, float f5) {
    vec3 ret;
    float magnitude, d0, d1, d2, d3;
    magnitude = sin(pi2wt * fm + pos.x*0.5 + pos.z*0.5 + pos.y*0.5) * mm + ma;
    d0 = sin(pi2wt * f0);
    d1 = sin(pi2wt * f1);
    d2 = sin(pi2wt * f2);
    ret.x = sin(pi2wt*f3 + d0 + d1 - pos.x + pos.z + pos.y) * magnitude;
    ret.z = sin(pi2wt*f4 + d1 + d2 + pos.x - pos.z + pos.y) * magnitude;
    ret.y = sin(pi2wt*f5 + d2 + d0 + pos.z + pos.y - pos.y) * magnitude;
    return ret;
}

vec3 calcMove(in vec3 pos, float f0, float f1, float f2, float f3, float f4, float f5, vec3 amp1, vec3 amp2) {
    vec3 move1 = calcWave(pos      , 0.0027, 0.0400, 0.0400, 0.0127, 0.0089, 0.0114, 0.0063, 0.0224, 0.0015) * amp1;
    vec3 move2 = calcWave(pos+move1, 0.0348, 0.0400, 0.0400, f0, f1, f2, f3, f4, f5) * amp2;
    vec3 returner = move1 + move2;
    return returner;
}

float calcLilypadMove(vec3 worldPos) {
    float wave = sin(2 * PI * (wavingTime*0.7 + worldPos.x * 0.14 + worldPos.z * 0.07))
                + sin(2 * PI * (wavingTime*0.5 + worldPos.x * 0.10 + worldPos.z * 0.20));
    return wave * 0.0125;
}

vec3 WavingBlocks(vec3 position, float istopv, float lmCoordY) {
    vec3 wave = vec3(0.0);
    vec3 worldpos = position + cameraPosition;

    #ifdef WAVING_CROPS
    if (mc_Entity.x == 59 && (istopv > 0.9 || fract(worldpos.y + 0.0675) > 0.01)) { // Crops
        if (length(position) < 2.0) wave.xz += position.xz*max(5.0/pow(max(length(position*vec3(8.0,2.0,8.0)-vec3(0.0,2.0,0.0)),2.0),1.0)-0.625,0.0);
        wave += calcMove(worldpos, 0.0041, 0.0070, 0.0044, 0.0038, 0.0240, 0.0000, vec3(0.4,0.0,0.4), vec3(0.2,0.0,0.2));
    }
    if (mc_Entity.x == 104 && (istopv > 0.9 || fract(worldpos.y + 0.0675) > 0.01)) { // Stems
        wave += calcMove(worldpos, 0.0041, 0.0070, 0.0044, 0.0038, 0.0240, 0.0000, vec3(0.1,0.4,0.1), vec3(0.05,0.2,0.05));
	}
    #endif
    #ifdef WAVING_FOLIAGE
    if (mc_Entity.x == 31 && istopv > 0.9) { // Foliage
        if (length(position) < 2.0) wave.xz += position.xz*max(5.0/pow(max(length(position*vec3(8.0,2.0,8.0)-vec3(0.0,2.0,0.0)),2.0),1.0)-0.625,0.0);
        wave += calcMove(worldpos, 0.0041, 0.0070, 0.0044, 0.0038, 0.0063, 0.0000, vec3(0.8,0.0,0.8), vec3(0.4,0.0,0.4));
    }
    if (mc_Entity.x == 175 || (mc_Entity.x == 176.0 && (istopv > 0.9 || fract(worldpos.y+0.005)>0.01))) { // Double Plants
        wave += calcMove(worldpos, 0.0041, 0.005, 0.0044, 0.0038, 0.0240, 0.0000, vec3(0.8,0.1,0.8), vec3(0.4,0.0,0.4));
	}
    if (mc_Entity.x == 6 && (istopv > 0.9 || fract(worldpos.y + 0.005) > 0.01)) { // Plants
        wave += calcMove(worldpos, 0.0041, 0.005, 0.0044, 0.0038, 0.0240, 0.0000, vec3(0.6,0.0,0.6), vec3(0.3,0.0,0.3));
	}
    #endif
    #ifdef WAVING_LEAVES
    if (mc_Entity.x == 18) // Leaves
        wave += calcMove(worldpos, 0.0040, 0.0064, 0.0043, 0.0035, 0.0037, 0.0041, vec3(0.5,0.5,0.5), vec3(0.25,0.25,0.25));
    #endif
    #ifdef WAVING_VINES
    if (mc_Entity.x == 9600) // Vines
        wave += calcMove(worldpos, 0.0040, 0.0064, 0.0043, 0.0035, 0.0037, 0.0041, vec3(0.25,0.5,0.25), vec3(0.125,0.25,0.125));
    #endif
    #ifdef WAVING_LILY_PADS
    if (mc_Entity.x == 9100) // Lily Pads
        wave.y += calcLilypadMove(worldpos);
    #endif

    #ifdef WAVING_EVERYTHING
        wave += calcWave(worldpos, 0.0027, 0.0400, 0.0400, 0.0127, 0.0089, 0.0114, 0.0063, 0.0224, 0.0015);
    #endif

    wave *= WAVING_INTENSITY * mix(1.0, RAIN_WAVING_INTENSITY, rainStrengthS);
    #ifndef DO_WAVING_UNDERGROUND
        wave *= float(lmCoordY > 0.9);
    #endif

    return wave;
}

float WavingWater(vec3 worldPos, float lmCoordY) {
	float fractY = fract(worldPos.y + cameraPosition.y + 0.005);
	worldPos += cameraPosition.xyz;

    float waterWaveTime = frametime * WATER_SPEED * 0.8;
	
	float wave = sin(6.28 * (waterWaveTime * 0.7 + worldPos.x * 0.14 + worldPos.z * 0.07)) +
				sin(6.28 * (waterWaveTime * 0.5 + worldPos.x * 0.10 + worldPos.z * 0.20));

    #if !defined DO_WAVING_UNDERGROUND && MC_VERSION >= 11800
        wave *= float(lmCoordY > 0.9);
    #endif
	if (fractY > 0.01) return wave * 0.0125;
	else return 0.0;
}