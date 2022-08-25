/*
Complementary Shaders by EminGT, based on BSL Shaders by Capt Tatsu
*/ 

//Common//
#include "/lib/common.glsl"

//Varyings//
varying vec2 texCoord;

//////////Fragment Shader//////////Fragment Shader//////////Fragment Shader//////////
#ifdef FSH

//Uniforms//
uniform sampler2D colortex0;

#if defined DOF_IS_ON || (defined NETHER_BLUR && defined NETHER)

uniform int isEyeInWater;

uniform float viewWidth, viewHeight, aspectRatio;

uniform sampler2D depthtex1;
uniform sampler2D depthtex0;

uniform mat4 gbufferProjection;

#if DOF == 2 || (defined NETHER_BLUR && defined NETHER)
	uniform mat4 gbufferProjectionInverse;

	uniform float rainStrengthS;
	uniform ivec2 eyeBrightnessSmooth;
#endif

#if DOF == 1 && !(defined NETHER_BLUR && defined NETHER) && DOF_FOCUS == 0
	uniform float centerDepthSmooth;
#endif

#if DOF == 1 && !(defined NETHER_BLUR && defined NETHER) && DOF_FOCUS > 0
	uniform float far, near;
#endif

//Optifine Constants//
const bool colortex0MipmapEnabled = true;

//Common Variables//
vec2 dofOffsets[18] = vec2[18](
	vec2( 0.0    ,  0.25  ),
	vec2(-0.2165 ,  0.125 ),
	vec2(-0.2165 , -0.125 ),
	vec2( 0      , -0.25  ),
	vec2( 0.2165 , -0.125 ),
	vec2( 0.2165 ,  0.125 ),
	vec2( 0      ,  0.5   ),
	vec2(-0.25   ,  0.433 ),
	vec2(-0.433  ,  0.25  ),
	vec2(-0.5    ,  0     ),
	vec2(-0.433  , -0.25  ),
	vec2(-0.25   , -0.433 ),
	vec2( 0      , -0.5   ),
	vec2( 0.25   , -0.433 ),
	vec2( 0.433  , -0.2   ),
	vec2( 0.5    ,  0     ),
	vec2( 0.433  ,  0.25  ),
	vec2( 0.25   ,  0.433 )
);

#if DOF == 2 || (defined NETHER_BLUR && defined NETHER)
	float eBS = eyeBrightnessSmooth.y / 240.0;
#endif

//Common Functions//
vec3 GetBlur(vec3 color, float z) {
	vec3 dof = vec3(0.0);
	float hand = float(z < 0.56);

	#if DOF == 2 || (defined NETHER && defined NETHER_BLUR)
		float z0 = texture2D(depthtex0, texCoord.xy).r;
		vec4 screenPos = vec4(texCoord.x, texCoord.y, z0, 1.0);
		vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
		viewPos /= viewPos.w;
	#endif

	#if defined NETHER && defined NETHER_BLUR
		// Nether Blur
		float coc = max(min(length(viewPos) * 0.001, 0.1) * NETHER_BLUR_STRENGTH / 256, 0.0);
	#elif DOF == 2
		// Distance Blur
		float coc = min(length(viewPos) * 0.001, 0.1) * DOF_STRENGTH
					* (1.0 + max(rainStrengthS * eBS * RAIN_BLUR_MULT, isEyeInWater * UNDERWATER_BLUR_MULT)) / 256;
		coc = max(coc, 0.0);
	#else
		// Depth Of Field
		#if DOF_FOCUS > 0
			float centerDepthSmooth = (far * (DOF_FOCUS - near)) / (DOF_FOCUS * (far - near));
		#endif
		float coc = max(abs(z - centerDepthSmooth) * 0.125 * DOF_STRENGTH - 0.0001, 0.0);
	#endif
		coc = coc / sqrt(coc * coc + 0.1);

	vec2 dofScale = vec2(1.0, aspectRatio);

	#ifdef ANAMORPHIC_BLUR
		dofScale *= vec2(0.5, 1.5);
	#endif
	#ifdef FOV_SCALED_BLUR
		coc *= gbufferProjection[1][1] / 1.37;
	#endif
	#ifdef CHROMATIC_BLUR
		float midDistX = texCoord.x - 0.5;
		float midDistY = texCoord.y - 0.5;
		vec2 chromaticScale = vec2(midDistX, midDistY);
		chromaticScale = sign(chromaticScale) * sqrt(abs(chromaticScale));
		chromaticScale *= vec2(1.0, viewHeight / viewWidth);
		vec2 aberration = (15.0 / vec2(viewWidth, viewHeight)) * chromaticScale * coc;
	#endif

	if (coc * 0.5 > 1.0 / max(viewWidth, viewHeight) && hand < 0.5) {
		for(int i = 0; i < 18; i++) {
			vec2 offset = dofOffsets[i] * coc * 0.0085 * dofScale;
			float lod = log2(viewHeight * aspectRatio * coc * 0.75 / 320.0);
			#ifndef CHROMATIC_BLUR
				dof += texture2DLod(colortex0, texCoord + offset, lod).rgb;
			#else
				dof += vec3(texture2DLod(colortex0, texCoord + offset + aberration, lod).r,
							texture2DLod(colortex0, texCoord + offset             , lod).g,
							texture2DLod(colortex0, texCoord + offset - aberration, lod).b);
			#endif
		}
		dof /= 18.0;
	}
	else dof = color;
	return dof;
}

//Includes//

#endif

//Program//
void main() {
	vec3 color = texture2DLod(colortex0, texCoord, 0.0).rgb;
	
	#if defined DOF_IS_ON || (defined NETHER && defined NETHER_BLUR)
	float z = texture2D(depthtex1, texCoord.st).x;

	color = GetBlur(color, z);
	#endif
	
    /*DRAWBUFFERS:0*/
	gl_FragData[0] = vec4(color,1.0);
}

#endif

//////////Vertex Shader//////////Vertex Shader//////////Vertex Shader//////////
#ifdef VSH

//Program//
void main() {
	texCoord = gl_MultiTexCoord0.xy;
	
	gl_Position = ftransform();
}

#endif