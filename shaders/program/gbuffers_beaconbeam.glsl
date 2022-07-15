/*
Complementary Shaders by EminGT, based on BSL Shaders by Capt Tatsu
*/

//Common//
#include "/lib/common.glsl"

//Varyings//
varying vec2 texCoord;

varying vec4 color;

//////////Fragment Shader//////////Fragment Shader//////////Fragment Shader//////////
#ifdef FSH

//Uniforms//
uniform sampler2D texture;

//Includes//
#include "/lib/color/blocklightColor.glsl"

//Program//
void main() {
    vec4 albedoP = texture2D(texture, texCoord);
	vec4 albedo = albedoP * color;
    
	albedo.rgb = pow(albedo.rgb, vec3(2.2));
	
	#ifdef WHITE_WORLD
		albedo.rgb = vec3(2.0);
	#endif

	float emissive = 0.0;

	// duplicate 39582069
	#ifdef COMPBR
		emissive = length(albedoP.rgb);
		emissive *= emissive;
		emissive *= emissive;
		if (color.a < 0.9) emissive = pow2(emissive * emissive) * 0.01;
		else emissive = emissive * 0.1;
	#else
		emissive = dot(albedoP, albedoP) * 0.1;
	#endif

	vec3 emissiveLighting = albedo.rgb * emissive * 20.0 * EMISSIVE_MULTIPLIER;
    albedo.rgb *= emissiveLighting;
	albedo.a *= albedo.a * albedo.a;

	#if MC_VERSION < 10800
		albedo.a = max(albedo.a, 0.101);
		albedo.rgb *= 0.125;
	#endif
    
	#ifdef GBUFFER_CODING
		albedo.rgb = vec3(0.0, 170.0, 170.0) / 255.0;
		albedo.rgb = pow(albedo.rgb, vec3(2.2)) * 0.5;
	#endif

    /* DRAWBUFFERS:03 */
	gl_FragData[0] = albedo;
	gl_FragData[1] = vec4(0.0, 0.0, 0.0, 1.0);

	#if defined ADV_MAT && defined REFLECTION_SPECULAR
	/* DRAWBUFFERS:0361 */
	gl_FragData[2] = vec4(0.0, 0.0, float(gl_FragCoord.z < 1.0), 1.0);
	gl_FragData[3] = vec4(0.0, 0.0, 0.0, 1.0);
	#endif
}

#endif

//////////Vertex Shader//////////Vertex Shader//////////Vertex Shader//////////
#ifdef VSH

//Uniforms//
#if AA == 2 || AA == 3
uniform int frameCounter;

uniform float viewWidth;
uniform float viewHeight;
#include "/lib/util/jitter.glsl"
#endif
#if AA == 4
uniform int frameCounter;

uniform float viewWidth;
uniform float viewHeight;
#include "/lib/util/jitter2.glsl"
#endif

#ifdef WORLD_CURVATURE
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
#endif

//Includes//
#ifdef WORLD_CURVATURE
	#include "/lib/vertex/worldCurvature.glsl"
#endif

//Program//
void main() {
	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

	color = gl_Color;

	#ifdef WORLD_CURVATURE
		vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
		if (gl_ProjectionMatrix[2][2] < -0.5) position.y -= WorldCurvature(position.xz);
		gl_Position = gl_ProjectionMatrix * gbufferModelView * position;
	#else
		gl_Position = ftransform();
	#endif
	
	#if AA > 1
		gl_Position.xy = TAAJitter(gl_Position.xy, gl_Position.w);
	#endif
}

#endif