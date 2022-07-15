#if defined MOON_PHASE_LIGHTING && !defined UNIFORM_moonPhase
	#define UNIFORM_moonPhase
	uniform int moonPhase;
#endif

#ifndef MOON_PHASE_LIGHTING
	float nightBrightness = NIGHT_BRIGHTNESS;
#else
	float nightBrightness = moonPhase == 0 ? NIGHT_BRIGHTNESS * NIGHT_LIGHTING_FULL_MOON :
							moonPhase != 4 ? NIGHT_BRIGHTNESS * NIGHT_LIGHTING_PARTIAL_MOON :
											 NIGHT_BRIGHTNESS * NIGHT_LIGHTING_NEW_MOON;
#endif

vec3 lightMorning    = vec3(LIGHT_MR, LIGHT_MG, LIGHT_MB) * LIGHT_MI / 255.0;
vec3 lightDay        = vec3(LIGHT_DR, LIGHT_DG, LIGHT_DB) * LIGHT_DI / 255.0;
vec3 lightEvening    = vec3(LIGHT_ER, LIGHT_EG, LIGHT_EB) * LIGHT_EI / 255.0;
#ifndef ONESEVEN
vec3 lightNight      = vec3(LIGHT_NR, LIGHT_NG, LIGHT_NB) * LIGHT_NI * (vsBrightness*0.125 + 0.80) * 0.4 / 255.0 * nightBrightness;
#else
vec3 lightNight      = (vec3(LIGHT_NR, LIGHT_NG, LIGHT_NB) * LIGHT_NI * 0.195 / 255.0) + vec3(0.37, 0.31, 0.25) * 0.35 ;
#endif

vec3 ambientMorning  = vec3(AMBIENT_MR, AMBIENT_MG, AMBIENT_MB) * AMBIENT_MI * 1.1 / 255.0;
vec3 ambientDay      = vec3(AMBIENT_DR, AMBIENT_DG, AMBIENT_DB) * AMBIENT_DI * 1.1 / 255.0;
vec3 ambientEvening  = vec3(AMBIENT_ER, AMBIENT_EG, AMBIENT_EB) * AMBIENT_EI * 1.1 / 255.0;
vec3 ambientNight    = vec3(AMBIENT_NR, AMBIENT_NG, AMBIENT_NB) * AMBIENT_NI * (vsBrightness*0.20 + 0.70) * 0.495 / 255.0 * nightBrightness;

vec3 weatherCol = vec3(WEATHER_RR, WEATHER_RG, WEATHER_RB) * WEATHER_RI / 255.0;
vec3 weatherIntensity = vec3(WEATHER_RI);

float mefade = 1.0 - clamp(abs(timeAngle - 0.5) * 8.0 - 1.5, 0.0, 1.0);
float dfade = 1.0 - timeBrightness;
float dfadeM = dfade * dfade;
float dfadeM2 = 1.0 - dfade * dfade;

vec3 meL = mix(lightMorning, lightEvening, mefade);
vec3 dayAllL = mix(meL, lightDay, dfadeM2);
vec3 cL = mix(lightNight, dayAllL, sunVisibility);
vec3 cL2 = mix(cL, dot(cL, vec3(0.299, 0.587, 0.114)) * weatherCol * (vsBrightness*0.1 + 0.9), rainStrengthS*0.6);
vec3 lightCol = cL2 * cL2;

vec3 meA = mix(ambientMorning, ambientEvening, mefade);
vec3 dayAllA = mix(meA, ambientDay, dfadeM2);
vec3 cA = mix(ambientNight, dayAllA, sunVisibility);
vec3 cA2 = mix(cA, dot(cA, vec3(0.299, 0.587, 0.114)) * weatherCol * (vsBrightness*0.1 + 0.9), rainStrengthS*0.6);
vec3 ambientCol = cA2 * cA2;