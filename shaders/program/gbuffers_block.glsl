/*
Complementary Shaders by EminGT, based on BSL Shaders by Capt Tatsu
*/

//Common//
#include "/lib/common.glsl"

//Varyings//
varying vec2 texCoord, lmCoord;

varying vec3 normal;
varying vec3 sunVec, upVec;

varying vec4 color;

#ifdef END_PORTAL_REWORK
	varying vec3 eastVec;
#endif

#if MC_VERSION >= 11700 && !defined COMPATIBILITY_MODE
	varying float fullLightmap;
#endif

#ifdef ADV_MAT
	#if defined PARALLAX || defined SELF_SHADOW
		varying float dist;
		varying vec3 viewVector;
	#endif

	#if !defined COMPBR || defined NORMAL_MAPPING || defined NOISY_TEXTURES
		varying vec4 vTexCoord;
		varying vec4 vTexCoordAM;
		#ifdef COMPBR
			varying vec2 vTexCoordL;
		#endif
	#endif

	#ifdef NORMAL_MAPPING
		varying vec3 binormal, tangent;
	#endif

	#ifdef GENERATED_NORMALS
		uniform mat4 gbufferProjection;
	#endif

	#ifdef NOISY_TEXTURES
		varying float noiseVarying;
	#endif
#endif

//////////Fragment Shader//////////Fragment Shader//////////Fragment Shader//////////
#ifdef FSH

//Uniforms//
uniform int blockEntityId;
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

uniform vec3 fogColor;
uniform vec3 cameraPosition;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform sampler2D texture;

#if ((defined WATER_CAUSTICS || defined CLOUD_SHADOW) && defined OVERWORLD) || defined RANDOM_BLOCKLIGHT || defined NOISY_TEXTURES
	uniform sampler2D noisetex;
#endif

#if defined ADV_MAT && !defined COMPBR
	uniform sampler2D specular;
	uniform sampler2D normals;
#endif

#ifdef COLORED_LIGHT
	uniform sampler2D colortex9;
#endif

#if defined NOISY_TEXTURES || defined GENERATED_NORMALS
	uniform ivec2 atlasSize;
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

#if defined ADV_MAT && RP_SUPPORT > 2 || defined GENERATED_NORMALS || defined NOISY_TEXTURES
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

#ifdef END_PORTAL_REWORK
	#include "/lib/util/dither.glsl"
#endif

#if defined WATER_CAUSTICS && defined OVERWORLD
	#include "/lib/color/waterColor.glsl"
#endif

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
		#include "/lib/surface/parallax.glsl"
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
    vec4 albedoP = texture2D(texture, texCoord);
    vec4 albedo = albedoP * color;
	
	vec3 newNormal = normal;
	
	float skymapMod = 0.0;
	float emissive = 0.0;

	float signBlockEntity = float(blockEntityId == 63);

	#ifdef ADV_MAT
		float smoothness = 0.0, metalData = 0.0, metalness = 0.0, f0 = 0.0;
		vec3 rawAlbedo = vec3(0.0);
		vec4 normalMap = vec4(0.0, 0.0, 1.0, 1.0);

		#if !defined COMPBR || defined NORMAL_MAPPING
			vec2 newCoord = vTexCoord.st * vTexCoordAM.pq + vTexCoordAM.st;
		#endif
		
		#if defined PARALLAX || defined SELF_SHADOW
			float parallaxFade = clamp((dist - PARALLAX_DISTANCE) / 32.0, 0.0, 1.0);
			float skipParallax = signBlockEntity;
			float parallaxDepth = 1.0;
		#endif
		
		#ifdef PARALLAX
			if (skipParallax < 0.5) {
				GetParallaxCoord(parallaxFade, newCoord, parallaxDepth);
				albedo = textureGrad(texture, newCoord, dcdx, dcdy) * color;
			}
		#endif
	#endif
	
	#ifndef COMPATIBILITY_MODE
		float albedocheck = albedo.a;
	#else
		float albedocheck = 1.0;
	#endif

	if (albedocheck > 0.00001) {
		if (albedo.a > 0.99) albedo.a = 1.0;

		vec2 lightmap = clamp(lmCoord, vec2(0.0), vec2(1.0));

		float subsurface = float(blockEntityId == 983);

		vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z);
		#if AA > 1
			vec3 viewPos = ScreenToView(vec3(TAAJitter(screenPos.xy, -0.5), screenPos.z));
		#else
			vec3 viewPos = ScreenToView(screenPos);
		#endif
		vec3 worldPos = ViewToWorld(viewPos);

		float lViewPos = length(viewPos.xyz);

		float materialAO = 1.0;
		#ifdef ADV_MAT
			#ifndef COMPBR
				GetMaterials(smoothness, metalness, f0, metalData, emissive, materialAO, normalMap, newCoord, dcdx, dcdy);
			#else
				if (blockEntityId == 12001) { // Conduit
					emissive = float(albedo.b > albedo.r) * pow2(length(albedo.rgb));
					if (CheckForColor(albedo.rgb, vec3(133, 122, 42))
					 || CheckForColor(albedo.rgb, vec3(117, 80, 37))
					 || CheckForColor(albedo.rgb, vec3(101, 36, 31))) { // Center Of The Eye
						emissive = 2.0;
						albedo.rgb = vec3(1.0, 0.2, 0.15) + 0.3 * albedo.rgb;
					}
				}

				#if defined NOISY_TEXTURES || defined GENERATED_NORMALS
					#ifdef NOISY_TEXTURES
						float noiseVaryingM = noiseVarying;
					#endif
					#include "/lib/other/mipLevel.glsl"
				#endif
			#endif
			
			#ifdef NORMAL_MAPPING
				#ifdef GENERATED_NORMALS
					AutoGenerateNormals(normalMap, albedoP.rgb, delta);
				#endif

				mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
									  tangent.y, binormal.y, normal.y,
									  tangent.z, binormal.z, normal.z);

				if (normalMap.x > -0.999 && normalMap.y > -0.999)
					newNormal = clamp(normalize(normalMap.xyz * tbnMatrix), vec3(-1.0), vec3(1.0));
			#endif
		#endif

		float quarterNdotU = clamp(0.25 * dot(newNormal, upVec) + 0.75, 0.5, 1.0);
			  quarterNdotU*= quarterNdotU * (subsurface > 0.5 ? 1.8 : 1.0);

		#ifdef END_PORTAL_REWORK
			#include "/lib/other/endPortalEffect.glsl"
		#endif

    	albedo.rgb = pow(albedo.rgb, vec3(2.2));

		#ifdef NOISY_TEXTURES
			if (blockEntityId != 200)
			NoiseCoatTextures(albedo, smoothness, emissive, metalness, worldPos, miplevel, noiseVaryingM, 0.0);
		#endif

		#ifdef WHITE_WORLD
			albedo.rgb = vec3(0.5);
		#endif
		
		float NdotL = clamp(dot(newNormal, lightVec) * 1.01 - 0.01, 0.0, 1.0);

		float parallaxShadow = 1.0;
		#ifdef ADV_MAT
			rawAlbedo = albedo.rgb * 0.999 + 0.001;
			#ifdef REFLECTION_SPECULAR
				#ifdef COMPBR
					if (metalness > 0.80) {
						albedo.rgb *= (1.0 - metalness*0.65);
					}
				#else
					albedo.rgb *= (1.0 - metalness*0.65);
				#endif
			#endif

			float doParallax = 0.0;
			#ifdef SELF_SHADOW
				#ifdef OVERWORLD
					doParallax = float(lightmap.y > 0.0 && NdotL > 0.0);
				#endif
				#ifdef END
					doParallax = float(NdotL > 0.0);
				#endif
				
				if (doParallax > 0.5) {
					parallaxShadow = GetParallaxShadow(parallaxFade, newCoord, lightVec, tbnMatrix, parallaxDepth, normalMap.a);
					NdotL *= parallaxShadow;
				}
			#endif
		#endif

		#if MC_VERSION >= 11500 && !defined COMPATIBILITY_MODE
			if (color.r + color.g + color.b <= 2.99 && signBlockEntity > 0.5) {
				#if MC_VERSION >= 11700
					if (fullLightmap < 0.5)
				#endif
				albedo.rgb *= 8.0;
				NdotL = 0.0;
			}
		#endif
		#ifdef COMPBR
			if (blockEntityId == 10364) { // Enchanting Table Book
				float ETBEF = albedo.r + albedo.g - albedo.b * 4.0;
				if (ETBEF > 0.75) { 
					emissive = 0.25;
				}
			}
		#endif
		if (blockEntityId == 11032) { // Beacon Beam
			lightmap = vec2(0.0, 0.0);
			// duplicate 39582069
			#ifdef COMPBR
				emissive = length(albedoP.rgb);
				emissive *= emissive;
				emissive *= emissive;
				if (color.a < 0.9) emissive = pow2(emissive * emissive) * 0.01;
				else emissive = emissive * 0.1;
			#else
				emissive = 1.0;
			#endif
		}
		
		vec3 shadow = vec3(0.0);
		vec3 lightAlbedo = vec3(0.0);
		GetLighting(albedo.rgb, shadow, lightAlbedo, viewPos, lViewPos, worldPos, lightmap, color.a, NdotL, quarterNdotU,
					parallaxShadow, emissive, subsurface, 0.0, materialAO);

		//albedo.rgb = vec3(lightmap.y);

		#ifdef ADV_MAT
			#if defined OVERWORLD || defined END
				#ifdef OVERWORLD
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
				#endif
				
				#ifdef SPECULAR_SKY_REF
					vec3 specularHighlight = GetSpecularHighlight(smoothness, metalness, f0, specularColor, rawAlbedo,
													shadow, newNormal, viewPos);
					#if	defined ADV_MAT && defined NORMAL_MAPPING && defined SELF_SHADOW
						specularHighlight *= parallaxShadow;
					#endif
					#ifdef LIGHT_LEAK_FIX
						if (isEyeInWater == 0) specularHighlight *= pow(lightmap.y, 2.5);
						else specularHighlight *= 0.15 + 0.85 * pow(lightmap.y, 2.5);
					#endif
					if (!(blockEntityId == 200)) // No sun/moon reflection on end portals
					albedo.rgb += specularHighlight;
				#endif
			#endif

			#if defined COMPBR && defined REFLECTION_SPECULAR
				smoothness *= 0.5;
			#endif
		#endif
		
		#if SHOW_LIGHT_LEVELS > 0
			#if SHOW_LIGHT_LEVELS == 1
				if (heldItemId == 13001 || heldItemId2 == 13001)
			#elif SHOW_LIGHT_LEVELS == 3
				if (heldBlockLightValue > 7.4 || heldBlockLightValue2 > 7.4)
			#endif
			if (dot(normal, upVec) > 0.99) {
				#include "/lib/other/indicateLightLevels.glsl"
			}
		#endif

		#ifdef GBUFFER_CODING
			albedo.rgb = vec3(170.0, 0.0, 170.0) / 255.0;
			albedo.rgb = pow(albedo.rgb, vec3(2.2)) * 0.2;
		#endif
	} else discard;

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = albedo;

	#if defined ADV_MAT && defined REFLECTION_SPECULAR
	/* DRAWBUFFERS:0361 */
	gl_FragData[1] = vec4(smoothness, metalData, skymapMod, 1.0);
    gl_FragData[2] = vec4(EncodeNormal(newNormal), 0.0, 1.0);
	gl_FragData[3] = vec4(rawAlbedo, 1.0);
	#endif
}

#endif

//////////Vertex Shader//////////Vertex Shader//////////Vertex Shader//////////
#ifdef VSH

//Uniforms//
uniform float frameTimeCounter;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelView, gbufferModelViewInverse;

#if AA > 1
	uniform int frameCounter;

	uniform float viewWidth, viewHeight;
#endif

#if defined NOISY_TEXTURES || defined GENERATED_NORMALS
	uniform int blockEntityId;
#endif

//Attributes//
#ifdef ADV_MAT
attribute vec4 mc_midTexCoord;
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
	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    
	lmCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	lmCoord = clamp(lmCoord, vec2(0.0), vec2(1.0));
	#if MC_VERSION >= 11700 && !defined COMPATIBILITY_MODE
		fullLightmap = 0.0;
		if (lmCoord.x > 0.96) fullLightmap = 1.0;
	#endif
	lmCoord.x -= max(lmCoord.x - 0.825, 0.0) * 0.75;

	normal = normalize(gl_NormalMatrix * gl_Normal);

	#ifdef ADV_MAT
		#ifdef NORMAL_MAPPING
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

		vec2 midCoord = (gl_TextureMatrix[0] * mc_midTexCoord).st;
		vec2 texMinMidCoord = texCoord - midCoord;

		#if !defined COMPBR || defined NORMAL_MAPPING || defined NOISY_TEXTURES
			vTexCoordAM.zw  = abs(texMinMidCoord) * 2;
			vTexCoordAM.xy  = min(texCoord, midCoord - texMinMidCoord);
			
			vTexCoord.xy    = sign(texMinMidCoord) * 0.5 + 0.5;

			#ifdef COMPBR
				vTexCoordL  = texMinMidCoord * 2;
			#endif
		#endif
	#endif
    
	color = gl_Color;

	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngleM - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

	upVec = normalize(gbufferModelView[1].xyz);

	#ifdef END_PORTAL_REWORK
		eastVec = normalize(gbufferModelView[0].xyz);
	#endif

    #ifdef WORLD_CURVATURE
		vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
		position.y -= WorldCurvature(position.xz);
		gl_Position = gl_ProjectionMatrix * gbufferModelView * position;
	#else
		gl_Position = ftransform();
    #endif

	#if defined NOISY_TEXTURES || defined GENERATED_NORMALS
		#ifdef NOISY_TEXTURES
			noiseVarying = 0.65;
		#endif
		if (blockEntityId == 12005) { // Chests
			float worldPosYF = fract((gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex).y + cameraPosition.y);
			if (worldPosYF > 0.56 && 0.57 > worldPosYF) gl_Position.z -= 0.0001;
		}
		else if (blockEntityId == 12009) { // Shulker Boxes, Banners
			#ifdef NOISY_TEXTURES
				noiseVarying = 0.35;
			#endif
		}
	#endif
	
	#if AA > 1
		gl_Position.xy = TAAJitter(gl_Position.xy, gl_Position.w);
	#endif
}

#endif