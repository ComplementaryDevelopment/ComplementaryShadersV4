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
		if (CheckForColor(albedo.rgb, vec3(11, 33, 42)) // Pixels on Warden
		||  CheckForColor(albedo.rgb, vec3(5, 98, 93))
		||  CheckForColor(albedo.rgb, vec3(13, 18, 23))
		||  CheckForColor(albedo.rgb, vec3(41, 223, 235))
		||  CheckForColor(albedo.rgb, vec3(0, 146, 149))
		||  CheckForColor(albedo.rgb, vec3(64, 87, 108))
		||  CheckForColor(albedo.rgb, vec3(3, 65, 80))) {
			// Warden Ears
			if (texCoord.x > 0.453125 && (texCoord.x < 0.703125 && texCoord.y > 0.046875 && texCoord.y < 0.125
									   || texCoord.x < 0.609375 && texCoord.y > 0.296875 && texCoord.y < 0.375))
				albedo = albedo;

			// Warden Heart
			else if (texCoord.x > 0.125 && texCoord.x < 0.1796875 && texCoord.y > 0.140625 && texCoord.y < 0.2109375)
				albedo = vec4(pow(albedo.rgb, vec3(0.7)) * (1.0 + 0.1), albedo.a + 0.1);

			else albedo = vec4(albedo.rgb * sqrt4(albedo.a) * 1.0, albedo.a + 0.101);
		}

		albedo.rgb = pow(albedo.rgb, vec3(3.6));
		albedo.rgb *= pow(1.0 + albedo.b, 3.0);
	#else
   		albedo.rgb = pow(albedo.rgb, vec3(3.6));
	#endif
	
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