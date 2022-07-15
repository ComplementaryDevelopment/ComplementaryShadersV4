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
uniform sampler2D colortex1;

uniform float viewWidth, viewHeight;

#if THE_FORBIDDEN_OPTION > 0
	uniform float frameTimeCounter;
#endif

#if defined GRAY_START || (defined WATERMARK && WATERMARK_DURATION < 900)
	uniform float starter;
#endif

#ifdef WATERMARK
	uniform sampler2D depthtex2;
#endif

//Optifine Constants//
/*
const int colortex0Format = R11F_G11F_B10F; //main
const int colortex1Format = RGB8; 			//raw albedo & raw translucent & water mask & vl & bloom
const int colortex2Format = RGBA16;		    //temporal stuff
const int colortex3Format = RGB8; 			//specular & skymapMod
const int gaux1Format = R8; 				//half-res ao
const int gaux2Format = RGBA8;			    //reflection
const int gaux3Format = RG16; 				//normals
const int gaux4Format = RGB8; 				//taa mask & galaxy image

#ifdef COLORED_LIGHT
	const int colortex8Format = RGB16;
	const int colortex9Format = RGB16;
#endif
*/

const bool shadowHardwareFiltering = true;
const float shadowDistanceRenderMul = 1.0;

const float entityShadowDistanceMul = 0.125; // Iris devs may bless us with their power

const int noiseTextureResolution = 512;

const float drynessHalflife = 300.0;
const float wetnessHalflife = 300.0;

const float ambientOcclusionLevel = 1.0;

//Common Functions//
#if SHARPEN > 0
	vec2 sharpenOffsets[4] = vec2[4](
		vec2( 1.0,  0.0),
		vec2( 0.0,  1.0),
		vec2(-1.0,  0.0),
		vec2( 0.0, -1.0)
	);

	void SharpenFilter(inout vec3 color, vec2 texCoord2) {
		float mult = SHARPEN * 0.025;
		vec2 view = 1.0 / vec2(viewWidth, viewHeight);

		color *= SHARPEN * 0.1 + 1.0;

		for(int i = 0; i < 4; i++) {
			vec2 offset = sharpenOffsets[i] * view;
			color -= texture2DLod(colortex1, texCoord2 + offset, 0).rgb * mult;
		}
	}
#endif

#ifdef GRAY_START
	float GetLuminance(vec3 color) {
		return dot(color, vec3(0.299, 0.587, 0.114));
	}
#endif

//Program//
void main() {
	#ifndef OVERDRAW
		vec2 texCoord2 = texCoord;
	#else
		vec2 texCoord2 = (texCoord - vec2(0.5)) * (2.0 / 3.0) + vec2(0.5);
	#endif
	
	/*
	vec2 wh = vec2(viewWidth, viewHeight);
	wh /= 32.0;
	texCoord2 = floor(texCoord2 * wh) / wh;
	*/

	#if CHROMATIC_ABERRATION < 1
		vec3 color = texture2DLod(colortex1, texCoord2, 0).rgb;
	#else
		float midDistX = texCoord2.x - 0.5;
		float midDistY = texCoord2.y - 0.5;
		vec2 scale = vec2(1.0, viewHeight / viewWidth);
		vec2 aberration = vec2(midDistX, midDistY) * (2.0 / vec2(viewWidth, viewHeight)) * scale * CHROMATIC_ABERRATION;
		vec3 color = vec3(texture2DLod(colortex1, texCoord2 + aberration, 0).r,
						  texture2DLod(colortex1, texCoord2, 0).g,
						  texture2DLod(colortex1, texCoord2 - aberration, 0).b);
	#endif

	#if SHARPEN > 0
		SharpenFilter(color, texCoord2);
	#endif
	
	#if THE_FORBIDDEN_OPTION > 0
		#if THE_FORBIDDEN_OPTION < 3
			float fractTime = fract(frameTimeCounter*0.01);
			color = pow(vec3(1.0) - color, vec3(5.0));
			color = vec3(color.r + color.g + color.b)*0.5;
			color.g = 0.0;
			if (fractTime < 0.5)  color.b *= fractTime, color.r *= 0.5 - fractTime;
			if (fractTime >= 0.5) color.b *= 1 - fractTime, color.r *= fractTime - 0.5;
			color = pow(color, vec3(1.8))*8;
		#else
			float colorM = dot(color, vec3(0.299, 0.587, 0.114));
			color = vec3(colorM);
		#endif
	#endif

	#ifdef WATERMARK
		#if WATERMARK_DURATION < 900
			if (starter < 0.99) {
		#endif
				vec2 textCoord = vec2(texCoord.x, 1.0 - texCoord.y);
				vec4 compText = texture2D(depthtex2, textCoord);
				//compText.rgb = pow(compText.rgb, vec3(2.2));
				#if WATERMARK_DURATION < 900
					float starterFactor = 1.0 - 2.0 * abs(starter - 0.5);
					starterFactor = max(starterFactor - 0.333333, 0.0) * 3.0;
					starterFactor = smoothstep(0.0, 1.0, starterFactor);
				#else
					float starterFactor = 1.0;
				#endif
				color.rgb = mix(color.rgb, compText.rgb, compText.a * starterFactor);
		#if WATERMARK_DURATION < 900
			}
		#endif
	#endif

	#ifdef GRAY_START
		float animation = min(starter, 0.1) * 10.0;
		vec3 grayStart = vec3(GetLuminance(color.rgb));
		color.rgb = mix(grayStart, color.rgb, animation);
	#endif

	gl_FragColor = vec4(color, 1.0);
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