/*
Complementary Shaders by EminGT, based on BSL Shaders by Capt Tatsu
*/

//Common//
#include "/lib/common.glsl"

//Varyings//
varying float mat;

varying vec2 texCoord;

varying vec4 color;
varying vec4 position;

//////////Fragment Shader//////////Fragment Shader//////////Fragment Shader//////////
#ifdef FSH

//Uniforms//
uniform int isEyeInWater;
uniform int blockEntityId;

uniform vec3 cameraPosition;

uniform sampler2D tex;
uniform sampler2D noisetex;

//Common Variables//
#if WORLD_TIME_ANIMATION >= 2
#else
uniform float frameTimeCounter;
#endif

#if WORLD_TIME_ANIMATION >= 2
	float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
	float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

//Includes//
#include "/lib/util/dither.glsl"

//Common Functions//
void doWaterShadowCaustics(float dither) {
	#if defined WATER_CAUSTICS && defined OVERWORLD
		vec3 worldPos = position.xyz + cameraPosition.xyz;
		worldPos *= 0.5;
		float noise = 0.0;
		float mult = 0.5;
		
		vec2 wind = vec2(frametime) * 0.3; //speed
		float verticalOffset = worldPos.y * 0.2;

		if (mult > 0.01) {
			float lacunarity = 1.0 / 750.0, persistance = 1.0, weight = 0.0;

			for(int i = 0; i < 8; i++) {
				float windSign = mod(i,2) * 2.0 - 1.0;
				vec2 noiseCoord = worldPos.xz + wind * windSign - verticalOffset;
				if (i < 7) noise += texture2D(noisetex, noiseCoord * lacunarity).r * persistance;
				else {
					noise += texture2D(noisetex, noiseCoord * lacunarity * 0.125).r * persistance * 10.0;
					noise = -noise;
					float noisePlus = 1.0 + 0.125 * -noise;
					noisePlus *= noisePlus;
					noisePlus *= noisePlus;
					noise *= noisePlus;
				}

				if (i == 0) noise = -noise;

				weight += persistance;
				lacunarity *= 1.50;
				persistance *= 0.60;
			}
			noise *= mult / weight;
		}
		float noiseFactor = 1.1 + noise;
		noiseFactor = pow(noiseFactor, 10.0);
		if (noiseFactor > 1.0 - dither * 0.5) discard;
	#else
		discard;
	#endif
}

//Program//
void main() {
    #if MC_VERSION >= 11300
		if (blockEntityId == 138) discard;
	#endif

	vec4 albedo = vec4(0.0);

	#ifdef WRONG_MIPMAP_FIX
		#if !defined COLORED_SHADOWS || !defined OVERWORLD
  			albedo.a = texture2DLod(tex, texCoord.xy, 0).a;
		#else
  			albedo = texture2DLod(tex, texCoord.xy, 0);
		#endif
	#else
		#if !defined COLORED_SHADOWS || !defined OVERWORLD
			albedo.a = texture2D(tex, texCoord.xy).a;
		#else
			albedo = texture2D(tex, texCoord.xy);
		#endif
	#endif

	if (blockEntityId == 200) { // End Gateway Beam Fix
		if (color.r > 0.1) discard;
	}

	if (albedo.a < 0.0001) discard;

    float premult = float(mat > 0.95 && mat < 1.05);
	float water = float(mat > 1.95 && mat < 2.05);
	float ice = float(mat > 2.95 && mat < 3.05);

	#ifdef NO_FOLIAGE_SHADOWS
		if (mat > 3.95 && mat < 4.05) discard;
	#endif

	vec4 albedo0 = albedo;
	if (water > 0.5) {
		if (isEyeInWater < 0.5) {
			albedo0 = vec4(1.0, 1.0, 1.0, 1.0);
			albedo = vec4(0.0, 0.0, 0.0, 1.0);
		} else {
			float dither = Bayer64(gl_FragCoord.xy);
			doWaterShadowCaustics(dither);
		}
	} else albedo0.rgb = vec3(0.0);

	#if !defined COLORED_SHADOWS || !defined OVERWORLD
	if (premult > 0.5) {
		if (albedo.a < 0.51) discard;
	}
	#endif
	
	gl_FragData[0] = clamp(albedo0, vec4(0.0), vec4(1.0));

	#if defined COLORED_SHADOWS && defined OVERWORLD
		vec4 albedoCS = albedo;
		albedoCS.rgb *= 1.0 - albedo.a * albedo.a;

		#if defined PROJECTED_CAUSTICS && defined OVERWORLD
			if (ice > 0.5) albedoCS = (albedo * albedo) * (albedo * albedo);
		#else
			if (ice > 0.5) albedoCS = vec4(0.0, 0.0, 0.0, 1.0);
		#endif

		gl_FragData[1] = clamp(albedoCS, vec4(0.0), vec4(1.0));
	#endif
}

#endif

//////////Vertex Shader//////////Vertex Shader//////////Vertex Shader//////////
#ifdef VSH

//Uniforms//
uniform float rainStrengthS;

uniform vec3 cameraPosition;

uniform mat4 shadowProjection, shadowProjectionInverse;
uniform mat4 shadowModelView, shadowModelViewInverse;
uniform mat4 gbufferModelView;

#if WORLD_TIME_ANIMATION < 2
	uniform float frameTimeCounter;
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

vec2 lmCoord = vec2(0.0);

//Includes//
#include "/lib/vertex/waving.glsl"

#ifdef WORLD_CURVATURE
	#include "/lib/vertex/worldCurvature.glsl"
#endif

//Program//
void main() {
	texCoord = gl_MultiTexCoord0.xy;
	color = gl_Color;
	
	lmCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	lmCoord = clamp((lmCoord - 0.03125) * 1.06667, 0.0, 1.0);
	
	position = shadowModelViewInverse * shadowProjectionInverse * ftransform();

	mat = 0;
	if (mc_Entity.x == 79) mat = 1; //premult
	if (mc_Entity.x == 7979) mat = 3; //ice
	if (mc_Entity.x == 8) {  //water
		#ifdef WATER_DISPLACEMENT
			position.y += WavingWater(position.xyz, lmCoord.y);
		#endif
		mat = 2;
	}
	
	float istopv = gl_MultiTexCoord0.t < mc_midTexCoord.t ? 1.0 : 0.0;
	position.xyz += WavingBlocks(position.xyz, istopv, lmCoord.y);

	#ifdef WORLD_CURVATURE
		position.y -= WorldCurvature(position.xz);
	#endif
	
	gl_Position = shadowProjection * shadowModelView * position;

	float dist = sqrt(gl_Position.x * gl_Position.x + gl_Position.y * gl_Position.y);
	float distortFactor = dist * shadowMapBias + (1.0 - shadowMapBias);

	if (mc_Entity.x ==  31 || mc_Entity.x ==   6 || mc_Entity.x ==  59 || 
		mc_Entity.x == 175 || mc_Entity.x == 176 || mc_Entity.x ==  83 || 
		mc_Entity.x == 104 || mc_Entity.x == 105 || mc_Entity.x == 11019) { // Foliage
		#if !defined NO_FOLIAGE_SHADOWS && SHADOW_SUBSURFACE > 0
			// Counter Shadow Bias
			#ifdef OVERWORLD
				float timeAngleM = timeAngle;
			#else
				#if !defined SEVEN && !defined SEVEN_2
					float timeAngleM = 0.25;
				#else
					float timeAngleM = 0.5;
				#endif
			#endif
			const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
			float ang = fract(timeAngleM - 0.25);
			ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
			vec3 sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);
			#ifdef OVERWORLD
				vec3 lightVec = sunVec * ((timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0);
			#else
				vec3 lightVec = sunVec;
			#endif
			vec3 upVec = normalize(gbufferModelView[1].xyz);
			float NdotLm = clamp(dot(upVec, lightVec) * 1.01 - 0.01, 0.0, 1.0) * 0.99 + 0.01;

			float distortBias = distortFactor * shadowDistance / 256.0;
			distortBias *= 8.0 * distortBias;
			float biasFactor = sqrt(1.0 - NdotLm * NdotLm) / NdotLm;
			float bias = (distortBias * biasFactor + 0.05) / shadowMapResolution;

			#if PIXEL_SHADOWS > 0
				bias += 0.0025 / PIXEL_SHADOWS;
			#endif
			gl_Position.z -= bias * 11.0;
		#else
			mat = 4;
		#endif
	}
	
	gl_Position.xy *= 1.0 / distortFactor;
	gl_Position.z = gl_Position.z * 0.2;
}

#endif