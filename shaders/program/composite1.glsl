/*
Complementary Shaders by EminGT, based on BSL Shaders by Capt Tatsu
*/

//Common//
#include "/lib/common.glsl"

//Varyings//
varying vec2 texCoord;

varying vec3 sunVec, upVec;

//////////Fragment Shader//////////Fragment Shader//////////Fragment Shader//////////
#ifdef FSH

//Uniforms//
uniform int isEyeInWater;

uniform float blindFactor;
uniform float rainStrengthS;
uniform float screenBrightness; 
uniform float viewWidth, viewHeight;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 skyColor;

uniform mat4 gbufferProjectionInverse;

uniform sampler2D colortex0;
uniform sampler2D colortex1;

#ifdef VL_CLOUDS
	uniform sampler2D colortex5;
#endif

#if NIGHT_VISION > 1
	uniform float nightVision;
#endif

#if MC_VERSION >= 11900
	uniform float darknessFactor;
#endif

//Optifine Constants//
#if !(LIGHT_SHAFT_QUALITY == 3)
	const bool colortex1MipmapEnabled = true;
#endif

#ifdef VL_CLOUDS
	const bool colortex5MipmapEnabled = true;
#endif

//Common Variables//
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility = clamp(dot( sunVec,upVec) + 0.0625, 0.0, 0.125) * 8.0;
float sunVisibilityLSM = clamp(dot( sunVec,upVec) + 0.125, 0.0, 0.25) * 4.0;
float vsBrightness = clamp(screenBrightness, 0.0, 1.0);
float rainStrengthSp2 = rainStrengthS * rainStrengthS;
float lightShaftTime = pow(abs(sunVisibility - 0.5) * 2.0, 10.0);
float worldBrightness = max(timeBrightness, moonBrightness);

//Common Functions//
float GetLuminance(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}

//Includes//
#include "/lib/color/dimensionColor.glsl"

//Program//
void main() {
    vec4 color = texture2D(colortex0,texCoord.xy);

	#ifdef VL_CLOUDS
		float offsetC = 2.0;
		float lodC = 1.5;
		vec4 clouds1 = texture2DLod(colortex5, texCoord.xy + vec2( 0.0,  offsetC / viewHeight), lodC);
		vec4 clouds2 = texture2DLod(colortex5, texCoord.xy + vec2( 0.0, -offsetC / viewHeight), lodC);
		vec4 clouds3 = texture2DLod(colortex5, texCoord.xy + vec2( offsetC / viewWidth,   0.0), lodC);
		vec4 clouds4 = texture2DLod(colortex5, texCoord.xy + vec2(-offsetC / viewWidth,   0.0), lodC);
		vec4 clouds = (clouds1 + clouds2 + clouds3 + clouds4) * 0.25;
		clouds *= clouds;
	#endif

	#ifdef END
		vec3 vl = texture2DLod(colortex1, texCoord.xy, 1.5).rgb;
		vl *= vl;
	#else
		#if LIGHT_SHAFT_QUALITY == 1
			float lod = 1.0;
		#elif LIGHT_SHAFT_QUALITY == 2
			float lod = 0.5;
		#else
			float lod = 0.0;
		#endif
		
		#ifndef MC_GL_RENDERER_GEFORCE
			if (fract(viewHeight / 2.0) > 0.25 || fract(viewWidth / 2.0) > 0.25) 
				lod = 0.0;
		#endif

		float offset = 1.0;
		vec3 vl1 = texture2DLod(colortex1, texCoord.xy + vec2( 0.0,  offset / viewHeight), lod).rgb;
		vec3 vl2 = texture2DLod(colortex1, texCoord.xy + vec2( 0.0, -offset / viewHeight), lod).rgb;
		vec3 vl3 = texture2DLod(colortex1, texCoord.xy + vec2( offset / viewWidth,   0.0), lod).rgb;
		vec3 vl4 = texture2DLod(colortex1, texCoord.xy + vec2(-offset / viewWidth,   0.0), lod).rgb;
		vec3 vlSum = (vl1 + vl2 + vl3 + vl4) * 0.25;
		vec3 vl = vlSum;

		vl *= vl;
	#endif
	#if MC_VERSION >= 11900
		vl *= 1.0 - darknessFactor;
	#endif
	vec3 vlP = vl;

	#ifdef OVERWORLD
		if (isEyeInWater == 0) {
			#if LIGHT_SHAFT_MODE == 2
				vec4 screenPos = vec4(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z, 1.0);
				vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
				viewPos /= viewPos.w;
				vec3 nViewPos = normalize(viewPos.xyz);

				float NdotU = dot(nViewPos, upVec);
				NdotU = max(NdotU, 0.0);
				NdotU = 1.0 - NdotU;
				if (NdotU > 0.5) NdotU = smoothstep(0.0, 1.0, NdotU);
				NdotU *= NdotU;
				NdotU *= NdotU;
				NdotU = mix(NdotU, 1.0, rainStrengthSp2 * 0.75);
				vl *= NdotU * NdotU;
			#else
				vec4 screenPos = vec4(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z, 1.0);
				vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
				viewPos /= viewPos.w;
				vec3 nViewPos = normalize(viewPos.xyz);

				float NdotU = dot(nViewPos, upVec);
				NdotU = max(NdotU, 0.0);
				NdotU = 1.0 - NdotU;
				if (NdotU > 0.5) NdotU = smoothstep(0.0, 1.0, NdotU);
				NdotU = mix(NdotU, 1.0, rainStrengthSp2 * 0.75);
				NdotU = pow(NdotU, 8.0 * smoothstep(0.0, 1.0, pow2(1.0 - worldBrightness)));
				vl *= max(NdotU, 0.0); // Using max() here fixes a bug that affects auto exposure
			#endif
			vlP = vl;

			vec3 lightCol2 = lightCol * lightCol;
			vec3 dayLightCol = lightCol2 * 0.73;
			vec3 nightLightCol = lightCol2 * 20.0;
			vec3 vlColor = mix(nightLightCol, dayLightCol, sunVisibility);
			//duplicate 98765
			vec3 weatherSky = weatherCol * weatherCol;
			weatherSky *= GetLuminance(ambientCol / (weatherSky)) * 1.4;
			weatherSky *= mix(SKY_RAIN_NIGHT, SKY_RAIN_DAY, sunVisibility);
			weatherSky = max(weatherSky, skyColor * skyColor * 0.75); // Lightning Sky Color
			weatherSky *= rainStrengthS;
			vlColor = mix(vlColor, weatherSky * 10.0, rainStrengthSp2);
			vl *= vlColor;

			float rainMult = mix(LIGHT_SHAFT_NIGHT_RAIN_MULTIPLIER,
									LIGHT_SHAFT_DAY_RAIN_MULTIPLIER * (0.65 + 0.2 * vsBrightness),
									sunVisibility);
			#if LIGHT_SHAFT_MODE == 2
				vl *= mix(1.0, LIGHT_SHAFT_NOON_MULTIPLIER * 0.4, timeBrightness * (1.0 - rainStrengthS * 0.8));
				vl *= mix(LIGHT_SHAFT_NIGHT_MULTIPLIER * 0.65, 2.0, sunVisibility);
				vl *= mix(1.0, rainMult, rainStrengthSp2);
			#else
				float timeBrightnessSqrt = sqrt1(timeBrightness);
				
				vl *= mix(1.0, LIGHT_SHAFT_NOON_MULTIPLIER * 0.75, timeBrightnessSqrt * (1.0 - rainStrengthS * 0.8));
				vl *= mix(LIGHT_SHAFT_NIGHT_MULTIPLIER * (0.91 - moonBrightness * 0.39), 2.0, sunVisibility);
				vl *= mix(1.0, rainMult, rainStrengthSp2);
			#endif
		} else vl *= length(lightCol) * 0.175 * LIGHT_SHAFT_UNDERWATER_MULTIPLIER  * (1.0 - rainStrengthS * 0.85);
	#endif

	#ifdef END
   		vl *= endCol * 0.1 * LIGHT_SHAFT_THE_END_MULTIPLIER;
    	vl *= LIGHT_SHAFT_STRENGTH * (1.0 - rainStrengthS * eBS * 0.875) * shadowFade * (1.0 + isEyeInWater*1.5) * (1.0 - blindFactor);
	#else
		vl *= LIGHT_SHAFT_STRENGTH * shadowFade * (1.0 - blindFactor);

		float vlFactor = (1.0 - min((timeBrightness)*2.0, 0.75));
		vlFactor = mix(vlFactor, 0.05, rainStrengthS);
		if (isEyeInWater == 1) vlFactor = 3.0;
		vl *= vlFactor * 1.15;
	#endif

	#if NIGHT_VISION > 1
		if (nightVision > 0.0) {
			vl = vec3(0.0, length(vl), 0.0);
		}
	#endif

	#ifdef END
		color.rgb += vl;
	#else
		vec3 addedColor = color.rgb + vl * lightShaftTime;
		#if LIGHT_SHAFT_MODE == 2
			vec3 vlMixBlend = vlP * (1.0 - 0.5 * rainStrengthS);
		#else
			vec3 vlMixBlend = vlP * 0.5;
			vlP *= 0.75;
		#endif
		float mixedTime = sunVisibility < 0.5 ?
						  sqrt3(max(moonBrightness - 0.3, 0.0) / 0.7) * lightShaftTime
						  : pow2(pow2((sunVisibilityLSM - 0.5) * 2.0));
		vec3 mixedColor = mix(color.rgb, vl / max(vlP, 0.01), vlMixBlend * mixedTime);
		color.rgb = mix(mixedColor, addedColor, sunVisibility * (1.0 - rainStrengthS));
	#endif

	#ifdef VL_CLOUDS
		clouds.a *= CLOUD_OPACITY;
		color.rgb = mix(color.rgb, clouds.rgb, clouds.a);
	#endif
	
	/*DRAWBUFFERS:0*/
	gl_FragData[0] = color;
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
	texCoord = gl_MultiTexCoord0.xy;
	
	gl_Position = ftransform();

	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngleM - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

	upVec = normalize(gbufferModelView[1].xyz);
}

#endif