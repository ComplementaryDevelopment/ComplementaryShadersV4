/*
Complementary Shaders by EminGT, based on BSL Shaders by Capt Tatsu
*/

//Common//
#include "/lib/common.glsl"

//Varyings//
varying vec2 texCoord;

varying vec3 sunVec, upVec;

#ifdef COLORED_LIGHT
	varying vec3 lightAlbedo;
	varying	vec3 lightBuffer;
#endif

//////////Fragment Shader//////////Fragment Shader//////////Fragment Shader//////////
#ifdef FSH

//Uniforms//
uniform int frameCounter;
uniform int isEyeInWater;
uniform int worldDay;

uniform float isEyeInCave;
uniform float blindFactor, nightVision;
uniform float far, near;
uniform float frameTimeCounter;
uniform float rainStrengthS;
uniform float screenBrightness; 
uniform float viewWidth, viewHeight, aspectRatio;
uniform float eyeAltitude;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 skyColor;
uniform vec3 fogColor;

uniform mat4 gbufferProjection, gbufferPreviousProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelView, gbufferPreviousModelView, gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform sampler2D colortex0;
uniform sampler2D depthtex0;

#ifdef AO
	uniform sampler2D colortex4;
#endif

#ifdef AURORA
	uniform int moonPhase;
	#define UNIFORM_moonPhase
#endif

#if defined ADV_MAT || defined GLOWING_ENTITY_FIX || defined AO
	uniform sampler2D colortex3;
#endif

#if (defined ADV_MAT && defined REFLECTION_SPECULAR) || defined SEVEN || (defined END && defined ENDER_NEBULA) || (defined NETHER && defined NETHER_SMOKE)
	uniform vec3 cameraPosition;

	uniform sampler2D colortex6;
	uniform sampler2D colortex1;
	uniform sampler2D noisetex;
#endif

#ifdef AURORA
	uniform float isDry, isRainy, isSnowy;
#endif

//Optifine Constants//
#if defined ADV_MAT && defined REFLECTION_SPECULAR
	const bool colortex0MipmapEnabled = true;
#endif
#ifdef COLORED_LIGHT
	const bool colortex8MipmapEnabled = true;
#endif

//Common Variables//
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility = clamp(dot( sunVec,upVec) + 0.0625, 0.0, 0.125) * 8.0;
float vsBrightness = clamp(screenBrightness, 0.0, 1.0);

vec3 lightVec = sunVec * (1.0 - 2.0 * float(timeAngle > 0.5325 && timeAngle < 0.9675));

vec2 aoOffsets[4] = vec2[4](
	vec2( 1.0,  0.0),
	vec2( 0.0,  1.0),
	vec2(-1.0,  0.0),
	vec2( 0.0, -1.0)
);

#if WORLD_TIME_ANIMATION == 2
	int modifiedWorldDay = int(mod(worldDay, 100.0) + 5.0);
	float frametime = (worldTime + modifiedWorldDay * 24000) * 0.05 * ANIMATION_SPEED;
	float cloudtime = frametime;
#endif
#if WORLD_TIME_ANIMATION == 1
	int modifiedWorldDay = int(mod(worldDay, 100.0) + 5.0);
	float frametime = frameTimeCounter * ANIMATION_SPEED;
	float cloudtime = (worldTime + modifiedWorldDay * 24000) * 0.05 * ANIMATION_SPEED;
#endif
#if WORLD_TIME_ANIMATION == 0
	float frametime = frameTimeCounter * ANIMATION_SPEED;
	float cloudtime = frametime;
#endif

#ifdef END
vec3 lightNight = vec3(0.0);
#endif

//Common Functions//
float GetLuminance(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}

float GetLinearDepth(float depth) {
   return (2.0 * near) / (far + near - depth * (far - near));
}

#ifdef AO
    vec2 OffsetDist(float x, int s) {
        float n = fract(x * 1.414) * 3.1415;
        return pow2(vec2(cos(n), sin(n)) * x / s);
    }

    float DoAmbientOcclusion(float linearZ0, float dither) {
        float ao = 0.0;

		#if AA > 1
			int samples = 12 * AO_QUALITY;

			float ditherAnimate = 1.61803398875 * mod(float(frameCounter), 3600.0);
			dither = fract(dither + ditherAnimate);
		#else
			int samples = 24 * AO_QUALITY;
		#endif
			
		float farMinusNear = far - near;
        
        float sampleDepth = 0.0, angle = 0.0, dist = 0.0;
        float fovScale = gbufferProjection[1][1] / 1.37;
        float distScale = max(farMinusNear * linearZ0 + near, 3.0);
        vec2 scale = vec2(0.4 / aspectRatio, 0.5) * fovScale / distScale;

        for (int i = 1; i <= samples; i++) {
            vec2 offset = OffsetDist(i + dither, samples) * scale;
            if (i % 2 == 0) offset.y = -offset.y;

            vec2 coord1 = texCoord + offset;
            vec2 coord2 = texCoord - offset;

            sampleDepth = GetLinearDepth(texture2D(depthtex0, coord1).r);
            float aosample = farMinusNear * (linearZ0 - sampleDepth) * 2.0;
            angle = clamp(0.5 - aosample, 0.0, 1.0);
            dist = clamp(0.5 * aosample - 1.0, 0.0, 1.0);

            sampleDepth = GetLinearDepth(texture2D(depthtex0, coord2).r);
            aosample = farMinusNear * (linearZ0 - sampleDepth) * 2.0;
            angle += clamp(0.5 - aosample, 0.0, 1.0);
            dist += clamp(0.5 * aosample - 1.0, 0.0, 1.0);
            
            ao += clamp(angle + dist, 0.0, 1.0);
        }
        ao /= samples;
        
        return pow(ao, AO_STRENGTH_NEW);
    }
#endif

#if SELECTION_MODE == 2 && defined ADV_MAT
vec3 GetVersatileOutline(vec3 color) {
	vec3 colorSqrt = sqrt(color.rgb);
	float perceived = 0.1126 * colorSqrt.r + 0.4152 * colorSqrt.g + 0.2722 * colorSqrt.b;

	color.rgb = color.rgb + max(normalize(color.rgb) * max(perceived * perceived, 0.001), vec3(0.0));
	color.rgb *= 20.0;

	perceived = max(1.0 - perceived * 1.3, 0.0);
	perceived *= perceived;
	perceived *= perceived;
	perceived = min(perceived, 1.0);
	float perSteep = 16.0;
	if (perceived > 0.5) perceived = pow((perceived - 0.5) * 2.0, 1.0 / perSteep) * 0.5 + 0.5;
	else perceived = pow(perceived * 2.0, perSteep) * 0.5;
	color.rgb *= max(perceived * 0.5, 0.007);
	return color.rgb;
}
#endif

//Includes//
#include "/lib/color/dimensionColor.glsl"
#include "/lib/color/skyColor.glsl"
#include "/lib/color/blocklightColor.glsl"
#include "/lib/color/waterColor.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/util/spaceConversion.glsl"

#ifdef OVERWORLD
	#include "/lib/atmospherics/sky.glsl"
#endif

#if defined SEVEN || (defined ADV_MAT && defined REFLECTION_SPECULAR && defined OVERWORLD) || (defined END && defined ENDER_NEBULA) || (defined NETHER && defined NETHER_SMOKE)
	#ifdef AURORA
		#include "/lib/color/auroraColor.glsl"
	#endif
	#include "/lib/atmospherics/skyboxEffects.glsl"
#endif

#include "/lib/atmospherics/fog.glsl"

#ifdef BLACK_OUTLINE
	#include "/lib/outline/blackOutline.glsl"
#endif

#ifdef PROMO_OUTLINE
	#include "/lib/outline/promoOutline.glsl"
#endif

#if defined ADV_MAT && defined REFLECTION_SPECULAR
	#include "/lib/util/encode.glsl"
	#include "/lib/reflections/raytrace.glsl"
	#include "/lib/reflections/complexFresnel.glsl"
	#include "/lib/surface/materialDeferred.glsl"
	#include "/lib/reflections/roughReflections.glsl"
#endif

//Program//
void main() {
    vec4 color = texture2D(colortex0, texCoord);
	float z    = texture2D(depthtex0, texCoord).r;

	float dither = Bayer64(gl_FragCoord.xy);
	
	vec4 screenPos = vec4(texCoord, z, 1.0);
	vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
	viewPos /= viewPos.w;

	#if defined NETHER && defined NETHER_SMOKE
		vec3 netherSmoke = DrawNetherSmoke(viewPos.xyz, dither, pow((netherCol * 2.5) / NETHER_I, vec3(2.2)) * 4);
	#endif
	#if defined END && defined ENDER_NEBULA
		vec3 nebulaStars = vec3(0.0);
		vec3 enderNebula = DrawEnderNebula(viewPos.xyz, dither, endCol, nebulaStars);
		nebulaStars = pow(nebulaStars, vec3(1.0 / 2.2));
		nebulaStars *= pow(nebulaStars, vec3(2.2));
		enderNebula = pow(enderNebula, vec3(1.0 / 2.2));
		enderNebula *= pow(enderNebula, vec3(2.2));
	#endif

	if (z < 1.0) {
		#if defined ADV_MAT || defined GLOWING_ENTITY_FIX || defined AO
			float skymapMod = texture2D(colortex3, texCoord).b;
			// skymapMod = 1.0            = Glowing Status Effect
			// skymapMod = 0.995          = Versatile Selection Outline
			// skymapMod = 0.515 ... 0.99 = Cauldron
			// skymapMod = 0.51           = No SSAO
			// skymapMod = 0.0   ... 0.5  = Rain Puddles
			// skymapMod = 0.0   ... 0.1  = Specular Sky Reflections
		#endif

		vec3 nViewPos = normalize(viewPos.xyz);
		float NdotU = dot(nViewPos, upVec);
		float lViewPos = length(viewPos.xyz);
		vec3 worldPos = ViewToWorld(viewPos.xyz);
	
		#ifdef AO
			float ao = clamp(DoAmbientOcclusion(GetLinearDepth(z), dither), 0.0, 1.0);
			float ambientOcclusion = ao;
		#endif

		#if SELECTION_MODE == 2 && defined ADV_MAT
			if (skymapMod > 0.9925 && 0.9975 > skymapMod) {
				color.rgb = GetVersatileOutline(color.rgb);
			}
		#endif

		#if defined ADV_MAT && defined REFLECTION_SPECULAR
			float smoothness = 0.0, metalness = 0.0, f0 = 0.0;
			vec3 normal = vec3(0.0), rawAlbedo = vec3(0.0);

			GetMaterials(smoothness, metalness, f0, normal, rawAlbedo, texCoord);

			float smoothnessP = smoothness;
			smoothness *= smoothness;
			
			float fresnel = pow(clamp(1.0 + dot(normal, nViewPos), 0.0, 1.0), 5.0);
			vec3 fresnel3 = vec3(0.0);

			rawAlbedo *= 5.0;
			float fresnelFactor = 0.25;

			#ifdef COMPBR
				if (f0 > 1.1) {
					fresnel = fresnel * 0.8 + 0.2;
					fresnelFactor *= 1.5;
				}
				fresnel3 = mix(mix(vec3(0.02), rawAlbedo, metalness), vec3(1.0), fresnel);
				if (metalness <= 0.004 && metalness > 0.0 && skymapMod == 0.0) fresnel3 = vec3(0.0);
				fresnel3 *= fresnelFactor * smoothness;
			#else
				#if RP_SUPPORT == 4
					fresnel3 = mix(mix(vec3(0.02), rawAlbedo, metalness), vec3(1.0), fresnel);
					fresnel3 *= fresnelFactor * smoothness;
				#endif
				#if RP_SUPPORT == 3
					fresnel3 = mix(mix(vec3(max(f0, 0.02)), rawAlbedo, metalness), vec3(1.0), fresnel);
					if (f0 >= 0.9 && f0 < 1.0) {
						fresnel3 = ComplexFresnel(fresnel, f0) * 1.5;
						color.rgb *= 1.5;
					}
					fresnel3 *= fresnelFactor * smoothness;
				#endif
			#endif

			float lFresnel3 = length(fresnel3);
			if (lFresnel3 < 0.0050) fresnel3 *= (lFresnel3 - 0.0025) / 0.0025;

			if (lFresnel3 > 0.0025) {
				vec4 reflection = vec4(0.0);
				vec3 skyReflection = vec3(0.0);

				#ifdef REFLECTION_ROUGH
					float roughness = 1.0 - smoothnessP;
					#ifdef COMPBR
						roughness *= 1.0 - 0.35 * float(metalness == 1.0);
					#endif
					roughness *= roughness;

					vec3 roughPos = worldPos + cameraPosition;
					roughPos *= 1000.0;
					vec3 roughNoise = texture2D(noisetex, roughPos.xz + roughPos.y).rgb;
					roughNoise = 0.3 * (roughNoise - vec3(0.5));
					
					roughNoise *= roughness;

					normal += roughNoise;
					reflection = RoughReflection(viewPos.xyz, normal, dither, smoothness);

					#ifdef DOUBLE_QUALITY_ROUGH_REF
						vec3 altRoughNormal = normal - roughNoise*2;
						reflection += RoughReflection(viewPos.xyz, altRoughNormal, dither, smoothness);
						reflection /= 2.0;
					#endif
				#else
					reflection = RoughReflection(viewPos.xyz, normal, dither, smoothness);
				#endif

				float cauldron = float(skymapMod > 0.51 && skymapMod < 0.9905);
				if (cauldron > 0.5) { 													//Cauldron Reflections
					#ifdef OVERWORLD
						fresnel3 = fresnel3 * 3.33333333 + vec3(0.0333333);

						float skymapModM = (skymapMod - 0.515) / 0.475;
						#if SKY_REF_FIX_1 == 1
							skymapModM = skymapModM * skymapModM;
						#elif SKY_REF_FIX_1 == 2
							skymapModM = max(skymapModM - 0.80, 0.0) * 5.0;
						#else
							skymapModM = max(skymapModM - 0.99, 0.0) * 100.0;
						#endif
						skymapModM = skymapModM * 0.5;

						vec3 skyReflectionPos = reflect(nViewPos, normal);
						float refNdotU = dot(skyReflectionPos, upVec);
						skyReflection = GetSkyColor(lightCol, refNdotU, skyReflectionPos, true);
						skyReflectionPos *= 1000000.0;

						#ifdef AURORA
							skyReflection += DrawAurora(skyReflectionPos, dither, 8, refNdotU);
						#endif
						#ifdef CLOUDS
							vec4 cloud = DrawCloud(skyReflectionPos, dither, lightCol, ambientCol, refNdotU, 3);
							float cloudMixRate = smoothness * smoothness * (3.0 - 2.0 * smoothness);
							skyReflection = mix(skyReflection, cloud.rgb, cloud.a * cloudMixRate);
						#endif
						skyReflection = mix(vec3(0.001), skyReflection, skymapModM * 2.0);
					#endif
					#ifdef NETHER
						skyReflection = netherCol * 0.005;
					#endif
					#ifdef END
						float skymapModM = (skymapMod - 0.515) / 0.475;
						skyReflection = endCol * 0.025;
						#ifdef ENDER_NEBULA
							vec3 skyReflectionPos = reflect(nViewPos, normal);
							skyReflectionPos *= 1000000.0;
							vec3 nebulaStars = vec3(0.0);
							vec3 nebulaCRef = DrawEnderNebula(skyReflectionPos, dither, endCol, nebulaStars);
							nebulaCRef += nebulaStars;
							skyReflection = nebulaCRef;
						#endif
						skyReflection *= 5.0 * skymapModM;
					#endif
				}
				if (skymapMod > 0.0 && skymapMod < 0.505) {
					#ifdef OVERWORLD												 //Rain Puddle + Specular Sky Reflections
						float skymapModM = skymapMod * 2.0;

						vec3 skyReflectionPos = reflect(nViewPos, normal);
						float refNdotU = dot(skyReflectionPos, upVec);
						skyReflection = GetSkyColor(lightCol, refNdotU, skyReflectionPos, true);
						skyReflectionPos *= 1000000.0;

						#ifdef CLOUDS
							vec4 cloud = DrawCloud(skyReflectionPos, dither, lightCol, ambientCol, refNdotU, 3);
							float cloudMixRate = smoothness * smoothness * (3.0 - 2.0 * smoothness);
							skyReflection = mix(skyReflection, cloud.rgb, cloud.a * cloudMixRate);
						#endif
						skyReflection = mix(vec3(0.001), skyReflection * 5.0, skymapModM);
					#endif
					#if defined END	&& defined ENDER_NEBULA	  							//End Ground Reflections
						vec3 skyReflectionPos = reflect(nViewPos, normal);
						skyReflectionPos *= 1000000.0;
						vec3 nebulaStars = vec3(0.0);
						vec3 nebulaGRef = DrawEnderNebula(skyReflectionPos, dither, endCol, nebulaStars);
						nebulaGRef += nebulaStars;
						skyReflection = nebulaGRef;
					#endif
				}

				reflection.rgb = max(mix(skyReflection, reflection.rgb, reflection.a), vec3(0.0));
				
				#ifdef AO
					if (skymapMod < 0.505) reflection.rgb *= pow(min(ao + max(0.25 - lViewPos * 0.01, 0.0), 1.0), min(lViewPos * 0.75, 10.0));
				#endif
				
				color.rgb = color.rgb * (1.0 - fresnel3 * (1.0 - metalness)) +
							reflection.rgb * fresnel3;

				#ifdef SHOW_RAY_TRACING
					float timeThing1 = abs(fract(frameTimeCounter * 1.35) - 0.5) * 2.0;
					float timeThing2 = abs(fract(frameTimeCounter * 1.15) - 0.5) * 2.0;
					float timeThing3 = abs(fract(frameTimeCounter * 1.55) - 0.5) * 2.0;
					color.rgb = 3.0 * pow(vec3(timeThing1, timeThing2, timeThing3), vec3(3.2));
				#endif
			}
		#endif
		
		#ifdef GLOWING_ENTITY_FIX
			if (skymapMod > 0.9975) {
				vec2 glowOutlineOffsets[8] = vec2[8](
									vec2(-1.0, 0.0),
									vec2( 0.0, 1.0),
									vec2( 1.0, 0.0),
									vec2( 0.0,-1.0),
									vec2(-1.0,-1.0),
									vec2(-1.0, 1.0),
									vec2( 1.0,-1.0),
									vec2( 1.0, 1.0)
									);

				float outline = 0.0;

				for(int i = 0; i < 64; i++) {
					vec2 offset = vec2(0.0);
					offset = glowOutlineOffsets[i-8*int(i/8)] * 0.00025 * (int(i/8)+1);
					outline += clamp(1.0 - texture2D(colortex3, texCoord + offset).b, 0.0, 1.0);
				}
				
				color.rgb += outline * vec3(0.05);
			}
		#endif
		
		#ifdef AO
			if (skymapMod < 0.505)
			color.rgb *= ambientOcclusion;
		#endif
		
		#ifdef PROMO_OUTLINE
			PromoOutline(color.rgb, depthtex0);
		#endif

		vec3 extra = vec3(0.0);
		#if defined NETHER && defined NETHER_SMOKE
			extra = netherSmoke;
		#endif
		#if defined END && defined ENDER_NEBULA
			extra = enderNebula;
		#endif

		color.rgb = startFog(color.rgb, nViewPos, lViewPos, worldPos, extra, NdotU);
	
	} else { /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/
		float NdotU = 0.0;

		vec2 skyBlurOffset[4] = vec2[4](vec2( 0.0,  1.0),
										vec2( 0.0, -1.0),
										vec2( 1.0,  0.0),
										vec2(-1.0,  0.0));
		vec2 wh = vec2(viewWidth, viewHeight);
		vec3 skyBlurColor = color.rgb;
		for(int i = 0; i < 4; i++) {
			vec2 texCoordM = texCoord + skyBlurOffset[i] / wh;
			float depth = texture2D(depthtex0, texCoordM).r;
			if (depth == 1.0) skyBlurColor += texture2DLod(colortex0, texCoordM, 0).rgb;
			else skyBlurColor += color.rgb;
		}
		color.rgb = skyBlurColor / 5.0;

		#ifdef NETHER
			color.rgb = pow((netherCol * 2.5) / NETHER_I, vec3(2.2)) * 4;
			#ifdef NETHER_SMOKE
				color.rgb += netherSmoke;
			#endif
		#endif

		#ifdef END
			#ifdef ENDER_NEBULA
				color.rgb = enderNebula + nebulaStars;
				color.rgb += endCol * (0.035 + 0.02 * vsBrightness);
			#endif
		#endif

		#ifdef TWENTY
			color.rgb *= 0.1;
		#endif
		
		#ifdef SEVEN
			NdotU = max(dot(normalize(viewPos.xyz), upVec), 0.0);

			vec3 twilightPurple = vec3(0.005, 0.006, 0.018);
			vec3 twilightGreen = vec3(0.015, 0.03, 0.02);

			#ifdef TWENTY
				twilightPurple = twilightGreen * 0.1;
			#endif

			color.rgb = 2 * (twilightPurple * 2 * clamp(pow(NdotU, 0.7), 0.0, 1.0) + twilightGreen * (1-clamp(pow(NdotU, 0.7), 0.0, 1.0)));

			#ifndef TWENTY
				vec3 stars = DrawStars(color.rgb, viewPos.xyz, NdotU);
				color.rgb += stars.rgb;
			#endif
		#endif
		
		#ifdef TWO
			NdotU = 1.0 - max(dot(normalize(viewPos.xyz), upVec), 0.0);
			NdotU *= NdotU;
			#ifndef ABYSS
				vec3 midnightPurple = vec3(0.0003, 0.0004, 0.002) * 1.25;
				vec3 midnightFogColor = fogColor * fogColor * 0.3;
			#else
				vec3 midnightPurple = skyColor * skyColor * 0.00075;
				vec3 midnightFogColor = fogColor * fogColor * 0.09;
			#endif
			color.rgb = mix(midnightPurple, midnightFogColor, NdotU);
		#endif

		if (isEyeInWater == 1) {
			NdotU = max(dot(normalize(viewPos.xyz), upVec), 0.0);
			color.rgb = mix(color.rgb, 0.8 * pow(underwaterColor.rgb * (1.0 - blindFactor), vec3(2.0)), 1.0 - NdotU*NdotU);
		} else if (isEyeInWater == 2) {
			//duplicate 792763950
			#ifndef VANILLA_UNDERLAVA_COLOR
				vec3 lavaFogColor = vec3(0.6, 0.35, 0.15);
			#else
				vec3 lavaFogColor = pow(fogColor, vec3(2.2));
			#endif
			color.rgb = lavaFogColor;
		}
		if (blindFactor > 0.0) color.rgb *= 1.0 - blindFactor;
	}
    
	#ifdef BLACK_OUTLINE
		float wFogMult = 1.0 + eBS;
		BlackOutline(color.rgb, depthtex0, wFogMult);
	#endif

	#ifdef COLORED_LIGHT
		float sumlightAlbedo = max(lightAlbedo.r + lightAlbedo.g + lightAlbedo.b, 0.0001);
		vec3 lightAlbedoM = lightAlbedo / sumlightAlbedo;
		lightAlbedoM *= lightAlbedoM;
		lightAlbedoM *= BLOCKLIGHT_I * vec3(2.0, 1.8, 2.0);

		float lightSpeed = 0.01;
		vec3 lightBufferM = mix(lightBuffer, blocklightCol, lightSpeed * 0.25);
		vec3 finalLight = mix(lightBufferM, lightAlbedoM, lightSpeed * float(sumlightAlbedo > 0.0002));
	#endif
	
	/*DRAWBUFFERS:05*/
    gl_FragData[0] = color;
	gl_FragData[1] = vec4(pow(color.rgb, vec3(0.125)) * 0.5, 1.0);

	#ifdef COLORED_LIGHT
	/*DRAWBUFFERS:059*/
	gl_FragData[2] = vec4(finalLight, 1.0);
	#endif
}

#endif

//////////Vertex Shader//////////Vertex Shader//////////Vertex Shader//////////
#ifdef VSH

//Uniforms//
uniform mat4 gbufferModelView;

#ifdef COLORED_LIGHT
	uniform float viewHeight;

	uniform sampler2D colortex8;
	uniform sampler2D colortex9;
#endif

//Optifine Constants//

//Common Variables//
#ifdef OVERWORLD
	float timeAngleM = timeAngle;
#else
	#if !defined SEVEN && !defined SEVEN_2
		float timeAngleM = 0.25;
	#else
		float timeAngleM = 0.5;
	#endif
#endif

//Program//
void main() {
	texCoord = gl_MultiTexCoord0.xy;
	
	gl_Position = ftransform();

	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngleM - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

	upVec = normalize(gbufferModelView[1].xyz);

	#ifdef COLORED_LIGHT
		lightAlbedo = texture2DLod(colortex8, texCoord, log2(viewHeight)).rgb;
		lightBuffer = texture2D(colortex9, texCoord).rgb;
	#endif
}

#endif
