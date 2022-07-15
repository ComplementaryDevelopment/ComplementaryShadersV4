// This mipLevel is corrected to give the result for 16x textures regardless of the actual texture resolution
vec2 mipx = dcdx / vTexCoordAM.zw * 16.0;
vec2 mipy = dcdy / vTexCoordAM.zw * 16.0;
float delta = max(dot(mipx, mipx), dot(mipy, mipy));
float miplevel = max(0.5 * log2(delta), 0.0);