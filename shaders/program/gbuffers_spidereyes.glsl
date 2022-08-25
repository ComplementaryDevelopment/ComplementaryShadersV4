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

//Program//
void main() {
    vec4 albedo = texture2D(texture, texCoord.xy) * color;
	
	#ifdef COMPBR
		if (CheckForColor(albedo.rgb, vec3(224, 121, 250))) { // Enderman Eye Edges
			albedo.rgb = vec3(0.8, 0.25, 0.8);
		}
	#endif

	albedo.rgb = pow1_5(albedo.rgb);
	albedo.rgb *= pow2(1.0 + albedo.b + 0.5 * albedo.g) * 1.5;

	albedo.rgb = pow(albedo.rgb, vec3(2.2)) * 0.35;
	
    #ifdef WHITE_WORLD
		albedo.rgb = vec3(2.0);
	#endif

	#ifdef GBUFFER_CODING
		albedo.rgb = vec3(170.0, 0.0, 0.0) / 255.0;
		albedo.rgb = pow(albedo.rgb, vec3(2.2)) * 0.5;
	#endif
	
    /* DRAWBUFFERS:0 */
	gl_FragData[0] = albedo;

	#if defined ADV_MAT && defined REFLECTION_SPECULAR
	/* DRAWBUFFERS:0361 */
	gl_FragData[1] = vec4(0.0, 0.0, 0.0, 1.0);
	gl_FragData[2] = vec4(0.0, 0.0, 0.0, 1.0);
	gl_FragData[3] = vec4(0.0, 0.0, 0.0, 1.0);
	#endif
}

#endif

//////////Vertex Shader//////////Vertex Shader//////////Vertex Shader//////////
#ifdef VSH

//Uniforms//
#ifdef WORLD_CURVATURE
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
#endif

//Attributes//

//Includes//
#ifdef WORLD_CURVATURE
	#include "/lib/vertex/worldCurvature.glsl"
#endif

//Program//
void main(){
	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	color = gl_Color;

	#ifdef WORLD_CURVATURE
		vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
		position.y -= WorldCurvature(position.xz);
		gl_Position = gl_ProjectionMatrix * gbufferModelView * position;
	#else
		gl_Position = ftransform();
	#endif
}

#endif