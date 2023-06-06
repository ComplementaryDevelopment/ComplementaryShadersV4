/*
Complementary Shaders by EminGT, based on BSL Shaders by Capt Tatsu
*/

//Common//
#include "/lib/common.glsl"

//Varyings//
varying float mat;
varying float mipmapDisabling, quarterNdotUfactor;
varying float specB;

#ifdef COMPBR
	varying float specR, specG, extraSpecular;
#endif

varying vec2 texCoord, lmCoord;

varying vec3 normal;
varying vec3 sunVec, upVec;

varying vec4 color;

#ifdef OLD_LIGHTING_FIX
	varying vec3 eastVec, northVec;
#endif

#ifdef ADV_MAT
	#if defined PARALLAX || defined SELF_SHADOW
		varying float dist;
		varying vec3 viewVector;
	#endif

	varying vec4 vTexCoordAM;
	varying vec2 vTexCoord;
	#if defined GENERATED_NORMALS || defined NOISY_TEXTURES || defined SNOW_MODE
		varying vec2 vTexCoordL;
	#endif

	#if defined NORMAL_MAPPING || defined REFLECTION_RAIN
		varying vec3 binormal, tangent;
	#endif
#endif

#ifdef SNOW_MODE
	varying float noSnow;
#endif

#ifdef COLORED_LIGHT
	varying float lightVarying;
#endif

#ifdef NOISY_TEXTURES
	varying float noiseVarying;
#endif

#if defined WORLD_CURVATURE && defined COMPBR
	varying vec3 oldPosition;
#endif

//////////Fragment Shader//////////Fragment Shader//////////Fragment Shader//////////
#ifdef FSH

//Uniforms//
uniform int frameCounter;
uniform int isEyeInWater;
uniform int moonPhase;
#define UNIFORM_moonPhase

#if defined DYNAMIC_SHADER_LIGHT || SHOW_LIGHT_LEVELS == 1 || SHOW_LIGHT_LEVELS == 3
	uniform int heldItemId, heldItemId2;

	uniform int heldBlockLightValue;
	uniform int heldBlockLightValue2;
#endif

uniform float frameTimeCounter;
uniform float nightVision;
uniform float rainStrengthS;
uniform float screenBrightness; 
uniform float viewWidth, viewHeight;

uniform ivec2 eyeBrightnessSmooth;
uniform ivec2 atlasSize;

uniform vec3 fogColor;
uniform vec3 cameraPosition;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform sampler2D texture;

#if ((defined WATER_CAUSTICS || defined SNOW_MODE || defined CLOUD_SHADOW || defined REFLECTION_RAIN) && defined OVERWORLD) || defined RANDOM_BLOCKLIGHT || defined NOISY_TEXTURES || defined GENERATED_NORMALS
	uniform sampler2D noisetex;
#endif

#ifdef ADV_MAT
	#ifndef COMPBR
		uniform sampler2D specular;
		uniform sampler2D normals;
	#endif

	#ifdef REFLECTION_RAIN
		uniform float wetness;
	#endif

	#if defined PARALLAX || defined SELF_SHADOW
		uniform int blockEntityId;
	#endif

	#if defined NORMAL_MAPPING && defined GENERATED_NORMALS
		uniform mat4 gbufferProjection;
	#endif
#endif

#ifdef REFLECTION_RAIN
	uniform float isDry, isRainy, isSnowy;
#endif

#ifdef COLORED_LIGHT
	uniform ivec2 eyeBrightness;

	uniform sampler2D colortex9;
#endif

#if MC_VERSION >= 11900
	uniform float darknessLightFactor;
#endif

//Common Variables//
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility = clamp(dot( sunVec,upVec) + 0.0625, 0.0, 0.125) * 8.0;
float vsBrightness = clamp(screenBrightness, 0.0, 1.0);

#if WORLD_TIME_ANIMATION >= 2
	float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
	float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

#if defined ADV_MAT && RP_SUPPORT > 2 || defined COMPBR
	vec2 dcdx = dFdx(texCoord.xy);
	vec2 dcdy = dFdy(texCoord.xy);
#endif

#ifdef OVERWORLD
	vec3 lightVec = sunVec * ((timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0);
#else
	vec3 lightVec = sunVec;
#endif
 
//Common Functions//
float GetLuminance(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}

//Includes//
#include "/lib/color/blocklightColor.glsl"
#include "/lib/color/dimensionColor.glsl"
#include "/lib/util/spaceConversion.glsl"
#include "/lib/color/waterColor.glsl"
#include "/lib/lighting/forwardLighting.glsl"

#if AA == 2 || AA == 3
	#include "/lib/util/jitter.glsl"
#endif
#if AA == 4
	#include "/lib/util/jitter2.glsl"
#endif

#ifdef ADV_MAT
	#include "/lib/util/encode.glsl"
	#include "/lib/lighting/ggx.glsl"

	#ifndef COMPBR
		#include "/lib/surface/materialGbuffers.glsl"
	#endif

	#if defined PARALLAX || defined SELF_SHADOW
		#include "/lib/util/dither.glsl"
		#include "/lib/surface/parallax.glsl"
	#endif

	#ifdef DIRECTIONAL_LIGHTMAP
		#include "/lib/surface/directionalLightmap.glsl"
	#endif

	#if defined REFLECTION_RAIN && defined OVERWORLD
		#include "/lib/surface/rainPuddles.glsl"
	#endif

	#ifdef GENERATED_NORMALS
		#include "/lib/surface/autoGenNormals.glsl"
	#endif

	#ifdef NOISY_TEXTURES
		#include "/lib/surface/noiseCoatedTextures.glsl"
	#endif
#endif

//Program//
void main() {
	vec4 albedo = vec4(0.0);
	if (mipmapDisabling < 0.25) {
		#if defined END && defined COMPATIBILITY_MODE && !defined SEVEN
			albedo.rgb = texture2D(texture, texCoord).rgb;
			albedo.a = texture2DLod(texture, texCoord, 0).a; // For BetterEnd compatibility
		#else
			albedo = texture2D(texture, texCoord);
		#endif
	} else {
		albedo = texture2DLod(texture, texCoord, 0);
	}
	vec3 albedoP = albedo.rgb;
	if (mat < 10000.0) albedo.rgb *= color.rgb;
	albedo.rgb = clamp(albedo.rgb, vec3(0.0), vec3(1.0));
	
	float material = floor(mat); // Ah yes this is a floor mat
	vec3 newNormal = normal;
	vec3 lightAlbedo = vec3(0.0);
	#ifdef GREEN_SCREEN
		float greenScreen = 0.0;
	#endif
	#ifdef BLUE_SCREEN
		float blueScreen = 0.0;
	#endif

	#ifdef ADV_MAT
		float smoothness = 0.0, metalData = 0.0, metalness = 0.0, f0 = 0.0, skymapMod = 0.0;
		vec3 rawAlbedo = vec3(0.0);
		vec4 normalMap = vec4(0.0, 0.0, 1.0, 1.0);

		#ifndef COMPBR
			vec2 newCoord = vTexCoord.xy * vTexCoordAM.zw + vTexCoordAM.xy;
		#endif
		
		#if defined PARALLAX || defined SELF_SHADOW
			float parallaxFade = clamp((dist - PARALLAX_DISTANCE) / 32.0, 0.0, 1.0);
			vec3 parallaxTraceCoordDepth = vec3(newCoord, 1.0);
			vec2 parallaxLocalCoord = vTexCoord.st;
			float parallaxTexDepth = 1.0;
		#endif

		#ifdef PARALLAX
			float skipParallax = float(blockEntityId == 63 || material == 4.0); // Fixes signs and lava
			if (skipParallax < 0.5) {
				parallaxLocalCoord = GetParallaxCoord(parallaxFade, newCoord, parallaxTexDepth, parallaxTraceCoordDepth);
				if (mipmapDisabling < 0.25) albedo = textureGrad(texture, newCoord, dcdx, dcdy) * vec4(color.rgb, 1.0);
				else 					    albedo = texture2DLod(texture, newCoord, 0) * vec4(color.rgb, 1.0);
			}
		#endif
	#endif
	
	#ifndef COMPATIBILITY_MODE
		float albedocheck = albedo.a;
	#else
		float albedocheck = albedo.a; // For BetterEndForge compatibility
	#endif

	if (albedocheck > 0.00001) {
		float foliage = float(material == 1.0);
		float leaves  = float(material == 2.0);

		//Emission
		vec2 lightmap = clamp(lmCoord, vec2(0.0), vec2(1.0));
		float emissive = specB * 4.0;
		
		//Subsurface Scattering
		#if SHADOW_SUBSURFACE == 0
			float subsurface = 0.0;
		#else
			float subsurface = foliage * SCATTERING_FOLIAGE + leaves * SCATTERING_LEAVES;
		#endif
		#ifndef SHADOWS
			if (leaves > 0.5) {
				subsurface *= 0.27;
				albedo.rgb *= 1.15;
			} else subsurface = pow2(subsurface * subsurface);
		#endif

		#ifdef COMPBR
			float lAlbedoP = length(albedoP);
			float extraSpecularM = extraSpecular;
		
			if (mat > 10000.0) { // More control over lAlbedoP at the cost of color.rgb
				if (mat < 19000.0) {
					if (mat < 16000) { // 15000 - Difference Based lAlbedoP
						vec3 averageAlbedo = texture2DLod(texture, texCoord, 100.0).rgb;
						lAlbedoP = sqrt2(length(albedoP.rgb - averageAlbedo) + color.r) * color.g * 20.0;
						#ifdef GREEN_SCREEN
							if (albedo.g * 1.4 > albedo.r + albedo.b && albedo.g > 0.6 && albedo.r * 2.0 > albedo.b)
								greenScreen = 1.0;
						#endif
						#ifdef BLUE_SCREEN
							if (albedo.b * 1.4 > albedo.r + albedo.g && albedo.b > 0.2 && abs(albedo.g - albedo.r) < 0.1)
								blueScreen = 1.0;
						#endif
					} else { // 17000 - Limited lAlbedoP
						lAlbedoP = min(lAlbedoP, color.r) * color.g;
						if (color.b < 2.0) albedo.b *= color.b;
						else albedo.g *= color.b - 2.0;
					}
				} else { 
					if (mat < 25000.0) { // 20000 - Channel Controlled lAlbedoP
						lAlbedoP = length(albedoP * max(color.rgb, vec3(0.0)));
						if (color.g < -0.0001) lAlbedoP = max(lAlbedoP + color.g * albedo.g * 0.1, 0.0);
					} else { // 30000 - Inverted lAlbedoP
						lAlbedoP = max(1.73 - lAlbedoP, 0.0) * color.r + color.g;
					}
				}
				
			}

			//Integrated Emission
			if (specB > 1.02) {
				emissive = pow(lAlbedoP, specB) * fract(specB) * 20.0;
			}

			//Integrated Smoothness
			smoothness = specR;
			if (specR > 1.02) {
				float lAlbedoPsp = lAlbedoP;
				float spec = specR;
				if (spec > 1000.0) lAlbedoPsp = 2.0 - lAlbedoP, spec -= 1000.0;
				smoothness = pow(lAlbedoPsp, spec * 0.1) * fract(specR) * 5.0;
				smoothness = min(smoothness, 1.0);
			}

			//Integrated Metalness+
			metalness = specG;
			if (specG > 10.0) {
				metalness = 3.0 - lAlbedoP * specG * 0.01;
				metalness = min(metalness, 1.0);
			}
		#endif

		//Main
		vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z);
		#if AA > 1
			vec3 viewPos = ScreenToView(vec3(TAAJitter(screenPos.xy, -0.5), screenPos.z));
		#else
			vec3 viewPos = ScreenToView(screenPos);
		#endif
		vec3 worldPos = ViewToWorld(viewPos);
		float lViewPos = length(viewPos.xyz);

		float materialAO = 1.0;
		float cauldron = 0.0;
		float snowFactor = 0.0;

		#ifdef ADV_MAT
			#ifdef REFLECTION_RAIN
				float noRain = 0.0;

				#ifdef RAIN_REF_BIOME_CHECK
					if (material == 3.0) noRain = 1.0;
				#endif
    			#ifndef SHADOWS
					if (material == 5.0) noRain = 1.0;
				#endif
			#endif

			#ifndef COMPBR
				GetMaterials(smoothness, metalness, f0, metalData, emissive, materialAO, normalMap, newCoord, dcdx, dcdy);
			#else
				#include "/lib/ifchecks/terrainFragment.glsl"

				#ifdef METALLIC_WORLD
					metalness = 1.0;
					smoothness = sqrt1(smoothness);
				#endif

				f0 = 0.78 * metalness + 0.02;
				metalData = metalness;

				if (material == 201.0) { // Diamond Block, Emerald Block
					f0 = smoothness;
					smoothness = 0.9 - f0 * 0.1;
					if (albedo.g > albedo.b * 1.1) { // Emerald Block
						f0 *= f0 * 1.2;
						f0 *= f0;
						f0 = clamp(f0 * f0, 0.0, 1.0);
					}
				}

				#if defined NOISY_TEXTURES || defined GENERATED_NORMALS
					#include "/lib/other/mipLevel.glsl"
				#endif
			#endif
			
			#ifdef NORMAL_MAPPING
				mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
									  tangent.y, binormal.y, normal.y,
									  tangent.z, binormal.z, normal.z);

				#ifdef GENERATED_NORMALS
					if (cauldron < 0.5)
						AutoGenerateNormals(normalMap, albedoP, delta);
	
					if (normalMap != vec4(0.0, 0.0, 1.0, 1.0))
				#endif
				{
					#ifdef PARALLAX_SLOPE_NORMALS
						float slopeThreshold = max(1.0 / PARALLAX_QUALITY, 1.0/255.0);
						if (parallaxTexDepth - parallaxTraceCoordDepth.z > slopeThreshold) {
							normalMap.xyz = GetParallaxSlopeNormal(parallaxLocalCoord, parallaxTraceCoordDepth.z, viewVector);
						}
					#endif

					if (normalMap.x > -0.999 && normalMap.y > -0.999)
						newNormal = clamp(normalize(normalMap.xyz * tbnMatrix), vec3(-1.0), vec3(1.0));
				}
			#endif
		#endif

    	albedo.rgb = pow(albedo.rgb, vec3(2.2));

		#ifdef SNOW_MODE
			#ifdef OVERWORLD
				if (noSnow + cauldron < 0.5) {
					vec3 snowColor = vec3(0.5, 0.5, 0.65);
					vec2 snowCoord = vTexCoord.xy / 8.0;
					float snowNoise = texture2D(noisetex, snowCoord).r;
					snowColor *= 0.85 + 0.5 * snowNoise;
					float grassFactor = ((1.0 - abs(albedo.g - 0.3) * 4.0) - albedo.r * 2.0) * float(color.r < 0.999) * 2.0;
					snowFactor = clamp(dot(newNormal, upVec), 0.0, 1.0);
					//snowFactor *= snowFactor;
					if (grassFactor > 0.0) snowFactor = max(snowFactor * 0.75, grassFactor);
					snowFactor *= pow(lightmap.y, 16.0) * (1.0 - pow(lightmap.x + 0.1, 8.0) * 1.5);
					snowFactor = clamp(snowFactor, 0.0, 0.85);
					albedo.rgb = mix(albedo.rgb, snowColor, snowFactor);
					#ifdef ADV_MAT
						float snowFactor2 = snowFactor * (0.75 + 0.5 * snowNoise);
						smoothness = mix(smoothness, 0.45, snowFactor2);
						metalness = mix(metalness, 0.0, snowFactor2);
						//emissive = mix(emissive, 0.0, min(snowFactor2 * 5.0, 1.0));
					#endif
				}
			#endif
		#endif

		#ifdef NOISY_TEXTURES
			if (cauldron < 0.5)
				NoiseCoatTextures(albedo, smoothness, emissive, metalness, worldPos, miplevel, noiseVarying, snowFactor);
		#endif

		#ifdef WHITE_WORLD
			albedo.rgb = vec3(0.5);
		#endif

		float NdotL = clamp(dot(newNormal, lightVec) * 1.01 - 0.01, 0.0, 1.0);

		float fullNdotU = dot(newNormal, upVec);
		float quarterNdotUp = clamp(0.25 * fullNdotU + 0.75, 0.5, 1.0);
		float quarterNdotU = quarterNdotUp * quarterNdotUp;
		if (quarterNdotUfactor < 0.5) quarterNdotU = 1.0;

		float smoothLighting = color.a;
		#ifdef OLD_LIGHTING_FIX 
			// Probably not worth the %4 fps loss
			// Don't forget to apply the same code to gbuffers_water if I end up making this an option
			if (smoothLighting < 0.9999999) {
				float absNdotE = abs(dot(newNormal, eastVec));
				float absNdotN = abs(dot(newNormal, northVec));
				float NdotD = abs(fullNdotU) * float(fullNdotU < 0.0);

				smoothLighting += 0.4 * absNdotE;
				smoothLighting += 0.2 * absNdotN;
				smoothLighting += 0.502 * NdotD;

				smoothLighting = clamp(smoothLighting, 0.0, 1.0);
				//albedo.rgb = mix(vec3(1, 0, 1), albedo.rgb, pow(smoothLighting, 10000.0));
			}
		#endif

		float parallaxShadow = 1.0;
		#ifdef ADV_MAT
			rawAlbedo = albedo.rgb * 0.999 + 0.001;
			#ifdef REFLECTION_SPECULAR
				#ifdef COMPBR
					if (metalness > 0.801) {
						albedo.rgb *= (1.0 - metalness*0.65);
					}
				#else
					albedo.rgb *= (1.0 - metalness*0.65);
				#endif
			#endif

			#if defined SELF_SHADOW && defined NORMAL_MAPPING
				float doParallax = 0.0;
				#ifdef OVERWORLD
					doParallax = float(lightmap.y > 0.0 && NdotL > 0.0);
				#endif
				#ifdef END
					doParallax = float(NdotL > 0.0);
				#endif
				if (doParallax > 0.5) {
					parallaxShadow = GetParallaxShadow(parallaxFade, parallaxLocalCoord, lightVec, tbnMatrix, parallaxTraceCoordDepth.z, normalMap.a);
				}
			#endif

			#ifdef DIRECTIONAL_LIGHTMAP
				mat3 lightmapTBN = GetLightmapTBN(viewPos);
				lightmap.x = DirectionalLightmap(lightmap.x, lmCoord.x, newNormal, lightmapTBN);
				lightmap.y = DirectionalLightmap(lightmap.y, lmCoord.y, newNormal, lightmapTBN);
			#endif
		#endif
		
		vec3 shadow = vec3(0.0);
		GetLighting(albedo.rgb, shadow, lightAlbedo, viewPos, lViewPos, worldPos, lightmap, smoothLighting, NdotL, quarterNdotU,
					parallaxShadow, emissive, subsurface, leaves, materialAO);

		#ifdef ADV_MAT
			#if defined OVERWORLD || defined END
				#ifdef OVERWORLD
					#ifdef REFLECTION_RAIN
						if (quarterNdotUp > 0.85 && noRain < 0.1) {
							vec2 rainPos = worldPos.xz + cameraPosition.xz;

							skymapMod = max(lmCoord.y * 16.0 - 15.5, 0.0);

							float puddleSize = 0.0025;
							skymapMod *= GetPuddles(rainPos * puddleSize);

							float skymapModx2 = skymapMod * 2.0;
							smoothness = mix(smoothness, 0.8 , skymapModx2);
							metalness  = mix(metalness , 0.0 , skymapModx2);
							metalData  = mix(metalData , 0.0 , skymapModx2);
							f0         = mix(f0        , 0.02, skymapModx2);

							mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
													tangent.y, binormal.y, normal.y,
													tangent.z, binormal.z, normal.z);
							rainPos *= 0.02;
							vec2 wind = vec2(frametime) * 0.01;
							vec3 pnormalMap = vec3(0.0, 0.0, 1.0);
							float pnormalMultiplier = 0.05;

							vec2 pnormalCoord1 = rainPos + vec2(wind.x, wind.y);
							vec3 pnormalNoise1 = texture2D(noisetex, pnormalCoord1).rgb;
							vec2 pnormalCoord2 = rainPos + vec2(wind.x * -1.5, wind.y * -1.0);
							vec3 pnormalNoise2 = texture2D(noisetex, pnormalCoord2).rgb;

							pnormalMap += (pnormalNoise1 + pnormalNoise2 - vec3(1.0)) * pnormalMultiplier;
							vec3 puddleNormal = clamp(normalize(pnormalMap * tbnMatrix),vec3(-1.0),vec3(1.0));

							albedo.rgb *= 1.0 - sqrt(length(pnormalMap.xy)) * 0.8 * skymapModx2 * (rainStrengthS);

							vec3 rainNormal = normalize(mix(newNormal, puddleNormal, rainStrengthS));

							newNormal = mix(newNormal, rainNormal, skymapModx2);
						}
					#endif

					vec3 lightME = mix(lightMorning, lightEvening, mefade);
					vec3 lightDayTint = lightDay * lightME * LIGHT_DI;
					vec3 lightDaySpec = mix(lightME, sqrt(lightDayTint), timeBrightness);
					vec3 specularColor = mix(sqrt(lightNight*0.3),
												lightDaySpec,
												sunVisibility);
					#ifdef WATER_CAUSTICS
						if (isEyeInWater == 1) specularColor *= underwaterColor.rgb * 8.0;
					#endif
					specularColor *= specularColor;

					#ifdef SPECULAR_SKY_REF
						float skymapModM = lmCoord.y;
						#if SKY_REF_FIX_1 == 1
							skymapModM = skymapModM * skymapModM;
						#elif SKY_REF_FIX_1 == 2
							skymapModM = max(skymapModM - 0.80, 0.0) * 5.0;
						#else
							skymapModM = max(skymapModM - 0.99, 0.0) * 100.0;
						#endif
						if (!(metalness <= 0.004 && metalness > 0.0)) skymapMod = max(skymapMod, skymapModM * 0.1);
					#endif
				#endif
				#ifdef END
					vec3 specularColor = endCol;
					#ifdef COMPBR
						if (cauldron > 0.0) skymapMod = (min(length(shadow), 0.475) + 0.515) * float(smoothness > 0.9);
						else
					#endif
					skymapMod = min(length(shadow), 0.5);
				#endif
				
				#ifdef SPECULAR_SKY_REF
					vec3 specularHighlight = vec3(0.0);
					specularHighlight = GetSpecularHighlight(smoothness - cauldron, metalness, f0, specularColor, rawAlbedo,
													shadow, newNormal, viewPos);
					#if	defined ADV_MAT && defined NORMAL_MAPPING && defined SELF_SHADOW
						specularHighlight *= parallaxShadow;
					#endif
					#if defined LIGHT_LEAK_FIX && !defined END
						if (isEyeInWater == 0) specularHighlight *= pow(lightmap.y, 2.5);
						else specularHighlight *= 0.15 + 0.85 * pow(lightmap.y, 2.5);
					#endif
					albedo.rgb += specularHighlight;
				#endif
			#endif

			#if defined COMPBR && defined REFLECTION_SPECULAR
				smoothness *= 0.5;
				if (extraSpecularM > 0.5) smoothness += 0.5;
			#endif
		#endif
		
		#if SHOW_LIGHT_LEVELS > 0
			#if SHOW_LIGHT_LEVELS == 1
				if (heldItemId == 13001 || heldItemId2 == 13001)
			#elif SHOW_LIGHT_LEVELS == 3
				if (heldBlockLightValue > 7.4 || heldBlockLightValue2 > 7.4)
			#endif
			if (dot(normal, upVec) > 0.99 && foliage + leaves < 0.1 && material != 162.0) {
				#include "/lib/other/indicateLightLevels.glsl"
			}
		#endif

		#ifdef GBUFFER_CODING
			albedo.rgb = vec3(1.0, 1.0, 170.0) / 255.0;
			albedo.rgb = pow(albedo.rgb, vec3(2.2)) * 0.5;
		#endif

		#if THE_FORBIDDEN_OPTION > 1
			albedo = min(albedo, vec4(1.0));
		#endif

		#ifdef GREEN_SCREEN
			if (greenScreen > 0.5) {
				albedo.rgb = vec3(0.0, 0.08, 0.0);
				#if defined ADV_MAT && defined REFLECTION_SPECULAR
					smoothness = 0.0;
					metalData = 0.0;
					skymapMod = 0.51;
				#endif
			}
		#endif
		#ifdef BLUE_SCREEN
			if (blueScreen > 0.5) {
				albedo.rgb = vec3(0.0, 0.0, 0.18);
				#if defined ADV_MAT && defined REFLECTION_SPECULAR
					smoothness = 0.0;
					metalData = 0.0;
					skymapMod = 0.51;
				#endif
			}
		#endif
	} else discard;

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = albedo;

	#if defined ADV_MAT && defined REFLECTION_SPECULAR
		/* DRAWBUFFERS:0361 */
		gl_FragData[1] = vec4(smoothness, metalData, skymapMod, 1.0);
		gl_FragData[2] = vec4(EncodeNormal(newNormal), 0.0, 1.0);
		gl_FragData[3] = vec4(rawAlbedo, 1.0);

		#ifdef COLORED_LIGHT
			/* DRAWBUFFERS:03618 */
			gl_FragData[4] = vec4(lightAlbedo, 1.0);
		#endif
	#else
		#ifdef COLORED_LIGHT
			/* DRAWBUFFERS:08 */
			gl_FragData[1] = vec4(lightAlbedo, 1.0);
		#endif
	#endif
}

#endif

//////////Vertex Shader//////////Vertex Shader//////////Vertex Shader//////////
#ifdef VSH

//Uniforms//
uniform float frameTimeCounter;
uniform float rainStrengthS;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelView, gbufferModelViewInverse;

#if AA > 1
	uniform int frameCounter;

	uniform float viewWidth, viewHeight;
#endif

//Attributes//
attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

#ifdef ADV_MAT
	attribute vec4 at_tangent;
#endif

//Common Variables//
#if WORLD_TIME_ANIMATION >= 2
	float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
	float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

#ifdef OVERWORLD
	float timeAngleM = timeAngle;
#else
	#if !defined SEVEN && !defined SEVEN_2
		float timeAngleM = 0.25;
	#else
		float timeAngleM = 0.5;
	#endif
#endif

//Includes//
#include "/lib/vertex/waving.glsl"

#if AA == 2 || AA == 3
	#include "/lib/util/jitter.glsl"
#endif
#if AA == 4
	#include "/lib/util/jitter2.glsl"
#endif

#ifdef WORLD_CURVATURE
	#include "/lib/vertex/worldCurvature.glsl"
#endif

//Program//
void main() {
	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	
	#if THE_FORBIDDEN_OPTION > 1
		if (length(position.xz) > 0.0) {
			gl_Position = gl_ProjectionMatrix * gbufferModelView * position;
			return;
		}
	#endif

	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	
	lmCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	lmCoord = clamp((lmCoord - 0.03125) * 1.06667, 0.0, 1.0);

	normal = normalize(gl_NormalMatrix * gl_Normal);

	#ifdef ADV_MAT
		#if defined NORMAL_MAPPING || defined REFLECTION_RAIN
			binormal = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
			tangent  = normalize(gl_NormalMatrix * at_tangent.xyz);
			
			#if defined PARALLAX || defined SELF_SHADOW
				mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
									  tangent.y, binormal.y, normal.y,
									  tangent.z, binormal.z, normal.z);
			
				viewVector = tbnMatrix * (gl_ModelViewMatrix * gl_Vertex).xyz;
				dist = length(gl_ModelViewMatrix * gl_Vertex);
			#endif
		#endif

		vec2 midCoord = (gl_TextureMatrix[0] * mc_midTexCoord).xy;
		vec2 texMinMidCoord = texCoord - midCoord;

		vTexCoordAM.zw  = abs(texMinMidCoord) * 2;
		vTexCoordAM.xy  = min(texCoord, midCoord - texMinMidCoord);
		vTexCoord.xy    = sign(texMinMidCoord) * 0.5 + 0.5;
		#if defined GENERATED_NORMALS || defined NOISY_TEXTURES || defined SNOW_MODE
			vTexCoordL  = texMinMidCoord * 2;
		#endif
	#endif
	
	color = gl_Color;
	if (color.a < 0.1) color.a = 1.0;
	
	upVec = normalize(gbufferModelView[1].xyz);

	#ifdef SNOW_MODE
		noSnow = 0.0;
	#endif
	#ifdef COLORED_LIGHT
		lightVarying = 0.0;
	#endif
	#ifdef NOISY_TEXTURES
		noiseVarying = 1.0;
	#endif
	
	mat = 0.0; mipmapDisabling = 0.0; quarterNdotUfactor = 1.0; specB = 0.0;
	
	#ifdef COMPBR
		specR = 0.0; specG = 0.0; extraSpecular = 0.0;
	#endif

	#include "/lib/ifchecks/terrainVertex.glsl"

	mat += 0.25;
	
	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngleM - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

	#ifdef OLD_LIGHTING_FIX
		eastVec = normalize(gbufferModelView[0].xyz);
		northVec = normalize(gbufferModelView[2].xyz);
	#endif

	float istopv = gl_MultiTexCoord0.t < mc_midTexCoord.t ? 1.0 : 0.0;
	vec3 wave = WavingBlocks(position.xyz, istopv, lmCoord.y);
	position.xyz += wave;

	#ifdef WORLD_CURVATURE
		#ifdef COMPBR
			oldPosition = position.xyz;
		#endif
		position.y -= WorldCurvature(position.xz);
	#endif
	
	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;

	#if AA > 1
		gl_Position.xy = TAAJitter(gl_Position.xy, gl_Position.w);
	#endif
}

#endif