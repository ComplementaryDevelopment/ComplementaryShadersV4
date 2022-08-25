#if defined SHADOWS && ((defined PROJECTED_CAUSTICS && !defined GBUFFERS_WATER) || defined COLORED_SHADOWS) && defined OVERWORLD
	uniform sampler2DShadow shadowtex1;
#endif

#if (defined OVERWORLD || defined END || defined SEVEN) && defined SHADOWS
	#include "/lib/lighting/shadows.glsl"

	vec3 DistortShadow(inout vec3 worldPos, float distortFactor) {
		worldPos.xy /= distortFactor;
		worldPos.z *= 0.2;
		return worldPos * 0.5 + 0.5;
	}
#endif

#if defined WATER_CAUSTICS && defined OVERWORLD
	#include "/lib/lighting/caustics.glsl"
#endif

float GetFakeShadow(float skyLight) {
	float fakeShadow = 0.0;

	#ifndef END
		if (isEyeInWater == 0) skyLight = pow(skyLight, 30.0);
		fakeShadow = skyLight;
	#else
		#ifdef SHADOWS
			fakeShadow = 1.0;
		#else
			fakeShadow = 0.0;
		#endif
	#endif

	return fakeShadow;
}

void GetLighting(inout vec3 albedo, inout vec3 shadow, inout vec3 lightAlbedo, vec3 viewPos, float lViewPos, vec3 worldPos,
                 vec2 lightmap, float smoothLighting, float NdotL, float quarterNdotU,
                 float parallaxShadow, float emissive, float subsurface, float leaves, float materialAO) {
	vec3 fullShadow = vec3(0.0);
	float fullShadow1 = 0.0;
	float fakeShadow = 0.0;
	float shadowMult = 1.0;
	float shadowTime = 1.0;
	float water = 0.0;
	
	#if PIXEL_SHADOWS > 0 && !defined GBUFFERS_HAND
		worldPos = floor((worldPos + cameraPosition) * PIXEL_SHADOWS + 0.001) / PIXEL_SHADOWS - cameraPosition + 0.5 / PIXEL_SHADOWS;
	#endif

    #if defined OVERWORLD || defined END || defined SEVEN
		#ifdef SHADOWS
			shadow = vec3(1.0);
			if ((NdotL > 0.0 || subsurface > 0.001)) {
				float shadowLength = shadowDistance * 0.9166667 - length(vec4(worldPos.x, worldPos.y, worldPos.y, worldPos.z));
				//shadowDistance * 0.9166667 is shadowDistance - shadowDistance / 12.0

				#if (defined OVERWORLD || defined SEVEN) && defined LIGHT_LEAK_FIX
					if (isEyeInWater == 0) shadowLength *= float(lightmap.y > 0.001);
				#endif

				#ifdef TEST_12312
					vec3 shadowPos = WorldToShadow(worldPos);
					float distb = sqrt(shadowPos.x * shadowPos.x + shadowPos.y * shadowPos.y);
					float distortFactor = distb * shadowMapBias + (1.0 - shadowMapBias);
					shadowPos = DistortShadow(shadowPos, distortFactor);

					bool doShadow = min2(shadowPos.xy) > 0.0
								 && max2(shadowPos.xy) < 1.0;
					if (!doShadow || shadowLength < 0.000001) albedo.rgb = vec3(1.0, 0.0, 1.0);
					shadowLength = 999999.0;
				#endif

				if (shadowLength > 0.000001) {
					#ifndef TEST_12312
						vec3 shadowPos = WorldToShadow(worldPos);
						float distb = sqrt(shadowPos.x * shadowPos.x + shadowPos.y * shadowPos.y);
						float distortFactor = distb * shadowMapBias + (1.0 - shadowMapBias);
						shadowPos = DistortShadow(shadowPos, distortFactor);
					#endif

					#ifdef NORMAL_MAPPING
						float NdotLm = clamp(dot(normal, lightVec) * 1.01 - 0.01, 0.0, 1.0) * 0.99 + 0.01;
						NdotL = min(NdotL, NdotLm);
					#else
						float NdotLm = NdotL * 0.99 + 0.01;
					#endif

					float dotWorldPos = dot(worldPos.xyz, worldPos.xyz);
					
					float biasFactor = sqrt(1.0 - NdotLm * NdotLm) / NdotLm;
					float distortBias = distortFactor * shadowDistance / 256.0;
					distortBias *= 8.0 * distortBias;
					
					float bias = (distortBias * biasFactor + dotWorldPos * 0.000005 + 0.05) / shadowMapResolution;
					float offset = 1.0 / shadowMapResolution;

					int doSubsurface = 0;
					if (subsurface > 0.001) {
						if (leaves < 0.5) {
							float UdotLm = clamp(dot(upVec, lightVec) * 1.01 - 0.01, 0.0, 1.0) * 0.99 + 0.01;
							float biasFactorF = sqrt(1.0 - UdotLm * UdotLm) / UdotLm;
							bias = (distortBias * biasFactorF + 0.05) / shadowMapResolution * 1.3;
						} else bias = 0.0002;
						offset = 0.002;					
    					#if SHADOW_SUBSURFACE > 2
							doSubsurface = 14;
						#endif
					}
					if (isEyeInWater == 1) offset *= 5.0;

					#if PIXEL_SHADOWS > 0 && !defined GBUFFERS_HAND
						bias += 0.0025 / PIXEL_SHADOWS * (1.0 + subsurface);
					#endif

					shadowPos.z -= bias;
					shadow = GetShadow(shadowPos, offset, water, doSubsurface);

					float extraSideLight = 1.0;
					shadow *= (1.0 + extraSideLight) - extraSideLight * quarterNdotU;

					#if defined PROJECTED_CAUSTICS && defined WATER_CAUSTICS && defined OVERWORLD && !defined GBUFFERS_WATER
						if (isEyeInWater == 0) {
							water = float(water > 0.99);
							water *= sqrt2(NdotL);
							float shadowSum = (shadow.r + shadow.g + shadow.b) / 3.0;
							water *= pow2(1.0 - shadowSum);
						}
						#ifdef GBUFFERS_ENTITIES
							if (entityId == 1089) { // Boats
								water = 0.0;
							}
						#endif
					#endif
				}

				float shadowSmooth = 16.0;
				if (shadowLength < shadowSmooth) {
					float shadowLengthDecider = max(shadowLength / shadowSmooth, 0.0);
					float skyLightShadow = GetFakeShadow(lightmap.y);
					shadow = mix(vec3(skyLightShadow), shadow, shadowLengthDecider);
					subsurface *= mix(subsurface * 0.5, subsurface, shadowLengthDecider);
					fakeShadow = mix(1.0, fakeShadow, shadowLengthDecider);
					fakeShadow = 1.0 - fakeShadow;
					fakeShadow *= fakeShadow;
					fakeShadow = 1.0 - fakeShadow;
				}

				#ifdef TEST_12312
					if (shadow.r < 0.1 && albedo.r + albedo.b < 1.9) {
						float timeThing1 = abs(fract(frameTimeCounter * 1.35) - 0.5) * 2.0;
						float timeThing2 = abs(fract(frameTimeCounter * 1.15) - 0.5) * 2.0;
						float timeThing3 = abs(fract(frameTimeCounter * 1.55) - 0.5) * 2.0;
						albedo.rgb = 3.0 * pow(vec3(timeThing1, timeThing2, timeThing3), vec3(3.2));
					}
				#endif
			}
		#else
			shadow = vec3(GetFakeShadow(lightmap.y));
		#endif
		
		#if defined CLOUD_SHADOW && defined OVERWORLD
			float cloudSize = 0.000025;
			vec2 wind = vec2(frametime, 0.0) * CLOUD_SPEED * 6.0;
			float cloudShadow = texture2D(noisetex, cloudSize * (wind + (worldPos.xz + cameraPosition.xz))).r;
			cloudShadow += texture2D(noisetex, cloudSize * (vec2(1000.0) + wind + (worldPos.xz + cameraPosition.xz))).r;
			cloudShadow = clamp(cloudShadow, 0.0, 1.0);
			cloudShadow *= cloudShadow;
			cloudShadow *= cloudShadow;
			shadow *= cloudShadow;
		#endif

		#ifdef ADV_MAT
			#ifdef SELF_SHADOW
				float shadowNdotL = min(NdotL + 0.5, 1.0);
				shadowNdotL *= shadowNdotL;
				shadow *= mix(1.0, parallaxShadow, shadowNdotL);
			#endif
		#endif
		
		fullShadow = shadow * max(NdotL, subsurface * (1.0 - max(rainStrengthS, (1.0 - sunVisibility)) * 0.40));

		fullShadow1 = (fullShadow.r + fullShadow.g + fullShadow.b) / 3.0;

		#ifdef ADV_MAT
			shadow *= float(fullShadow1 > 0.01);
		#endif

		#if defined OVERWORLD && !defined TWO
			shadowMult = 1.0 * (1.0 - 0.95 * rainStrengthS);
			
			shadowTime = abs(sunVisibility - 0.5) * 2.0;
			shadowTime *= shadowTime;
			shadowMult *= shadowTime * shadowTime;
			
			#ifndef LIGHT_LEAK_FIX
				ambientCol *= pow(lightmap.y, 2.5);
			#else
				if (isEyeInWater == 1) ambientCol *= pow(lightmap.y, 2.5);
			#endif
			
			vec3 lightingCol = pow(lightCol, vec3(1.0 + sunVisibility * 1.5 - 0.5 * timeBrightness));
			#ifdef SHADOWS
				lightingCol *= (1.0 + 0.5 * leaves);
			#else
				lightingCol *= (1.0 + 0.4 * leaves);
			#endif
			vec3 shadowDecider = fullShadow * shadowMult;
			if (isEyeInWater == 1) shadowDecider *= pow(min(lightmap.y * 1.03, 1.0), 200.0);
			ambientCol *= AMBIENT_GROUND;
			lightingCol *= LIGHT_GROUND;
			vec3 sceneLighting = mix(ambientCol, lightingCol, shadowDecider);
			
			#ifdef LIGHT_LEAK_FIX
				if (isEyeInWater == 0) sceneLighting *= pow(lightmap.y, 2.5);
			#endif
		#endif

		#ifdef END
			vec3 ambientEnd = endCol * 0.07;
			vec3 lightEnd   = endCol * 0.17;
			vec3 shadowDecider = fullShadow;
			vec3 sceneLighting = mix(ambientEnd, lightEnd, shadowDecider);
			sceneLighting *= END_I * (0.7 + 0.4 * vsBrightness);
		#endif

		#ifdef TWO
			#ifndef ABYSS
				vec3 sceneLighting = vec3(0.0003, 0.0004, 0.002) * 10.0;
			#else
				vec3 sceneLighting = pow(fogColor, vec3(0.2)) * 0.125;
			#endif
		#endif
		
		#if defined SEVEN && !defined SEVEN_2
			sceneLighting = vec3(0.005, 0.006, 0.018) * 133 * (0.3 * fullShadow + 0.025);
		#endif
		#ifdef SEVEN_2
			vec3 sceneLighting = vec3(0.005, 0.006, 0.018) * 33 * (1.0 * fullShadow + 0.025);
		#endif
		#if defined SEVEN || defined SEVEN_2
			sceneLighting *= lightmap.y * lightmap.y;
		#endif
		
		#if defined SHADOWS && defined OVERWORLD
			if (subsurface > 0.001) {
				float VdotL = clamp(dot(normalize(viewPos.xyz), lightVec), 0.0, 1.0);
				
				vec3 subsurfaceGlow = (5.5 + 8.0 * leaves) * (1.0 - fakeShadow) * shadowTime * fullShadow * pow(VdotL, 10.0);
				subsurfaceGlow *= 1.0 - rainStrengthS * 0.68;
				albedo.rgb += max(albedo.g * normalize(sqrt((albedo.rgb + vec3(0.001)) * lightCol)) * subsurfaceGlow, vec3(0.0));
			}
		#endif
    #else
		#ifdef NETHER
			#if MC_VERSION >= 11600
				if (quarterNdotU < 0.5625) quarterNdotU = 0.5625 + (0.4 - quarterNdotU * 0.7111111111111111);
			#endif
		
			#if MC_VERSION >= 11600
				vec3 sceneLighting = normalize(sqrt(max(fogColor, vec3(0.001)))) * 0.0385 * NETHER_I * (vsBrightness*0.5 + 0.6);
			#else
				vec3 sceneLighting = normalize(netherCol) * 0.0385 * NETHER_I * (vsBrightness*0.5 + 0.6);
			#endif
		#else
			vec3 sceneLighting = vec3(0.0);
		#endif
    #endif

	#ifdef DYNAMIC_SHADER_LIGHT
		float handLight = min(float(heldBlockLightValue2 + heldBlockLightValue), 15.0) / 15.0;

		float handLightFactor = 1.0 - min(DYNAMIC_LIGHT_DISTANCE * handLight, lViewPos) / (DYNAMIC_LIGHT_DISTANCE * handLight);
		#ifdef GBUFFERS_WATER
			if (mat > 0.05) handLight *= 0.9;
		#endif
		#ifdef GBUFFERS_HAND
			handLight = min(handLight, 0.95);
		#endif
		float finalHandLight = handLight * handLightFactor;
		lightmap.x = max(finalHandLight * 0.95, lightmap.x);
	#endif

	float lightmapX2 = lightmap.x * lightmap.x;
	float lightmapXM1 = pow2(pow2(lightmapX2)) * lightmapX2;
	float lightmapXM2 = max((lightmap.x - 0.05) * 0.925, 0.0);
	float newLightmap = mix(lightmapXM1 * 5.0 + lightmapXM2, lightmapXM1 * 4.0 + lightmapXM2 * 1.5, vsBrightness);

	#ifdef BLOCKLIGHT_FLICKER
		float frametimeM = frametime * 0.5;
		float lightFlicker = min(((1 - clamp(sin(fract(frametimeM*2.7) + frametimeM*3.7) - 0.75, 0.0, 0.25) * BLOCKLIGHT_FLICKER_STRENGTH)
					* max(fract(frametimeM*1.4), (1 - BLOCKLIGHT_FLICKER_STRENGTH * 0.25))) / (1.0 - BLOCKLIGHT_FLICKER_STRENGTH * 0.2)
					, 0.8) * 1.25
					* 0.8 + 0.2 * clamp((cos(fract(frametimeM*0.47) * fract(frametimeM*1.17) + fract(frametimeM*2.17))) * 1.5, 1.0 - BLOCKLIGHT_FLICKER_STRENGTH * 0.25, 1.0);
		newLightmap *= lightFlicker;
	#endif

	#ifdef RANDOM_BLOCKLIGHT
		float CLr = texture2D(noisetex, 0.00006 * (worldPos.xz + cameraPosition.xz)).r;
		float CLg = texture2D(noisetex, 0.00009 * (worldPos.xz + cameraPosition.xz)).r;
		float CLb = texture2D(noisetex, 0.00014 * (worldPos.xz + cameraPosition.xz)).r;
		blocklightCol = vec3(CLr, CLg, CLb);
		blocklightCol *= blocklightCol * BLOCKLIGHT_I * 2.22;
	#endif

	#ifdef COLORED_LIGHT
		#ifdef GBUFFERS_TERRAIN
			if (lightVarying > 0.5) {
				if (lightVarying < 1.5) {
					lightAlbedo = albedo;
				}
				else if (lightVarying < 2.5) {
					#ifdef COMPBR
					lightAlbedo = float(eyeBrightness.x < 144) * emissive * albedo;
					#else
					lightAlbedo = float(eyeBrightness.x < 144) * albedo;
					#endif
				}
				else if (lightVarying < 3.5) {
					lightAlbedo = vec3(0.7, 0.5, 0.2);
				}
				else if (lightVarying < 4.5) { // Sea Lantern, Beacon, End Rod
					lightAlbedo = albedo * vec3(0.6, 0.85, 1.0);
				}
				else if (lightVarying < 5.5) { // Sea Pickles
					lightAlbedo = vec3(0.2, 0.9, 1.0);
				}
			}
			//if (lViewPos > 16.0) lightAlbedo = vec3(0.0);
		#endif

		vec3 blocklightComplex = texture2D(colortex9, texCoord).rgb;
		blocklightComplex *= 0.75 + 2.0 * blocklightComplex.b;

		blocklightCol = mix(blocklightCol, blocklightComplex, 0.7);

		#ifdef DYNAMIC_SHADER_LIGHT
			#include "/lib/ifchecks/heldColoredLighting.glsl"
		#endif
	#endif

    vec3 blockLighting = blocklightCol * newLightmap * newLightmap;

	vec3 minLighting = vec3(0.000000000001 + (MIN_LIGHT * 0.0035 * (vsBrightness*0.0775 + 0.0125)));
	#ifndef MIN_LIGHT_EVERYWHERE
		minLighting *= (1.0 - eBS);
	#endif
	#ifdef GBUFFERS_WATER
		minLighting *= 2.0;
	#endif
	
	float shade = pow(quarterNdotU, SHADING_STRENGTH);

	vec3 emissiveLighting = albedo.rgb * emissive * 20.0 / shade * EMISSIVE_MULTIPLIER;

    float nightVisionLighting = nightVision * 0.25;

	if (smoothLighting > 0.01) {
		smoothLighting = clamp(smoothLighting, 0.0, 1.0);
		#if VAO_STRENGTH == 10
			smoothLighting *= smoothLighting;
		#else
			smoothLighting = pow(smoothLighting, 0.2 * VAO_STRENGTH);
		#endif
	} else smoothLighting = 1.0;

	if (materialAO < 1.0) {
		smoothLighting *= pow(materialAO, max(1.0 - shadowTime * length(shadow) * NdotL - lmCoord.x, 0.0));
	}

    albedo *= sceneLighting + blockLighting + emissiveLighting + nightVisionLighting + minLighting;
	albedo *= shade;
	albedo *= smoothLighting;

	#if defined WATER_CAUSTICS && defined OVERWORLD
		#if defined PROJECTED_CAUSTICS && !defined GBUFFERS_WATER
		if (water > 0.0 || isEyeInWater == 1) {
		#else
		if ((isEyeInWater != 0 && isEyeInWater != 2 && isEyeInWater != 3)) {
		// Not just doing (isEyeInWater == 1) to fix caustics appearing in shadows on AMD Mesa with Iris
		#endif
			vec3 albedoCaustic = albedo;

			float skyLightMap = lightmap.y * lightmap.y * (3.0 - 2.0 * lightmap.y);
			float skyLightMapA = pow2(pow2((1.0 - skyLightMap)));
			float skyLightMapB = skyLightMap > 0.98 ? (1.0 - skyLightMap) * 50.0 : 1.0;
			
			float causticfactor = 1.0 - lightmap.x * 0.8;

			vec3 causticpos = worldPos.xyz + cameraPosition.xyz;
			float caustic = getCausticWaves(causticpos);
			vec3 causticcol = underwaterColor.rgb / UNDERWATER_I;
			
			#if defined PROJECTED_CAUSTICS && !defined GBUFFERS_WATER
				if (isEyeInWater == 0) {
					causticfactor *= 1.0 - skyLightMapA;
					causticfactor *= 10.0;

					causticcol = sqrt(normalize(waterColor.rgb + vec3(0.01)) * 0.32 * sqrt(UNDERWATER_I));
					#ifndef WATER_ABSORPTION
						albedoCaustic = albedo.rgb * causticcol * 3.0;
						causticcol *= 0.53;
					#else
						albedoCaustic = albedo.rgb * water * 1.74;
						causticcol = sqrt(causticcol) * 0.2;
					#endif
				} else {
			#endif
					causticfactor *= shadow.g * sqrt2(NdotL) * (1.0 - rainStrengthS);
					causticfactor *= 0.25 - 0.15 * skyLightMapA;
					causticfactor *= skyLightMapB;

					albedoCaustic = (albedo.rgb + albedo.rgb * underwaterColor.rgb * 16.0) * 0.225;
					#ifdef WATER_ABSORPTION
						albedoCaustic *= 1.5;
					#endif
					albedoCaustic += albedo.rgb * underwaterColor.rgb * caustic * sqrt1(lightmap.x) * 4.0 * skyLightMapB;
					causticcol = sqrt(causticcol) * 30.0;
			#if defined PROJECTED_CAUSTICS && !defined GBUFFERS_WATER
				}
			#endif

			vec3 lightcaustic = caustic * causticfactor * causticcol * UNDERWATER_I;
			albedoCaustic *= 1.0 + lightcaustic;

			#if defined PROJECTED_CAUSTICS && !defined GBUFFERS_WATER
				if (isEyeInWater == 0) albedo = mix(albedo, albedoCaustic, max(water - rainStrengthS, 0.0));
				else albedo = albedoCaustic;
			#else
				albedo = albedoCaustic;
			#endif
		}
	#endif

	#if defined GBUFFERS_HAND && defined HAND_BLOOM_REDUCTION
		float albedoStrength = (albedo.r + albedo.g + albedo.b) / 10.0;
		if (albedoStrength > 1.0) albedo.rgb = albedo.rgb * max(2.0 - albedoStrength, 0.34);
	#endif

	#if MC_VERSION >= 11900
		albedo *= 1.0 - clamp(darknessLightFactor * (2.0 - emissive * 10000.0), 0.0, 1.0);
	#endif
}