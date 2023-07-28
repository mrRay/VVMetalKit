//	adapted from http://transitions.glsl.io/transition/35e8c18557995c77278e


const constant float2 fadeCenter = float2(0.5, 0.5);
const constant float fadeCenterSmoothness = 0.25;
const constant float fadeCenter_SQRT_2 = 1.414213562373;
const constant bool fadeCenterOpening = true;


float4 CompositeTopAndBottom(thread float4 & bottom, thread float4 & top, thread float & topAlpha, thread MSLCompModeFragData & fragData)
{
	float2		p = fragData.gl_FragCoord.xy / fragData._VVCanvasRect.zw;
	float4		darkenedBottom = float4(bottom.a) * bottom;
	darkenedBottom.a = bottom.a;
	float4		returnMe = darkenedBottom;

	float		x = fadeCenterOpening ? topAlpha : 1.0-topAlpha;
	float		m = smoothstep(-fadeCenterSmoothness, 0.0, fadeCenter_SQRT_2*distance(fadeCenter, p) - x*(1.+fadeCenterSmoothness));
	
	returnMe = mix(darkenedBottom, top, fadeCenterOpening ? 1.-m : m);
	return returnMe;
}

float4 CompositeBottom(thread float4 & bottom, thread float & bottomAlpha, thread MSLCompModeFragData & fragData)	{
	float2		p = fragData.gl_FragCoord.xy / fragData._VVCanvasRect.zw;
	float4		darkenedBottom = float4(0.0);
	float4		returnMe = darkenedBottom;

	float		x = fadeCenterOpening ? bottomAlpha : 1.0-bottomAlpha;
	float		m = smoothstep(-fadeCenterSmoothness, 0.0, fadeCenter_SQRT_2*distance(fadeCenter, p) - x*(1.+fadeCenterSmoothness));
	
	returnMe = mix(darkenedBottom, bottom, fadeCenterOpening ? 1.-m : m);
	return returnMe;
}

//vec4 CompositeTop(vec4 top, float topAlpha)	{
//	return vec4(0.0, 0.0, 0.0, 0.0);
//}
