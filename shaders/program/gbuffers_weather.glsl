/*
Complementary Shaders by EminGT, based on BSL Shaders by Capt Tatsu
*/

//Common//
#include "/lib/common.glsl"

//Varyings//
varying vec2 texCoord, lmCoord;

varying vec3 upVec, sunVec;

varying vec4 color;

//////////Fragment Shader//////////Fragment Shader//////////Fragment Shader//////////
#ifdef FSH

//Uniforms//
uniform int isEyeInWater;

uniform float nightVision;
uniform float rainStrengthS;
uniform float screenBrightness; 
uniform float viewWidth, viewHeight;

uniform ivec2 eyeBrightnessSmooth;

uniform mat4 gbufferProjectionInverse;

uniform sampler2D texture;

#ifdef DYNAMIC_SHADER_LIGHT
	uniform int heldItemId, heldItemId2;

	uniform int heldBlockLightValue;
	uniform int heldBlockLightValue2;

	uniform mat4 gbufferModelViewInverse;
	uniform mat4 shadowProjection;
	uniform mat4 shadowModelView;
#endif

//Common Variables//
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility = clamp(dot( sunVec,upVec) + 0.0625, 0.0, 0.125) * 8.0;
float vsBrightness = clamp(screenBrightness, 0.0, 1.0);

//Includes//
#include "/lib/color/lightColor.glsl"
#include "/lib/color/blocklightColor.glsl"

#ifdef DYNAMIC_SHADER_LIGHT
	#include "/lib/util/spaceConversion.glsl"

	#if AA == 2 || AA == 3
		#include "/lib/util/jitter.glsl"
	#endif
	#if AA == 4
		#include "/lib/util/jitter2.glsl"
	#endif
#endif

//Program//
void main() {
	vec4 albedo = texture2D(texture, texCoord.xy);
	vec2 lightmap = lmCoord;

	#ifdef OVERLAY_FIX
	if (color.r + color.g + color.b > 2.99999) {
	#endif
		if (albedo.a > 0.0) {
			#ifdef DYNAMIC_SHADER_LIGHT
				vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z);
				#if AA > 1
					vec3 viewPos = ScreenToView(vec3(TAAJitter(screenPos.xy, -0.5), screenPos.z));
				#else
					vec3 viewPos = ScreenToView(screenPos);
				#endif
				vec3 worldPos = ViewToWorld(viewPos);
				float lViewPos = length(viewPos.xyz);

				float handLight = min(float(heldBlockLightValue2 + heldBlockLightValue), 15.0) / 15.0;

				float handLightFactor = 1.0 - min(DYNAMIC_LIGHT_DISTANCE * handLight, lViewPos) / (DYNAMIC_LIGHT_DISTANCE * handLight);
				float finalHandLight = handLight * handLightFactor;
				lightmap.x = max(finalHandLight * 0.95, lightmap.x);
			#endif
			#ifndef COMPATIBILITY_MODE
				if (albedo.r <= 0.75) { // Rain
					albedo.a *= 0.15;
					albedo.rgb = sqrt(albedo.rgb);
					albedo.rgb *= (ambientCol + lightmap.x * lightmap.x * blocklightCol) * 0.75;
				} else { 				// Snow
					albedo.a *= 0.15;
					albedo.rgb = sqrt(albedo.rgb);
					albedo.rgb *= (ambientCol + lightmap.x * lightmap.x * blocklightCol) * 2.0;
				}
			#else
				albedo.a *= 0.15;
				albedo.rgb = sqrt(albedo.rgb);
				albedo.rgb *= (ambientCol + lightmap.x * lightmap.x * blocklightCol) * 0.75;
			#endif
		}
		
		#ifdef GBUFFER_CODING
			albedo.rgb = vec3(85.0, 85.0, 85.0) / 255.0;
			albedo.rgb = pow(albedo.rgb, vec3(2.2)) * 0.5;
		#endif
	#ifdef OVERLAY_FIX
	} else {
		albedo.rgb = pow(color.rgb, vec3(2.2)) * 2.0;
		albedo.rgb *= 0.25 + lightmap.x + lightmap.y * (1.0 + sunVisibility);
		if (texCoord.x == 0.0) albedo.a = pow2(color.a * color.a);
	}
	#endif

/* DRAWBUFFERS:0 */
	gl_FragData[0] = albedo;
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
	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

	lmCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	lmCoord = clamp(lmCoord * 2.0 - 1.0, 0.0, 1.0);

	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngleM - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

	upVec = normalize(gbufferModelView[1].xyz);
	
	gl_Position = ftransform();

	color = gl_Color;
}

#endif