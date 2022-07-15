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
uniform float viewWidth, viewHeight, aspectRatio;

uniform float rainStrengthS;

uniform sampler2D colortex0;

//Optifine Constants//
const bool colortex0MipmapEnabled = true;

//Common Variables//
float pw = 1.0 / viewWidth;
float ph = 1.0 / viewHeight;

float weight[7] = float[7](1.0, 6.0, 15.0, 20.0, 15.0, 6.0, 1.0);

//Common Functions//
vec3 BloomTile(float lod, vec2 offset, vec2 rescale) {
	vec3 bloom = vec3(0.0);
	float scale = exp2(lod);
	vec2 coord = (texCoord - offset) * scale;
	float padding = 0.5 + 0.005 * scale;

	if (abs(coord.x - 0.5) < padding && abs(coord.y - 0.5) < padding) {
		for(int i = -3; i <= 3; i++) {
			for(int j = -3; j <= 3; j++) {
				float wg = weight[i + 3] * weight[j + 3];
				vec2 pixelOffset = vec2(i, j) * rescale;
				vec2 bloomCoord = (texCoord - offset + pixelOffset) * scale;
				bloom += texture2D(colortex0, bloomCoord).rgb * wg;
			}
		}
		bloom /= 4096.0;
	}

	return pow(bloom / 128.0, vec3(0.25));
}

//Includes//

//Program//
void main() {
	#ifndef ANAMORPHIC_BLOOM
		vec2 rescale = 1.0 / vec2(1920.0, 1080.0);

		#if !defined NETHER
			vec3 blur = BloomTile(2.0, vec2(0.0      , 0.0   ), rescale);
				blur += BloomTile(3.0, vec2(0.0      , 0.26  ), rescale);
				blur += BloomTile(4.0, vec2(0.135    , 0.26  ), rescale);
				blur += BloomTile(5.0, vec2(0.2075   , 0.26  ), rescale) * 0.8;
				blur += BloomTile(6.0, vec2(0.135    , 0.3325), rescale) * 0.8;
				blur += BloomTile(7.0, vec2(0.160625 , 0.3325), rescale) * 0.6;
				blur += BloomTile(8.0, vec2(0.1784375, 0.3325), rescale) * 0.4;
		#else
			vec3 blur = BloomTile(2.0, vec2(0.0      , 0.0   ), rescale);
				blur += BloomTile(3.0, vec2(0.0      , 0.26  ), rescale);
				blur += BloomTile(4.0, vec2(0.135    , 0.26  ), rescale);
				blur += BloomTile(5.0, vec2(0.2075   , 0.26  ), rescale);
				blur += BloomTile(6.0, vec2(0.135    , 0.3325), rescale);
				blur += BloomTile(7.0, vec2(0.160625 , 0.3325), rescale);
				blur += BloomTile(8.0, vec2(0.1784375, 0.3325), rescale) * 0.6;
		#endif
	#else
		vec3 bloom = vec3(0.0);
		float scale = 4.0;
		vec2 coord = texCoord * scale;
		float padding = 0.52;

		if (abs(coord.x - 0.5) < padding && abs(coord.y - 0.5) < padding) {
			for(int i = -27; i <= 27; i++) {
				for(int j = -3; j <= 3; j++) {
					float wg = pow(0.9, abs(2.0 * i) + 1.0);
					float hg = weight[j + 3];
					hg *= hg / 400.0;
					vec2 pixelOffset = vec2(i * pw, j * ph);
					vec2 bloomCoord = (texCoord + pixelOffset) * scale;
					bloom += texture2D(colortex0, bloomCoord).rgb * wg * hg;
				}
			}
			bloom /= 128.0;
		}

		vec3 blur = pow(bloom / 128.0, vec3(0.25));
		blur = clamp(blur, vec3(0.0), vec3(1.0));
	#endif

    /* DRAWBUFFERS:1 */
	gl_FragData[0] = vec4(blur, 1.0);
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