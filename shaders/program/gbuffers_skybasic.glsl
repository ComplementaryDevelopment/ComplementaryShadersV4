/*
Complementary Shaders by EminGT, based on BSL Shaders by Capt Tatsu
*/

//Common//
#include "/lib/common.glsl"

//Varyings//
varying float vanillaStars;

varying vec3 upVec, sunVec;

//////////Fragment Shader//////////Fragment Shader//////////Fragment Shader//////////
#ifdef FSH

//Uniforms//
uniform int isEyeInWater;
uniform int worldDay;
uniform int moonPhase;
#define UNIFORM_moonPhase

uniform float isEyeInCave;
uniform float blindFactor;
uniform float frameCounter;
uniform float frameTimeCounter;
uniform float nightVision;
uniform float rainStrength;
uniform float rainStrengthS;
uniform float screenBrightness; 
uniform float viewWidth, viewHeight;
uniform float eyeAltitude;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 cameraPosition;
uniform vec3 skyColor;
uniform vec3 fogColor;
uniform vec3 moonPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

uniform sampler2D noisetex;

#ifdef GALAXIES
	uniform sampler2D gaux4;
#endif

#ifdef AURORA
	uniform float isDry, isRainy, isSnowy;
#endif

#if MC_VERSION >= 11900
	uniform float darknessFactor;
#endif

//Common Variables//
#if WORLD_TIME_ANIMATION >= 1
	int modifiedWorldDay = int(mod(worldDay, 100.0) + 5.0);
	float frametime = (worldTime + modifiedWorldDay * 24000) * 0.05 * ANIMATION_SPEED;
#else
	float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility = clamp(dot( sunVec,upVec) + 0.0625, 0.0, 0.125) * 8.0;
float vsBrightness = clamp(screenBrightness, 0.0, 1.0);

vec3 lightVec = sunVec * (1.0 - 2.0 * float(timeAngle > 0.5325 && timeAngle < 0.9675));

//Common Functions//
float GetLuminance(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}

vec3 RoundSunMoon(vec3 nViewPos, vec3 sunColor, vec3 moonColor, float NdotU, float cosS) {
	float isMoon = float(cosS < 0.0);
	float sun = pow(abs(cosS), 2600.0 * isMoon + 1800.0 * (1 - isMoon));

	if (isMoon > 0.0) {
		if (moonPhase >= 1) {
			float moonPhaseOffset = float(!(moonPhase == 4));
			if (moonPhase > 4) moonPhaseOffset *= -1.0;

			float ang = fract(timeAngle - (0.25 + 0.0035 * moonPhaseOffset));
			ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
			vec2 sunRotationData2 = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
			vec3 rawSunVec2 = (gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData2) * 2000.0, 1.0)).xyz;
		
			float moonPhaseCosS = dot(nViewPos, normalize(rawSunVec2.xyz));
			moonPhaseCosS = pow(abs(moonPhaseCosS), 750.0);
			sun = mix(sun, 0.0, min(moonPhaseCosS * 2.0, 1.0));
		}
	}

	#ifdef SUN_MOON_HORIZON
		float horizonFactor = clamp((NdotU+0.0025)*20, 0.0, 1.0);
		sun *= horizonFactor;
		moonColor *= 1.0 - sunVisibility;
		sunColor *= sunVisibility;
	#endif

	vec3 sunMoonCol = mix(moonColor, sunColor, float(cosS > 0.0));

	vec3 finalSunMoon = sun * sunMoonCol * 32.0;
	finalSunMoon = pow(finalSunMoon, vec3(2.0 - min(finalSunMoon.r + finalSunMoon.g + finalSunMoon.b, 1.0)));

	return finalSunMoon;
}

float GetStarNoise(vec2 pos) {
	return fract(sin(dot(pos, vec2(12.9898, 4.1414))) * 43758.54953);
}

vec3 GetGalaxy(vec3 viewPos, float NdotU, float cosS, vec3 lightNight) {
	vec3 wpos = vec3(gbufferModelViewInverse * vec4(viewPos * 70.0, 1.0));
	vec3 planeCoord = wpos / (wpos.y + length(wpos.xz) * 0.5);

	vec3 moonPos = vec3(gbufferModelViewInverse * vec4(- sunVec * 70.0, 1.0));
	vec3 moonCoord = moonPos / (moonPos.y + length(moonPos.xz));
	vec2 wind = vec2(frametime, 0.0);
	vec2 skyCoord = planeCoord.xz - moonCoord.xz;
	skyCoord *= 0.35;

	#ifdef SHADER_STARS
		#if STAR_AMOUNT == 1
			float floorStar = 768.0;
			vec2 starCoord = floor(skyCoord * floorStar) / floorStar;
			
			float star = 1.0;
			if (NdotU > 0.0) {
				star -= GetStarNoise(starCoord.xy+0.2);
				star -= GetStarNoise(starCoord.xy+0.3);
				star = pow(max(star, 0.0), 200.0) * 0.5;
			}
		#else
			float floorStar = 768.0;
			vec2 starCoord = floor(skyCoord * floorStar) / floorStar;
			float floorStar1 = 1024.0;
			vec2 starCoord1 = floor(skyCoord * floorStar1) / floorStar1;
			
			float star = 1.0;
			float star1 = 1.0;
			if (NdotU > 0.0) {
				star -= GetStarNoise(starCoord.xy+0.2);
				star -= GetStarNoise(starCoord.xy+0.3);
				star1 -= GetStarNoise(starCoord1.xy);
				star1 -= GetStarNoise(starCoord1.xy+0.1);

				float star1m = pow2(max(star1 - 0.925, 0.0));
				star = pow(max(star, 0.0), 200.0);
				star = star1m + star * 0.5;
			}
		#endif
	#else
		float star = vanillaStars * 0.05;
	#endif

	float starDeletionTime = 1.0 - min(timeBrightness * 16.0, 1.0) * 0.15 - sunVisibility * 0.85;
	float starNdotU = pow2(pow2(clamp(NdotU * 3.0, 0.0, 1.0)));
	float starFactor = starNdotU * starDeletionTime;
	star *= starFactor * 32.0 * (1.0 - isEyeInCave) * STAR_BRIGHTNESS;

	vec3 starColor = lightNight * lightNight * 30.0;
	vec3 starImage = starColor * star;

	vec3 result = starImage;
	#ifndef SUNSET_STARS
		result *= 1.0 - sunVisibility;
	#endif

	#ifdef GALAXIES
		if (sunVisibility < 1.0) {
			vec3 galaxy = texture2D(gaux4, skyCoord * 0.9 + 0.4).rgb;
			float lGalaxy = pow2(length(galaxy) + 0.3);
			galaxy *= lGalaxy;
			#ifdef SHADER_STARS
				#if STAR_AMOUNT == 1
					float floorStar1 = 1024.0;
					vec2 starCoord1 = floor(skyCoord * floorStar1) / floorStar1;
					float star1 = 1.0;
					if (NdotU > 0.0) {
						star1 -= GetStarNoise(starCoord1.xy);
						star1 -= GetStarNoise(starCoord1.xy+0.1);
					}
				#endif
				galaxy += max(star1 - 0.65, 0.0) * starColor * lGalaxy;
			#endif
			result += galaxy * galaxy * 0.015 * starNdotU * (1.0 - sunVisibility) * GALAXY_BRIGHTNESS;
		}
	#endif

	result *= clamp(1.0 - pow(abs(cosS) * 1.002, 100.0), 0.0, 1.0);

	result *= pow2(pow2(1.0 - max(rainStrength, rainStrengthS)));

	return result;
}

//Includes//
#include "/lib/color/lightColor.glsl"
#include "/lib/color/skyColor.glsl"
#include "/lib/color/waterColor.glsl"
#include "/lib/color/endColor.glsl"
#include "/lib/util/dither.glsl"

#ifdef AURORA
#include "/lib/color/auroraColor.glsl"
#endif

#if (defined CLOUDS || defined AURORA) && defined OVERWORLD
#include "/lib/atmospherics/skyboxEffects.glsl"
#endif
#include "/lib/atmospherics/sky.glsl"
#include "/lib/atmospherics/sunGlare.glsl"

//Program//
void main() {
	vec3 albedo = vec3(0.0);

	vec4 screenPos = vec4(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z, 1.0);
	vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
	viewPos /= viewPos.w;

	vec3 nViewPos = normalize(viewPos.xyz);

	float NdotU = dot(nViewPos, upVec);
	
	#ifdef OVERWORLD
		#if defined CLOUDS || defined AURORA
			float dither = Bayer64(gl_FragCoord.xy);
		#endif
		#ifdef CLOUDS
			vec4 cloud = DrawCloud(viewPos.xyz * 1000000.0, dither, lightCol, ambientCol, NdotU, 6);
			float cloudMaskR = cloud.a / CLOUD_OPACITY;
			if (NdotU > 0.025) cloudMaskR /= pow2(pow2(1.0 - exp(- (10.0 - 8.2 * rainStrengthS) * NdotU))); //duplicate 78634
		#endif
		
		albedo = GetSkyColor(lightCol, NdotU, nViewPos, false);
		
		float cosS = dot(nViewPos, sunVec);

		vec3 galaxy = GetGalaxy(viewPos.xyz, NdotU, cosS, lightNight);
		#ifdef CLOUDS
			galaxy *= smoothstep(0.0, 1.0, 1.0 - cloudMaskR);
		#endif
		albedo.rgb += galaxy;
		
		#ifdef ROUND_SUN_MOON
			vec3 sunColor = vec3(0.9, 0.35, 0.05);
			if (isEyeInWater == 1) sunColor = 2.0 * normalize(underwaterColor.rgb);
			vec3 moonColor = vec3(12.0, 13.8, 15.9) / 35.7;
			
			vec3 roundSunMoon = RoundSunMoon(nViewPos, sunColor, moonColor, NdotU, cosS);

			#ifdef CLOUDS
				roundSunMoon *= pow2(pow2(pow2(pow2(pow2(1.0 - cloudMaskR * cloudMaskR * rainStrengthS)))));
				//This should still be faster than pow()

				roundSunMoon *= pow2(1.0 - rainStrengthS);
			#else
				roundSunMoon *= 1.0 - max(rainStrength, rainStrengthS);
			#endif
			albedo.rgb += roundSunMoon;
		#endif

		albedo = SunGlare(albedo, nViewPos, lightCol);
		
		#ifdef AURORA
			vec3 aurora = DrawAurora(viewPos.xyz * 1000000.0, dither, 20, NdotU);
			#ifdef CLOUDS
				aurora *= 1.0 - cloudMaskR;
			#endif
			albedo.rgb += aurora;
		#endif

		#if defined CLOUDS && THE_FORBIDDEN_OPTION == 0
			albedo.rgb = mix(albedo.rgb, cloud.rgb, cloud.a);
		#endif
	#endif

	#ifdef GBUFFER_CODING
		albedo.rgb = vec3(0.0, 0.0, 0.0);
	#endif

	#ifdef SHADER_STARS
		float alpha = 1.0 - vanillaStars;
	#else
		#ifdef SUNSET_STARS
			float alpha = max(1.0 - vanillaStars * timeBrightness * 10.0, 0.0);
		#else
			float alpha = 1.0 - vanillaStars * sunVisibility;
		#endif
		float vanillaStarsM = vanillaStars * (1.0 - clamp(NdotU * 3.0, 0.0, 1.0));
		alpha = max(alpha - vanillaStarsM, 0.0);
	#endif

	#if MC_VERSION >= 11700
		if (isEyeInWater == 3 && blindFactor == 0) albedo.rgb = vec3(0.1, 0.15, 0.2);
	#endif

	#if defined CAVE_SKY_FIX && defined OVERWORLD
		albedo.rgb *= 1.0 - isEyeInCave;
	#endif

	#if MC_VERSION >= 11900
		if (darknessFactor > 0.001) albedo.rgb = mix(albedo.rgb, darknessColor, darknessFactor);
	#endif

    /* DRAWBUFFERS:0 */
	gl_FragData[0] = vec4(albedo, alpha);
}

#endif

//////////Vertex Shader//////////Vertex Shader//////////Vertex Shader//////////
#ifdef VSH

//Uniforms//

uniform mat4 gbufferModelView;

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
    const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngleM - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	vec3 rawSunVec = (gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz;
	sunVec = normalize(rawSunVec);

	upVec = normalize(gbufferModelView[1].xyz);
	
	gl_Position = ftransform();

	vec3 color = gl_Color.rgb;
	
	//Vanilla Star Dedection by Builderb0y
	vanillaStars = float(color.r == color.g && color.g == color.b && color.r > 0.0 && color.r < 0.51);
}

#endif