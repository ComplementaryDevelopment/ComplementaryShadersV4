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

//////////Fragment Shader//////////Fragment Shader//////////Fragment Shader//////////
#ifdef FSH

//Uniforms//
uniform int frameCounter;
uniform int isEyeInWater;

#ifdef DYNAMIC_SHADER_LIGHT
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

#if ((defined WATER_CAUSTICS || defined CLOUD_SHADOW) && defined OVERWORLD) || defined RANDOM_BLOCKLIGHT
	uniform sampler2D noisetex;
#endif

#ifdef COLORED_LIGHT
	uniform sampler2D colortex9;
#endif

#if MC_VERSION >= 11700
	uniform int renderStage;
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

#if defined WATER_CAUSTICS && defined OVERWORLD
	#include "/lib/color/waterColor.glsl"
#endif

#include "/lib/lighting/forwardLighting.glsl"

#if SELECTION_MODE == 1
	#include "/lib/color/selectionColor.glsl"
#endif

#if AA == 2 || AA == 3
	#include "/lib/util/jitter.glsl"
#endif
#if AA == 4
	#include "/lib/util/jitter2.glsl"
#endif

//Program//
void main() {
    vec4 albedo = color;

	float skymapMod = 0.0;
	
	#ifndef COMPATIBILITY_MODE
		float albedocheck = albedo.a;
	#else
		float albedocheck = 1.0;
	#endif

	if (albedocheck > 0.00001) {	
		vec2 lightmap = clamp(lmCoord, vec2(0.0), vec2(1.0));

		vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z);
		#if AA > 1
			vec3 viewPos = ScreenToView(vec3(TAAJitter(screenPos.xy, -0.5), screenPos.z));
		#else
			vec3 viewPos = ScreenToView(screenPos);
		#endif
		vec3 worldPos = ViewToWorld(viewPos);
		float lViewPos = length(viewPos.xyz);

    	albedo.rgb = pow(albedo.rgb, vec3(2.2));
		albedo.a = albedo.a * 0.5 + 0.5;

		#ifdef WHITE_WORLD
			if (albedo.a > 0.9) albedo.rgb = vec3(0.5);
		#endif

		float NdotL = clamp(dot(normal, lightVec) * 1.01 - 0.01, 0.0, 1.0);

		float quarterNdotU = clamp(0.25 * dot(normal, upVec) + 0.75, 0.5, 1.0);
			  quarterNdotU*= quarterNdotU;
		
		vec3 shadow = vec3(0.0);
		vec3 lightAlbedo = vec3(0.0);
		GetLighting(albedo.rgb, shadow, lightAlbedo, viewPos, lViewPos, worldPos, lightmap, 1.0, NdotL, quarterNdotU,
				    1.0, 0.0, 0.0, 0.0, 1.0);

		#if MC_VERSION >= 11700
		if (renderStage == 14) {
		#else
		if (albedo.rgb == vec3(0.0) && albedo.a > 0.5) {
		#endif
			albedo.a = 1.0;	
			#if SELECTION_MODE == 1 // Select Color
				albedo.rgb = selectionCol;
			#endif
			#if SELECTION_MODE == 2 // Versatile
				albedo.a = 0.1;
				skymapMod = 0.995;
			#endif
			#if SELECTION_MODE == 4 // Rainbow
				float posFactor = worldPos.x + worldPos.y + worldPos.z + cameraPosition.x + cameraPosition.y + cameraPosition.z;
				albedo.rgb = clamp(abs(mod(fract(frameTimeCounter*0.25 + posFactor*0.1) * 6.0 + vec3(0.0,4.0,2.0), 6.0) - 3.0)-1.0,
							0.0, 1.0);
				albedo.rgb = pow(albedo.rgb, vec3(2.2)) * SELECTION_I * SELECTION_I * 0.5;
			#endif
			#if SELECTION_MODE == 3 // Disabled
				albedo.a = 0.0;
				discard;
			#endif
		}
	} else discard;

	#ifdef GBUFFER_CODING
		albedo.rgb = vec3(85.0, 255.0, 85.0) / 255.0;
		albedo.rgb = pow(albedo.rgb, vec3(2.2)) * 0.5;
	#endif

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = albedo;

	#if (defined ADV_MAT && defined REFLECTION_SPECULAR) || SELECTION_MODE == 2
		/* DRAWBUFFERS:0361 */
		gl_FragData[1] = vec4(0.0, 0.0, skymapMod, 1.0);
		gl_FragData[2] = vec4(0.0, 0.0, float(gl_FragCoord.z < 1.0), 1.0);
		gl_FragData[3] = vec4(0.0, 0.0, 0.0, 1.0);
	#endif
}

#endif

//////////Vertex Shader//////////Vertex Shader//////////Vertex Shader//////////
#ifdef VSH

//Uniforms//
uniform float frameTimeCounter;
uniform float viewWidth, viewHeight;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelView, gbufferModelViewInverse;

#if AA > 1
	uniform int frameCounter;
#endif

#if MC_VERSION >= 11700
	uniform int renderStage;
#endif

//Attributes//
attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

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
	lmCoord = clamp((lmCoord - 0.03125) * 1.06667, 0.0, 1.0);

	normal = normalize(gl_NormalMatrix * gl_Normal);
    
	color = gl_Color;

	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngleM - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

	upVec = normalize(gbufferModelView[1].xyz);

	#ifndef GBUFFERS_LINE
		#ifdef WORLD_CURVATURE
			vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
			position.y -= WorldCurvature(position.xz);
			gl_Position = gl_ProjectionMatrix * gbufferModelView * position;
		#else
			gl_Position = ftransform();
		#endif
	#else
		float lineWidth = 2.0;
		vec2 screenSize = vec2(viewWidth, viewHeight);
		const mat4 VIEW_SCALE = mat4(mat3(1.0 - (1.0 / 256.0)));
		vec4 linePosStart = projectionMatrix * VIEW_SCALE * modelViewMatrix * vec4(vaPosition, 1.0);
		vec4 linePosEnd = projectionMatrix * VIEW_SCALE * modelViewMatrix * (vec4(vaPosition + vaNormal, 1.0));
		vec3 ndc1 = linePosStart.xyz / linePosStart.w;
		vec3 ndc2 = linePosEnd.xyz / linePosEnd.w;
		vec2 lineScreenDirection = normalize((ndc2.xy - ndc1.xy) * screenSize);
		vec2 lineOffset = vec2(-lineScreenDirection.y, lineScreenDirection.x) * lineWidth / screenSize;
		if (lineOffset.x < 0.0)
			lineOffset *= -1.0;
		if (gl_VertexID % 2 == 0)
			gl_Position = vec4((ndc1 + vec3(lineOffset, 0.0)) * linePosStart.w, linePosStart.w);
		else
			gl_Position = vec4((ndc1 - vec3(lineOffset, 0.0)) * linePosStart.w, linePosStart.w);
	#endif
	
	#if AA > 1
		gl_Position.xy = TAAJitter(gl_Position.xy, gl_Position.w);
	#endif
}

#endif