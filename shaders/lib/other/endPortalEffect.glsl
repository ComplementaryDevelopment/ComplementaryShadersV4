// End Portal fix by fayer3#2332 (Modified)
if (blockEntityId == 200) {
    if (albedo.b < 10.1) {
        vec3[9] colors = vec3[](
            vec3(0.347247, 0.605995, 0.758838) * 1.5,
            vec3(0.601078, 0.715565, 1.060625),
            vec3(0.422100, 0.813094, 0.902606),
            vec3(0.349221, 1.024201, 1.861281),
            vec3(0.754305, 0.828697, 0.680323),
            vec3(0.414472, 0.568165, 0.8037  ) * 0.9,
            vec3(0.508905, 0.679649, 0.998285) * 0.9,
            vec3(0.531914, 0.547583, 0.800852) * 0.7,
            vec3(0.261914, 0.747583, 0.700852) * 0.5);
        albedo.rgb = vec3(0.4214321, 0.4722309, 1.9922364) * 0.07;  

        float dither = Bayer64(gl_FragCoord.xy);
        #if AA > 1
            dither = fract(dither + frameTimeCounter * 16.0);
            int repeat = 4;
        #else
            int repeat = 8;
        #endif
        float dismult = 0.5;
        for (int j = 0; j < repeat; j++) {
            float add = float(j + dither) * 0.0625 / float(repeat);
            int samples = 9;
            if (j > 2) samples = 6;
            for (int i = 1; i <= samples; i++) {
                float colormult = 0.9/(30.0+i);
                vec2 offset = vec2(0.0, 1.0/(3600.0/24.0)) * pow(16.0 - i, 2.0) * 0.004;

                vec3 wpos = normalize((gbufferModelViewInverse * vec4(viewPos * (i * dismult + 1), 1.0)).xyz);
                if (abs(dot(normal, upVec)) > 0.9) {
                    wpos.xz /= wpos.y;
                    wpos.xz *= 0.06 * sign(- worldPos.y);
                    wpos.xz *= abs(worldPos.y) + i * dismult + add;
                    wpos.xz -= cameraPosition.xz * 0.05;
                } else {
                    vec3 absPos = abs(worldPos);
                    if (abs(dot(normal, eastVec)) > 0.9) {
                        wpos.xz = wpos.yz / wpos.x;
                        wpos.xz *= 0.06 * sign(- worldPos.x);
                        wpos.xz *= abs(worldPos.x) + i * dismult + add;
                        wpos.xz -= cameraPosition.yz * 0.05;
                    } else {
                        wpos.xz = wpos.yx / wpos.z;
                        wpos.xz *= 0.06 * sign(- worldPos.z);
                        wpos.xz *= abs(worldPos.z) + i * dismult + add;
                        wpos.xz -= cameraPosition.yx * 0.05;
                    }
                }
                vec2 pos = wpos.xz;

                vec2 wind = fract((frametime + 984.0) * (i + 8) * 0.125 * offset);
                vec2 coord = pos + wind;
                if (mod(float(i), 4) < 1.5) coord = coord.yx + vec2(-1.0, 1.0) * wind.y;
                
                vec3 psample = pow(texture2D(texture, coord).rgb, vec3(0.85)) * colors[i-1] * colormult;
                albedo.rgb += psample * length(psample.rgb) * (2500.0 / repeat);
            }
        }
    } else {
        albedo.rgb *= 2.2;
        emissive = 0.25;
    }
    quarterNdotU = 1.0;
    lightmap = vec2(0.9, 0.0);
}