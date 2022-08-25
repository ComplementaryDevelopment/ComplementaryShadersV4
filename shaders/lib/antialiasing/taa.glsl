/*
Complementary Shaders by EminGT, based on BSL Shaders by Capt Tatsu
*/

#include "/lib/util/reprojection.glsl"

ivec2 neighbourhoodOffsets[8] = ivec2[8](
	ivec2(-1, -1),
	ivec2( 0, -1),
	ivec2( 1, -1),
	ivec2(-1,  0),
	ivec2( 1,  0),
	ivec2(-1,  1),
	ivec2( 0,  1),
	ivec2( 1,  1)
);

void NeighbourhoodClamping(vec3 color, inout vec3 tempColor, float depth, inout float edge) {
	vec3 minclr = color, maxclr = color;

	ivec2 texelCoord = ivec2(gl_FragCoord.xy);

	for (int i = 0; i < 8; i++) {
		float depthCheck = texelFetch(depthtex1, texelCoord + neighbourhoodOffsets[i], 0).r;
		if (abs(GetLinearDepth(depthCheck) - GetLinearDepth(depth)) > 0.09) edge = 0.25;
		vec3 clr = texelFetch(colortex1, texelCoord + neighbourhoodOffsets[i], 0).rgb;
		minclr = min(minclr, clr); maxclr = max(maxclr, clr);
	}

	tempColor = clamp(tempColor, minclr, maxclr);
}

void TAA(inout vec3 color, inout vec4 temp) {
	float depth = texture2D(depthtex1, texCoord).r;
	float noTAA = texture2D(colortex7, texCoord).r;
	if (depth < 0.56 || noTAA > 0.5) { // Fixes entities and hand
		return;
	}

	vec3 coord = vec3(texCoord, depth);
	vec2 prvCoord = Reprojection(coord);
	
	vec2 view = vec2(viewWidth, viewHeight);
	vec3 tempColor = texture2D(colortex2, prvCoord).gba;
	if (tempColor == vec3(0.0)) { // Fixes the first frame
		temp = vec4(temp.r, color);
		return;
	}

	float edge = 0.0;
	NeighbourhoodClamping(color, tempColor, depth, edge);
	
	vec2 velocity = (texCoord - prvCoord.xy) * view;

	float blendFactor = float(prvCoord.x > 0.0 && prvCoord.x < 1.0 &&
	                          prvCoord.y > 0.0 && prvCoord.y < 1.0);
	#if AA == 2 || AA == 3
		float blendMinimum = 0.3;
	#elif AA == 4
		float blendMinimum = 0.6;
	#endif
	float blendVariable = 0.25;
	float blendConstant = 0.65;

	float lengthVelocity = length(velocity) * 50;
	blendFactor *= max(exp(-lengthVelocity) * blendVariable + blendConstant - lengthVelocity * edge, blendMinimum);
	
	color = mix(color, tempColor, blendFactor);
	temp = vec4(temp.r, color);
	//if (edge > 0.05) color.rgb = vec3(1.0, 0.0, 1.0);
}