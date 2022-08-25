void GetMaterials(out float smoothness, out float metalness, out float f0, out float metalData, 
                  inout float emissive, out float materialAO, out vec4 normalMap,
                  vec2 newCoord, vec2 dcdx, vec2 dcdy) {
	#ifdef MC_SPECULAR_MAP 
		#ifdef WRONG_MIPMAP_FIX
			vec4 specularMap = texture2DLod(specular, newCoord, 0);
		#else
			vec4 specularMap = texture2D(specular, newCoord);
		#endif
	#else
		vec4 specularMap = vec4(0.0, 0.0, 0.0, 1.0);
	#endif

	#ifdef NORMAL_MAPPING
		normalMap = textureGrad(normals, newCoord, dcdx, dcdy).rgba;

		normalMap.xyz += vec3(0.5, 0.5, 0.0);
		normalMap.xyz = pow(normalMap.xyz, vec3(NORMAL_MULTIPLIER));
		normalMap.xyz -= vec3(0.5, 0.5, 0.0);
	#endif
	
	#if RP_SUPPORT == 4
		smoothness = specularMap.r;
		
		metalness = specularMap.g;
		f0 = 0.78 * metalness + 0.02;
		metalData = metalness;

		materialAO = 1.0;

		float materialEmissive = specularMap.b;

		#ifdef NORMAL_MAPPING
			normalMap.xyz = normalMap.xyz * 2.0 - 1.0;
		#endif
	#else
		smoothness = specularMap.r;

		f0 = specularMap.g;
		metalness = f0 >= 0.9 ? 1.0 : 0.0;
		metalData = f0;
	
		#ifdef NORMAL_MAPPING
			materialAO = normalMap.z;
		#else
			materialAO = texture2D(normals, newCoord).z;
		#endif
		materialAO *= materialAO;

		float materialEmissive = specularMap.a < 1.0 ? specularMap.a : 0.0;
		
		#ifdef NORMAL_MAPPING
			normalMap.xyz = normalMap.xyz * 2.0 - 1.0;
			float normalCheck = normalMap.x + normalMap.y;
			if (normalCheck > -1.999) {
				if (length(normalMap.xy) > 1.0) normalMap.xy = normalize(normalMap.xy);
				normalMap.z = sqrt(1.0 - dot(normalMap.xy, normalMap.xy));
				normalMap.xyz = normalize(clamp(normalMap.xyz, vec3(-1.0), vec3(1.0)));
			} else {
				normalMap.xyz = vec3(0.0, 0.0, 1.0);
				materialAO = 1.0;
			}
		#endif
	#endif
	
	materialEmissive = pow(materialEmissive, 2.5 + 2.0 * materialEmissive);
	emissive = mix(materialEmissive, 1.0, emissive);
	
	materialAO = clamp(materialAO, 0.01, 1.0);
}